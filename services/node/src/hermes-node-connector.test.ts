import assert from "node:assert/strict";
import test from "node:test";

import type { AgentCapabilities, AgentEvent } from "@agent-talk/core";
import {
  HermesHttpError,
  type HermesApprovalResolutionMode,
  type HermesEventStreamOptions,
  type HermesRun,
} from "@agent-talk/adapters";
import { create } from "@bufbuild/protobuf";
import {
  AgentCapabilitiesSchema,
  AgentEventType,
  ApprovalDecision,
  ComponentRole,
  ConnectNodeResponseSchema,
  type ConnectNodeRequest,
} from "@agent-talk/protocol";

import { AsyncQueue } from "./async-queue.js";
import {
  HermesNodeConnector,
  type HermesAgentPort,
} from "./hermes-node-connector.js";

const capabilities: AgentCapabilities = {
  deltaMode: "append_only",
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
  idempotency: true,
  replay: true,
  sequenceRecovery: true,
};

class FakeHermes implements HermesAgentPort {
  readonly calls: string[] = [];
  continueStream!: () => void;
  private readonly streamGate = new Promise<void>((resolve) => {
    this.continueStream = resolve;
  });

  async health(): Promise<unknown> {
    return { ok: true };
  }

  async capabilities(): Promise<AgentCapabilities> {
    return capabilities;
  }

  async createSession(): Promise<string> {
    this.calls.push("session");
    return "hermes-session-1";
  }

  async startRun(
    _input: string,
    options: { sessionId?: string; requestId?: string } = {},
  ): Promise<HermesRun> {
    this.calls.push(`start:${options.sessionId}:${options.requestId}`);
    return {
      runId: "hermes-run-1",
      requestId: options.requestId ?? "missing",
      ...(options.sessionId === undefined ? {} : { sessionId: options.sessionId }),
    };
  }

  async *streamRunEvents(run: HermesRun): AsyncGenerator<AgentEvent> {
    yield event(run, 2, "message.delta", { delta: "partial" });
    yield event(run, 4, "approval.required", {
      approvalId: "approval-1",
      safeSummary: "Run a harmless test command.",
      operationSummarySha256: "a".repeat(64),
      expiresAt: "2099-01-01T00:00:00.000Z",
    });
    await this.streamGate;
    yield event(run, 6, "request.completed", {});
  }

  async stopRun(runId: string, commandId?: string): Promise<void> {
    this.calls.push(`stop:${runId}:${commandId}`);
  }

  async resolveApproval(
    runId: string,
    approvalId: string,
    approved: boolean,
    commandId?: string,
  ): Promise<void> {
    this.calls.push(`approval:${runId}:${approvalId}:${approved}:${commandId}`);
  }

  approvalResolutionMode(): HermesApprovalResolutionMode {
    return "fifo";
  }
}

