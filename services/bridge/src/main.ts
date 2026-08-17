#!/usr/bin/env node

import { readBridgeConfig } from "./config.js";
import { DeviceCredentialService } from "./credentials.js";
import { PairingService } from "./pairing.js";
import { CapabilityDiscovery } from "./manifest.js";
import { ReverseProxy } from "./proxy.js";
import { PinManager } from "./pinning.js";
import { createBridgeServer, CompanionBridgeApplication, listenBridgeServer } from "./server.js";
import { loadBridgeStateStore } from "./state.js";

async function main(): Promise<void> {
  const config = readBridgeConfig();
  const stateStore = await loadBridgeStateStore(config.stateFile);
  const pinning = await PinManager.load(config, stateStore, (pins) => {
    config.currentSpkiPin = pins.currentSpkiPin;
    config.backupSpkiPin = pins.backupSpkiPin;
  });
  const pairing = new PairingService(config, stateStore);
  const credentials = new DeviceCredentialService(stateStore);
  const application = new CompanionBridgeApplication(config, {
    pairing,
    credentials,
    manifest: new CapabilityDiscovery(config),
    proxy: new ReverseProxy(config),
    pinning,
    readinessChecks: [
      { name: "tls", ready: () => true },
      { name: "state", ready: () => true },
      { name: "certificate_pins", ready: () => config.currentSpkiPin !== undefined && config.backupSpkiPin !== undefined },
    ],
  });
  const server = createBridgeServer(config, application);
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
