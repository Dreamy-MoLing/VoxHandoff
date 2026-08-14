import {
  DeviceSignatureAlgorithm,
  administratorPairingPayload,
  credentialRefreshPayload,
  deviceRevocationPayload,
  normalizeDeviceScopes,
  pairingConfirmationPayload,
  pairingProofPayload,
  type DeviceScope,
  type DeviceSignature,
} from "@agent-talk/protocol";

import {
  canonicalGatewayAudience,
  newChallenge,
  newOpaqueId,
  newOpaqueSecret,
  normalizeEd25519PublicKey,
  sha256,
  validateNonce,
  verifyEd25519Signature,
} from "./device-crypto.js";
import type {
  DeviceCredentialRecord,
  PairingAuditFact,
  PairingLedger,
  PairingLedgerTransaction,
  PairingRecord,
} from "./pairing-ledger.js";

export type PairingErrorCode =
  | "invalid_request"
  | "rate_limited"
  | "pairing_not_found"
  | "pairing_expired"
  | "pairing_not_approved"
  | "pairing_conflict"
  | "fingerprint_mismatch"
  | "scope_not_allowed"
  | "authentication_failed"
  | "authorization_denied"
  | "proof_invalid"
  | "nonce_replayed"
  | "credential_not_found"
  | "credential_revoked"
  | "credential_expired"
  | "refresh_replayed";

export class PairingError extends Error {
  constructor(
    readonly code: PairingErrorCode,
    message: string,
    readonly retryable = false,
  ) {
    super(message);
    this.name = "PairingError";
  }
}

export interface PairingServiceDependencies {
  now(): Date;
  newOpaqueId(prefix: string): string;
  newChallenge(bytes?: number): Uint8Array;
  newOpaqueSecret(bytes?: number): string;
  newUserCode(): string;
}

export interface PairingServiceOptions {
  gatewayAudience: string;
  gatewayFingerprint: string;
  verificationUri: string;
  allowInsecureLoopbackForTests?: boolean;
  pairingLifetimeMs?: number;
  confirmationLifetimeMs?: number;
  confirmationResultCacheMs?: number;
  accessLifetimeMs?: number;
  credentialLifetimeMs?: number;
  rateLimitWindowMs?: number;
  maximumBeginsPerWindow?: number;
  dependencies?: Partial<PairingServiceDependencies>;
}

export interface BeginPairingInput {
  deviceDisplayName: string;
  devicePublicKey: Uint8Array;
  requestedScopes: readonly string[];
  expectedGatewayAudience: string;
  rateLimitKey: string;
}

export interface BegunPairing {
  pairingId: string;
  userCode: string;
  verificationUri: string;
  expiresInSeconds: number;
  deviceProofPayload: Uint8Array;
  deviceFingerprint: string;
  gatewayFingerprint: string;
  gatewayAudience: string;
}

export interface InspectedPairing {
  pairingId: string;
  deviceDisplayName: string;
  deviceFingerprint: string;
  gatewayFingerprint: string;
  gatewayAudience: string;
  requestedScopes: readonly DeviceScope[];
  expiresInSeconds: number;
}

export interface ApprovePairingInput {
  pairingId: string;
  userCode: string;
  approvedScopes: readonly string[];
  expectedDeviceFingerprint: string;
  expectedGatewayFingerprint: string;
  expectedGatewayAudience: string;
  administratorDeviceId: string;
  administratorSignature: DeviceSignature | undefined;
}

export interface CompletePairingInput {
  pairingId: string;
  legacyDeviceProof: string;
  deviceKeyProof: DeviceSignature | undefined;
}

export interface CompletedPairing {
  deviceId: string;
  credentialId: string;
  scopes: readonly DeviceScope[];
  confirmationPayload: Uint8Array;
  gatewayAudience: string;
  confirmationExpiresInSeconds: number;
}

export interface ConfirmPairingInput {
  pairingId: string;
  credentialId: string;
  deviceSignature: DeviceSignature | undefined;
}

export interface ConfirmedPairing {
  deviceId: string;
  credentialId: string;
  accessToken: string;
  refreshToken: string;
  scopes: readonly DeviceScope[];
  accessExpiresAt: Date;
  refreshExpiresAt: Date;
  gatewayAudience: string;
}

interface CachedConfirmation {
  result: ConfirmedPairing;
  expiresAt: Date;
  expiryTimer: NodeJS.Timeout;
}

export interface RefreshCredentialInput {
  credentialId: string;
  refreshToken: string;
  deviceSignature: DeviceSignature | undefined;
}

export interface RefreshedCredential extends ConfirmedPairing {}

