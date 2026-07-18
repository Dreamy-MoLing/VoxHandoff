import assert from "node:assert/strict";
import test from "node:test";

import { HermesApiClient } from "./hermes-api.js";

test("Hermes client rejects plaintext non-local endpoints by default", () => {
  assert.throws(
    () =>
      new HermesApiClient({
        baseUrl: "http://agent.example.test",
        token: "test",
      }),
    /require HTTPS/,
  );
});

test("Hermes client probes capabilities and preserves idempotency keys", async () => {
  const requests: Request[] = [];
  const fakeFetch: typeof fetch = async (input, init) => {
    const request = new Request(input, init);
    requests.push(request);
    if (request.url.endsWith("/health")) {
      return Response.json({ status: "ok" });
    }
    if (request.url.endsWith("/v1/capabilities")) {
      return Response.json({
        version: "test",
        features: { run_stop: true, idempotency: true, event_replay: false },
      });
    }
    if (request.url.endsWith("/v1/runs") && request.method === "POST") {
      return Response.json({ run_id: "run-1" }, { status: 202 });
    }
    throw new Error(`Unexpected request: ${request.method} ${request.url}`);
  };
  const client = new HermesApiClient({
    baseUrl: "https://hermes.example.test",
    token: "not-a-real-token",
    fetch: fakeFetch,
  });

  assert.deepEqual(await client.health(), { status: "ok" });
  const capabilities = await client.capabilities();
  assert.equal(capabilities.cancel, true);
  assert.equal(capabilities.eventReplay, false);
  const run = await client.startRun("hello", { requestId: "request-1" });
  assert.equal(run.runId, "run-1");

  const startRequest = requests.at(-1);
  assert.equal(startRequest?.headers.get("Authorization"), "Bearer not-a-real-token");
  assert.equal(startRequest?.headers.get("Idempotency-Key"), "request-1");
});

test("Hermes SSE events normalize into the shared event contract", async () => {
  const encoder = new TextEncoder();
  const fakeFetch: typeof fetch = async () =>
    new Response(
      new ReadableStream<Uint8Array>({
        start(controller) {
          controller.enqueue(
            encoder.encode(
              'event: assistant.delta\ndata: {"delta":"完成"}\n\n' +
                'event: run.completed\ndata: {"type":"run.completed","seq":8}\n\n',
            ),
          );
          controller.close();
        },
      }),
      { headers: { "Content-Type": "text/event-stream" } },
    );
  const client = new HermesApiClient({
    baseUrl: "https://hermes.example.test",
    token: "test",
    fetch: fakeFetch,
  });
  const events = [];
  for await (const event of client.streamRunEvents({
    runId: "run-1",
    requestId: "request-1",
    sessionId: "session-1",
  })) {
    events.push(event);
  }
  assert.equal(events[0]?.type, "message.delta");
  assert.deepEqual(events[0]?.payload, {
    delta: "完成",
    native: { delta: "完成" },
  });
  assert.equal(events[1]?.type, "request.completed");
  assert.equal(events[1]?.sequence, 8);
  assert.equal(events[1]?.final, true);
});
