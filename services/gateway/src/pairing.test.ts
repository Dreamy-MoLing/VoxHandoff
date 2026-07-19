import assert from "node:assert/strict";
import { generateKeyPairSync, sign, type KeyObject } from "node:crypto";
import test from "node:test";
import { setTimeout as delay } from "node:timers/promises";

import {
  DeviceSignatureAlgorithm,
  administratorPairingPayload,
  credentialRefreshPayload,
  deviceRevocationPayload,
  type DeviceScope,
  type DeviceSignature,
} from "@agent-talk/protocol";

import { normalizeEd25519PublicKey, sha256 } from "./device-crypto.js";
import type {
  DeviceAuthorizationRecord,
  DeviceCredentialRecord,
  PairingActivationFacts,
  PairingApprovalFacts,
  PairingAuditFact,
  PairingLedger,
  PairingLedgerTransaction,
  PairingProofFacts,
  PairingRecord,
  UsedRefreshRecord,
} from "./pairing-ledger.js";
import { PairingCoordinator, PairingError } from "./pairing.js";

interface MemoryState {
  pairings: Map<string, PairingRecord>;
  devices: Map<string, DeviceAuthorizationRecord>;
  credentials: Map<string, DeviceCredentialRecord>;
  rateAttempts: Map<string, Date[]>;
  nonces: Set<string>;
  usedRefresh: Map<string, UsedRefreshRecord>;
  audits: PairingAuditFact[];
}

class MemoryPairingLedger implements PairingLedger {
  private state: MemoryState = {
    pairings: new Map(),
    devices: new Map(),
    credentials: new Map(),
    rateAttempts: new Map(),
    nonces: new Set(),
    usedRefresh: new Map(),
    audits: [],
  };
  private tail: Promise<void> = Promise.resolve();

  seedDevice(device: DeviceAuthorizationRecord, credential: DeviceCredentialRecord): void {
    this.state.devices.set(device.deviceId, structuredClone(device));
    this.state.credentials.set(credential.credentialId, structuredClone(credential));
  }

  pairing(pairingId: string): PairingRecord | undefined {
    const value = this.state.pairings.get(pairingId);
    return value === undefined ? undefined : structuredClone(value);
  }

  credential(credentialId: string): DeviceCredentialRecord | undefined {
    const value = this.state.credentials.get(credentialId);
    return value === undefined ? undefined : structuredClone(value);
  }

  auditFacts(): readonly PairingAuditFact[] {
    return structuredClone(this.state.audits);
  }

  async runPairingTransaction<T>(work: (transaction: PairingLedgerTransaction) => Promise<T>): Promise<T> {
    let release: (() => void) | undefined;
    const previous = this.tail;
    this.tail = new Promise<void>((resolve) => {
      release = resolve;
    });
    await previous;
    const staged = structuredClone(this.state);
    try {
      const result = await work(this.transaction(staged));
      this.state = staged;
      return result;
    } finally {
      release?.();
    }
  }

