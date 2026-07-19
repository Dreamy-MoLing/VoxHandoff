import assert from "node:assert/strict";
import { generateKeyPairSync, sign } from "node:crypto";
import test from "node:test";

import { pairingProofPayload } from "@agent-talk/protocol";

import {
  DeviceCryptoError,
  canonicalGatewayAudience,
  newChallenge,
  newOpaqueId,
  newOpaqueSecret,
  normalizeEd25519PublicKey,
  sha256,
  validateNonce,
  verifyEd25519Signature,
} from "./device-crypto.js";

test("accepts only canonical Ed25519 SPKI keys and verifies exact payloads", () => {
  const { publicKey, privateKey } = generateKeyPairSync("ed25519");
  const spki = new Uint8Array(publicKey.export({ format: "der", type: "spki" }));
  const normalized = normalizeEd25519PublicKey(spki);
  assert.equal(normalized.sha256, sha256(spki));
  assert.equal(normalized.fingerprint, `sha256:${sha256(spki)}`);

  const payload = pairingProofPayload({
    pairingId: "pairing-1",
    challenge: new Uint8Array(32).fill(4),
    gatewayAudience: "https://gateway.example",
    deviceFingerprint: normalized.fingerprint,
    requestedScopes: ["observe", "send"],
  });
  const signature = new Uint8Array(sign(null, payload, privateKey));
  assert.equal(verifyEd25519Signature(normalized, payload, signature), true);
  assert.equal(verifyEd25519Signature(normalized, new Uint8Array([1]), signature), false);
  assert.equal(verifyEd25519Signature(normalized, payload, signature.subarray(0, 63)), false);
});

test("rejects malformed and non-Ed25519 public keys with safe codes", () => {
  assert.throws(
    () => normalizeEd25519PublicKey(new Uint8Array([1, 2, 3])),
    (error: unknown) => error instanceof DeviceCryptoError && error.code === "invalid_public_key",
  );
  const { publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const spki = new Uint8Array(publicKey.export({ format: "der", type: "spki" }));
  assert.throws(
    () => normalizeEd25519PublicKey(spki),
    (error: unknown) => error instanceof DeviceCryptoError && error.code === "unsupported_public_key",
  );
});

test("creates opaque random material and enforces nonce sizes", () => {
  const first = newOpaqueSecret();
  const second = newOpaqueSecret();
  assert.notEqual(first, second);
  assert.match(newOpaqueId("credential"), /^credential_[0-9a-f-]{36}$/u);
  assert.equal(newChallenge().byteLength, 32);
  assert.doesNotThrow(() => validateNonce(new Uint8Array(16)));
  assert.throws(() => validateNonce(new Uint8Array(15)), DeviceCryptoError);
});

test("canonicalizes HTTPS audiences and limits plaintext to explicit loopback tests", () => {
  assert.equal(canonicalGatewayAudience("https://gateway.example:8443/"), "https://gateway.example:8443");
  assert.throws(() => canonicalGatewayAudience("http://gateway.example"), /HTTPS/u);
  assert.equal(canonicalGatewayAudience("http://127.0.0.1:8080/", true), "http://127.0.0.1:8080");
  assert.throws(() => canonicalGatewayAudience("https://gateway.example/path"), /origin/u);
  assert.throws(() => canonicalGatewayAudience("https://user@gateway.example/"), /origin/u);
});