export interface RevokeDeviceInput {
  targetDeviceId: string;
  reasonCode: string;
  administratorDeviceId: string;
  administratorSignature: DeviceSignature | undefined;
}

const defaultDependencies: PairingServiceDependencies = {
  now: () => new Date(),
  newOpaqueId,
  newChallenge,
  newOpaqueSecret,
  newUserCode: () => {
    const alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
    const random = newChallenge(16);
    const characters = [...random].map((value) => alphabet[value % alphabet.length]);
    return `${characters.slice(0, 4).join("")}-${characters.slice(4, 8).join("")}`;
  },
};

const fingerprintPattern = /^sha256:[0-9a-f]{64}$/u;
const userCodePattern = /^[2-9A-HJ-NP-Z]{4}-[2-9A-HJ-NP-Z]{4}$/u;

function duration(value: number | undefined, fallback: number, maximum: number, name: string): number {
  const resolved = value ?? fallback;
  if (!Number.isInteger(resolved) || resolved <= 0 || resolved > maximum) {
    throw new Error(`${name} is outside its supported security bound`);
  }
  return resolved;
}

function future(now: Date, milliseconds: number): Date {
  return new Date(now.getTime() + milliseconds);
}

function secondsUntil(deadline: Date, now: Date): number {
  return Math.max(0, Math.ceil((deadline.getTime() - now.getTime()) / 1_000));
}

function requireDisplayName(value: string): string {
  const normalized = value.trim();
  if (
    normalized.length === 0 ||
    new TextEncoder().encode(normalized).byteLength > 128 ||
    /[\u0000-\u001f\u007f]/u.test(normalized)
  ) {
    throw new PairingError("invalid_request", "The device display name is invalid.");
  }
  return normalized;
}

function requireOpaque(value: string, name: string): string {
  if (value.length === 0 || value.length > 256 || /[\u0000-\u001f\u007f]/u.test(value)) {
    throw new PairingError("invalid_request", `${name} is invalid.`);
  }
  return value;
}

function normalizeUserCode(value: string): string {
  const normalized = value.trim().toUpperCase();
  if (!userCodePattern.test(normalized)) {
    throw new PairingError("pairing_not_found", "The pairing request was not found.");
  }
  return normalized;
}

function exactSignature(
  signature: DeviceSignature | undefined,
  expectedCredentialId: string,
  nonceRequired: boolean,
): DeviceSignature {
  if (
    signature === undefined ||
    signature.algorithm !== DeviceSignatureAlgorithm.ED25519 ||
    signature.credentialId !== expectedCredentialId ||
    signature.signature.byteLength !== 64 ||
    (nonceRequired ? signature.nonce.byteLength < 16 : signature.nonce.byteLength !== 0)
  ) {
    throw new PairingError("proof_invalid", "The device signature is invalid.");
  }
  if (nonceRequired) validateNonce(signature.nonce);
  return signature;
}

function scopesAreSubset(candidate: readonly DeviceScope[], allowed: readonly DeviceScope[]): boolean {
  const set = new Set(allowed);
  return candidate.every((scope) => set.has(scope));
}

function assertFingerprint(value: string): void {
  if (!fingerprintPattern.test(value)) {
    throw new Error("Gateway fingerprint must use sha256:<lowercase-hex>");
  }
}

function assertAdministratorCredential(
  credential: DeviceCredentialRecord | undefined,
  administratorDeviceId: string,
  gatewayAudience: string,
): DeviceCredentialRecord {
  if (credential === undefined || credential.deviceId !== administratorDeviceId) {
    throw new PairingError("authentication_failed", "The administrator credential is invalid.");
  }
  if (
    credential.state !== "active" ||
    !credential.deviceActive ||
    credential.gatewayAudience !== gatewayAudience ||
    !credential.scopes.includes("administer")
  ) {
    throw new PairingError("authorization_denied", "The device is not authorized to administer pairing.");
  }
  return credential;
}

function requireReasonCode(value: string): string {
  if (!/^[a-z][a-z0-9_.-]{0,63}$/u.test(value)) {
    throw new PairingError("invalid_request", "The device revocation reason code is invalid.");
  }
  return value;
}

export class PairingCoordinator {
  private readonly gatewayAudience: string;
  private readonly gatewayFingerprint: string;
  private readonly verificationUri: string;
  private readonly pairingLifetimeMs: number;
  private readonly confirmationLifetimeMs: number;
  private readonly confirmationResultCacheMs: number;
  private readonly accessLifetimeMs: number;
  private readonly credentialLifetimeMs: number;
  private readonly rateLimitWindowMs: number;
  private readonly maximumBeginsPerWindow: number;
  private readonly dependencies: PairingServiceDependencies;
  private readonly confirmationResults = new Map<string, CachedConfirmation>();
  private readonly inFlightConfirmations = new Map<string, Promise<ConfirmedPairing>>();

