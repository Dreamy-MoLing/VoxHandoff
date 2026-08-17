import test from "node:test";
import assert from "node:assert/strict";

import { readBridgeConfig } from "./config.js";

function environment(overrides: NodeJS.ProcessEnv = {}): NodeJS.ProcessEnv {
  return {
    VOXHANDOFF_BRIDGE_ENDPOINT: "https://phone.example.test:9443",
    VOXHANDOFF_BRIDGE_TLS_KEY_FILE: "/tmp/bridge.key",
    VOXHANDOFF_BRIDGE_TLS_CERT_FILE: "/tmp/bridge.crt",
    VOXHANDOFF_BRIDGE_SERVER_ID: "server-1",
    VOXHANDOFF_BRIDGE_SPKI_PIN: "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
    VOXHANDOFF_BRIDGE_BACKUP_SPKI_PIN: "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",
    ...overrides,
  };
}

test("bridge config keeps HTTPS as the default trust boundary", () => {
  const config = readBridgeConfig(environment());
  assert.equal(config.listenHost, "127.0.0.1");
  assert.equal(config.listenPort, 9443);
  assert.equal(config.pairingTtlMs, 180_000);
  assert.equal(config.maxRequestBytes, 8 * 1024 * 1024);
});

test("bridge config rejects insecure non-loopback upstreams and embedded credentials", () => {
  assert.throws(
    () => readBridgeConfig(environment({ VOXHANDOFF_BRIDGE_HERMES_URL: "http://hermes.example.test", VOXHANDOFF_BRIDGE_HERMES_TOKEN: "test-token" })),
    /requires HTTPS/u,
  );
  assert.throws(
    () => readBridgeConfig(environment({ VOXHANDOFF_BRIDGE_ENDPOINT: "https://user:pass@phone.example.test" })),
    /credentials/u,
  );
});

test("pairing TTL cannot exceed the five minute security bound", () => {
  assert.throws(
    () => readBridgeConfig(environment({ VOXHANDOFF_BRIDGE_PAIRING_TTL_MS: "300001" })),
    /between 1000 and 300000/u,
  );
});
