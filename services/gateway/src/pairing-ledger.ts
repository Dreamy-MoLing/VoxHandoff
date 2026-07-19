import type { DeviceScope } from "@agent-talk/protocol";

export type PairingState = "pending_owner" | "approved" | "proof_verified" | "confirmed" | "expired" | "rejected";
export type DeviceCredentialState = "pending_confirmation" | "active" | "revoked";

export interface PairingRecord {
  pairingId: string;
  userCodeSha256: string;
  deviceDisplayName: string;
  devicePublicKeySpki: Uint8Array;
  devicePublicKeySha256: string;
  deviceFingerprint: string;
  gatewayFingerprint: string;
  gatewayAudience: string;
  requestedScopes: readonly DeviceScope[];
  approvedScopes: readonly DeviceScope[] | null;
  administratorProofSha256: string | null;
  deviceProofPayload: Uint8Array;
  deviceProofSha256: string | null;
  deviceId: string | null;
  credentialId: string | null;
  confirmationPayload: Uint8Array | null;
  state: PairingState;
  expiresAt: Date;
  confirmationExpiresAt: Date | null;
  approvedByDeviceId: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface DeviceAuthorizationRecord {
  deviceId: string;
  active: boolean;
  scopes: readonly DeviceScope[];
}

export interface DeviceCredentialRecord {
  credentialId: string;
  deviceId: string;
  state: DeviceCredentialState;
  deviceActive: boolean;
  publicKeySpki: Uint8Array;
  publicKeySha256: string;
  gatewayAudience: string;
  scopes: readonly DeviceScope[];
  generation: bigint;
  accessTokenSha256: string | null;
  accessExpiresAt: Date | null;
  refreshTokenSha256: string | null;
  refreshExpiresAt: Date;
  familyExpiresAt: Date;
}

export interface PendingCredentialRecord {
  credentialId: string;
  deviceId: string;
  pairingId: string;
  publicKeySpki: Uint8Array;
  publicKeySha256: string;
  gatewayAudience: string;
  scopes: readonly DeviceScope[];
  confirmationPayload: Uint8Array;
  confirmationExpiresAt: Date;
  familyExpiresAt: Date;
  createdAt: Date;
}

export interface PairingApprovalFacts {
  pairingId: string;
  administratorDeviceId: string;
  approvedScopes: readonly DeviceScope[];
  administratorProofSha256: string;
  approvedAt: Date;
}

export interface PairingProofFacts {
  pairingId: string;
  proofSha256: string;
  deviceId: string;
  credential: PendingCredentialRecord;
  verifiedAt: Date;
}

export interface PairingActivationFacts {
  pairingId: string;
  credentialId: string;
  deviceId: string;
  displayName: string;
  publicKeySha256: string;
  scopes: readonly DeviceScope[];
  accessTokenSha256: string;
  accessExpiresAt: Date;
  refreshTokenSha256: string;
  refreshExpiresAt: Date;
  activatedAt: Date;
}

export interface PairingAuditFact {
  auditId: string;
  deviceId: string | null;
  action: string;
  outcome: "allowed" | "denied" | "expired" | "revoked";
  targetType: string;
  targetIdSha256: string;
  safeCode: string;
  occurredAt: Date;
}

export interface PairingLedgerTransaction {
  consumePairingRateLimit(
    keySha256: string,
    windowStartedAt: Date,
    maximumAttempts: number,
    now: Date,
  ): Promise<boolean>;
  insertPairing(record: PairingRecord): Promise<void>;
  lockPairingById(pairingId: string): Promise<PairingRecord | undefined>;
  lockPairingByUserCodeSha256(userCodeSha256: string): Promise<PairingRecord | undefined>;
  lockDeviceAuthorization(deviceId: string): Promise<DeviceAuthorizationRecord | undefined>;
  lockCredential(credentialId: string): Promise<DeviceCredentialRecord | undefined>;
  recordNonce(credentialId: string, purpose: string, nonceSha256: string, usedAt: Date): Promise<boolean>;
  approvePairing(facts: PairingApprovalFacts): Promise<void>;
  verifyPairingProof(facts: PairingProofFacts): Promise<void>;
  activatePairing(facts: PairingActivationFacts): Promise<void>;
  expirePairing(pairingId: string, expiredAt: Date): Promise<void>;
  insertSecurityAudit(fact: PairingAuditFact): Promise<void>;
}

export interface PairingLedger {
  runPairingTransaction<T>(work: (transaction: PairingLedgerTransaction) => Promise<T>): Promise<T>;
}