  constructor(
    private readonly ledger: PairingLedger,
    options: PairingServiceOptions,
  ) {
    this.gatewayAudience = canonicalGatewayAudience(
      options.gatewayAudience,
      options.allowInsecureLoopbackForTests ?? false,
    );
    assertFingerprint(options.gatewayFingerprint);
    this.gatewayFingerprint = options.gatewayFingerprint;
    this.verificationUri = options.verificationUri;
    this.pairingLifetimeMs = duration(options.pairingLifetimeMs, 10 * 60_000, 10 * 60_000, "pairingLifetimeMs");
    this.confirmationLifetimeMs = duration(
      options.confirmationLifetimeMs,
      2 * 60_000,
      10 * 60_000,
      "confirmationLifetimeMs",
    );
    this.confirmationResultCacheMs = duration(
      options.confirmationResultCacheMs,
      2 * 60_000,
      2 * 60_000,
      "confirmationResultCacheMs",
    );
    this.accessLifetimeMs = duration(options.accessLifetimeMs, 15 * 60_000, 15 * 60_000, "accessLifetimeMs");
    this.credentialLifetimeMs = duration(
      options.credentialLifetimeMs,
      30 * 24 * 60 * 60_000,
      30 * 24 * 60 * 60_000,
      "credentialLifetimeMs",
    );
    this.rateLimitWindowMs = duration(options.rateLimitWindowMs, 60_000, 60 * 60_000, "rateLimitWindowMs");
    this.maximumBeginsPerWindow = duration(options.maximumBeginsPerWindow, 5, 100, "maximumBeginsPerWindow");
    this.dependencies = { ...defaultDependencies, ...options.dependencies };
  }

  async begin(input: BeginPairingInput): Promise<BegunPairing> {
    const now = this.dependencies.now();
    const displayName = requireDisplayName(input.deviceDisplayName);
    const expectedAudience = canonicalGatewayAudience(
      input.expectedGatewayAudience,
      this.gatewayAudience.startsWith("http://"),
    );
    if (expectedAudience !== this.gatewayAudience) {
      throw new PairingError("fingerprint_mismatch", "The expected Gateway audience does not match this Gateway.");
    }
    const publicKey = normalizeEd25519PublicKey(input.devicePublicKey);
    const scopes = normalizeDeviceScopes(input.requestedScopes);
    const pairingId = this.dependencies.newOpaqueId("pairing");
    const userCode = normalizeUserCode(this.dependencies.newUserCode());
    const challenge = this.dependencies.newChallenge(32);
    const deviceProofPayload = pairingProofPayload({
      pairingId,
      challenge,
      gatewayAudience: this.gatewayAudience,
      deviceFingerprint: publicKey.fingerprint,
      requestedScopes: scopes,
    });
    const expiresAt = future(now, this.pairingLifetimeMs);
    const record: PairingRecord = {
      pairingId,
      userCodeSha256: sha256(userCode),
      deviceDisplayName: displayName,
      devicePublicKeySpki: publicKey.spkiDer,
      devicePublicKeySha256: publicKey.sha256,
      deviceFingerprint: publicKey.fingerprint,
      gatewayFingerprint: this.gatewayFingerprint,
      gatewayAudience: this.gatewayAudience,
      requestedScopes: scopes,
      approvedScopes: null,
      administratorProofSha256: null,
      deviceProofPayload,
      deviceProofSha256: null,
      deviceId: null,
      credentialId: null,
      confirmationPayload: null,
      state: "pending_owner",
      expiresAt,
      confirmationExpiresAt: null,
      approvedByDeviceId: null,
      createdAt: now,
      updatedAt: now,
    };
    const inserted = await this.ledger.runPairingTransaction(async (transaction) => {
      const allowed = await transaction.consumePairingRateLimit(
        sha256(input.rateLimitKey),
        new Date(now.getTime() - this.rateLimitWindowMs),
        this.maximumBeginsPerWindow,
        now,
      );
      if (!allowed) {
        await this.audit(transaction, null, "pairing.begin", "denied", pairingId, "rate_limited", now);
        return false;
      }
      await transaction.insertPairing(record);
      await this.audit(transaction, null, "pairing.begin", "allowed", pairingId, "challenge_created", now);
      return true;
    });
    if (!inserted) {
      throw new PairingError("rate_limited", "Too many pairing attempts. Try again later.", true);
    }
    return {
      pairingId,
      userCode,
      verificationUri: this.verificationUri,
      expiresInSeconds: secondsUntil(expiresAt, now),
      deviceProofPayload,
      deviceFingerprint: publicKey.fingerprint,
      gatewayFingerprint: this.gatewayFingerprint,
      gatewayAudience: this.gatewayAudience,
    };
  }