  private transaction(state: MemoryState): PairingLedgerTransaction {
    return {
      consumePairingRateLimit: async (key, windowStartedAt, maximumAttempts, now) => {
        const retained = (state.rateAttempts.get(key) ?? []).filter(
          (attempt) => attempt.getTime() > windowStartedAt.getTime(),
        );
        retained.push(now);
        state.rateAttempts.set(key, retained);
        return retained.length <= maximumAttempts;
      },
      insertPairing: async (record) => {
        if (state.pairings.has(record.pairingId)) throw new Error("duplicate pairing");
        state.pairings.set(record.pairingId, structuredClone(record));
      },
      lockPairingById: async (pairingId) => state.pairings.get(pairingId),
      lockPairingByUserCodeSha256: async (code) =>
        [...state.pairings.values()].find((pairing) => pairing.userCodeSha256 === code),
      lockDeviceAuthorization: async (deviceId) => state.devices.get(deviceId),
      lockCredential: async (credentialId) => state.credentials.get(credentialId),
      findUsedRefresh: async (credentialId, refreshTokenSha256) =>
        state.usedRefresh.get(`${credentialId}\0${refreshTokenSha256}`),
      recordNonce: async (credentialId, purpose, nonceSha256) => {
        const identity = `${credentialId}\0${purpose}\0${nonceSha256}`;
        if (state.nonces.has(identity)) return false;
        state.nonces.add(identity);
        return true;
      },
      approvePairing: async (facts: PairingApprovalFacts) => {
        const pairing = required(state.pairings.get(facts.pairingId));
        pairing.state = "approved";
        pairing.approvedByDeviceId = facts.administratorDeviceId;
        pairing.approvedScopes = [...facts.approvedScopes];
        pairing.administratorProofSha256 = facts.administratorProofSha256;
        pairing.updatedAt = facts.approvedAt;
      },
      verifyPairingProof: async (facts: PairingProofFacts) => {
        const pairing = required(state.pairings.get(facts.pairingId));
        pairing.state = "proof_verified";
        pairing.deviceProofSha256 = facts.proofSha256;
        pairing.deviceId = facts.deviceId;
        pairing.credentialId = facts.credential.credentialId;
        pairing.confirmationPayload = facts.credential.confirmationPayload;
        pairing.confirmationExpiresAt = facts.credential.confirmationExpiresAt;
        pairing.updatedAt = facts.verifiedAt;
        state.credentials.set(facts.credential.credentialId, {
          credentialId: facts.credential.credentialId,
          deviceId: facts.credential.deviceId,
          state: "pending_confirmation",
          deviceActive: false,
          publicKeySpki: facts.credential.publicKeySpki,
          publicKeySha256: facts.credential.publicKeySha256,
          gatewayAudience: facts.credential.gatewayAudience,
          scopes: facts.credential.scopes,
          generation: 1n,
          accessTokenSha256: null,
          accessExpiresAt: null,
          refreshTokenSha256: null,
          refreshExpiresAt: facts.credential.familyExpiresAt,
          familyExpiresAt: facts.credential.familyExpiresAt,
        });
      },
      activatePairing: async (facts: PairingActivationFacts) => {
        const pairing = required(state.pairings.get(facts.pairingId));
        const credential = required(state.credentials.get(facts.credentialId));
        pairing.state = "confirmed";
        pairing.updatedAt = facts.activatedAt;
        state.devices.set(facts.deviceId, {
          deviceId: facts.deviceId,
          active: true,
          scopes: [...facts.scopes],
        });
        credential.state = "active";
        credential.deviceActive = true;
        credential.accessTokenSha256 = facts.accessTokenSha256;
        credential.accessExpiresAt = facts.accessExpiresAt;
        credential.refreshTokenSha256 = facts.refreshTokenSha256;
        credential.refreshExpiresAt = facts.refreshExpiresAt;
      },
      rotateCredential: async (facts) => {
        const credential = required(state.credentials.get(facts.credentialId));
        if (
          credential.deviceId !== facts.deviceId ||
          credential.generation !== facts.expectedGeneration ||
          credential.refreshTokenSha256 !== facts.previousRefreshTokenSha256
        ) {
          throw new Error("credential rotation state changed concurrently");
        }
        state.usedRefresh.set(`${facts.credentialId}\0${facts.previousRefreshTokenSha256}`, {
          credentialId: facts.credentialId,
          refreshTokenSha256: facts.previousRefreshTokenSha256,
          generation: facts.expectedGeneration,
        });
        credential.generation += 1n;
        credential.accessTokenSha256 = facts.accessTokenSha256;
        credential.accessExpiresAt = facts.accessExpiresAt;
        credential.refreshTokenSha256 = facts.refreshTokenSha256;
        credential.refreshExpiresAt = facts.refreshExpiresAt;
      },
      revokeDeviceCredentials: async (facts) => {
        const device = state.devices.get(facts.deviceId);
        if (device !== undefined) device.active = false;
        for (const credential of state.credentials.values()) {
          if (credential.deviceId !== facts.deviceId) continue;
          credential.state = "revoked";
          credential.deviceActive = false;
          credential.accessTokenSha256 = null;
          credential.accessExpiresAt = null;
          credential.refreshTokenSha256 = null;
        }
      },
      expirePairing: async (pairingId, expiredAt) => {
        const pairing = required(state.pairings.get(pairingId));
        pairing.state = "expired";
        pairing.updatedAt = expiredAt;
        if (pairing.credentialId !== null) {
          const credential = state.credentials.get(pairing.credentialId);
          if (credential !== undefined) credential.state = "revoked";
        }
      },
      insertSecurityAudit: async (fact) => {
        state.audits.push(structuredClone(fact));
      },
    };
  }
}

