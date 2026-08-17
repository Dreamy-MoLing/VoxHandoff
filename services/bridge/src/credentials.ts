import { constantTimeEqual, hashSecret } from "./crypto.js";
import type { BridgeStateStore, DeviceScope } from "./state.js";

export type CredentialErrorCode = "authentication_failed" | "authorization_denied" | "device_not_found";

export class CredentialError extends Error {
  constructor(readonly code: CredentialErrorCode, message: string, readonly status: number) {
    super(message);
    this.name = "CredentialError";
  }
}

export interface AuthenticatedDevice {
  deviceId: string;
  credentialId: string;
  deviceName: string;
  scopes: readonly DeviceScope[];
  expiresAt: string;
}

export interface DeviceSummary {
  deviceId: string;
  deviceName: string;
  deviceFingerprint: string;
  status: "pending" | "active" | "revoked";
  scopes: readonly DeviceScope[];
  createdAt: string;
  updatedAt: string;
}

export class DeviceCredentialService {
  readonly #store: BridgeStateStore;
  readonly #now: () => Date;

  constructor(store: BridgeStateStore, now: () => Date = () => new Date()) {
    this.#store = store;
    this.#now = now;
  }

  async authenticateAuthorization(authorization: string | undefined): Promise<AuthenticatedDevice> {
    const token = bearerToken(authorization);
    const tokenHash = hashSecret(token);
    const now = this.#now();
    const state = await this.#store.snapshot();
    const credential = state.credentials.find((candidate) => constantTimeEqual(candidate.accessTokenHash, tokenHash));
    if (credential === undefined || credential.status !== "active" || Date.parse(credential.expiresAt) <= now.getTime()) {
      throw new CredentialError("authentication_failed", "The device credential is invalid.", 401);
    }
    const device = state.devices.find((candidate) => candidate.deviceId === credential.deviceId);
    if (device === undefined || device.status !== "active") {
      throw new CredentialError("authentication_failed", "The device credential is invalid.", 401);
    }
    if (credential.scopes.some((scope) => !device.scopes.includes(scope))) {
      throw new CredentialError("authentication_failed", "The device credential binding is invalid.", 401);
    }
    return {
      deviceId: device.deviceId,
      credentialId: credential.credentialId,
      deviceName: device.deviceName,
      scopes: credential.scopes,
      expiresAt: credential.expiresAt,
    };
  }

  async listDevices(): Promise<DeviceSummary[]> {
    const state = await this.#store.snapshot();
    return state.devices.map((device) => ({
      deviceId: device.deviceId,
      deviceName: device.deviceName,
      deviceFingerprint: device.deviceFingerprint,
      status: device.status,
      scopes: [...device.scopes],
      createdAt: device.createdAt,
      updatedAt: device.updatedAt,
    }));
  }

  async revokeDevice(deviceId: string): Promise<boolean> {
    if (!opaque(deviceId)) throw new CredentialError("device_not_found", "The device was not found.", 404);
    const now = this.#now();
    return this.#store.mutate((state) => {
      const device = state.devices.find((candidate) => candidate.deviceId === deviceId);
      if (device === undefined) throw new CredentialError("device_not_found", "The device was not found.", 404);
      const changed = device.status !== "revoked" || state.credentials.some((credential) => credential.deviceId === deviceId && credential.status !== "revoked");
      device.status = "revoked";
      device.updatedAt = now.toISOString();
      for (const credential of state.credentials) {
        if (credential.deviceId === deviceId) credential.status = "revoked";
      }
      return changed;
    });
  }
}

function bearerToken(authorization: string | undefined): string {
  const match = authorization?.match(/^Bearer ([A-Za-z0-9_-]{43})$/u);
  if (match?.[1] === undefined) throw new CredentialError("authentication_failed", "The device credential is invalid.", 401);
  return match[1];
}

function opaque(value: string): boolean {
  return value.length > 0 && value.length <= 256 && !/[\u0000-\u001f\u007f]/u.test(value);
}
