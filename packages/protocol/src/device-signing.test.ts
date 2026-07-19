import assert from "node:assert/strict";
import test from "node:test";

import {
  approvalDecisionPayload,
  DeviceSigningContractError,
  administratorPairingPayload,
  canonicalSignedPayload,
  credentialRefreshPayload,
  normalizeDeviceScopes,
  pairingProofPayload,
} from "./device-signing.js";

test("canonical payload framing is deterministic, ordered, and domain separated", () => {
  const first = canonicalSignedPayload("agent-talk/test/v1", [
    { name: "alpha", value: "one" },
    { name: "beta", value: new Uint8Array([2, 3]) },
  ]);
  const exact = canonicalSignedPayload("agent-talk/test/v1", [
    { name: "alpha", value: "one" },
    { name: "beta", value: new Uint8Array([2, 3]) },
  ]);
  const reordered = canonicalSignedPayload("agent-talk/test/v1", [
    { name: "beta", value: new Uint8Array([2, 3]) },
    { name: "alpha", value: "one" },
  ]);
  const otherDomain = canonicalSignedPayload("agent-talk/other/v1", [
    { name: "alpha", value: "one" },
    { name: "beta", value: new Uint8Array([2, 3]) },
  ]);

  assert.deepEqual(first, exact);
  assert.notDeepEqual(first, reordered);
  assert.notDeepEqual(first, otherDomain);
  assert.throws(
    () => canonicalSignedPayload("agent-talk/test/v1", [
      { name: "alpha", value: "one" },
      { name: "alpha", value: "two" },
    ]),
    (error: unknown) => error instanceof DeviceSigningContractError && error.code === "duplicate_field",
  );
});

test("device scopes are exact, unique, and canonicalized", () => {
  assert.deepEqual(normalizeDeviceScopes(["send", "observe"]), ["observe", "send"]);
  assert.throws(
    () => normalizeDeviceScopes(["send", "send"]),
    (error: unknown) => error instanceof DeviceSigningContractError && error.code === "duplicate_scope",
  );
  assert.throws(
    () => normalizeDeviceScopes(["owner"]),
    (error: unknown) => error instanceof DeviceSigningContractError && error.code === "invalid_scope",
  );
});

test("pairing and administrator payloads bind audience, fingerprints, scopes, and nonce", () => {
  const proof = pairingProofPayload({
    pairingId: "pairing-1",
    challenge: new Uint8Array(32).fill(7),
    gatewayAudience: "https://gateway.example",
    deviceFingerprint: `sha256:${"a".repeat(64)}`,
    requestedScopes: ["send", "observe"],
  });
  const changedAudience = pairingProofPayload({
    pairingId: "pairing-1",
    challenge: new Uint8Array(32).fill(7),
    gatewayAudience: "https://other.example",
    deviceFingerprint: `sha256:${"a".repeat(64)}`,
    requestedScopes: ["observe", "send"],
  });
  assert.notDeepEqual(proof, changedAudience);

  const approval = administratorPairingPayload({
    pairingId: "pairing-1",
    userCode: "ABCD-EFGH",
    deviceFingerprint: `sha256:${"a".repeat(64)}`,
    gatewayFingerprint: `sha256:${"b".repeat(64)}`,
    gatewayAudience: "https://gateway.example",
    approvedScopes: ["observe"],
    nonce: new Uint8Array(32).fill(9),
  });
  assert.notDeepEqual(proof, approval);
});

test("refresh payload rejects ambiguous hashes and non-positive generations", () => {
  const input = {
    credentialId: "credential-1",
    deviceId: "device-1",
    gatewayAudience: "https://gateway.example",
    refreshTokenSha256: "a".repeat(64),
    generation: 1n,
    nonce: new Uint8Array(32).fill(1),
  };
  assert(credentialRefreshPayload(input).byteLength > 0);
  assert.throws(
    () => credentialRefreshPayload({ ...input, refreshTokenSha256: "not-a-hash" }),
    (error: unknown) => error instanceof DeviceSigningContractError && error.code === "invalid_sha256",
  );
  assert.throws(
    () => credentialRefreshPayload({ ...input, generation: 0n }),
    (error: unknown) => error instanceof DeviceSigningContractError && error.code === "invalid_field",
  );
});

test("approval signatures bind the actual Agent host and Gateway audience", () => {
  const input = {
    credentialId: "credential-1",
    deviceId: "device-1",
    hostIdentity: "node-1",
    gatewayAudience: "https://gateway.example",
    requestId: "request-1",
    approvalId: "approval-1",
    decision: "approve" as const,
    operationSummarySha256: "a".repeat(64),
    nonce: new Uint8Array(32).fill(3),
  };
  assert.notDeepEqual(
    approvalDecisionPayload(input),
    approvalDecisionPayload({ ...input, hostIdentity: "node-2" }),
  );
  assert.notDeepEqual(
    approvalDecisionPayload(input),
    approvalDecisionPayload({ ...input, gatewayAudience: "https://other.example" }),
  );
});
