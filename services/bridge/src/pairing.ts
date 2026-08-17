import type { BridgeConfig } from "./config.js";
import {
  constantTimeEqual,
  createDeviceCredential,
  createPairingToken,
  hashSecret,
  isPairingToken,
  normalizeDevicePublicKey,
  pairingCompletionPayload,
  randomChallenge,
  randomConfirmationCode,
  randomOpaqueId,
  verifyDeviceSignature,
} from "./crypto.js";
import type {
  BridgeStateDocument,
  BridgeStateStore,
  DeviceRecord,
  PairingRequestRecord,
  PairingSessionRecord,
  DeviceScope,
} from "./state.js";
import { deviceScopes } from "./state.js";

export type PairingErrorCode =
  | "invalid_request"
  | "pairing_not_found"
  | "pairing_token_invalid"
  | "pairing_expired"
  | "pairing_consumed"
  | "pairing_cancelled"
  | "pairing_request_not_found"
  | "pairing_request_expired"
  | "pairing_request_cancelled"
  | "confirmation_invalid"
  | "pairing_not_confirmed"
  | "pairing_completed"
  | "device_revoked"
  | "bridge_not_ready";

export class PairingError extends Error {
  constructor(readonly code: PairingErrorCode, message: string, readonly status: number) {
    super(message);
    this.name = "PairingError";
  }
}

export interface PairingQrPayload {
  protocol_version: 1;
  bridge_endpoint: string;
  server_id: string;
  pairing_session_id: string;
  spki_pin: string;
  pairing_token: string;
  expires_at: string;
}

export interface PairingExchangeInput {
  serverId: string;
  pairingSessionId: string;
  pairingToken: string;
  deviceName: string;
  devicePublicKeySpki: string;
}

export interface PairingExchangeResult {
  pairingRequestId: string;
  deviceId: string;
  deviceName: string;
  deviceFingerprint: string;
  challenge: string;
  status: "awaiting_confirmation";
  expiresAt: string;
}

export interface PendingPairingRequest {
  pairingRequestId: string;
  deviceId: string;
  deviceName: string;
  deviceFingerprint: string;
  confirmationCode: string;
  status: PairingRequestRecord["status"];
  expiresAt: string;
}

export interface PairingRequestStatusResult {
  pairingRequestId: string;
  status: "awaiting_confirmation" | "confirmed" | "expired" | "cancelled";
  expiresAt: string;
}

export interface ConfirmedPairingRequest extends PendingPairingRequest {
  status: "confirmed";
}

export interface CompletedPairing {
  pairingRequestId: string;
  deviceId: string;
  credentialId: string;
  deviceCredential: string;
  scopes: readonly DeviceScope[];
  expiresAt: string;
}

export class PairingService {
  readonly #config: BridgeConfig;
  readonly #store: BridgeStateStore;
  readonly #now: () => Date;

  constructor(config: BridgeConfig, store: BridgeStateStore, now: () => Date = () => new Date()) {
    this.#config = config;
    this.#store = store;
    this.#now = now;
  }

