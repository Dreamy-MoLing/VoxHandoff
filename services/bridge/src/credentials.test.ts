import test from "node:test";
import assert from "node:assert/strict";
import { generateKeyPairSync, sign, type KeyObject } from "node:crypto";

import type { BridgeConfig } from "./config.js";
import { pairingCompletionPayload } from "./crypto.js";
import { CredentialError, DeviceCredentialService } from "./credentials.js";
import { PairingService } from "./pairing.js";
import { createMemoryBridgeStateStore } from "./state.js";

const config: BridgeConfig = {
  version: "0.1.0",
  listenHost: "127.0.0.1",
  listenPort: 9443,
  tlsKeyFile: "/tmp/not-used.key",
  tlsCertFile: "/tmp/not-used.crt",
  endpoint: "https://127.0.0.1:9443",
  serverId: "server-1",
  stateFile: "/tmp/bridge-state.json",
  profileId: "profile-1",
  profileName: "Hermes",
  model: "test-model",
  maxRequestBytes: 1024 * 1024,
  upstreamTimeoutMs: 1000,
  pairingTtlMs: 180_000,
  confirmationTtlMs: 300_000,
  credentialTtlMs: 3_600_000,
  currentSpkiPin: "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
};

function keyPair(): { publicKey: KeyObject; privateKey: KeyObject } {
  return generateKeyPairSync("ed25519");
}

function spki(publicKey: KeyObject): string {
  return Buffer.from(publicKey.export({ format: "der", type: "spki" })).toString("base64");
}

test("device public key proof gates independent credential issuance", async () => {
  const store = createMemoryBridgeStateStore();
  const pairing = new PairingService(config, store);
  const keys = keyPair();
  const qr = await pairing.createQr();
  const exchange = await pairing.exchange({
    serverId: qr.server_id,
    pairingSessionId: qr.pairing_session_id,
    pairingToken: qr.pairing_token,
    deviceName: "Phone A",
    devicePublicKeySpki: spki(keys.publicKey),
  });
  const pending = await pairing.pendingRequests();
  await pairing.confirm(exchange.pairingRequestId, "Phone A", pending[0]?.confirmationCode ?? "000000");
  const wrongKeys = keyPair();
  const wrongSignature = sign(null, pairingCompletionPayload(exchange.pairingRequestId, exchange.challenge), wrongKeys.privateKey).toString("base64");
  await assert.rejects(
    () => pairing.complete(exchange.pairingRequestId, wrongSignature),
    (error: unknown) => error instanceof Error && error.message === "The device proof is invalid.",
  );
  const signature = sign(null, pairingCompletionPayload(exchange.pairingRequestId, exchange.challenge), keys.privateKey).toString("base64");
  const completed = await pairing.complete(exchange.pairingRequestId, signature);
  assert.equal(completed.deviceId, exchange.deviceId);
  assert.match(completed.deviceCredential, /^[A-Za-z0-9_-]{43}$/u);
  assert.notEqual(completed.deviceCredential, qr.pairing_token);
  const state = await store.snapshot();
  assert.equal(state.devices[0]?.status, "active");
  assert.equal(state.credentials[0]?.status, "active");
  assert.equal(JSON.stringify(state).includes(completed.deviceCredential), false);
});

test("credentials authenticate and revoke one device without affecting another", async () => {
  const store = createMemoryBridgeStateStore();
  const pairing = new PairingService(config, store);
  const credentials = new DeviceCredentialService(store);

  const keysA = keyPair();
  const qrA = await pairing.createQr();
  const exchangeA = await pairing.exchange({
    serverId: qrA.server_id,
    pairingSessionId: qrA.pairing_session_id,
    pairingToken: qrA.pairing_token,
    deviceName: "Phone A",
    devicePublicKeySpki: spki(keysA.publicKey),
  });
  const pendingA = await pairing.pendingRequests();
  await pairing.confirm(exchangeA.pairingRequestId, "Phone A", pendingA[0]?.confirmationCode ?? "000000");
  const signatureA = sign(null, pairingCompletionPayload(exchangeA.pairingRequestId, exchangeA.challenge), keysA.privateKey).toString("base64");
  const completedA = await pairing.complete(exchangeA.pairingRequestId, signatureA);
  assert.equal((await credentials.authenticateAuthorization(`Bearer ${completedA.deviceCredential}`)).deviceId, completedA.deviceId);

  const keysB = keyPair();
  const qrB = await pairing.createQr();
  const exchangeB = await pairing.exchange({
    serverId: qrB.server_id,
    pairingSessionId: qrB.pairing_session_id,
    pairingToken: qrB.pairing_token,
    deviceName: "Phone B",
    devicePublicKeySpki: spki(keysB.publicKey),
  });
  const pendingB = await pairing.pendingRequests();
  await pairing.confirm(exchangeB.pairingRequestId, "Phone B", pendingB[0]?.confirmationCode ?? "000000");
  const signatureB = sign(null, pairingCompletionPayload(exchangeB.pairingRequestId, exchangeB.challenge), keysB.privateKey).toString("base64");
  const completedB = await pairing.complete(exchangeB.pairingRequestId, signatureB);

  await credentials.revokeDevice(completedA.deviceId);
  await assert.rejects(
    () => credentials.authenticateAuthorization(`Bearer ${completedA.deviceCredential}`),
    (error: unknown) => error instanceof CredentialError && error.code === "authentication_failed",
  );
  assert.equal((await credentials.authenticateAuthorization(`Bearer ${completedB.deviceCredential}`)).deviceId, completedB.deviceId);
});
