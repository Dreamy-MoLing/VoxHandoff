import assert from "node:assert/strict";
import test from "node:test";

import { parseArgs } from "./args.js";

test("parses command values and flags", () => {
  const parsed = parseArgs(["codex", "--prompt", "hello", "--verbose"]);
  assert.equal(parsed.command, "codex");
  assert.equal(parsed.values.get("prompt"), "hello");
  assert.equal(parsed.flags.has("verbose"), true);
});
