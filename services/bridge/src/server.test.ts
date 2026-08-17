import test from "node:test";
import assert from "node:assert/strict";
import { generateKeyPairSync } from "node:crypto";
import { createServer, type IncomingMessage } from "node:http";
import { once } from "node:events";

import type { BridgeConfig } from "./config.js";
import { PairingService } from "./pairing.js";
import { CompanionBridgeApplication, closeBridgeServer } from "./server.js";
import { createMemoryBridgeStateStore } from "./state.js";

const config: BridgeConfig = {
  version: "0.1.0",
  listenHost: "127.0.0.1",
  listenPort: 0,
  tlsKeyFile: "/tmp/not-used.key",
  tlsCertFile: "/tmp/not-used.crt",
  endpoint: "https://127.0.0.1:9443",
  serverId: "server-1",
  stateFile: "/tmp/bridge-state.json",
  profileId: "profile-1",
  profileName: "Hermes",
  model: "test-model",
  maxRequestBytes: 1024,
  upstreamTimeoutMs: 1000,
  pairingTtlMs: 180_000,
  confirmationTtlMs: 300_000,
  credentialTtlMs: 3_600_000,
  currentSpkiPin: "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
};

function publicKey(): string {
  return Buffer.from(generateKeyPairSync("ed25519").publicKey.export({ format: "der", type: "spki" })).toString("base64");
}

test("health and readiness endpoints expose bounded non-secret status", async () => {
  const application = new CompanionBridgeApplication(config);
  const server = createServer((request, response) => {
    void application.handle(request as IncomingMessage, response);
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  assert.notEqual(address, null);
  if (address === null || typeof address === "string") throw new Error("test server address unavailable");

  const health = await fetch(`http://127.0.0.1:${address.port}/healthz`);
  assert.equal(health.status, 200);
  assert.deepEqual(await health.json(), { status: "ok", component: "companion-bridge", version: "0.1.0" });

  const readiness = await fetch(`http://127.0.0.1:${address.port}/readyz`);
  assert.equal(readiness.status, 200);
  assert.deepEqual(await readiness.json(), {
    status: "ready",
    component: "companion-bridge",
    version: "0.1.0",
    checks: { tls: "ok" },
  });
  await closeBridgeServer(server);
});

test("readiness can fail without leaking configuration details", async () => {
  const application = new CompanionBridgeApplication(config, {
    readinessChecks: [{ name: "hermes", ready: () => false }],
  });
  const server = createServer((request, response) => {
    void application.handle(request as IncomingMessage, response);
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  assert.notEqual(address, null);
  if (address === null || typeof address === "string") throw new Error("test server address unavailable");
  const response = await fetch(`http://127.0.0.1:${address.port}/readyz`);
  assert.equal(response.status, 503);
  const body = await response.json();
  assert.deepEqual(body, {
    status: "not_ready",
    component: "companion-bridge",
    version: "0.1.0",
    checks: { hermes: "not_ready" },
  });
  assert.equal(JSON.stringify(body).includes("/tmp/not-used"), false);
  await closeBridgeServer(server);
});

test("phone status and cancel routes accept pairing-token authorization", async () => {
  const store = createMemoryBridgeStateStore();
  const pairing = new PairingService(config, store);
  const application = new CompanionBridgeApplication(config, { pairing });
  const server = createServer((request, response) => {
    void application.handle(request as IncomingMessage, response);
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  assert.notEqual(address, null);
  if (address === null || typeof address === "string") throw new Error("test server address unavailable");
  const base = `http://127.0.0.1:${address.port}`;

  try {
    const qrResponse = await fetch(`${base}/v1/pairing/sessions`, { method: "POST" });
    assert.equal(qrResponse.status, 201);
    const qr = await qrResponse.json() as Record<string, unknown>;
    const exchangeResponse = await fetch(`${base}/v1/pairing/exchange`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        server_id: qr.server_id,
        pairing_session_id: qr.pairing_session_id,
        pairing_token: qr.pairing_token,
        device_name: "Phone",
        device_public_key_spki: publicKey(),
      }),
    });
    assert.equal(exchangeResponse.status, 200);
    const exchange = await exchangeResponse.json() as Record<string, unknown>;
    assert.deepEqual(Object.keys(exchange).sort(), [
      "challenge",
      "deviceFingerprint",
      "deviceId",
      "deviceName",
      "expiresAt",
      "pairingRequestId",
      "status",
    ]);

    const pairingHeader = { "X-Bridge-Pairing-Authorization": `Bearer ${qr.pairing_token as string}` };
    const pendingStatus = await fetch(`${base}/v1/pairing/requests/${encodeURIComponent(exchange.pairingRequestId as string)}/status`, {
      headers: pairingHeader,
    });
    assert.equal(pendingStatus.status, 200);
    assert.deepEqual(await pendingStatus.json(), {
      pairingRequestId: exchange.pairingRequestId,
      status: "awaiting_confirmation",
      expiresAt: exchange.expiresAt,
    });

    const pendingResponse = await fetch(`${base}/v1/pairing/requests`);
    const pendingBody = await pendingResponse.json() as { requests: Array<Record<string, unknown>> };
    const confirmationCode = pendingBody.requests[0]?.confirmationCode;
    const confirmResponse = await fetch(`${base}/v1/pairing/requests/${encodeURIComponent(exchange.pairingRequestId as string)}/confirm`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ device_name: "Phone", confirmation_code: confirmationCode }),
    });
    assert.equal(confirmResponse.status, 200);

    const confirmedStatus = await fetch(`${base}/v1/pairing/requests/${encodeURIComponent(exchange.pairingRequestId as string)}/status`, {
      headers: pairingHeader,
    });
    assert.equal(confirmedStatus.status, 200);
    assert.equal((await confirmedStatus.json() as Record<string, unknown>).status, "confirmed");

    const secondQrResponse = await fetch(`${base}/v1/pairing/sessions`, { method: "POST" });
    const secondQr = await secondQrResponse.json() as Record<string, unknown>;
    const secondExchangeResponse = await fetch(`${base}/v1/pairing/exchange`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        server_id: secondQr.server_id,
        pairing_session_id: secondQr.pairing_session_id,
        pairing_token: secondQr.pairing_token,
        device_name: "Phone 2",
        device_public_key_spki: publicKey(),
      }),
    });
    const secondExchange = await secondExchangeResponse.json() as Record<string, unknown>;
    const cancelResponse = await fetch(`${base}/v1/pairing/sessions/${encodeURIComponent(secondQr.pairing_session_id as string)}/cancel`, {
      method: "POST",
      headers: { "X-Bridge-Pairing-Authorization": `Bearer ${secondQr.pairing_token as string}` },
    });
    assert.equal(cancelResponse.status, 200);
    assert.deepEqual(await cancelResponse.json(), { cancelled: true });
    const cancelledStatus = await fetch(`${base}/v1/pairing/requests/${encodeURIComponent(secondExchange.pairingRequestId as string)}/status`, {
      headers: { "X-Bridge-Pairing-Authorization": `Bearer ${secondQr.pairing_token as string}` },
    });
    assert.equal((await cancelledStatus.json() as Record<string, unknown>).status, "cancelled");
  } finally {
    await closeBridgeServer(server);
  }
});