  async inspect(userCode: string, administratorDeviceId: string): Promise<InspectedPairing> {
    const now = this.dependencies.now();
    const codeSha256 = sha256(normalizeUserCode(userCode));
    const result = await this.ledger.runPairingTransaction(async (transaction) => {
      const administrator = await transaction.lockDeviceAuthorization(requireOpaque(administratorDeviceId, "Device ID"));
      if (administrator === undefined || !administrator.active || !administrator.scopes.includes("administer")) {
        throw new PairingError("authorization_denied", "The device is not authorized to inspect pairing.");
      }
      const pairing = await transaction.lockPairingByUserCodeSha256(codeSha256);
      if (pairing === undefined) {
        throw new PairingError("pairing_not_found", "The pairing request was not found.");
      }
      if (await this.expireIfNeeded(transaction, pairing, now)) return null;
      return {
        pairingId: pairing.pairingId,
        deviceDisplayName: pairing.deviceDisplayName,
        deviceFingerprint: pairing.deviceFingerprint,
        gatewayFingerprint: pairing.gatewayFingerprint,
        gatewayAudience: pairing.gatewayAudience,
        requestedScopes: pairing.requestedScopes,
        expiresInSeconds: secondsUntil(pairing.expiresAt, now),
      };
    });
    if (result === null) {
      throw new PairingError("pairing_expired", "The pairing request has expired.");
    }
    return result;
  }

  async approve(input: ApprovePairingInput): Promise<{ approved: true; expiresInSeconds: number }> {
    const now = this.dependencies.now();
    const pairingId = requireOpaque(input.pairingId, "Pairing ID");
    const userCode = normalizeUserCode(input.userCode);
    const approvedScopes = normalizeDeviceScopes(input.approvedScopes);
    const signature = exactSignature(
      input.administratorSignature,
      input.administratorSignature?.credentialId ?? "",
      true,
    );
    const administratorProofSha256 = sha256(signature.signature);
    const result = await this.ledger.runPairingTransaction(async (transaction) => {
      const pairing = await transaction.lockPairingById(pairingId);
      if (pairing === undefined || pairing.userCodeSha256 !== sha256(userCode)) {
        throw new PairingError("pairing_not_found", "The pairing request was not found.");
      }
      if (await this.expireIfNeeded(transaction, pairing, now)) return null;
      if (!scopesAreSubset(approvedScopes, pairing.requestedScopes)) {
        throw new PairingError("scope_not_allowed", "Approved scopes cannot exceed the device request.");
      }
      if (
        input.expectedDeviceFingerprint !== pairing.deviceFingerprint ||
        input.expectedGatewayFingerprint !== pairing.gatewayFingerprint ||
        input.expectedGatewayAudience !== pairing.gatewayAudience
      ) {
        throw new PairingError("fingerprint_mismatch", "The pairing fingerprints or Gateway audience changed.");
      }
      const credential = assertAdministratorCredential(
        await transaction.lockCredential(signature.credentialId),
        requireOpaque(input.administratorDeviceId, "Device ID"),
        this.gatewayAudience,
      );
      const payload = administratorPairingPayload({
        pairingId,
        userCode,
        deviceFingerprint: pairing.deviceFingerprint,
        gatewayFingerprint: pairing.gatewayFingerprint,
        gatewayAudience: pairing.gatewayAudience,
        approvedScopes,
        nonce: signature.nonce,
      });
      const publicKey = normalizeEd25519PublicKey(credential.publicKeySpki);
      if (publicKey.sha256 !== credential.publicKeySha256) {
        throw new PairingError("authentication_failed", "The administrator credential key binding is invalid.");
      }
      if (!verifyEd25519Signature(publicKey, payload, signature.signature)) {
        throw new PairingError("proof_invalid", "The administrator device signature is invalid.");
      }
      if (pairing.state === "approved") {
        if (
          pairing.approvedByDeviceId === input.administratorDeviceId &&
          pairing.approvedScopes !== null &&
          pairing.approvedScopes.join("\0") === approvedScopes.join("\0") &&
          pairing.administratorProofSha256 === administratorProofSha256
        ) {
          return { approved: true as const, expiresInSeconds: secondsUntil(pairing.expiresAt, now) };
        }
        throw new PairingError("pairing_conflict", "The pairing request was already approved differently.");
      }
      if (pairing.state !== "pending_owner") {
        throw new PairingError("pairing_conflict", "The pairing request is no longer pending owner approval.");
      }
      if (!await transaction.recordNonce(signature.credentialId, "pairing_approval", sha256(signature.nonce), now)) {
        throw new PairingError("nonce_replayed", "The device-signature nonce was already used.");
      }
      await transaction.approvePairing({
        pairingId,
        administratorDeviceId: input.administratorDeviceId,
        approvedScopes,
        administratorProofSha256,
        approvedAt: now,
      });
      await this.audit(
        transaction,
        input.administratorDeviceId,
        "pairing.approve",
        "allowed",
        pairingId,
        "owner_approved",
        now,
      );
      return { approved: true as const, expiresInSeconds: secondsUntil(pairing.expiresAt, now) };
    });
    if (result === null) {
      throw new PairingError("pairing_expired", "The pairing request has expired.");
    }
    return result;
  }