  async createQr(): Promise<PairingQrPayload> {
    const spkiPin = this.#config.currentSpkiPin;
    if (spkiPin === undefined) throw new PairingError("bridge_not_ready", "The bridge certificate pin is not configured.", 503);
    const now = this.#now();
    const expiresAt = new Date(now.getTime() + this.#config.pairingTtlMs).toISOString();
    const sessionId = randomOpaqueId("pairing");
    const token = createPairingToken();
    await this.#store.mutate((state) => {
      expireState(state, now);
      for (const pairing of state.pairings) {
        if (pairing.status === "pending") pairing.status = "cancelled";
      }
      for (const request of state.pairingRequests) {
        if (request.status === "awaiting_confirmation" || request.status === "confirmed") request.status = "cancelled";
      }
      state.pairings.push({
        sessionId,
        tokenHash: token.tokenHash,
        status: "pending",
        createdAt: now.toISOString(),
        expiresAt,
        serverId: this.#config.serverId,
        endpoint: this.#config.endpoint,
        profileId: this.#config.profileId,
        profileName: this.#config.profileName,
        model: this.#config.model,
        spkiPin,
      });
    });
    return {
      protocol_version: 1,
      bridge_endpoint: this.#config.endpoint,
      server_id: this.#config.serverId,
      pairing_session_id: sessionId,
      spki_pin: spkiPin,
      pairing_token: token.token,
      expires_at: expiresAt,
    };
  }

  async exchange(input: PairingExchangeInput): Promise<PairingExchangeResult> {
    const deviceName = displayName(input.deviceName);
    if (input.serverId !== this.#config.serverId) throw new PairingError("pairing_token_invalid", "The pairing token is invalid.", 401);
    if (!opaque(input.pairingSessionId) || !isPairingToken(input.pairingToken)) {
      throw new PairingError("pairing_token_invalid", "The pairing token is invalid.", 401);
    }
    let publicKey;
    try {
      publicKey = normalizeDevicePublicKey(input.devicePublicKeySpki);
    } catch {
      throw new PairingError("invalid_request", "The device public key is invalid.", 400);
    }
    const now = this.#now();
    const requestId = randomOpaqueId("pairing-request");
    const deviceId = randomOpaqueId("device");
    const challenge = randomChallenge();
    const confirmationCode = randomConfirmationCode();
    const requestExpiresAt = new Date(now.getTime() + this.#config.confirmationTtlMs).toISOString();
    return this.#store.mutate((state) => {
      expireState(state, now);
      const session = state.pairings.find((candidate) => candidate.sessionId === input.pairingSessionId);
      if (session === undefined) throw new PairingError("pairing_token_invalid", "The pairing token is invalid.", 401);
      if (!constantTimeEqual(session.tokenHash, hashSecret(input.pairingToken))) {
        throw new PairingError("pairing_token_invalid", "The pairing token is invalid.", 401);
      }
      if (session.status === "expired") throw new PairingError("pairing_expired", "The pairing token has expired.", 410);
      if (session.status === "cancelled") throw new PairingError("pairing_cancelled", "The pairing token has been cancelled.", 410);
      if (session.status === "consumed") throw new PairingError("pairing_consumed", "The pairing token has already been consumed.", 409);
      session.status = "consumed";
      const device: DeviceRecord = {
        deviceId,
        deviceName,
        devicePublicKeySpki: publicKey.spki,
        deviceFingerprint: publicKey.fingerprint,
        scopes: [...deviceScopes],
        status: "pending",
        createdAt: now.toISOString(),
        updatedAt: now.toISOString(),
      };
      const request: PairingRequestRecord = {
        requestId,
        sessionId: session.sessionId,
        deviceId,
        deviceName,
        devicePublicKeySpki: publicKey.spki,
        deviceFingerprint: publicKey.fingerprint,
        challenge,
        confirmationCode,
        status: "awaiting_confirmation",
        createdAt: now.toISOString(),
        expiresAt: requestExpiresAt,
      };
      state.devices.push(device);
      state.pairingRequests.push(request);
      return {
        pairingRequestId: requestId,
        deviceId,
        deviceName,
        deviceFingerprint: publicKey.fingerprint,
        challenge,
        status: "awaiting_confirmation" as const,
        expiresAt: requestExpiresAt,
      };
    });
  }

  async pendingRequests(): Promise<PendingPairingRequest[]> {
    const now = this.#now();
    return this.#store.mutate((state) => {
      expireState(state, now);
      return state.pairingRequests
        .filter((request) => request.status === "awaiting_confirmation" || request.status === "confirmed")
        .map((request) => publicRequest(request));
    });
  }

  async requestStatus(requestId: string, pairingToken: string): Promise<PairingRequestStatusResult> {
    if (!opaque(requestId)) throw new PairingError("pairing_request_not_found", "The pairing request was not found.", 404);
    const now = this.#now();
    return this.#store.mutate((state) => {
      expireState(state, now);
      const request = state.pairingRequests.find((candidate) => candidate.requestId === requestId);
      if (request === undefined) throw new PairingError("pairing_request_not_found", "The pairing request was not found.", 404);
      const session = state.pairings.find((candidate) => candidate.sessionId === request.sessionId);
      assertPairingToken(session, pairingToken);
      return {
        pairingRequestId: request.requestId,
        status: request.status === "completed" ? "confirmed" : request.status,
        expiresAt: request.expiresAt,
      };
    });
  }

  async confirm(requestId: string, deviceName: string, confirmationCode: string): Promise<ConfirmedPairingRequest> {
    if (!opaque(requestId)) throw new PairingError("pairing_request_not_found", "The pairing request was not found.", 404);
    const normalizedName = displayName(deviceName);
    if (!/^\d{6}$/u.test(confirmationCode)) throw new PairingError("confirmation_invalid", "The device confirmation is invalid.", 400);
    const now = this.#now();
    return this.#store.mutate((state) => {
      expireState(state, now);
      const request = state.pairingRequests.find((candidate) => candidate.requestId === requestId);
      if (request === undefined) throw new PairingError("pairing_request_not_found", "The pairing request was not found.", 404);
      if (request.status === "expired") throw new PairingError("pairing_request_expired", "The pairing request has expired.", 410);
      if (request.status === "cancelled") throw new PairingError("pairing_request_cancelled", "The pairing request has been cancelled.", 410);
      if (request.status !== "awaiting_confirmation" || !constantTimeEqual(request.deviceName, normalizedName) || !constantTimeEqual(request.confirmationCode, confirmationCode)) {
        throw new PairingError("confirmation_invalid", "The device confirmation is invalid.", 409);
      }
      request.status = "confirmed";
      request.confirmedAt = now.toISOString();
      return publicRequest(request) as ConfirmedPairingRequest;
    });
  }

  async complete(requestId: string, deviceSignature: string): Promise<CompletedPairing> {
    if (!opaque(requestId)) throw new PairingError("pairing_request_not_found", "The pairing request was not found.", 404);
    if (deviceSignature.length === 0 || deviceSignature.length > 512) throw new PairingError("invalid_request", "The device proof is invalid.", 400);
    const now = this.#now();
    return this.#store.mutate((state) => {
      expireState(state, now);
      const request = state.pairingRequests.find((candidate) => candidate.requestId === requestId);
      if (request === undefined) throw new PairingError("pairing_request_not_found", "The pairing request was not found.", 404);
      if (request.status === "expired") throw new PairingError("pairing_request_expired", "The pairing request has expired.", 410);
      if (request.status === "cancelled") throw new PairingError("pairing_request_cancelled", "The pairing request has been cancelled.", 410);
      if (request.status === "completed") throw new PairingError("pairing_completed", "The pairing request has already been completed.", 409);
      if (request.status !== "confirmed") throw new PairingError("pairing_not_confirmed", "The host has not confirmed this device.", 409);
      if (!verifyDeviceSignature(request.devicePublicKeySpki, pairingCompletionPayload(request.requestId, request.challenge), deviceSignature)) {
        throw new PairingError("invalid_request", "The device proof is invalid.", 401);
      }
      const device = state.devices.find((candidate) => candidate.deviceId === request.deviceId);
      if (device === undefined || device.status !== "pending") throw new PairingError("device_revoked", "The device is not eligible for activation.", 403);
      const credential = createDeviceCredential();
      const credentialId = randomOpaqueId("credential");
      const expiresAt = new Date(now.getTime() + this.#config.credentialTtlMs).toISOString();
      device.status = "active";
      device.updatedAt = now.toISOString();
      request.status = "completed";
      request.completedAt = now.toISOString();
      request.credentialId = credentialId;
      state.credentials.push({
        credentialId,
        deviceId: device.deviceId,
        accessTokenHash: credential.credentialHash,
        status: "active",
        scopes: [...deviceScopes],
        createdAt: now.toISOString(),
        expiresAt,
      });
      return {
        pairingRequestId: request.requestId,
        deviceId: device.deviceId,
        credentialId,
        deviceCredential: credential.credential,
        scopes: [...deviceScopes],
        expiresAt,
      };
    });
  }

  async cancelSession(sessionId: string): Promise<void> {
    if (!opaque(sessionId)) throw new PairingError("pairing_not_found", "The pairing session was not found.", 404);
    await this.#store.mutate((state) => {
      const session = state.pairings.find((candidate) => candidate.sessionId === sessionId);
      if (session === undefined) throw new PairingError("pairing_not_found", "The pairing session was not found.", 404);
      cancelSessionState(state, session);
    });
  }

  async cancelSessionWithPairingToken(sessionId: string, pairingToken: string): Promise<void> {
    if (!opaque(sessionId)) throw new PairingError("pairing_not_found", "The pairing session was not found.", 404);
    await this.#store.mutate((state) => {
      const session = state.pairings.find((candidate) => candidate.sessionId === sessionId);
      assertPairingToken(session, pairingToken);
      cancelSessionState(state, session);
    });
  }

  async cancelRequest(requestId: string): Promise<void> {
    if (!opaque(requestId)) throw new PairingError("pairing_request_not_found", "The pairing request was not found.", 404);
    await this.#store.mutate((state) => {
      const request = state.pairingRequests.find((candidate) => candidate.requestId === requestId);
      if (request === undefined) throw new PairingError("pairing_request_not_found", "The pairing request was not found.", 404);
      if (request.status === "awaiting_confirmation" || request.status === "confirmed") request.status = "cancelled";
    });
  }
}

