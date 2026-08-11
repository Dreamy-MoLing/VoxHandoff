#!/usr/bin/env node

import { HermesApiClient } from "@agent-talk/adapters";

import { readHermesNodeConfig } from "./config.js";
import { createGatewayControlClient } from "./gateway-client.js";
import { runGatewayConnectionSupervisor } from "./gateway-connection-supervisor.js";
import { HermesNodeConnector } from "./hermes-node-connector.js";
import { JsonHermesSessionStore } from "./session-store.js";

async function main(): Promise<void> {
  const config = readHermesNodeConfig();
  const hermes = new HermesApiClient({
    baseUrl: config.hermesUrl,
    token: config.hermesToken,
    allowInsecureHttp: config.allowInsecureLoopback,
    approvalTimeoutMs: config.hermesApprovalTimeoutMs,
  });
  const connector = new HermesNodeConnector(
    hermes,
    {
      nodeId: config.nodeId,
      agentId: config.agentId,
      nodeDisplayName: config.nodeDisplayName,
      agentDisplayName: config.agentDisplayName,
    },
    new JsonHermesSessionStore(config.stateFile),
  );
  await connector.initialize();

  const abortController = new AbortController();
  const stop = () => abortController.abort();
  process.once("SIGINT", stop);
  process.once("SIGTERM", stop);
  try {
    process.stderr.write("VoxHandoff Hermes Node connected configuration validated.\n");
    await runGatewayConnectionSupervisor(
      () => connector.run(
        createGatewayControlClient(config.gatewayUrl),
        config.gatewayToken,
        abortController.signal,
      ),
      abortController.signal,
      {
        onReconnect: (attempt) => {
          process.stderr.write(`VoxHandoff Gateway Node stream reconnecting (attempt ${attempt}).\n`);
        },
      },
    );
  } finally {
    process.off("SIGINT", stop);
    process.off("SIGTERM", stop);
  }
}

main().catch((error: unknown) => {
  const safeMessage =
    error instanceof Error &&
    /^(Gateway|Hermes|VOXHANDOFF|Node|Hermes Node|VoxHandoff)/u.test(error.message)
      ? error.message
      : "VoxHandoff Hermes Node stopped at a protected integration boundary.";
  process.stderr.write(`${safeMessage}\n`);
  process.exitCode = 1;
});
