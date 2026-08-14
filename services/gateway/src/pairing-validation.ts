import {
  DeviceSignatureAlgorithm,
  type DeviceScope,
  type DeviceSignature,
} from "@agent-talk/protocol";

import {
  canonicalGatewayAudience,
  newChallenge,
  newOpaqueId,
  newOpaqueSecret,
  validateNonce,
} from "./device-crypto.js";
import type { DeviceCredentialRecord } from "./pairing-ledger.js";
import {
  PairingError,
  type PairingServiceDependencies,
} from "./pairing-contracts.js";

export const defaultDependencies: PairingServiceDependencies = {
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

export function duration(value: number | undefined, fallback: number, maximum: number, name: string): number {
  const resolved = value ?? fallback;
  if (!Number.isInteger(resolved) || resolved <= 0 || resolved > maximum) {
    throw new Error(`${name} is outside its supported security bound`);
  }
  return resolved;
}
export function future(now: Date, milliseconds: number): Date {
  return new Date(now.getTime() + milliseconds);
}

export function secondsUntil(deadline: Date, now: Date): number {
  return Math.max(0, Math.ceil((deadline.getTime() - now.getTime()) / 1_000));
}

export function requireDisplayName(value: string): string {
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

export function requireOpaque(value: string, name: string): string {
  if (value.length === 0 || value.length > 256 || /[\u0000-\u001f\u007f]/u.test(value)) {
    throw new PairingError("invalid_request", `${name} is invalid.`);
  }
  return value;
}

export function normalizeUserCode(value: string): string {
  const normalized = value.trim().toUpperCase();
  if (!userCodePattern.test(normalized)) {
    throw new PairingError("pairing_not_found", "The pairing request was not found.");
  }
  return normalized;
}

export function exactSignature(
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

export function scopesAreSubset(candidate: readonly DeviceScope[], allowed: readonly DeviceScope[]): boolean {
  const set = new Set(allowed);
  return candidate.every((scope) => set.has(scope));
}

export function assertFingerprint(value: string): void {
  if (!fingerprintPattern.test(value)) {
    throw new Error("Gateway fingerprint must use sha256:<lowercase-hex>");
  }
}

export function assertAdministratorCredential(
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

export function requireReasonCode(value: string): string {
  if (!/^[a-z][a-z0-9_.-]{0,63}$/u.test(value)) {
    throw new PairingError("invalid_request", "The device revocation reason code is invalid.");
  }
  return value;
}