function required<T>(value: T | undefined): T {
  if (value === undefined) throw new Error("missing test record");
  return value;
}

interface TestContext {
  ledger: MemoryPairingLedger;
  coordinator: PairingCoordinator;
  now: { value: Date };
  administratorPrivateKey: KeyObject;
  devicePrivateKey: KeyObject;
  devicePublicKey: Uint8Array;
}

function context(options: {
  maximumBeginsPerWindow?: number;
  pairingLifetimeMs?: number;
  confirmationResultCacheMs?: number;
} = {}): TestContext {
  const ledger = new MemoryPairingLedger();
  const now = { value: new Date("2030-01-01T00:00:00.000Z") };
  let nextId = 0;
  let nextChallenge = 0;
  const administrator = generateKeyPairSync("ed25519");
  const administratorSpki = new Uint8Array(administrator.publicKey.export({ format: "der", type: "spki" }));
  const administratorKey = normalizeEd25519PublicKey(administratorSpki);
  ledger.seedDevice(
    { deviceId: "administrator-device", active: true, scopes: ["administer"] },
    {
      credentialId: "administrator-credential",
      deviceId: "administrator-device",
      state: "active",
      deviceActive: true,
      publicKeySpki: administratorSpki,
      publicKeySha256: administratorKey.sha256,
      gatewayAudience: "https://gateway.example",
      scopes: ["administer"],
      generation: 1n,
      accessTokenSha256: "a".repeat(64),
      accessExpiresAt: new Date("2030-01-01T00:15:00.000Z"),
      refreshTokenSha256: "b".repeat(64),
      refreshExpiresAt: new Date("2030-01-31T00:00:00.000Z"),
      familyExpiresAt: new Date("2030-01-31T00:00:00.000Z"),
    },
  );
  const device = generateKeyPairSync("ed25519");
  const devicePublicKey = new Uint8Array(device.publicKey.export({ format: "der", type: "spki" }));
  const coordinator = new PairingCoordinator(ledger, {
    gatewayAudience: "https://gateway.example",
    gatewayFingerprint: `sha256:${"c".repeat(64)}`,
    verificationUri: "https://gateway.example/pair",
    ...(options.maximumBeginsPerWindow === undefined ? {} : { maximumBeginsPerWindow: options.maximumBeginsPerWindow }),
    ...(options.pairingLifetimeMs === undefined ? {} : { pairingLifetimeMs: options.pairingLifetimeMs }),
    ...(options.confirmationResultCacheMs === undefined
      ? {}
      : { confirmationResultCacheMs: options.confirmationResultCacheMs }),
    dependencies: {
      now: () => new Date(now.value),
      newOpaqueId: (prefix) => `${prefix}-${++nextId}`,
      newChallenge: (bytes = 32) => new Uint8Array(bytes).fill(++nextChallenge),
      newOpaqueSecret: (bytes = 32) => `${bytes}-${++nextId}-${"x".repeat(bytes)}`,
      newUserCode: () => "ABCD-EFGH",
    },
  });
  return {
    ledger,
    coordinator,
    now,
    administratorPrivateKey: administrator.privateKey,
    devicePrivateKey: device.privateKey,
    devicePublicKey,
  };
}

function signature(
  credentialId: string,
  payload: Uint8Array,
  privateKey: KeyObject,
  nonce: Uint8Array = new Uint8Array(),
): DeviceSignature {
  return {
    $typeName: "agent_talk.v1.DeviceSignature",
    credentialId,
    nonce,
    signature: new Uint8Array(sign(null, payload, privateKey)),
    algorithm: DeviceSignatureAlgorithm.ED25519,
  };
}

async function begin(context: TestContext, scopes: readonly string[] = ["observe", "send"]) {
  return context.coordinator.begin({
    deviceDisplayName: "Test device",
    devicePublicKey: context.devicePublicKey,
    requestedScopes: scopes,
    expectedGatewayAudience: "https://gateway.example",
    rateLimitKey: "198.51.100.10",
  });
}

