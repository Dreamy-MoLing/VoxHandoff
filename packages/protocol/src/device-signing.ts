const encoder = new TextEncoder();
const payloadMagic = encoder.encode("agent-talk-signed-payload\0v1");
const domainPattern = /^agent-talk\/[a-z0-9.-]+\/v1$/u;
const fieldNamePattern = /^[a-z][a-z0-9_.-]*$/u;
const sha256Pattern = /^[0-9a-f]{64}$/u;

export const deviceScopes = ["observe", "send", "interrupt", "approve", "administer"] as const;
export type DeviceScope = (typeof deviceScopes)[number];

export type DeviceSigningContractErrorCode =
  | "invalid_domain"
  | "invalid_field"
  | "duplicate_field"
  | "payload_too_large"
  | "invalid_scope"
  | "duplicate_scope"
  | "invalid_sha256";

export class DeviceSigningContractError extends Error {
  constructor(
    readonly code: DeviceSigningContractErrorCode,
    message: string,
  ) {
    super(message);
    this.name = "DeviceSigningContractError";
  }
}

export interface SignedPayloadField {
  name: string;
  value: string | Uint8Array;
}

function bytes(value: string | Uint8Array): Uint8Array {
  return typeof value === "string" ? encoder.encode(value) : value;
}

function uint32(value: number): Uint8Array {
  const encoded = new Uint8Array(4);
  new DataView(encoded.buffer).setUint32(0, value, false);
  return encoded;
}

function frame(value: Uint8Array): Uint8Array[] {
  if (value.byteLength > 1_048_576) {
    throw new DeviceSigningContractError("payload_too_large", "A signed payload field exceeds one MiB.");
  }
  return [uint32(value.byteLength), value];
}

export function canonicalSignedPayload(domain: string, fields: readonly SignedPayloadField[]): Uint8Array {
  if (!domainPattern.test(domain)) {
    throw new DeviceSigningContractError("invalid_domain", "The device-signature domain is invalid.");
  }
  const names = new Set<string>();
  const parts: Uint8Array[] = [payloadMagic, ...frame(encoder.encode(domain)), uint32(fields.length)];
  for (const field of fields) {
    if (!fieldNamePattern.test(field.name)) {
      throw new DeviceSigningContractError("invalid_field", "A device-signature field name is invalid.");
    }
    if (names.has(field.name)) {
      throw new DeviceSigningContractError("duplicate_field", "A device-signature field name is duplicated.");
    }
    names.add(field.name);
    parts.push(...frame(encoder.encode(field.name)), ...frame(bytes(field.value)));
  }
  const length = parts.reduce((total, part) => total + part.byteLength, 0);
  if (length > 1_048_576) {
    throw new DeviceSigningContractError("payload_too_large", "The signed payload exceeds one MiB.");
  }
  const output = new Uint8Array(length);
  let offset = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.byteLength;
  }
  return output;
}

export function normalizeDeviceScopes(scopes: readonly string[]): readonly DeviceScope[] {
  if (scopes.length === 0 || scopes.length > deviceScopes.length) {
    throw new DeviceSigningContractError("invalid_scope", "At least one valid device scope is required.");
  }
  const allowed = new Set<string>(deviceScopes);
  const normalized = [...scopes].sort();
  for (let index = 0; index < normalized.length; index += 1) {
    const scope = normalized[index];
    if (scope === undefined || !allowed.has(scope)) {
      throw new DeviceSigningContractError("invalid_scope", "The requested device scope is not supported.");
    }
    if (index > 0 && normalized[index - 1] === scope) {
      throw new DeviceSigningContractError("duplicate_scope", "A device scope is duplicated.");
    }
  }
  return normalized as DeviceScope[];
}

function scopeFields(scopes: readonly string[]): SignedPayloadField[] {
  return normalizeDeviceScopes(scopes).map((scope, index) => ({
    name: `scope.${index.toString().padStart(3, "0")}`,
    value: scope,
  }));
}

function requireSha256(value: string): string {
  if (!sha256Pattern.test(value)) {
    throw new DeviceSigningContractError("invalid_sha256", "A signed SHA-256 value is invalid.");
  }
  return value;
}

export interface PairingProofPayloadInput {
  pairingId: string;
  challenge: Uint8Array;
  gatewayAudience: string;
  deviceFingerprint: string;
  requestedScopes: readonly string[];
}

export function pairingProofPayload(input: PairingProofPayloadInput): Uint8Array {
  return canonicalSignedPayload("agent-talk/pairing-proof/v1", [
    { name: "pairing_id", value: input.pairingId },
    { name: "challenge", value: input.challenge },
    { name: "gateway_audience", value: input.gatewayAudience },
    { name: "device_fingerprint", value: input.deviceFingerprint },
    ...scopeFields(input.requestedScopes),
  ]);
}

