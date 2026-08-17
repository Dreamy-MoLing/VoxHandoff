import test from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { once } from "node:events";

import type { BridgeConfig } from "./config.js";
import { hashSecret } from "./crypto.js";
import { DeviceCredentialService } from "./credentials.js";
import { CapabilityDiscovery } from "./manifest.js";
import { CompanionBridgeApplication, closeBridgeServer } from "./server.js";
import { createMemoryBridgeStateStore } from "./state.js";

const token = Buffer.alloc(32, 7).toString("base64url");

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
  profileName: "Hermes Profile",
  model: "hermes-model",
  hermes: {
    baseUrl: "https://hermes.internal",
    token: "hermes-test-token",
    healthPath: "/health",
    capabilitiesPath: "/v1/capabilities",
  },
  stt: {
    baseUrl: "https://stt.internal",
    token: "stt-test-token",
    healthPath: "/v1/health",
  },
  tts: {
    baseUrl: "https://tts.internal",
    token: "tts-test-token",
    healthPath: "/v1/health",
  },
  maxRequestBytes: 1024 * 1024,
  upstreamTimeoutMs: 1000,
  pairingTtlMs: 180_000,
  confirmationTtlMs: 300_000,
  credentialTtlMs: 3_600_000,
};

function fakeFetch(): typeof globalThis.fetch {
  return async (input, init) => {
    const url = String(input);
    const headers = new Headers(init?.headers);
    assert.match(headers.get("authorization") ?? "", /^Bearer .+$/u);
    if (url === "https://hermes.internal/health") return response({ status: "ok" });
    if (url === "https://hermes.internal/v1/capabilities") return response({ streaming: true, tool_progress: false, endpoint: "must-not-leak" });
    if (url === "https://stt.internal/v1/health") return response({ status: "ready", model: "base", authorization: "must-not-leak" });
    if (url === "https://tts.internal/v1/health") return response({ status: "ready", voices: ["Bronya", "Luna"], recommended_voice: "Bronya" });
    return response({ error: "not found" }, 404);
  };
}

function response(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "content-type": "application/json", "content-length": String(Buffer.byteLength(JSON.stringify(value))) },
  });
}

test("manifest discovers the four product sections and redacts transport secrets", async () => {
  const discovery = new CapabilityDiscovery(config, { fetch: fakeFetch() });
  assert.deepEqual(await discovery.manifest(), {
    chat: { available: true },
    stt: { available: true, capabilities: { status: "ready", model: "base" } },
    tts: { available: true, voices: ["Bronya", "Luna"], recommended_voice: "Bronya" },
    hermes: {
      profile: "Hermes Profile",
      model: "hermes-model",
      capabilities: { streaming: true, tool_progress: false },
    },
  });
});

test("missing upstreams fail closed to unavailable capabilities", async () => {
  const { hermes: _hermes, stt: _stt, tts: _tts, ...withoutProviders } = config;
  const discovery = new CapabilityDiscovery(withoutProviders, { fetch: fakeFetch() });
  assert.deepEqual(await discovery.manifest(), {
    chat: { available: false },
    stt: { available: false, capabilities: {} },
    tts: { available: false, voices: [] },
    hermes: { profile: "Hermes Profile", model: "hermes-model", capabilities: {} },
  });
});

test("capability discovery is behind device credential authentication", async () => {
  const state = createMemoryBridgeStateStore({
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
      accessTokenHash: hashSecret(token),
      status: "active",
      scopes: ["chat", "stt", "tts"],
      createdAt: "2026-08-17T00:00:00.000Z",
      expiresAt: "2099-01-01T00:00:00.000Z",
    }],
  });
  const app = new CompanionBridgeApplication(config, {
    credentials: new DeviceCredentialService(state),
    manifest: new CapabilityDiscovery(config, { fetch: fakeFetch() }),
  });
  const server = createServer((request, response) => void app.handle(request, response));
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  assert.notEqual(address, null);
  if (address === null || typeof address === "string") throw new Error("test server address unavailable");
  const unauthorized = await fetch(`http://127.0.0.1:${address.port}/v1/capabilities`);
  assert.equal(unauthorized.status, 401);
  const authorized = await fetch(`http://127.0.0.1:${address.port}/v1/capabilities`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(authorized.status, 200);
  assert.equal((await authorized.json()).chat.available, true);
  await closeBridgeServer(server);
});