function approvalSignature(
  context: TestContext,
  begun: Awaited<ReturnType<typeof begin>>,
  approvedScopes: readonly DeviceScope[],
  nonce: Uint8Array,
): DeviceSignature {
  return signature(
    "administrator-credential",
    administratorPairingPayload({
      pairingId: begun.pairingId,
      userCode: begun.userCode,
      deviceFingerprint: begun.deviceFingerprint,
      gatewayFingerprint: begun.gatewayFingerprint,
      gatewayAudience: begun.gatewayAudience,
      approvedScopes,
      nonce,
    }),
    context.administratorPrivateKey,
    nonce,
  );
}

async function approve(
  context: TestContext,
  begun: Awaited<ReturnType<typeof begin>>,
  approvedScopes: readonly DeviceScope[] = ["observe"],
  nonce = new Uint8Array(32).fill(9),
) {
  return context.coordinator.approve({
    pairingId: begun.pairingId,
    userCode: begun.userCode,
    approvedScopes,
    expectedDeviceFingerprint: begun.deviceFingerprint,
    expectedGatewayFingerprint: begun.gatewayFingerprint,
    expectedGatewayAudience: begun.gatewayAudience,
    administratorDeviceId: "administrator-device",
    administratorSignature: approvalSignature(context, begun, approvedScopes, nonce),
  });
}

async function confirmDevice(testContext: TestContext) {
  const begun = await begin(testContext);
  await approve(testContext, begun, ["observe"]);
  const completed = await testContext.coordinator.complete({
    pairingId: begun.pairingId,
    legacyDeviceProof: "",
    deviceKeyProof: signature("", begun.deviceProofPayload, testContext.devicePrivateKey),
  });
  const confirmationProof = signature(
    completed.credentialId,
    completed.confirmationPayload,
    testContext.devicePrivateKey,
  );
  const confirmationInput = {
    pairingId: begun.pairingId,
    credentialId: completed.credentialId,
    deviceSignature: confirmationProof,
  };
  const confirmations = await Promise.all([
    testContext.coordinator.confirm(confirmationInput),
    testContext.coordinator.confirm(confirmationInput),
  ]);
  const confirmed = confirmations[0];
  assert.deepEqual(confirmations[1], confirmed);
  return { begun, completed, confirmationProof, confirmed };
}

test("requires owner verification and two device signatures before issuing tokens", async () => {
  const testContext = context();
  const begun = await begin(testContext);
  assert.equal(Object.hasOwn(begun, "accessToken"), false);
  const inspected = await testContext.coordinator.inspect(begun.userCode, "administrator-device");
  assert.equal(inspected.deviceFingerprint, begun.deviceFingerprint);
  assert.deepEqual(inspected.requestedScopes, ["observe", "send"]);

  await assert.rejects(
    testContext.coordinator.complete({
      pairingId: begun.pairingId,
      legacyDeviceProof: "",
      deviceKeyProof: signature("", begun.deviceProofPayload, testContext.devicePrivateKey),
    }),
    (error: unknown) => error instanceof PairingError && error.code === "pairing_not_approved",
  );
  await approve(testContext, begun, ["observe"]);
  const proof = signature("", begun.deviceProofPayload, testContext.devicePrivateKey);
  const completed = await testContext.coordinator.complete({
    pairingId: begun.pairingId,
    legacyDeviceProof: "",
    deviceKeyProof: proof,
  });
  assert.equal(Object.hasOwn(completed, "accessToken"), false);
  assert.deepEqual(completed.scopes, ["observe"]);
  assert.deepEqual(
    await testContext.coordinator.complete({
      pairingId: begun.pairingId,
      legacyDeviceProof: "",
      deviceKeyProof: proof,
    }),
    completed,
  );

  const confirmationProof = signature(
    completed.credentialId,
    completed.confirmationPayload,
    testContext.devicePrivateKey,
  );
  const confirmed = await testContext.coordinator.confirm({
    pairingId: begun.pairingId,
    credentialId: completed.credentialId,
    deviceSignature: confirmationProof,
  });
  assert.equal(confirmed.deviceId, completed.deviceId);
  assert.notEqual(confirmed.accessToken, "");
  assert.notEqual(confirmed.refreshToken, "");
  const persisted = required(testContext.ledger.credential(completed.credentialId));
  assert.equal(persisted.state, "active");
  assert.equal(persisted.accessTokenSha256, sha256(confirmed.accessToken));
  assert.equal(persisted.refreshTokenSha256, sha256(confirmed.refreshToken));
  assert.equal(JSON.stringify(testContext.ledger.auditFacts()).includes(confirmed.accessToken), false);
  assert.equal(JSON.stringify(testContext.ledger.auditFacts()).includes(confirmed.refreshToken), false);
  assert.deepEqual(
    await testContext.coordinator.confirm({
      pairingId: begun.pairingId,
      credentialId: completed.credentialId,
      deviceSignature: confirmationProof,
    }),
    confirmed,
  );
  const changedProof = {
    ...confirmationProof,
    signature: Uint8Array.from(confirmationProof.signature),
  };
  changedProof.signature[0] = (changedProof.signature[0] ?? 0) ^ 1;
  await assert.rejects(
    testContext.coordinator.confirm({
      pairingId: begun.pairingId,
      credentialId: completed.credentialId,
      deviceSignature: changedProof,
    }),
    (error: unknown) => error instanceof PairingError && error.code === "pairing_conflict",
  );
});

