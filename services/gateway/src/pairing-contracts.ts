import type { DeviceScope, DeviceSignature } from "@agent-talk/protocol";

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

export interface CachedConfirmation {
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
