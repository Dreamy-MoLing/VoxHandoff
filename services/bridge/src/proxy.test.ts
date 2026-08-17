import test from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { once } from "node:events";

import type { BridgeConfig } from "./config.js";
import { hashSecret } from "./crypto.js";
import { DeviceCredentialService } from "./credentials.js";
import { CompanionBridgeApplication, closeBridgeServer } from "./server.js";
import { ReverseProxy } from "./proxy.js";
import { createMemoryBridgeStateStore } from "./state.js";

const deviceCredential = Buffer.alloc(32, 9).toString("base64url");

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
  hermes: {
    baseUrl: "https://hermes.internal",
    token: "hermes-upstream-secret",
    healthPath: "/health",
  },
  stt: {
    baseUrl: "https://stt.internal",
    token: "stt-upstream-secret",
    healthPath: "/v1/health",
  },
  tts: {
    baseUrl: "https://tts.internal",
    token: "tts-upstream-secret",
    healthPath: "/v1/health",
  },
  maxRequestBytes: 1024 * 1024,
  upstreamTimeoutMs: 1000,
  pairingTtlMs: 180_000,
  confirmationTtlMs: 300_000,
  credentialTtlMs: 3_600_000,
};

function credentials() {
  return new DeviceCredentialService(createMemoryBridgeStateStore({
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
      accessTokenHash: hashSecret(deviceCredential),
      status: "active",
      scopes: ["chat", "stt", "tts"],
      createdAt: "2026-08-17T00:00:00.000Z",
      expiresAt: "2099-01-01T00:00:00.000Z",
    }],
  }));
}

async function withApp(application: CompanionBridgeApplication, action: (port: number) => Promise<void>): Promise<void> {
  const server = createServer((request, response) => void application.handle(request, response));
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  assert.notEqual(address, null);
  if (address === null || typeof address === "string") throw new Error("test server address unavailable");
  try {
    await action(address.port);
  } finally {
    await closeBridgeServer(server);
  }
}

test("proxy authenticates at the bridge, injects only the host upstream credential, and streams replies", async () => {
  const body = JSON.stringify({ model: "test", messages: [{ role: "user", content: "hello" }], stream: true });
  const calls: string[] = [];
  const fetcher: typeof globalThis.fetch = async (input, init) => {
    calls.push(String(input));
    const headers = new Headers(init?.headers);
    assert.equal(headers.get("authorization"), "Bearer hermes-upstream-secret");
    assert.equal(headers.get("x-hermes-session-id"), "session-1");
    assert.equal(headers.get("x-device-credential"), null);
    assert.equal(Buffer.from(init?.body as unknown as Uint8Array).toString("utf8"), body);
    return new Response("data: {\"delta\":\"ok\"}\n\n", {
      status: 200,
      headers: { "content-type": "text/event-stream" },
    });
  };
  const app = new CompanionBridgeApplication(config, {
    credentials: credentials(),
    proxy: new ReverseProxy(config, { fetch: fetcher }),
  });
  await withApp(app, async (port) => {
    const response = await fetch(`http://127.0.0.1:${port}/v1/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${deviceCredential}`,
        "Content-Type": "application/json",
        "X-Hermes-Session-Id": "session-1",
        "X-Hermes-Session-Key": "memory-1",
      },
      body,
    });
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("content-type"), "text/event-stream");
    assert.equal(await response.text(), "data: {\"delta\":\"ok\"}\n\n");
  });
  assert.deepEqual(calls, ["https://hermes.internal/v1/chat/completions"]);
});

test("proxy applies bounded request bodies and reports absent providers without leaking upstream data", async () => {
  let calls = 0;
  const fetcher: typeof globalThis.fetch = async () => {
    calls += 1;
    return new Response(JSON.stringify({ ok: true }));
  };
  const { stt: _stt, ...withoutStt } = config;
  const app = new CompanionBridgeApplication(withoutStt, {
    credentials: credentials(),
    proxy: new ReverseProxy(withoutStt, { fetch: fetcher }),
  });
  await withApp(app, async (port) => {
    const missing = await fetch(`http://127.0.0.1:${port}/v1/stt/transcribe`, {
      method: "POST",
      headers: { Authorization: `Bearer ${deviceCredential}`, "Content-Type": "application/json" },
      body: "{}",
    });
    assert.equal(missing.status, 503);
    assert.equal((await missing.json()).error.code, "upstream_not_configured");
  });
  assert.equal(calls, 0);

  const boundedConfig = { ...config, maxRequestBytes: 8 };
  const bounded = new CompanionBridgeApplication(boundedConfig, {
    credentials: credentials(),
    proxy: new ReverseProxy(boundedConfig, { fetch: fetcher }),
  });
  await withApp(bounded, async (port) => {
    const response = await fetch(`http://127.0.0.1:${port}/v1/chat/completions`, {
      method: "POST",
      headers: { Authorization: `Bearer ${deviceCredential}`, "Content-Type": "application/json" },
      body: "123456789",
    });
    assert.equal(response.status, 413);
    assert.equal((await response.json()).error.code, "request_too_large");
  });
  assert.equal(calls, 0);
});

test("proxy never accepts a device credential as an upstream API credential", async () => {
  let authorization: string | null = null;
  const fetcher: typeof globalThis.fetch = async (_input, init) => {
    authorization = new Headers(init?.headers).get("authorization");
    return new Response(JSON.stringify({ ok: true }), { headers: { "content-type": "application/json" } });
  };
  const app = new CompanionBridgeApplication(config, {
    credentials: credentials(),
    proxy: new ReverseProxy(config, { fetch: fetcher }),
  });
  await withApp(app, async (port) => {
    const response = await fetch(`http://127.0.0.1:${port}/v1/tts/synthesize`, {
      method: "POST",
      headers: { Authorization: `Bearer ${deviceCredential}`, "Content-Type": "application/json" },
      body: JSON.stringify({ text: "hello" }),
    });
    assert.equal(response.status, 200);
  });
  assert.equal(authorization, "Bearer tts-upstream-secret");
});