test("does not return a confirmation result after its short recovery window", async () => {
  const testContext = context({ confirmationResultCacheMs: 20 });
  const { begun, completed, confirmationProof } = await confirmDevice(testContext);
  await delay(40);

  await assert.rejects(
    testContext.coordinator.confirm({
      pairingId: begun.pairingId,
      credentialId: completed.credentialId,
      deviceSignature: confirmationProof,
    }),
    (error: unknown) => error instanceof PairingError && error.code === "pairing_conflict",
  );
});

test("approval cannot expand scope, skip fingerprint checks, or reuse an administrator nonce", async () => {
  const testContext = context();
  const first = await begin(testContext, ["observe"]);
  await assert.rejects(
    approve(testContext, first, ["observe", "send"]),
    (error: unknown) => error instanceof PairingError && error.code === "scope_not_allowed",
  );
  const validSignature = approvalSignature(testContext, first, ["observe"], new Uint8Array(32).fill(5));
  await assert.rejects(
    testContext.coordinator.approve({
      pairingId: first.pairingId,
      userCode: first.userCode,
      approvedScopes: ["observe"],
      expectedDeviceFingerprint: `sha256:${"0".repeat(64)}`,
      expectedGatewayFingerprint: first.gatewayFingerprint,
      expectedGatewayAudience: first.gatewayAudience,
      administratorDeviceId: "administrator-device",
      administratorSignature: validSignature,
    }),
    (error: unknown) => error instanceof PairingError && error.code === "fingerprint_mismatch",
  );
  await approve(testContext, first, ["observe"], new Uint8Array(32).fill(7));

  const second = await begin(testContext, ["observe"]);
  await assert.rejects(
    approve(testContext, second, ["observe"], new Uint8Array(32).fill(7)),
    (error: unknown) => error instanceof PairingError && error.code === "nonce_replayed",
  );
  assert.equal(testContext.ledger.pairing(second.pairingId)?.state, "pending_owner");
});

test("rate limiting and expiry commit safe audit facts without creating credentials", async () => {
  const rateLimited = context({ maximumBeginsPerWindow: 1 });
  await begin(rateLimited);
  await assert.rejects(
    begin(rateLimited),
    (error: unknown) => error instanceof PairingError && error.code === "rate_limited" && error.retryable,
  );
  assert.equal(rateLimited.ledger.auditFacts().at(-1)?.safeCode, "rate_limited");

  const expiring = context({ pairingLifetimeMs: 1_000 });
  const begun = await begin(expiring);
  expiring.now.value = new Date("2030-01-01T00:00:02.000Z");
  await assert.rejects(
    expiring.coordinator.inspect(begun.userCode, "administrator-device"),
    (error: unknown) => error instanceof PairingError && error.code === "pairing_expired",
  );
  assert.equal(expiring.ledger.pairing(begun.pairingId)?.state, "expired");
  assert.equal(expiring.ledger.auditFacts().at(-1)?.safeCode, "challenge_expired");
});

