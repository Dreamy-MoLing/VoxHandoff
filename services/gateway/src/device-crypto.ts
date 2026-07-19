import {
  createHash,
  createPublicKey,
  randomBytes,
  randomUUID,
  timingSafeEqual,
  verify,
  type KeyObject,
} from "node:crypto";

export type DeviceCryptoErrorCode =
  | "invalid_public_key"
  | "unsupported_public_key"
  | "noncanonical_public_key"
  | "invalid_signature";

export class DeviceCryptoError extends Error {
  constructor(
    readonly code: DeviceCryptoErrorCode,
    message: string,
  ) {
    super(message);
    this.name = "DeviceCryptoError";
  }
}

export interface CanonicalDevicePublicKey {
  key: KeyObject;
  spkiDer: Uint8Array;
  sha256: string;
  fingerprint: string;
}

export function sha256(value: Uint8Array | string): string {
  return createHash("sha256").update(value).digest("hex");
}

export function normalizeEd25519PublicKey(value: Uint8Array): CanonicalDevicePublicKey {
  if (value.byteLength === 0 || value.byteLength > 512) {
    throw new DeviceCryptoError("invalid_public_key", "The device public key is invalid.");
  }
  let key: KeyObject;
  try {
    key = createPublicKey({ key: Buffer.from(value), format: "der", type: "spki" });
  } catch {
    throw new DeviceCryptoError("invalid_public_key", "The device public key is invalid.");
  }
  if (key.asymmetricKeyType !== "ed25519") {
    throw new DeviceCryptoError("unsupported_public_key", "The device public key algorithm is not supported.");
  }
  const exported = key.export({ format: "der", type: "spki" });
  const canonical = new Uint8Array(exported);
  if (canonical.byteLength !== value.byteLength || !timingSafeEqual(canonical, value)) {
    throw new DeviceCryptoError("noncanonical_public_key", "The device public key encoding is not canonical.");
  }
  const digest = sha256(canonical);
  return { key, spkiDer: canonical, sha256: digest, fingerprint: `sha256:${digest}` };
}

export function verifyEd25519Signature(
  publicKey: CanonicalDevicePublicKey | KeyObject,
  payload: Uint8Array,
  signature: Uint8Array,
): boolean {
  if (signature.byteLength !== 64 || payload.byteLength === 0) return false;
  try {
    return verify(null, payload, "key" in publicKey ? publicKey.key : publicKey, signature);
  } catch {
    return false;
  }
}

export function newOpaqueSecret(bytes = 32): string {
  if (!Number.isInteger(bytes) || bytes < 24 || bytes > 128) {
    throw new DeviceCryptoError("invalid_signature", "The opaque secret size is invalid.");
  }
  return randomBytes(bytes).toString("base64url");
}

export function newOpaqueId(prefix: string): string {
  if (!/^[a-z][a-z0-9-]{0,31}$/u.test(prefix)) {
    throw new Error("Opaque ID prefix is invalid");
  }
  return `${prefix}_${randomUUID()}`;
}

export function newChallenge(bytes = 32): Uint8Array {
  if (!Number.isInteger(bytes) || bytes < 16 || bytes > 128) {
    throw new Error("Challenge size must be between 16 and 128 bytes");
  }
  return randomBytes(bytes);
}

export function validateNonce(nonce: Uint8Array): void {
  if (nonce.byteLength < 16 || nonce.byteLength > 128) {
    throw new DeviceCryptoError("invalid_signature", "The device-signature nonce is invalid.");
  }
}

export function canonicalGatewayAudience(value: string, allowInsecureLoopbackForTests = false): string {
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error("Gateway audience must be an absolute URL");
  }
  const loopback = parsed.hostname === "127.0.0.1" || parsed.hostname === "[::1]" || parsed.hostname === "::1";
  if (parsed.protocol !== "https:" && !(allowInsecureLoopbackForTests && parsed.protocol === "http:" && loopback)) {
    throw new Error("Gateway audience must use HTTPS");
  }
  if (parsed.username !== "" || parsed.password !== "" || parsed.hash !== "" || parsed.search !== "" || parsed.pathname !== "/") {
    throw new Error("Gateway audience must be an origin without credentials, query, fragment, or path");
  }
  return parsed.origin;
}
