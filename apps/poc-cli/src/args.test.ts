import assert from "node:assert/strict";
import test from "node:test";

import { optionalPositiveInteger, parseArgs } from "./args.js";

test("parses command values and flags", () => {
  const parsed = parseArgs(["codex", "--prompt", "hello", "--verbose"]);
  assert.equal(parsed.command, "codex");
  assert.equal(parsed.values.get("prompt"), "hello");
  assert.equal(parsed.flags.has("verbose"), true);
});

test("parses an optional positive integer", () => {
  const parsed = parseArgs(["codex", "--interrupt-after-ms", "750"]);
  assert.equal(optionalPositiveInteger(parsed, "interrupt-after-ms"), 750);
  assert.equal(optionalPositiveInteger(parsed, "missing"), undefined);
});

test("rejects unsafe optional integer values", () => {
  for (const value of ["0", "-1", "1.5", "soon", "9007199254740992"]) {
    const parsed = parseArgs(["codex", "--interrupt-after-ms", value]);
    assert.throws(
      () => optionalPositiveInteger(parsed, "interrupt-after-ms"),
      /positive integer|supported integer range/,
    );
  }
});
