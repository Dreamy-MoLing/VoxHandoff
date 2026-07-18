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

test("SSE parser rejects an event that exceeds its configured byte limit", async () => {
  const encoder = new TextEncoder();
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(encoder.encode("data: 123456789\n\n"));
      controller.close();
    },
  });

  await assert.rejects(
    async () => {
      for await (const _message of parseSseStream(stream, { maxEventBytes: 8 })) {
        // No message should be yielded.
      }
    },
    /exceeds 8 bytes/,
  );
});

test("SSE parser rejects invalid limits before reading", async () => {
  const stream = new ReadableStream<Uint8Array>();
  await assert.rejects(
    async () => {
      for await (const _message of parseSseStream(stream, { maxEventBytes: 0 })) {
        // No message should be yielded.
      }
    },
    /positive safe integer/,
  );
});
