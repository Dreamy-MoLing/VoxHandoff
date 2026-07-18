import assert from "node:assert/strict";
import test from "node:test";

import { redact } from "./redaction.js";
import { createDeterministicSpeechSummary } from "./speech-summary.js";

test("speech summary strips code and limits length", () => {
  const result = createDeterministicSpeechSummary(
    "已完成。```ts\nconst token = 'secret';\n```测试全部通过，详情请查看文字结果。",
    { maxCharacters: 24 },
  );
  assert.doesNotMatch(result, /const|token/);
  assert.ok(result.length <= 24);
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
