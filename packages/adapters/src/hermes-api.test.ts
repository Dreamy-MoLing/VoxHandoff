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
        features: {
          runs: true,
          streaming: true,
          append_only_delta: true,
          run_stop: true,
          idempotency: true,
          event_replay: false,
        },
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
  assert.equal(capabilities.eventStream, true);
  assert.equal(capabilities.deltaMode, "append_only");
  assert.equal(capabilities.replay, false);
  assert.equal(capabilities.approval, false);
  assert.equal(capabilities.createSession, false);
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
  assert.equal(events[0]?.sequence, 2);
  assert.equal(events[1]?.sequence, 16);
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
      [2, "message.delta", { delta: "partial" }],
      [3, "connection.lost", { reason: "transport_disconnected" }],
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
  assert.equal(firstClient.approvalResolutionMode(), "fifo");

  const firstEvents = [];
  for await (const event of firstClient.streamRunEvents(run)) firstEvents.push(event);
  assert.equal(firstEvents[0]?.type, "approval.required");
  assert.deepEqual(firstEvents[0]?.payload, {
    approvalId: "approval-1",
    safeSummary: "Run a harmless test command.",
    operationSummarySha256: "a".repeat(64),
    expiresAt: "2099-01-01T00:00:00.000Z",
  });
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
    choice: "deny",
  });
  assert.equal(stopRequest?.headers.get("Idempotency-Key"), "stop-command-1");

  const restartedClient = new HermesApiClient({
    baseUrl: "https://hermes.example.test",
    token: "test",
    fetch: fakeFetch,
  });
  const replayedEvents = [];
  for await (const event of restartedClient.streamRunEvents(run)) replayedEvents.push(event);
  assert.equal(replayedEvents[0]?.sequence, 2);
  assert.equal(replayedEvents[0]?.eventId, firstEvents[0]?.eventId);
});

test("Hermes 0.19 approval and tool events use configured manual timeout facts", async () => {
  const encoder = new TextEncoder();
  const fixture = [
    'data: {"event":"tool.started","run_id":"run-1","timestamp":1785333000.25,"tool":"terminal"}',
    "",
    'data: {"event":"approval.request","run_id":"run-1","timestamp":1785333001.5,"description":"delete in root path","command":"rm -rf /tmp/test","choices":["once","deny"]}',
    "",
    'data: {"event":"approval.responded","run_id":"run-1","timestamp":1785333002,"choice":"deny","resolved":1}',
    "",
    'data: {"event":"run.completed","run_id":"run-1","timestamp":1785333003}',
    "",
    "",
  ].join("\n");
  const client = new HermesApiClient({
    baseUrl: "https://hermes.example.test",
    token: "test",
    approvalTimeoutMs: 60_000,
    fetch: async () =>
      new Response(
        new ReadableStream<Uint8Array>({
          start(controller) {
            controller.enqueue(encoder.encode(fixture));
            controller.close();
          },
        }),
      ),
  });

  const events = [];
  for await (const event of client.streamRunEvents({
    runId: "run-1",
    requestId: "request-1",
  })) {
    events.push(event);
  }

  assert.equal(events[0]?.occurredAt, "2026-07-29T13:50:00.250Z");
  assert.deepEqual(events[0]?.payload, {
    toolName: "terminal",
    safeSummary: "Tool execution started.",
  });
  assert.equal(events[1]?.type, "approval.required");
  assert.deepEqual(events[1]?.payload, {
    approvalId: `hermes:${events[1]?.eventId}`,
    safeSummary: "delete in root path",
    operationSummarySha256:
      "bbb25590a77ad16e8db6d841104466997b3243dd794da6c9f21a5eb000f8c0c2",
    expiresAt: "2026-07-29T13:51:01.500Z",
  });
  assert.deepEqual(events[2]?.payload, {
    approvalId: `hermes:${events[1]?.eventId}`,
    outcome: "rejected",
  });
});

test("Hermes capability negotiation fails closed when fields are absent", async () => {
  const client = new HermesApiClient({
    baseUrl: "https://hermes.example.test",
    token: "test",
    fetch: async () => Response.json({ version: "test", features: { run_stop: true } }),
  });

  assert.deepEqual(await client.capabilities(), {
    serverVersion: "test",
    deltaMode: "none",
    eventStream: false,
    sessionHistory: false,
    createSession: false,
    resumeSession: false,
    interrupt: true,
    steer: false,
    clarification: false,
    approval: false,
    toolEvents: false,
    attachments: false,
    idempotency: false,
    replay: false,
    sequenceRecovery: false,
  });
});

test("Hermes 0.19 capabilities require explicit features and session endpoints", async () => {
  const client = new HermesApiClient({
    baseUrl: "https://hermes.example.test",
    token: "test",
    fetch: async () =>
      Response.json({
        object: "hermes.api_server.capabilities",
        features: {
          run_submission: true,
          run_events_sse: true,
          run_stop: true,
          run_approval_response: true,
          approval_events: true,
          tool_progress_events: true,
          session_resources: true,
        },
        endpoints: {
          session_create: { method: "POST", path: "/api/sessions" },
          session_messages: {
            method: "GET",
            path: "/api/sessions/{session_id}/messages",
          },
        },
      }),
  });

  assert.deepEqual(await client.capabilities(), {
    deltaMode: "none",
    eventStream: true,
    sessionHistory: true,
    createSession: true,
    resumeSession: true,
    interrupt: true,
    steer: false,
    clarification: false,
    approval: true,
    toolEvents: true,
    attachments: false,
    idempotency: false,
    replay: false,
    sequenceRecovery: false,
  });
});

test("Hermes 0.19 session features fail closed when endpoint facts are missing", async () => {
  const client = new HermesApiClient({
    baseUrl: "https://hermes.example.test",
    token: "test",
    fetch: async () =>
      Response.json({
        features: {
          run_submission: true,
          session_resources: true,
        },
      }),
  });

  const capabilities = await client.capabilities();
  assert.equal(capabilities.sessionHistory, false);
  assert.equal(capabilities.createSession, false);
  assert.equal(capabilities.resumeSession, true);
});

test("Hermes forwards an explicit SSE resume cursor and preserves native event identity", async () => {
  const encoder = new TextEncoder();
  const requests: Request[] = [];
  const fakeFetch: typeof fetch = async (input, init) => {
    const request = new Request(input, init);
    requests.push(request);
    return new Response(
      new ReadableStream<Uint8Array>({
        start(controller) {
          controller.enqueue(
            encoder.encode(
              'id: native-event-42\nevent: run.completed\ndata: {"seq":42,"type":"run.completed"}\n\n',
            ),
          );
          controller.close();
        },
      }),
    );
  };
  const client = new HermesApiClient({
    baseUrl: "https://hermes.example.test",
    token: "test",
    fetch: fakeFetch,
  });
  const run = { runId: "run-1", requestId: "request-1" };

  const first = [];
  for await (const event of client.streamRunEvents(run, { lastEventId: "native-event-41" })) {
    first.push(event);
  }
  const second = [];
  for await (const event of client.streamRunEvents(run, { lastEventId: "native-event-41" })) {
    second.push(event);
  }

  assert.equal(requests[0]?.headers.get("Last-Event-ID"), "native-event-41");
  assert.equal(first[0]?.sequence, 84);
  assert.equal(first[0]?.eventId, second[0]?.eventId);
  assert.equal(first[0]?.occurredAt, second[0]?.occurredAt);
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
