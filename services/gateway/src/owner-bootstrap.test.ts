import assert from "node:assert/strict";
import { generateKeyPairSync, sign } from "node:crypto";
import test from "node:test";

import { DeviceSignatureAlgorithm, ownerBootstrapPayload } from "@agent-talk/protocol";
import { normalizeEd25519PublicKey, sha256 } from "./device-crypto.js";
import {
  bootstrapInitialOwner,
  OwnerBootstrapError,
  type OwnerBootstrapFacts,
  type OwnerBootstrapStore,
} from "./owner-bootstrap.js";

class FakeStore implements OwnerBootstrapStore {
  facts: OwnerBootstrapFacts | undefined;
  async createInitialOwner(facts: OwnerBootstrapFacts): Promise<boolean> {
    if (this.facts !== undefined) return false;
    this.facts = structuredClone(facts);
    return true;
  }
}

test("bootstraps exactly one owner from a local proof without storing plaintext tokens", async () => {
  const keys = generateKeyPairSync("ed25519");
  const spki = new Uint8Array(keys.publicKey.export({ format: "der", type: "spki" }));
  const publicKey = normalizeEd25519PublicKey(spki);
  const nonce = new Uint8Array(32).fill(4);
  const payload = ownerBootstrapPayload({
    gatewayAudience: "https://gateway.example",
    deviceFingerprint: publicKey.fingerprint,
    scopes: ["administer", "approve", "interrupt", "observe", "send"],
    nonce,
  });
  const store = new FakeStore();
  let nextId = 0;
  const options = {
    gatewayAudience: "https://gateway.example",
    now: () => new Date("2030-01-01T00:00:00.000Z"),
    newOpaqueId: (prefix: string) => `${prefix}-${++nextId}`,
    newOpaqueSecret: (bytes = 32) => `${bytes}-${"x".repeat(bytes)}`,
  };
  const input = {
    deviceDisplayName: "Owner device",
    devicePublicKey: spki,
    expectedGatewayAudience: "https://gateway.example",
    deviceSignature: {
      $typeName: "agent_talk.v1.DeviceSignature" as const,
      credentialId: "",
      nonce,
      signature: new Uint8Array(sign(null, payload, keys.privateKey)),
      algorithm: DeviceSignatureAlgorithm.ED25519,
    },
  };
  const result = await bootstrapInitialOwner(store, input, options);
  assert.deepEqual(result.scopes, ["administer", "approve", "interrupt", "observe", "send"]);
  assert.equal(store.facts?.accessTokenSha256, sha256(result.accessToken));
  assert.equal(store.facts?.refreshTokenSha256, sha256(result.refreshToken));
  assert.equal(JSON.stringify(store.facts).includes(result.accessToken), false);
  await assert.rejects(
    bootstrapInitialOwner(store, input, options),
    (error: unknown) => error instanceof OwnerBootstrapError && error.code === "owner_exists",
  );
});

test("rejects bootstrap without proof of possession before touching the store", async () => {
  const keys = generateKeyPairSync("ed25519");
  const spki = new Uint8Array(keys.publicKey.export({ format: "der", type: "spki" }));
  const store = new FakeStore();
  await assert.rejects(
    bootstrapInitialOwner(store, {
      deviceDisplayName: "Owner device",
      devicePublicKey: spki,
      expectedGatewayAudience: "https://gateway.example",
      deviceSignature: undefined,
    }, { gatewayAudience: "https://gateway.example" }),
    (error: unknown) => error instanceof OwnerBootstrapError && error.code === "proof_invalid",
  );
  assert.equal(store.facts, undefined);
});

test("maps malformed owner input to stable errors before touching the store", async () => {
  const store = new FakeStore();
  await assert.rejects(
    bootstrapInitialOwner(store, {
      deviceDisplayName: "Owner\nDevice",
      devicePublicKey: new Uint8Array([1, 2, 3]),
      expectedGatewayAudience: "https://gateway.example",
      deviceSignature: undefined,
    }, { gatewayAudience: "https://gateway.example" }),
    (error: unknown) => error instanceof OwnerBootstrapError && error.code === "invalid_request",
  );
  await assert.rejects(
    bootstrapInitialOwner(store, {
      deviceDisplayName: "Owner device",
      devicePublicKey: new Uint8Array([1, 2, 3]),
      expectedGatewayAudience: "https://gateway.example",
      deviceSignature: undefined,
    }, { gatewayAudience: "https://gateway.example" }),
    (error: unknown) => error instanceof OwnerBootstrapError && error.code === "proof_invalid",
  );
  await assert.rejects(
    bootstrapInitialOwner(store, {
      deviceDisplayName: "Owner device",
      devicePublicKey: new Uint8Array([1, 2, 3]),
      expectedGatewayAudience: "http://gateway.example",
      deviceSignature: undefined,
    }, { gatewayAudience: "https://gateway.example" }),
    (error: unknown) => error instanceof OwnerBootstrapError && error.code === "invalid_request",
  );
  assert.equal(store.facts, undefined);
});
