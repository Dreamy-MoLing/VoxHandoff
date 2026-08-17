import test from "node:test";
import assert from "node:assert/strict";
import { generateKeyPairSync } from "node:crypto";

import type { BridgeConfig } from "./config.js";
import { PairingError, PairingService } from "./pairing.js";
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

function publicKey(): string {
  return Buffer.from(generateKeyPairSync("ed25519").publicKey.export({ format: "der", type: "spki" })).toString("base64");
}

test("pairing QR uses a 256-bit token while persisted state contains only its hash", async () => {
  const store = createMemoryBridgeStateStore();
  const service = new PairingService(config, store);
  const qr = await service.createQr();
  assert.match(qr.pairing_token, /^[A-Za-z0-9_-]{43}$/u);
  assert.equal(qr.expires_at, new Date(Date.parse(qr.expires_at)).toISOString());
  const state = await store.snapshot();
  assert.equal(state.pairings.length, 1);
  assert.notEqual(state.pairings[0]?.tokenHash, qr.pairing_token);
  assert.equal(state.pairings[0]?.tokenHash, (await import("./crypto.js")).hashSecret(qr.pairing_token));
});

test("token consumption is atomic and replay is rejected", async () => {
  const store = createMemoryBridgeStateStore();
  const service = new PairingService(config, store);
  const qr = await service.createQr();
  const input = {
    serverId: qr.server_id,
    pairingSessionId: qr.pairing_session_id,
    pairingToken: qr.pairing_token,
    deviceName: "vivo V2359A",
    devicePublicKeySpki: publicKey(),
  };
  const first = await service.exchange(input);
  assert.equal(first.status, "awaiting_confirmation");
  await assert.rejects(
    () => service.exchange({ ...input, devicePublicKeySpki: publicKey() }),
    (error: unknown) => error instanceof PairingError && error.code === "pairing_consumed" && error.status === 409,
  );
  const state = await store.snapshot();
  assert.equal(state.pairings[0]?.status, "consumed");
  assert.equal(state.pairingRequests.length, 1);
});

test("expiry, cancellation, and QR regeneration invalidate old tokens", async () => {
  let now = new Date("2026-08-17T00:00:00.000Z");
  const store = createMemoryBridgeStateStore();
  const service = new PairingService(config, store, () => now);
  const first = await service.createQr();
  now = new Date(now.getTime() + config.pairingTtlMs + 1);
  await assert.rejects(() => service.exchange({
    serverId: first.server_id,
    pairingSessionId: first.pairing_session_id,
    pairingToken: first.pairing_token,
    deviceName: "expired",
    devicePublicKeySpki: publicKey(),
  }), (error: unknown) => error instanceof PairingError && error.code === "pairing_expired");

  now = new Date("2026-08-17T01:00:00.000Z");
  const second = await service.createQr();
  await service.cancelSession(second.pairing_session_id);
  await assert.rejects(() => service.exchange({
    serverId: second.server_id,
    pairingSessionId: second.pairing_session_id,
    pairingToken: second.pairing_token,
    deviceName: "cancelled",
    devicePublicKeySpki: publicKey(),
  }), (error: unknown) => error instanceof PairingError && error.code === "pairing_cancelled");

  const third = await service.createQr();
  const fourth = await service.createQr();
  await assert.rejects(() => service.exchange({
    serverId: third.server_id,
    pairingSessionId: third.pairing_session_id,
    pairingToken: third.pairing_token,
    deviceName: "regenerated",
    devicePublicKeySpki: publicKey(),
  }), (error: unknown) => error instanceof PairingError && error.code === "pairing_cancelled");
  assert.notEqual(third.pairing_session_id, fourth.pairing_session_id);
});

test("host confirmation requires the displayed device name and six-digit code", async () => {
  const store = createMemoryBridgeStateStore();
  const service = new PairingService(config, store);
  const qr = await service.createQr();
  const exchange = await service.exchange({
    serverId: qr.server_id,
    pairingSessionId: qr.pairing_session_id,
    pairingToken: qr.pairing_token,
    deviceName: "Phone",
    devicePublicKeySpki: publicKey(),
  });
  const pending = await service.pendingRequests();
  assert.equal(pending[0]?.pairingRequestId, exchange.pairingRequestId);
  await assert.rejects(() => service.confirm(exchange.pairingRequestId, "Other phone", pending[0]?.confirmationCode ?? "000000"), /confirmation is invalid/u);
  const confirmed = await service.confirm(exchange.pairingRequestId, "Phone", pending[0]?.confirmationCode ?? "000000");
  assert.equal(confirmed.status, "confirmed");
});

test("phone status and cancellation are authenticated by the consumed pairing token", async () => {
  const store = createMemoryBridgeStateStore();
  const service = new PairingService(config, store);
  const qr = await service.createQr();
  const exchange = await service.exchange({
    serverId: qr.server_id,
    pairingSessionId: qr.pairing_session_id,
    pairingToken: qr.pairing_token,
    deviceName: "Phone",
    devicePublicKeySpki: publicKey(),
  });

  assert.deepEqual(await service.requestStatus(exchange.pairingRequestId, qr.pairing_token), {
    pairingRequestId: exchange.pairingRequestId,
    status: "awaiting_confirmation",
    expiresAt: exchange.expiresAt,
  });
  await assert.rejects(
    () => service.requestStatus(exchange.pairingRequestId, "invalid-token"),
    (error: unknown) => error instanceof PairingError && error.code === "pairing_token_invalid" && error.status === 401,
  );

  await service.cancelSessionWithPairingToken(qr.pairing_session_id, qr.pairing_token);
  assert.deepEqual(await service.requestStatus(exchange.pairingRequestId, qr.pairing_token), {
    pairingRequestId: exchange.pairingRequestId,
    status: "cancelled",
    expiresAt: exchange.expiresAt,
  });
});
