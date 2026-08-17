import test from "node:test";
import assert from "node:assert/strict";
import { createServer, type IncomingMessage } from "node:http";
import { once } from "node:events";

import type { BridgeConfig } from "./config.js";
import { CompanionBridgeApplication, closeBridgeServer } from "./server.js";

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
};

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