  async complete(input: CompletePairingInput): Promise<CompletedPairing> {
    const now = this.dependencies.now();
    const pairingId = requireOpaque(input.pairingId, "Pairing ID");
    if (input.legacyDeviceProof !== "") {
      throw new PairingError("proof_invalid", "Legacy pairing proof is not accepted.");
    }
    const signature = exactSignature(input.deviceKeyProof, "", false);
    const proofSha256 = sha256(signature.signature);
    const result = await this.ledger.runPairingTransaction(async (transaction) => {
      const pairing = await transaction.lockPairingById(pairingId);
      if (pairing === undefined) {
        throw new PairingError("pairing_not_found", "The pairing request was not found.");
      }
      if (await this.expireIfNeeded(transaction, pairing, now)) return null;
      if (pairing.state === "proof_verified") {
        if (
          pairing.deviceProofSha256 === proofSha256 &&
          pairing.deviceId !== null &&
          pairing.credentialId !== null &&
          pairing.confirmationPayload !== null &&
          pairing.confirmationExpiresAt !== null &&
          pairing.approvedScopes !== null
        ) {
          return {
            deviceId: pairing.deviceId,
            credentialId: pairing.credentialId,
            scopes: pairing.approvedScopes,
            confirmationPayload: pairing.confirmationPayload,
            gatewayAudience: pairing.gatewayAudience,
            confirmationExpiresInSeconds: secondsUntil(pairing.confirmationExpiresAt, now),
          };
        }
        throw new PairingError("pairing_conflict", "The pairing proof was already completed differently.");
      }
      if (pairing.state !== "approved" || pairing.approvedScopes === null) {
        throw new PairingError("pairing_not_approved", "The pairing request has not been approved.");
      }
      const publicKey = normalizeEd25519PublicKey(pairing.devicePublicKeySpki);
      if (publicKey.sha256 !== pairing.devicePublicKeySha256) {
        throw new PairingError("proof_invalid", "The device key binding is invalid.");
      }
      if (!verifyEd25519Signature(publicKey, pairing.deviceProofPayload, signature.signature)) {
        throw new PairingError("proof_invalid", "The device key proof is invalid.");
      }
      const deviceId = this.dependencies.newOpaqueId("device");
      const credentialId = this.dependencies.newOpaqueId("credential");
      const confirmationExpiresAt = future(now, this.confirmationLifetimeMs);
      const confirmationPayload = pairingConfirmationPayload({
        pairingId,
        credentialId,
        deviceId,
        challenge: this.dependencies.newChallenge(32),
        gatewayAudience: pairing.gatewayAudience,
        deviceFingerprint: pairing.deviceFingerprint,
        approvedScopes: pairing.approvedScopes,
      });
      await transaction.verifyPairingProof({
        pairingId,
        proofSha256,
        deviceId,
        credential: {
          credentialId,
          deviceId,
          pairingId,
          publicKeySpki: pairing.devicePublicKeySpki,
          publicKeySha256: pairing.devicePublicKeySha256,
          gatewayAudience: pairing.gatewayAudience,
          scopes: pairing.approvedScopes,
          confirmationPayload,
          confirmationExpiresAt,
          familyExpiresAt: future(now, this.credentialLifetimeMs),
          createdAt: now,
        },
        verifiedAt: now,
      });
      await this.audit(transaction, null, "pairing.complete", "allowed", pairingId, "proof_verified", now);
      return {
        deviceId,
        credentialId,
        scopes: pairing.approvedScopes,
        confirmationPayload,
        gatewayAudience: pairing.gatewayAudience,
        confirmationExpiresInSeconds: secondsUntil(confirmationExpiresAt, now),
      };
    });
    if (result === null) {
      throw new PairingError("pairing_expired", "The pairing request has expired.");
    }
    return result;
  }