export interface PairingConfirmationPayloadInput {
  pairingId: string;
  credentialId: string;
  deviceId: string;
  challenge: Uint8Array;
  gatewayAudience: string;
  deviceFingerprint: string;
  approvedScopes: readonly string[];
}

export function pairingConfirmationPayload(input: PairingConfirmationPayloadInput): Uint8Array {
  return canonicalSignedPayload("agent-talk/pairing-confirmation/v1", [
    { name: "pairing_id", value: input.pairingId },
    { name: "credential_id", value: input.credentialId },
    { name: "device_id", value: input.deviceId },
    { name: "challenge", value: input.challenge },
    { name: "gateway_audience", value: input.gatewayAudience },
    { name: "device_fingerprint", value: input.deviceFingerprint },
    ...scopeFields(input.approvedScopes),
  ]);
}

export interface AdministratorPairingPayloadInput {
  pairingId: string;
  userCode: string;
  deviceFingerprint: string;
  gatewayFingerprint: string;
  gatewayAudience: string;
  approvedScopes: readonly string[];
  nonce: Uint8Array;
}

export function administratorPairingPayload(input: AdministratorPairingPayloadInput): Uint8Array {
  return canonicalSignedPayload("agent-talk/pairing-approval/v1", [
    { name: "pairing_id", value: input.pairingId },
    { name: "user_code", value: input.userCode },
    { name: "device_fingerprint", value: input.deviceFingerprint },
    { name: "gateway_fingerprint", value: input.gatewayFingerprint },
    { name: "gateway_audience", value: input.gatewayAudience },
    { name: "nonce", value: input.nonce },
    ...scopeFields(input.approvedScopes),
  ]);
}

export interface CredentialRefreshPayloadInput {
  credentialId: string;
  deviceId: string;
  gatewayAudience: string;
  refreshTokenSha256: string;
  generation: bigint;
  nonce: Uint8Array;
}

export function credentialRefreshPayload(input: CredentialRefreshPayloadInput): Uint8Array {
  if (input.generation <= 0n) {
    throw new DeviceSigningContractError("invalid_field", "The credential generation must be positive.");
  }
  return canonicalSignedPayload("agent-talk/credential-refresh/v1", [
    { name: "credential_id", value: input.credentialId },
    { name: "device_id", value: input.deviceId },
    { name: "gateway_audience", value: input.gatewayAudience },
    { name: "refresh_token_sha256", value: requireSha256(input.refreshTokenSha256) },
    { name: "generation", value: input.generation.toString() },
    { name: "nonce", value: input.nonce },
  ]);
}

export interface DeviceRevocationPayloadInput {
  administratorDeviceId: string;
  targetDeviceId: string;
  reasonCode: string;
  gatewayAudience: string;
  nonce: Uint8Array;
}

export function deviceRevocationPayload(input: DeviceRevocationPayloadInput): Uint8Array {
  return canonicalSignedPayload("agent-talk/device-revocation/v1", [
    { name: "administrator_device_id", value: input.administratorDeviceId },
    { name: "target_device_id", value: input.targetDeviceId },
    { name: "reason_code", value: input.reasonCode },
    { name: "gateway_audience", value: input.gatewayAudience },
    { name: "nonce", value: input.nonce },
  ]);
}

export interface ApprovalDecisionPayloadInput {
  credentialId: string;
  deviceId: string;
  hostIdentity: string;
  gatewayAudience: string;
  requestId: string;
  approvalId: string;
  decision: "approve" | "deny";
  operationSummarySha256: string;
  nonce: Uint8Array;
}

export function approvalDecisionPayload(input: ApprovalDecisionPayloadInput): Uint8Array {
  return canonicalSignedPayload("agent-talk/approval-decision/v1", [
    { name: "credential_id", value: input.credentialId },
    { name: "device_id", value: input.deviceId },
    { name: "host_identity", value: input.hostIdentity },
    { name: "gateway_audience", value: input.gatewayAudience },
    { name: "request_id", value: input.requestId },
    { name: "approval_id", value: input.approvalId },
    { name: "decision", value: input.decision },
    { name: "operation_summary_sha256", value: requireSha256(input.operationSummarySha256) },
    { name: "nonce", value: input.nonce },
  ]);
}

export interface OwnerBootstrapPayloadInput {
  gatewayAudience: string;
  deviceFingerprint: string;
  scopes: readonly string[];
  nonce: Uint8Array;
}

export function ownerBootstrapPayload(input: OwnerBootstrapPayloadInput): Uint8Array {
  return canonicalSignedPayload("agent-talk/owner-bootstrap/v1", [
    { name: "gateway_audience", value: input.gatewayAudience },
    { name: "device_fingerprint", value: input.deviceFingerprint },
    { name: "nonce", value: input.nonce },
    ...scopeFields(input.scopes),
  ]);
}
