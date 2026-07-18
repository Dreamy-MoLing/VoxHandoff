import assert from "node:assert/strict";
import test from "node:test";

import { parseSseStream, SseTransportError } from "./sse.js";

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

test("SSE parser replaces reader failures with a generic transport error", async () => {
  const stream = new ReadableStream<Uint8Array>({
    pull(controller) {
      controller.error(new Error("native transport secret"));
    },
  });

  await assert.rejects(
    async () => {
      for await (const _message of parseSseStream(stream)) {
        // No message should be yielded.
      }
    },
    (error: unknown) => {
      assert.ok(error instanceof SseTransportError);
      assert.equal(error.message, "SSE transport disconnected");
      assert.doesNotMatch(error.message, /secret/);
      return true;
    },
  );
});