test("bridges send, session, SSE, approval, and stop without bypassing Gateway dispatch", async () => {
  const hermes = new FakeHermes();
  const connector = new HermesNodeConnector(hermes, {
    nodeId: "node-1",
    agentId: "agent-1",
    nodeDisplayName: "Node",
    agentDisplayName: "Hermes",
  });
  await connector.initialize();
  const output = new AsyncQueue<ConnectNodeRequest>();
  const iterator = output[Symbol.asyncIterator]();

  connector.handle(create(ConnectNodeResponseSchema, {
    body: {
      case: "handshake",
      value: {
        selectedProtocol: { major: 1, minor: 0 },
        connectionId: "gateway-connection-1",
        schemaBuild: "test",
        schemaSha256: "b".repeat(64),
        componentVersion: "test",
        componentRole: ComponentRole.GATEWAY,
        capabilityRevision: "gateway-cap-1",
        capabilities: create(AgentCapabilitiesSchema),
      },
    },
  }), output);
  assert.equal((await iterator.next()).value?.body.case, "registration");

  connector.handle(create(ConnectNodeResponseSchema, {
    body: {
      case: "dispatchRequest",
      value: {
        dispatchId: "dispatch-send-1",
        requestId: "request-1",
        idempotencyKey: "send-idempotency-1",
        conversationId: "conversation-1",
        nodeId: "node-1",
        agentId: "agent-1",
        capabilityRevision: connector.capabilityRevision(),
        confirmedText: "Confirmed safe text",
      },
    },
  }), output);

  assert.equal((await iterator.next()).value?.body.case, "dispatchAck");
  assert.equal(eventType(await iterator.next()), AgentEventType.MESSAGE_DELTA);
  assert.equal(eventType(await iterator.next()), AgentEventType.APPROVAL_REQUIRED);

  connector.handle(create(ConnectNodeResponseSchema, {
    body: {
      case: "dispatchApproval",
      value: {
        dispatchId: "dispatch-approval-1",
        requestId: "request-1",
        approvalId: "approval-1",
        idempotencyKey: "approval-idempotency-1",
        decision: ApprovalDecision.APPROVE,
        operationSummarySha256: "a".repeat(64),
      },
    },
  }), output);
  const approvalAck = (await iterator.next()).value?.body;
  assert.equal(approvalAck?.case, "dispatchAck");
  if (approvalAck?.case === "dispatchAck") {
    assert.equal(approvalAck.value.accepted, false);
    assert.equal(approvalAck.value.failure?.code, "hermes_approval_resolution_ambiguous");
  }

  connector.handle(create(ConnectNodeResponseSchema, {
    body: {
      case: "dispatchInterrupt",
      value: {
        dispatchId: "dispatch-stop-1",
        requestId: "request-1",
        idempotencyKey: "stop-idempotency-1",
      },
    },
  }), output);
  assert.equal((await iterator.next()).value?.body.case, "dispatchAck");
  hermes.continueStream();
  assert.equal(eventType(await iterator.next()), AgentEventType.REQUEST_COMPLETED);
  assert.deepEqual(hermes.calls, [
    "session",
    "start:hermes-session-1:request-1",
    "stop:hermes-run-1:stop-idempotency-1",
  ]);
});

test("rejects approval B without resolving FIFO approval A", async () => {
  const hermes = new FakeHermes();
  let releaseStream!: () => void;
  const streamGate = new Promise<void>((resolve) => {
    releaseStream = resolve;
  });
  hermes.streamRunEvents = async function* (run: HermesRun): AsyncGenerator<AgentEvent> {
    yield event(run, 2, "approval.required", {
      approvalId: "approval-a",
      safeSummary: "Approval A",
      operationSummarySha256: "a".repeat(64),
      expiresAt: "2099-01-01T00:00:00.000Z",
    });
    yield event(run, 4, "approval.required", {
      approvalId: "approval-b",
      safeSummary: "Approval B",
      operationSummarySha256: "b".repeat(64),
      expiresAt: "2099-01-01T00:00:00.000Z",
    });
    await streamGate;
  };
  const connector = new HermesNodeConnector(hermes, {
    nodeId: "node-1",
    agentId: "agent-1",
    nodeDisplayName: "Node",
    agentDisplayName: "Hermes",
  });
  await connector.initialize();
  const output = new AsyncQueue<ConnectNodeRequest>();
  const iterator = output[Symbol.asyncIterator]();

  connector.handle(create(ConnectNodeResponseSchema, {
    body: {
      case: "dispatchRequest",
      value: {
        dispatchId: "dispatch-approval-b-send",
        requestId: "request-approval-b",
        idempotencyKey: "idempotency-approval-b-send",
        conversationId: "conversation-approval-b",
        nodeId: "node-1",
        agentId: "agent-1",
        capabilityRevision: connector.capabilityRevision(),
        confirmedText: "Confirmed safe text",
      },
    },
  }), output);
  assert.equal((await iterator.next()).value?.body.case, "dispatchAck");
  assert.equal(eventType(await iterator.next()), AgentEventType.APPROVAL_REQUIRED);
  assert.equal(eventType(await iterator.next()), AgentEventType.APPROVAL_REQUIRED);

  connector.handle(create(ConnectNodeResponseSchema, {
    body: {
      case: "dispatchApproval",
      value: {
        dispatchId: "dispatch-approval-b",
        requestId: "request-approval-b",
        approvalId: "approval-b",
        idempotencyKey: "idempotency-approval-b",
        decision: ApprovalDecision.APPROVE,
        operationSummarySha256: "b".repeat(64),
      },
    },
  }), output);
  const acknowledgement = (await iterator.next()).value?.body;
  assert.equal(acknowledgement?.case, "dispatchAck");
  if (acknowledgement?.case === "dispatchAck") {
    assert.equal(acknowledgement.value.accepted, false);
    assert.equal(acknowledgement.value.failure?.code, "hermes_approval_resolution_ambiguous");
  }
  assert.equal(hermes.calls.some((call) => call.startsWith("approval:")), false);
  releaseStream();
});