function expireState(state: BridgeStateDocument, now: Date): void {
  const timestamp = now.getTime();
  for (const pairing of state.pairings) {
    if (pairing.status === "pending" && Date.parse(pairing.expiresAt) <= timestamp) pairing.status = "expired";
  }
  for (const request of state.pairingRequests) {
    if ((request.status === "awaiting_confirmation" || request.status === "confirmed") && Date.parse(request.expiresAt) <= timestamp) request.status = "expired";
  }
}

function publicRequest(request: PairingRequestRecord): PendingPairingRequest {
  return {
    pairingRequestId: request.requestId,
    deviceId: request.deviceId,
    deviceName: request.deviceName,
    deviceFingerprint: request.deviceFingerprint,
    confirmationCode: request.confirmationCode,
    status: request.status,
    expiresAt: request.expiresAt,
  };
}

function assertPairingToken(session: PairingSessionRecord | undefined, pairingToken: string): asserts session is PairingSessionRecord {
  if (session === undefined || !isPairingToken(pairingToken) || !constantTimeEqual(session.tokenHash, hashSecret(pairingToken))) {
    throw new PairingError("pairing_token_invalid", "The pairing token is invalid.", 401);
  }
}

function cancelSessionState(state: BridgeStateDocument, session: PairingSessionRecord): void {
  if (session.status === "pending") session.status = "cancelled";
  for (const request of state.pairingRequests) {
    if (request.sessionId === session.sessionId && (request.status === "awaiting_confirmation" || request.status === "confirmed")) request.status = "cancelled";
  }
}

function opaque(value: string): boolean {
  return value.length > 0 && value.length <= 256 && !/[\u0000-\u001f\u007f]/u.test(value);
}

function displayName(value: string): string {
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > 120 || /[\u0000-\u001f\u007f]/u.test(normalized)) {
    throw new PairingError("invalid_request", "The device name is invalid.", 400);
  }
  return normalized;
}
