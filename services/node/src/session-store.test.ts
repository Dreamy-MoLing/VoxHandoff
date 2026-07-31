import assert from "node:assert/strict";
import { mkdtemp, readFile, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import {
  JsonHermesSessionStore,
  type HermesSessionStoreFileSystem,
} from "./session-store.js";

test("persists only conversation-to-session identities with private permissions", async () => {
  const root = await mkdtemp(path.join(tmpdir(), "voxhandoff-node-store-"));
  const stateFile = path.join(root, "state", "sessions.json");
  const first = new JsonHermesSessionStore(stateFile);
  await first.set("conversation-1", "hermes-session-1");

  const second = new JsonHermesSessionStore(stateFile);
  assert.equal(await second.get("conversation-1"), "hermes-session-1");
  assert.deepEqual(JSON.parse(await readFile(stateFile, "utf8")), {
    "conversation-1": "hermes-session-1",
  });
  assert.equal((await stat(stateFile)).mode & 0o777, 0o600);
  assert.equal((await stat(path.dirname(stateFile))).mode & 0o777, 0o700);
});

test("waits for one cold load before exposing persisted sessions to concurrent callers", async () => {
  let releaseRead!: () => void;
  const readStarted = new Promise<void>((resolve) => {
    releaseRead = resolve;
  });
  let allowRead!: () => void;
  const delayedRead = new Promise<void>((resolve) => {
    allowRead = resolve;
  });
  let reads = 0;
  const fileSystem: HermesSessionStoreFileSystem = {
    async readFile() {
      reads += 1;
      releaseRead();
      await delayedRead;
      return JSON.stringify({ "conversation-1": "hermes-session-1" });
    },
    async mkdir() { return undefined; },
    async chmod() {},
    async writeFile() {},
    async rename() {},
  };
  const store = new JsonHermesSessionStore("/tmp/voxhandoff-session-store-test.json", fileSystem);

  const first = store.get("conversation-1");
  await readStarted;
  const second = store.get("conversation-1");
  allowRead();

  assert.deepEqual(await Promise.all([first, second]), ["hermes-session-1", "hermes-session-1"]);
  assert.equal(reads, 1);
});
