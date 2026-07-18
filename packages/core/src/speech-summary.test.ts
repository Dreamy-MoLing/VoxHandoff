import assert from "node:assert/strict";
import test from "node:test";

import { redact } from "./redaction.js";
import { terminalAgentEventTypes } from "./model.js";
import {
  createDeterministicSpeechSummary,
  createSpeechSummaryForOutcome,
} from "./speech-summary.js";

test("speech summary strips code and limits length", () => {
  const result = createDeterministicSpeechSummary(
    "已完成。```ts\nconst token = 'secret';\n```测试全部通过，详情请查看文字结果。",
    { maxCharacters: 24 },
  );
  assert.doesNotMatch(result, /const|token/);
  assert.ok(result.length <= 24);
});

test("speech output is enabled only for a completed request", () => {
  assert.equal(
    createSpeechSummaryForOutcome("request.completed", "Everything completed safely."),
    "Everything completed safely.",
  );
  for (const outcome of terminalAgentEventTypes) {
    if (outcome === "request.completed") continue;
    assert.equal(createSpeechSummaryForOutcome(outcome, "Must not be spoken"), undefined);
  }
  assert.equal(createSpeechSummaryForOutcome(undefined, "Must not be spoken"), undefined);
});

test("redaction removes nested credentials", () => {
  const value = redact({
    authorization: "Bearer abcdefghijklmnop",
    nested: { apiKey: "sk-example-secret", safe: "visible" },
  });
  assert.deepEqual(value, {
    authorization: "[REDACTED]",
    nested: { apiKey: "[REDACTED]", safe: "visible" },
  });
});
