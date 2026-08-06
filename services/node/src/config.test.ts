import assert from "node:assert/strict";
import test from "node:test";

import { readHermesNodeConfig } from "./config.js";

const valid = {
  VOXHANDOFF_GATEWAY_URL: "https://gateway.example.test",
  VOXHANDOFF_GATEWAY_NODE_TOKEN: "synthetic-gateway-token",
  VOXHANDOFF_HERMES_URL: "https://hermes.example.test",
  VOXHANDOFF_HERMES_TOKEN: "synthetic-hermes-token",
  VOXHANDOFF_NODE_ID: "node-1",
  VOXHANDOFF_HERMES_AGENT_ID: "agent-hermes-1",
  VOXHANDOFF_HERMES_APPROVAL_TIMEOUT_SECONDS: "60",
  VOXHANDOFF_NODE_STATE_FILE: "/tmp/voxhandoff-test-sessions.json",
} satisfies NodeJS.ProcessEnv;

test("loads Hermes and Gateway secrets only from explicit environment fields", () => {
  const config = readHermesNodeConfig(valid);
  assert.equal(config.gatewayToken, "synthetic-gateway-token");
  assert.equal(config.hermesToken, "synthetic-hermes-token");
  assert.equal(config.allowInsecureLoopback, false);
  assert.equal(config.agentDisplayName, "Hermes");
  assert.equal(config.hermesApprovalTimeoutMs, 60_000);
});

test("rejects credentials embedded in URLs and plaintext remote endpoints", () => {
  assert.throws(
    () => readHermesNodeConfig({
      ...valid,
      VOXHANDOFF_HERMES_URL: "https://token@hermes.example.test",
    }),
    /must not contain credentials/u,
  );
  assert.throws(
    () => readHermesNodeConfig({
      ...valid,
      VOXHANDOFF_GATEWAY_URL: "http://gateway.example.test",
    }),
    /requires HTTPS/u,
  );
});

test("allows plaintext only for explicit isolated loopback", () => {
  const config = readHermesNodeConfig({
    ...valid,
    VOXHANDOFF_GATEWAY_URL: "http://127.0.0.1:50051",
    VOXHANDOFF_HERMES_URL: "http://[::1]:18642",
    VOXHANDOFF_ALLOW_INSECURE_LOOPBACK: "1",
  });
  assert.equal(config.allowInsecureLoopback, true);
});

test("does not treat a resolvable hostname as a literal loopback boundary", () => {
  assert.throws(
    () => readHermesNodeConfig({
      ...valid,
      VOXHANDOFF_HERMES_URL: "http://localhost:18642",
      VOXHANDOFF_ALLOW_INSECURE_LOOPBACK: "1",
    }),
    /requires HTTPS/u,
  );
});

test("requires an explicit bounded Hermes approval timeout", () => {
  assert.throws(
    () => readHermesNodeConfig({
      ...valid,
      VOXHANDOFF_HERMES_APPROVAL_TIMEOUT_SECONDS: "",
    }),
    /is required/u,
  );
  assert.throws(
    () => readHermesNodeConfig({
      ...valid,
      VOXHANDOFF_HERMES_APPROVAL_TIMEOUT_SECONDS: "3601",
    }),
    /between 1 and 3600/u,
  );
});
