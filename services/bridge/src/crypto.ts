import {
  createHash,
  createPublicKey,
  randomBytes,
  randomInt,
  randomUUID,
  timingSafeEqual,
  verify,
  type KeyObject,
} from "node:crypto";

const tokenBytes = 32;
const base64Pattern = /^[A-Za-z0-9+/]+={0,2}$/u;
const tokenPattern = /^[A-Za-z0-9_-]{43}$/u;

export interface NormalizedDevicePublicKey {
  spki: string;
  fingerprint: string;
  key: KeyObject;
}

export function createPairingToken(): { token: string; tokenHash: string } {
  const token = randomBytes(tokenBytes).toString("base64url");
  return { token, tokenHash: hashSecret(token) };
}

export function createDeviceCredential(): { credential: string; credentialHash: string } {
  const credential = randomBytes(tokenBytes).toString("base64url");
  return { credential, credentialHash: hashSecret(credential) };
}

export function hashSecret(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

export function constantTimeEqual(left: string, right: string): boolean {
  const leftBytes = Buffer.from(left, "utf8");
  const rightBytes = Buffer.from(right, "utf8");
  return leftBytes.byteLength === rightBytes.byteLength && timingSafeEqual(leftBytes, rightBytes);
}

export function randomOpaqueId(prefix: string): string {
  if (!/^[a-z][a-z0-9-]{0,31}$/u.test(prefix)) throw new Error("The opaque id prefix is invalid.");
  return `${prefix}_${randomUUID()}`;
}

export function randomChallenge(): string {
  return randomBytes(32).toString("base64url");
}

export function randomConfirmationCode(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, "0");
}

export function normalizeDevicePublicKey(spki: string): NormalizedDevicePublicKey {
  if (spki.length === 0 || spki.length > 1024 || !base64Pattern.test(spki)) {
    throw new Error("The device public key is invalid.");
  }
  const der = Buffer.from(spki, "base64");
  if (der.byteLength === 0 || der.toString("base64") !== spki) throw new Error("The device public key encoding is invalid.");
  let key: KeyObject;
  try {
    key = createPublicKey({ key: der, format: "der", type: "spki" });
  } catch {
    throw new Error("The device public key is invalid.");
  }
  if (key.asymmetricKeyType !== "ed25519") throw new Error("The device public key algorithm is unsupported.");
  const canonical = key.export({ format: "der", type: "spki" });
  const canonicalSpki = Buffer.from(canonical).toString("base64");
  if (canonicalSpki !== spki) throw new Error("The device public key encoding is not canonical.");
  const digest = createHash("sha256").update(canonical).digest("hex");
  return { spki: spki, fingerprint: `sha256:${digest}`, key };
}

export function verifyDeviceSignature(
  spki: string,
  payload: Uint8Array,
  signature: string,
): boolean {
  if (!base64Pattern.test(signature)) return false;
  const signatureBytes = Buffer.from(signature, "base64");
  if (signatureBytes.byteLength !== 64 || signatureBytes.toString("base64") !== signature) return false;
  try {
    return verify(null, Buffer.from(payload), normalizeDevicePublicKey(spki).key, signatureBytes);
  } catch {
    return false;
  }
}

export function pairingCompletionPayload(pairingRequestId: string, challenge: string): Uint8Array {
  return new TextEncoder().encode(`voxhandoff/companion-bridge/pairing-complete/v1\0${pairingRequestId}\0${challenge}`);
}

export function isPairingToken(value: string): boolean {
  return tokenPattern.test(value);
}
