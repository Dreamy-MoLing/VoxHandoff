import test from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { once } from "node:events";

import type { BridgeConfig } from "./config.js";
import { hashSecret } from "./crypto.js";
import { DeviceCredentialService } from "./credentials.js";
import { PairingService } from "./pairing.js";
import { PinManager } from "./pinning.js";
import { CompanionBridgeApplication, closeBridgeServer } from "./server.js";
import { createMemoryBridgeStateStore } from "./state.js";

const deviceToken = Buffer.alloc(32, 4).toString("base64url");
const hostToken = "h".repeat(32);
const current = "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
const backup = "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
const next = "sha256/CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=";

function config(): BridgeConfig {
  return {
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
    currentSpkiPin: current,
    backupSpkiPin: backup,
    hostAdminToken: hostToken,
  };
}

test("host controls and authenticated pin reads are separated from device auth", async () => {
  const bridgeConfig = config();
  const store = createMemoryBridgeStateStore({
    version: 1,
    pairings: [],
    pairingRequests: [],
    devices: [{
      deviceId: "device-1",
      deviceName: "Phone",
      devicePublicKeySpki: "unused",
      deviceFingerprint: "sha256:unused",
      scopes: ["chat", "stt", "tts"],
      status: "active",
      createdAt: "2026-08-17T00:00:00.000Z",
      updatedAt: "2026-08-17T00:00:00.000Z",
    }],
    credentials: [{
      credentialId: "credential-1",
      deviceId: "device-1",
      accessTokenHash: hashSecret(deviceToken),
      status: "active",
      scopes: ["chat", "stt", "tts"],
      createdAt: "2026-08-17T00:00:00.000Z",
      expiresAt: "2099-01-01T00:00:00.000Z",
    }],
  });
  const pinning = new PinManager(current, backup, store, (snapshot) => {
    bridgeConfig.currentSpkiPin = snapshot.currentSpkiPin;
    bridgeConfig.backupSpkiPin = snapshot.backupSpkiPin;
  });
  const app = new CompanionBridgeApplication(bridgeConfig, {
    pairing: new PairingService(bridgeConfig, store),
    credentials: new DeviceCredentialService(store),
    pinning,
  });
  const server = createServer((request, response) => void app.handle(request, response));
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  assert.notEqual(address, null);
  if (address === null || typeof address === "string") throw new Error("test server address unavailable");
  const base = `http://127.0.0.1:${address.port}`;
  try {
    const missingDeviceAuth = await fetch(`${base}/v1/pinning`);
    assert.equal(missingDeviceAuth.status, 401);
    const devicePins = await fetch(`${base}/v1/pinning`, { headers: { Authorization: `Bearer ${deviceToken}` } });
    assert.equal(devicePins.status, 200);
    assert.deepEqual(await devicePins.json(), { currentSpkiPin: current, backupSpkiPin: backup, generation: 1 });

    const missingHostAuth = await fetch(`${base}/v1/pairing/sessions`, { method: "POST" });
    assert.equal(missingHostAuth.status, 401);
    const qr = await fetch(`${base}/v1/pairing/sessions`, {
      method: "POST",
      headers: { "X-Bridge-Host-Authorization": `Bearer ${hostToken}` },
    });
    assert.equal(qr.status, 201);
    const qrBody = await qr.json();
    assert.equal(qrBody.spki_pin, current);
    assert.match(qrBody.pairing_token, /^[A-Za-z0-9_-]{43}$/u);

    const wrongRotation = await fetch(`${base}/v1/pinning/rotate`, {
      method: "POST",
      headers: {
        "X-Bridge-Host-Authorization": `Bearer ${hostToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ presented_pin: backup, next_backup_pin: next }),
    });
    assert.equal(wrongRotation.status, 409);
    const rotation = await fetch(`${base}/v1/pinning/rotate`, {
      method: "POST",
      headers: {
        "X-Bridge-Host-Authorization": `Bearer ${hostToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ presented_pin: current, next_backup_pin: next }),
    });
    assert.equal(rotation.status, 200);
    assert.deepEqual(await rotation.json(), { currentSpkiPin: backup, backupSpkiPin: next, generation: 2 });
  } finally {
    await closeBridgeServer(server);
  }
});