  async confirm(input: ConfirmPairingInput): Promise<ConfirmedPairing> {
    const now = this.dependencies.now();
    const pairingId = requireOpaque(input.pairingId, "Pairing ID");
    const credentialId = requireOpaque(input.credentialId, "Credential ID");
    const signature = exactSignature(input.deviceSignature, credentialId, false);
    const cacheKey = sha256(`${pairingId}\0${credentialId}\0${sha256(signature.signature)}`);
    const cached = this.confirmationResults.get(cacheKey);
    if (cached !== undefined) {
      if (
        cached.expiresAt.getTime() > now.getTime() &&
        await this.cachedConfirmationIsCurrent(cached.result, now)
      ) {
        return this.copyConfirmation(cached.result);
      }
      this.deleteCachedConfirmation(cacheKey, cached);
    }
    const inFlight = this.inFlightConfirmations.get(cacheKey);
    if (inFlight !== undefined) {
      return this.copyConfirmation(await inFlight);
    }
    const operation = this.confirmOnce(pairingId, credentialId, signature, now);
    this.inFlightConfirmations.set(cacheKey, operation);
    try {
      const result = await operation;
      const expiresAt = new Date(Math.min(
        now.getTime() + this.confirmationResultCacheMs,
        result.accessExpiresAt.getTime(),
        result.refreshExpiresAt.getTime(),
      ));
      this.cacheConfirmation(cacheKey, result, expiresAt, now);
      return this.copyConfirmation(result);
    } finally {
      this.inFlightConfirmations.delete(cacheKey);
    }
  }

  private async confirmOnce(
    pairingId: string,
    credentialId: string,
    signature: DeviceSignature,
    now: Date,
  ): Promise<ConfirmedPairing> {
    const result = await this.ledger.runPairingTransaction(async (transaction) => {
      const pairing = await transaction.lockPairingById(pairingId);
      if (
        pairing === undefined ||
        pairing.state !== "proof_verified" ||
        pairing.credentialId !== credentialId ||
        pairing.deviceId === null ||
        pairing.confirmationPayload === null ||
        pairing.confirmationExpiresAt === null ||
        pairing.approvedScopes === null
      ) {
        throw new PairingError("pairing_conflict", "The pairing request is not awaiting confirmation.");
      }
      if (pairing.confirmationExpiresAt.getTime() <= now.getTime()) {
        await transaction.expirePairing(pairingId, now);
        await this.audit(transaction, null, "pairing.confirm", "expired", pairingId, "confirmation_expired", now);
        return null;
      }
      const credential = await transaction.lockCredential(credentialId);
      if (credential === undefined || credential.state !== "pending_confirmation") {
        throw new PairingError("credential_not_found", "The pending device credential was not found.");
      }
      const publicKey = normalizeEd25519PublicKey(credential.publicKeySpki);
      if (
        publicKey.sha256 !== credential.publicKeySha256 ||
        publicKey.sha256 !== pairing.devicePublicKeySha256
      ) {
        throw new PairingError("proof_invalid", "The pending credential key binding is invalid.");
      }
      if (!verifyEd25519Signature(publicKey, pairing.confirmationPayload, signature.signature)) {
        throw new PairingError("proof_invalid", "The pairing confirmation signature is invalid.");
      }
      const accessToken = this.dependencies.newOpaqueSecret(32);
      const refreshToken = this.dependencies.newOpaqueSecret(48);
      const accessExpiresAt = future(now, this.accessLifetimeMs);
      const refreshExpiresAt = credential.familyExpiresAt;
      await transaction.activatePairing({
        pairingId,
        credentialId,
        deviceId: pairing.deviceId,
        displayName: pairing.deviceDisplayName,
        publicKeySha256: pairing.devicePublicKeySha256,
        scopes: pairing.approvedScopes,
        accessTokenSha256: sha256(accessToken),
        accessExpiresAt,
        refreshTokenSha256: sha256(refreshToken),
        refreshExpiresAt,
        activatedAt: now,
      });
      await this.audit(
        transaction,
        pairing.deviceId,
        "pairing.confirm",
        "allowed",
        pairingId,
        "credential_activated",
        now,
      );
      return {
        deviceId: pairing.deviceId,
        credentialId,
        accessToken,
        refreshToken,
        scopes: pairing.approvedScopes,
        accessExpiresAt,
        refreshExpiresAt,
        gatewayAudience: pairing.gatewayAudience,
      };
    });
    if (result === null) {
      throw new PairingError("pairing_expired", "The pairing confirmation has expired.");
    }
    return result;
  }

