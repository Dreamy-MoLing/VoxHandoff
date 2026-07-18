import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
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

test("Hermes HTTP failures do not expose upstream response bodies", async () => {
  const client = new HermesApiClient({
    baseUrl: "https://hermes.example.test",
    token: "test",
    fetch: async () => new Response("upstream-secret-value", { status: 500 }),
  });

  await assert.rejects(
    () => client.health(),
    (error: unknown) => {
      assert.ok(error instanceof Error);
      assert.match(error.message, /Hermes HTTP 500/);
      assert.doesNotMatch(error.message, /upstream-secret-value/);
      return true;
    },
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
  assert.equal(capabilities.interrupt, true);
  assert.equal(capabilities.replay, false);
  assert.equal(capabilities.attachments, false);
  const run = await client.startRun("hello", { requestId: "request-1" });
  assert.equal(run.runId, "run-1");

  const startRequest = requests.at(-1);
  assert.equal(startRequest?.headers.get("Authorization"), "Bearer not-a-real-token");
  assert.equal(startRequest?.headers.get("Idempotency-Key"), "request-1");
});

test("Hermes SSE events normalize into the shared event contract", async () => {
  const encoder = new TextEncoder();
  const fixture = await readFile(
    new URL("../test-fixtures/hermes-run.sse", import.meta.url),
    "utf8",
  );
  const fakeFetch: typeof fetch = async () =>
    new Response(
      new ReadableStream<Uint8Array>({
        start(controller) {
          controller.enqueue(encoder.encode(fixture));
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
  });
  assert.equal(events[1]?.type, "request.completed");
  assert.equal(events[1]?.sequence, 2);
  assert.equal(typeof events[1]?.eventId, "string");
});

test("Hermes SSE rejects malformed JSON instead of leaking native payloads", async () => {
  const encoder = new TextEncoder();
  const fakeFetch: typeof fetch = async () =>
    new Response(
      new ReadableStream<Uint8Array>({
        start(controller) {
          controller.enqueue(encoder.encode("event: assistant.delta\ndata: not-json\n\n"));
          controller.close();
        },
      }),
    );
  const client = new HermesApiClient({
    baseUrl: "https://hermes.example.test",
    token: "test",
    fetch: fakeFetch,
  });

  await assert.rejects(
    async () => {
      for await (const _event of client.streamRunEvents({
        runId: "run-1",
        requestId: "request-1",
      })) {
        // No event should be yielded.
      }
    },
    /invalid JSON/,
  );
});

test("Hermes normalizes an interrupted SSE transport as connection lost", async () => {
  const encoder = new TextEncoder();
  let pullCount = 0;
  const fakeFetch: typeof fetch = async () =>
    new Response(
      new ReadableStream<Uint8Array>({
        pull(controller) {
          pullCount += 1;
          if (pullCount === 1) {
            controller.enqueue(
              encoder.encode('event: assistant.delta\ndata: {"delta":"partial"}\n\n'),
            );
          } else {
            controller.error(new Error("native transport secret"));
          }
        },
      }),
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
  })) {
    events.push(event);
  }
  assert.deepEqual(
    events.map((event) => [event.sequence, event.type, event.payload]),
    [
      [1, "message.delta", { delta: "partial" }],
      [2, "connection.lost", { reason: "transport_disconnected" }],
    ],
  );
  assert.doesNotMatch(JSON.stringify(events), /native transport secret/);
});

test("Hermes approval, stop, and client recreation preserve explicit command identity", async () => {
  const encoder = new TextEncoder();
  const fixture = await readFile(
    new URL("../test-fixtures/hermes-approval.sse", import.meta.url),
    "utf8",
  );
  const requests: Request[] = [];
  const fakeFetch: typeof fetch = async (input, init) => {
    const request = new Request(input, init);
    requests.push(request);
    if (request.url.endsWith("/events")) {
      return new Response(
        new ReadableStream<Uint8Array>({
          start(controller) {
            controller.enqueue(encoder.encode(fixture));
            controller.close();
          },
        }),
      );
    }
    return new Response(null, { status: 204 });
  };
  const run = { runId: "run-1", requestId: "request-1", sessionId: "session-1" };
  const firstClient = new HermesApiClient({
    baseUrl: "https://hermes.example.test",
    token: "test",
    fetch: fakeFetch,
  });

  const firstEvents = [];
  for await (const event of firstClient.streamRunEvents(run)) firstEvents.push(event);
  assert.equal(firstEvents[0]?.type, "approval.required");
  assert.deepEqual(firstEvents[0]?.payload, { approvalId: "approval-1" });
  assert.equal(firstEvents[1]?.type, "approval.resolved");
  assert.deepEqual(firstEvents[1]?.payload, {
    approvalId: "approval-1",
    outcome: "approved",
  });
  assert.doesNotMatch(JSON.stringify(firstEvents), /token/);

  await firstClient.resolveApproval("run-1", "approval-1", false, "approval-command-1");
  await firstClient.stopRun("run-1", "stop-command-1");

  const approvalRequest = requests.find((request) => request.url.endsWith("/approval"));
  const stopRequest = requests.find((request) => request.url.endsWith("/stop"));
  assert.equal(approvalRequest?.headers.get("Idempotency-Key"), "approval-command-1");
  assert.deepEqual(await approvalRequest?.clone().json(), {
    approval_id: "approval-1",
    approved: false,
  });
  assert.equal(stopRequest?.headers.get("Idempotency-Key"), "stop-command-1");

  const restartedClient = new HermesApiClient({
    baseUrl: "https://hermes.example.test",
    token: "test",
    fetch: fakeFetch,
  });
  const replayedEvents = [];
  for await (const event of restartedClient.streamRunEvents(run)) replayedEvents.push(event);
  assert.equal(replayedEvents[0]?.sequence, 1);
  assert.notEqual(replayedEvents[0]?.eventId, firstEvents[0]?.eventId);
});

test("Hermes rejects empty approval and stop command identities", async () => {
  const client = new HermesApiClient({
    baseUrl: "https://hermes.example.test",
    token: "test",
    fetch: async () => new Response(null, { status: 204 }),
  });

  await assert.rejects(() => client.resolveApproval("run-1", "", false, "command-1"), /id is required/);
  await assert.rejects(
    () => client.resolveApproval("run-1", "approval-1", false, ""),
    /command id is required/,
  );
  await assert.rejects(() => client.stopRun("run-1", ""), /command id is required/);
});