test("fails initialization closed when Hermes omits idempotency", async () => {
  const hermes = new FakeHermes();
  hermes.capabilities = async () => ({ ...capabilities, idempotency: false });
  const connector = new HermesNodeConnector(hermes, {
    nodeId: "node-1",
    agentId: "agent-1",
    nodeDisplayName: "Node",
    agentDisplayName: "Hermes",
  });
  await assert.rejects(() => connector.initialize(), /explicitly advertise/u);
});

test("serializes concurrent cold dispatches onto one durable Hermes session", async () => {
  const hermes = new FakeHermes();
  let signalSessionCreation!: () => void;
  const sessionCreationStarted = new Promise<void>((resolve) => {
    signalSessionCreation = resolve;
  });
  let releaseSessionCreation!: () => void;
  const sessionCreationGate = new Promise<void>((resolve) => {
    releaseSessionCreation = resolve;
  });
  hermes.createSession = async () => {
    hermes.calls.push("session");
    signalSessionCreation();
    await sessionCreationGate;
    return "hermes-session-1";
  };
  hermes.streamRunEvents = async function* (run: HermesRun): AsyncGenerator<AgentEvent> {
    yield event(run, 2, "request.completed", {});
  };
  const connector = new HermesNodeConnector(hermes, {
    nodeId: "node-1",
    agentId: "agent-1",
    nodeDisplayName: "Node",
    agentDisplayName: "Hermes",
  });
  await connector.initialize();
  const output = new AsyncQueue<ConnectNodeRequest>();
  const iterator = output[Symbol.asyncIterator]();

  for (const suffix of ["a", "b"]) {
    connector.handle(create(ConnectNodeResponseSchema, {
      body: {
        case: "dispatchRequest",
        value: {
          dispatchId: `dispatch-concurrent-${suffix}`,
          requestId: `request-concurrent-${suffix}`,
          idempotencyKey: `idempotency-concurrent-${suffix}`,
          conversationId: "conversation-concurrent-1",
          nodeId: "node-1",
          agentId: "agent-1",
          capabilityRevision: connector.capabilityRevision(),
          confirmedText: "Confirmed safe text",
        },
      },
    }), output);
  }

  await sessionCreationStarted;
  await Promise.resolve();
  assert.deepEqual(hermes.calls, ["session"]);
  releaseSessionCreation();
  await Promise.all(Array.from({ length: 4 }, () => iterator.next()));
  assert.equal(hermes.calls.filter((call) => call === "session").length, 1);
  assert.deepEqual(
    hermes.calls.filter((call) => call.startsWith("start:")),
    [
      "start:hermes-session-1:request-concurrent-a",
      "start:hermes-session-1:request-concurrent-b",
    ],
  );
});