  private async cachedConfirmationIsCurrent(result: ConfirmedPairing, now: Date): Promise<boolean> {
    return this.ledger.runPairingTransaction(async (transaction) => {
      const credential = await transaction.lockCredential(result.credentialId);
      return credential !== undefined &&
        credential.state === "active" &&
        credential.deviceActive &&
        credential.deviceId === result.deviceId &&
        credential.gatewayAudience === result.gatewayAudience &&
        credential.generation === 1n &&
        credential.accessTokenSha256 === sha256(result.accessToken) &&
        credential.refreshTokenSha256 === sha256(result.refreshToken) &&
        credential.accessExpiresAt !== null &&
        credential.accessExpiresAt.getTime() > now.getTime() &&
        credential.refreshExpiresAt.getTime() > now.getTime() &&
        credential.scopes.length === result.scopes.length &&
        credential.scopes.every((scope, index) => scope === result.scopes[index]);
    });
  }

  private cacheConfirmation(
    cacheKey: string,
    result: ConfirmedPairing,
    expiresAt: Date,
    now: Date,
  ): void {
    let entry: CachedConfirmation;
    const expiryTimer = setTimeout(() => {
      if (this.confirmationResults.get(cacheKey) === entry) {
        this.confirmationResults.delete(cacheKey);
      }
    }, Math.max(1, expiresAt.getTime() - now.getTime()));
    expiryTimer.unref();
    entry = {
      result: this.copyConfirmation(result),
      expiresAt,
      expiryTimer,
    };
    this.confirmationResults.set(cacheKey, entry);
  }

  private deleteCachedConfirmation(cacheKey: string, entry: CachedConfirmation): void {
    clearTimeout(entry.expiryTimer);
    if (this.confirmationResults.get(cacheKey) === entry) {
      this.confirmationResults.delete(cacheKey);
    }
  }

  private copyConfirmation(result: ConfirmedPairing): ConfirmedPairing {
    return {
      deviceId: result.deviceId,
      credentialId: result.credentialId,
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      scopes: [...result.scopes],
      accessExpiresAt: new Date(result.accessExpiresAt),
      refreshExpiresAt: new Date(result.refreshExpiresAt),
      gatewayAudience: result.gatewayAudience,
    };
  }

  async refresh(input: RefreshCredentialInput): Promise<RefreshedCredential> {
    const now = this.dependencies.now();
    const credentialId = requireOpaque(input.credentialId, "Credential ID");
    const refreshToken = requireOpaque(input.refreshToken, "Refresh token");
    const refreshTokenSha256 = sha256(refreshToken);
    const signature = exactSignature(input.deviceSignature, credentialId, true);
    const result = await this.ledger.runPairingTransaction(async (transaction) => {
      const credential = await transaction.lockCredential(credentialId);
      if (credential === undefined) {
        throw new PairingError("authentication_failed", "The device credential is invalid.");
      }
      const usedRefresh = credential.refreshTokenSha256 === refreshTokenSha256
        ? undefined
        : await transaction.findUsedRefresh(credentialId, refreshTokenSha256);
      const generation = credential.refreshTokenSha256 === refreshTokenSha256
        ? credential.generation
        : usedRefresh?.generation;
      if (generation === undefined) {
        throw new PairingError("authentication_failed", "The refresh credential is invalid.");
      }
      if (
        credential.state !== "active" ||
        !credential.deviceActive ||
        credential.gatewayAudience !== this.gatewayAudience
      ) {
        throw new PairingError("credential_revoked", "The device credential is no longer active.");
      }
      if (
        credential.refreshExpiresAt.getTime() <= now.getTime() ||
        credential.familyExpiresAt.getTime() <= now.getTime()
      ) {
        throw new PairingError("credential_expired", "The device credential has expired.");
      }
      const publicKey = normalizeEd25519PublicKey(credential.publicKeySpki);
      if (publicKey.sha256 !== credential.publicKeySha256) {
        throw new PairingError("authentication_failed", "The device credential key binding is invalid.");
      }
      const payload = credentialRefreshPayload({
        credentialId,
        deviceId: credential.deviceId,
        gatewayAudience: credential.gatewayAudience,
        refreshTokenSha256,
        generation,
        nonce: signature.nonce,
      });
      if (!verifyEd25519Signature(publicKey, payload, signature.signature)) {
        throw new PairingError("proof_invalid", "The refresh device signature is invalid.");
      }
      if (usedRefresh !== undefined) {
        await transaction.revokeDeviceCredentials({ deviceId: credential.deviceId, revokedAt: now });
        await this.audit(
          transaction,
          credential.deviceId,
          "credential.refresh",
          "revoked",
          credentialId,
          "refresh_replayed",
          now,
          "credential",
        );
        return { kind: "replayed" as const };
      }
      if (!await transaction.recordNonce(credentialId, "credential_refresh", sha256(signature.nonce), now)) {
        throw new PairingError("nonce_replayed", "The device-signature nonce was already used.");
      }
      const accessToken = this.dependencies.newOpaqueSecret(32);
      const nextRefreshToken = this.dependencies.newOpaqueSecret(48);
      const accessExpiresAt = future(now, this.accessLifetimeMs);
      await transaction.rotateCredential({
        credentialId,
        deviceId: credential.deviceId,
        expectedGeneration: credential.generation,
        previousRefreshTokenSha256: refreshTokenSha256,
        accessTokenSha256: sha256(accessToken),
        accessExpiresAt,
        refreshTokenSha256: sha256(nextRefreshToken),
        refreshExpiresAt: credential.familyExpiresAt,
        rotatedAt: now,
      });
      await this.audit(
        transaction,
        credential.deviceId,
        "credential.refresh",
        "allowed",
        credentialId,
        "credential_rotated",
        now,
        "credential",
      );
      return {
        kind: "refreshed" as const,
        value: {
          deviceId: credential.deviceId,
          credentialId,
          accessToken,
          refreshToken: nextRefreshToken,
          scopes: credential.scopes,
          accessExpiresAt,
          refreshExpiresAt: credential.familyExpiresAt,
          gatewayAudience: credential.gatewayAudience,
        } satisfies RefreshedCredential,
      };
    });
    if (result.kind === "replayed") {
      throw new PairingError("refresh_replayed", "Refresh credential reuse revoked this device.");
    }
    return result.value;
  }