test("concurrent exact approval serializes to one durable owner decision", async () => {
  const testContext = context();
  const begun = await begin(testContext);
  const nonce = new Uint8Array(32).fill(8);
  const results = await Promise.all([
    approve(testContext, begun, ["observe"], nonce),
    approve(testContext, begun, ["observe"], nonce),
  ]);
  assert.deepEqual(results.map((result) => result.approved), [true, true]);
  assert.equal(testContext.ledger.auditFacts().filter((fact) => fact.action === "pairing.approve").length, 1);
  assert.equal(testContext.ledger.pairing(begun.pairingId)?.state, "approved");
});

test("rotates refresh credentials once and revokes the device on valid old-token replay", async () => {
  const testContext = context();
  const { begun, completed, confirmationProof, confirmed } = await confirmDevice(testContext);
  const nonce = new Uint8Array(32).fill(11);
  const payload = credentialRefreshPayload({
    credentialId: confirmed.credentialId,
    deviceId: confirmed.deviceId,
    gatewayAudience: confirmed.gatewayAudience,
    refreshTokenSha256: sha256(confirmed.refreshToken),
    generation: 1n,
    nonce,
  });
  const refreshSignature = signature(
    confirmed.credentialId,
    payload,
    testContext.devicePrivateKey,
    nonce,
  );
  const refreshed = await testContext.coordinator.refresh({
    credentialId: confirmed.credentialId,
    refreshToken: confirmed.refreshToken,
    deviceSignature: refreshSignature,
  });
  assert.notEqual(refreshed.accessToken, confirmed.accessToken);
  assert.notEqual(refreshed.refreshToken, confirmed.refreshToken);
  assert.equal(testContext.ledger.credential(confirmed.credentialId)?.generation, 2n);
  await assert.rejects(
    testContext.coordinator.confirm({
      pairingId: begun.pairingId,
      credentialId: completed.credentialId,
      deviceSignature: confirmationProof,
    }),
    (error: unknown) => error instanceof PairingError && error.code === "pairing_conflict",
  );

  await assert.rejects(
    testContext.coordinator.refresh({
      credentialId: confirmed.credentialId,
      refreshToken: confirmed.refreshToken,
      deviceSignature: refreshSignature,
    }),
    (error: unknown) => error instanceof PairingError && error.code === "refresh_replayed",
  );
  assert.equal(testContext.ledger.credential(confirmed.credentialId)?.state, "revoked");
  assert.equal(testContext.ledger.auditFacts().at(-1)?.safeCode, "refresh_replayed");
});

test("does not revoke for an old token without a valid device signature", async () => {
  const testContext = context();
  const { confirmed } = await confirmDevice(testContext);
  const nonce = new Uint8Array(32).fill(12);
  await assert.rejects(
    testContext.coordinator.refresh({
      credentialId: confirmed.credentialId,
      refreshToken: confirmed.refreshToken,
      deviceSignature: signature(
        confirmed.credentialId,
        new Uint8Array([1, 2, 3]),
        testContext.devicePrivateKey,
        nonce,
      ),
    }),
    (error: unknown) => error instanceof PairingError && error.code === "proof_invalid",
  );
  assert.equal(testContext.ledger.credential(confirmed.credentialId)?.state, "active");
});

test("requires an administrator device signature to revoke an active device", async () => {
  const testContext = context();
  const { confirmed } = await confirmDevice(testContext);
  const nonce = new Uint8Array(32).fill(13);
  const payload = deviceRevocationPayload({
    administratorDeviceId: "administrator-device",
    targetDeviceId: confirmed.deviceId,
    reasonCode: "owner_revoked",
    gatewayAudience: confirmed.gatewayAudience,
    nonce,
  });
  assert.equal(await testContext.coordinator.revokeDevice({
    targetDeviceId: confirmed.deviceId,
    reasonCode: "owner_revoked",
    administratorDeviceId: "administrator-device",
    administratorSignature: signature(
      "administrator-credential",
      payload,
      testContext.administratorPrivateKey,
      nonce,
    ),
  }), true);
  assert.equal(testContext.ledger.credential(confirmed.credentialId)?.state, "revoked");
  assert.equal(testContext.ledger.auditFacts().at(-1)?.action, "device.revoke");
});
