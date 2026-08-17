#!/usr/bin/env node

import { readBridgeConfig } from "./config.js";
import { createBridgeServer, listenBridgeServer } from "./server.js";

async function main(): Promise<void> {
  const config = readBridgeConfig();
  const server = createBridgeServer(config);
  const stop = () => server.close();
  process.once("SIGINT", stop);
  process.once("SIGTERM", stop);
  try {
    const address = await listenBridgeServer(server, config);
    process.stderr.write(`VoxHandoff Companion Bridge listening on ${typeof address === "string" ? address : `${address.address}:${address.port}`}\n`);
  } catch (error) {
    const message = error instanceof Error ? error.message : "The bridge could not start.";
    process.stderr.write(`Companion Bridge stopped at startup: ${message}\n`);
    process.exitCode = 1;
  }
}

main().catch(() => {
  process.stderr.write("Companion Bridge stopped at a protected startup boundary.\n");
  process.exitCode = 1;
});