  async revokeDevice(input: RevokeDeviceInput): Promise<boolean> {
    const now = this.dependencies.now();
    const targetDeviceId = requireOpaque(input.targetDeviceId, "Target device ID");
    const administratorDeviceId = requireOpaque(input.administratorDeviceId, "Administrator device ID");
    const reasonCode = requireReasonCode(input.reasonCode);
    const credentialId = input.administratorSignature?.credentialId ?? "";
    const signature = exactSignature(input.administratorSignature, credentialId, true);
    return this.ledger.runPairingTransaction(async (transaction) => {
      const credential = assertAdministratorCredential(
        await transaction.lockCredential(credentialId),
        administratorDeviceId,
        this.gatewayAudience,
      );
      const publicKey = normalizeEd25519PublicKey(credential.publicKeySpki);
      if (publicKey.sha256 !== credential.publicKeySha256) {
        throw new PairingError("authentication_failed", "The administrator credential key binding is invalid.");
      }
      const payload = deviceRevocationPayload({
        administratorDeviceId,
        targetDeviceId,
        reasonCode,
        gatewayAudience: this.gatewayAudience,
        nonce: signature.nonce,
      });
      if (!verifyEd25519Signature(publicKey, payload, signature.signature)) {
        throw new PairingError("proof_invalid", "The device revocation signature is invalid.");
      }
      if (!await transaction.recordNonce(credentialId, "device_revocation", sha256(signature.nonce), now)) {
        throw new PairingError("nonce_replayed", "The device-signature nonce was already used.");
      }
      const target = await transaction.lockDeviceAuthorization(targetDeviceId);
      if (target === undefined || !target.active) return false;
      await transaction.revokeDeviceCredentials({ deviceId: targetDeviceId, revokedAt: now });
      await this.audit(
        transaction,
        administratorDeviceId,
        "device.revoke",
        "revoked",
        targetDeviceId,
        reasonCode,
        now,
        "device",
      );
      return true;
    });
  }

  private async expireIfNeeded(
    transaction: PairingLedgerTransaction,
    pairing: PairingRecord,
    now: Date,
  ): Promise<boolean> {
    if (pairing.state === "expired") return true;
    if (pairing.expiresAt.getTime() <= now.getTime()) {
      await transaction.expirePairing(pairing.pairingId, now);
      await this.audit(transaction, null, "pairing.expire", "expired", pairing.pairingId, "challenge_expired", now);
      return true;
    }
    return false;
  }

  private async audit(
    transaction: PairingLedgerTransaction,
    deviceId: string | null,
    action: string,
    outcome: PairingAuditFact["outcome"],
    targetId: string,
    safeCode: string,
    occurredAt: Date,
    targetType = "pairing",
  ): Promise<void> {
    await transaction.insertSecurityAudit({
      auditId: this.dependencies.newOpaqueId("audit"),
      deviceId,
      action,
      outcome,
      targetType,
      targetIdSha256: sha256(targetId),
      safeCode,
      occurredAt,
    });
  }
}
