#!/usr/bin/env node

import { HermesApiClient } from "@agent-talk/adapters";
import { GatewayControlService } from "@agent-talk/protocol";
import { createClient } from "@connectrpc/connect";
import { createGrpcTransport } from "@connectrpc/connect-node";

import { readHermesNodeConfig } from "./config.js";
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

  const transport = createGrpcTransport({
    baseUrl: config.gatewayUrl,
    defaultTimeoutMs: 30_000,
    pingIntervalMs: 20_000,
    pingIdleConnection: true,
    pingTimeoutMs: 10_000,
  });
  const client = createClient(GatewayControlService, transport);
  const abortController = new AbortController();
  const stop = () => abortController.abort();
  process.once("SIGINT", stop);
  process.once("SIGTERM", stop);
  try {
    process.stderr.write("VoxHandoff Hermes Node connected configuration validated.\n");
    await connector.run(client, config.gatewayToken, abortController.signal);
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