test("distinguishes a confirmed Hermes HTTP rejection from uncertain acceptance", async () => {
  const hermes = new FakeHermes();
  hermes.startRun = async () => {
    throw new HermesHttpError(422, "Unprocessable Content");
  };
  const connector = new HermesNodeConnector(hermes, {
    nodeId: "node-1",
    agentId: "agent-1",
    nodeDisplayName: "Node",
    agentDisplayName: "Hermes",
  });
  await connector.initialize();
  const output = new AsyncQueue<ConnectNodeRequest>();
  const iterator = output[Symbol.asyncIterator]();

  connector.handle(create(ConnectNodeResponseSchema, {
    body: {
      case: "dispatchRequest",
      value: {
        dispatchId: "dispatch-rejected-1",
        requestId: "request-rejected-1",
        idempotencyKey: "idempotency-rejected-1",
        conversationId: "conversation-1",
        nodeId: "node-1",
        agentId: "agent-1",
        capabilityRevision: connector.capabilityRevision(),
        confirmedText: "Confirmed safe text",
      },
    },
  }), output);

  const body = (await iterator.next()).value?.body;
  assert.equal(body?.case, "dispatchAck");
  if (body?.case !== "dispatchAck") assert.fail("expected a dispatch acknowledgement");
  assert.equal(body.value.accepted, false);
  assert.equal(body.value.failure?.code, "hermes_http_422");
  assert.doesNotMatch(JSON.stringify(body.value), /Unprocessable Content/u);
});

test("resumes only the Hermes event stream from a stable cursor without resubmitting", async () => {
  const hermes = new FakeHermes();
  let streamCalls = 0;
  const resumeOptions: HermesEventStreamOptions[] = [];
  hermes.streamRunEvents = async function* (
    run: HermesRun,
    options: HermesEventStreamOptions = {},
  ) {
    streamCalls += 1;
    resumeOptions.push(options);
    if (streamCalls === 1) {
      options.onResumeCursor?.("native-event-1");
      yield event(run, 2, "message.delta", { delta: "partial" });
      yield event(run, 3, "connection.lost", { reason: "transport_disconnected" });
      return;
    }
    yield event(run, 4, "message.completed", { text: "recovered" });
    yield event(run, 6, "request.completed", {});
  };
  const connector = new HermesNodeConnector(hermes, {
    nodeId: "node-1",
    agentId: "agent-1",
    nodeDisplayName: "Node",
    agentDisplayName: "Hermes",
  });
  await connector.initialize();
  const output = new AsyncQueue<ConnectNodeRequest>();
  const iterator = output[Symbol.asyncIterator]();

  connector.handle(create(ConnectNodeResponseSchema, {
    body: {
      case: "dispatchRequest",
      value: {
        dispatchId: "dispatch-resume-1",
        requestId: "request-resume-1",
        idempotencyKey: "idempotency-resume-1",
        conversationId: "conversation-1",
        nodeId: "node-1",
        agentId: "agent-1",
        capabilityRevision: connector.capabilityRevision(),
        confirmedText: "Confirmed safe text",
      },
    },
  }), output);

  assert.equal((await iterator.next()).value?.body.case, "dispatchAck");
  assert.equal(eventType(await iterator.next()), AgentEventType.MESSAGE_DELTA);
  assert.equal(eventType(await iterator.next()), AgentEventType.CONNECTION_LOST);
  assert.equal(eventType(await iterator.next()), AgentEventType.MESSAGE_COMPLETED);
  assert.equal(eventType(await iterator.next()), AgentEventType.REQUEST_COMPLETED);
  assert.equal(streamCalls, 2);
  assert.equal(resumeOptions[1]?.lastEventId, "native-event-1");
  assert.equal(resumeOptions[1]?.previousSequence, 3);
  assert.equal(
    hermes.calls.filter((call) => call.startsWith("start:")).length,
    1,
  );
});

function event(
  run: HermesRun,
  sequence: number,
  type: AgentEvent["type"],
  payload: unknown,
): AgentEvent {
  return {
    eventId: `event-${sequence}`,
    connectionId: "hermes-connection-1",
    requestId: run.requestId,
    sequence,
    occurredAt: "2026-07-26T00:00:00.000Z",
    type,
    payload,
  };
}

function eventType(
  result: IteratorResult<ConnectNodeRequest>,
): AgentEventType | undefined {
  const body = result.value?.body;
  return body?.case === "event" ? body.value.event?.type : undefined;
}
