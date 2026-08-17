import test from "node:test";
import assert from "node:assert/strict";

import type { BridgeConfig } from "./config.js";
import { PinManager, PinningError, validateSpkiPin } from "./pinning.js";
import { createMemoryBridgeStateStore } from "./state.js";

const current = "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
const backup = "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
const next = "sha256/CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=";
const other = "sha256/DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=";

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
  maxRequestBytes: 1024,
  upstreamTimeoutMs: 1000,
  pairingTtlMs: 180_000,
  confirmationTtlMs: 300_000,
  credentialTtlMs: 3_600_000,
  currentSpkiPin: current,
  backupSpkiPin: backup,
};

test("pin validation accepts standard SHA-256 SPKI pins and rejects malformed values", () => {
  assert.equal(validateSpkiPin(current), current);
  assert.throws(() => validateSpkiPin("sha256/unknown"), (error: unknown) => error instanceof PinningError && error.code === "pin_invalid");
});

test("unknown certificate pins fail closed and rotation requires the current pin", async () => {
  const manager = new PinManager(current, backup);
  assert.equal(manager.isPinned(current), true);
  assert.equal(manager.isPinned(backup), true);
  assert.equal(manager.isPinned(next), false);
  assert.throws(() => manager.assertPinned(next), (error: unknown) => error instanceof PinningError && error.code === "pin_mismatch");
  await assert.rejects(() => manager.rotate({ presentedPin: other, nextBackupPin: next }), (error: unknown) => error instanceof PinningError && error.code === "pin_rotation_rejected");
  assert.deepEqual(manager.snapshot(), { currentSpkiPin: current, backupSpkiPin: backup, generation: 1 });
});

test("rotation promotes the pre-generated backup and persists the new backup", async () => {
  const store = createMemoryBridgeStateStore();
  const manager = await PinManager.load(config, store);
  const rotated = await manager.rotate({ presentedPin: current, nextBackupPin: next });
  assert.deepEqual(rotated, { currentSpkiPin: backup, backupSpkiPin: next, generation: 2 });
  assert.equal(manager.isPinned(current), false);
  assert.equal(manager.isPinned(backup), true);
  assert.equal(manager.isPinned(next), true);
  assert.equal((await store.snapshot()).pinState?.backupSpkiPin, next);
  await assert.rejects(() => manager.rotate({ presentedPin: current, nextBackupPin: other }), /current pinned channel/u);

  const reloaded = await PinManager.load(config, store);
  assert.deepEqual(reloaded.snapshot(), rotated);
});

test("rotation rejects duplicate active pins and never disables pinning", async () => {
  const manager = new PinManager(current, backup);
  await assert.rejects(() => manager.rotate({ presentedPin: current, nextBackupPin: backup }), /distinct/u);
  assert.equal(manager.isPinned(other), false);
  assert.throws(() => manager.assertPinned(other), /not trusted/u);
});
