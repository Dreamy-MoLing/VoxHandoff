import assert from "node:assert/strict";
import test from "node:test";

import { parseSseStream } from "./sse.js";

test("SSE parser handles chunk boundaries and multiline data", async () => {
  const encoder = new TextEncoder();
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(encoder.encode("event: message.delta\ndata: {\"delta\":"));
      controller.enqueue(encoder.encode("\"你\"}\n\ndata: line one\ndata: line two\n\n"));
      controller.close();
    },
  });

  const messages = [];
  for await (const message of parseSseStream(stream)) messages.push(message);
  assert.deepEqual(messages, [
    { event: "message.delta", data: '{"delta":"你"}' },
    { data: "line one\nline two" },
  ]);
});
