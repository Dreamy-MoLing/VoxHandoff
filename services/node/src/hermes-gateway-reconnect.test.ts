import assert from "node:assert/strict";
import test from "node:test";

import type { AgentCapabilities, AgentEvent } from "@agent-talk/core";
import type { HermesApprovalResolutionMode, HermesRun } from "@agent-talk/adapters";
import { create } from "@bufbuild/protobuf";
import { Code, ConnectError, type Client } from "@connectrpc/connect";
import {
  AgentCapabilitiesSchema,
  ComponentRole,
  ConnectNodeResponseSchema,
  GatewayControlService,
  NodeEventReceiptSchema,
  type ConnectNodeRequest,
  type ConnectNodeResponse,
} from "@agent-talk/protocol";

import { runGatewayConnectionSupervisor } from "./gateway-connection-supervisor.js";
import { AsyncQueue } from "./async-queue.js";
import {
  HermesNodeConnector,
  type HermesAgentPort,
} from "./hermes-node-connector.js";

const capabilities: AgentCapabilities = {
  deltaMode: "append_only",
  eventStream: true,
  sessionHistory: false,
  createSession: false,
  resumeSession: false,
  interrupt: true,
  steer: false,
  clarification: false,
  approval: false,
  toolEvents: false,
  attachments: false,
  idempotency: true,
  replay: false,
  sequenceRecovery: false,
};

class ReconnectHermes implements HermesAgentPort {
  readonly startCalls: string[] = [];
  readonly streamStarted = deferred();
  readonly releaseSecondEvent = deferred();

  async health(): Promise<unknown> {
    return { status: "ok" };
  }

  async capabilities(): Promise<AgentCapabilities> {
    return capabilities;
  }

  async createSession(): Promise<string> {
    throw new Error("session creation was not advertised");
  }

  async startRun(
    _input: string,
    options: { sessionId?: string; requestId?: string } = {},
  ): Promise<HermesRun> {
    const requestId = options.requestId ?? "missing";
    this.startCalls.push(requestId);
    return { runId: "hermes-run-1", requestId };
  }

  async *streamRunEvents(run: HermesRun): AsyncGenerator<AgentEvent> {
    this.streamStarted.resolve();
    yield {
      eventId: "hermes-event-2",
      connectionId: "hermes-connection-1",
      requestId: run.requestId,
      sequence: 2,
      occurredAt: "2026-08-11T00:00:00.000Z",
      type: "message.delta",
      payload: { delta: "first" },
    };
    await this.releaseSecondEvent.promise;
    yield {
      eventId: "hermes-event-3",
      connectionId: "hermes-connection-1",
      requestId: run.requestId,
      sequence: 3,
      occurredAt: "2026-08-11T00:00:01.000Z",
      type: "request.completed",
      payload: {},
    };
  }

  async stopRun(): Promise<void> {}

  async resolveApproval(): Promise<void> {}

  approvalResolutionMode(): HermesApprovalResolutionMode {
    return "exact";
  }
}

class BacklogHermes implements HermesAgentPort {
  readonly releaseEvents = deferred();
  readonly allStreamsStarted = deferred();
  #startedStreams = 0;

  constructor(private readonly expectedStreams: number) {}

  async health(): Promise<unknown> {
    return { status: "ok" };
  }

  async capabilities(): Promise<AgentCapabilities> {
    return capabilities;
  }

  async createSession(): Promise<string> {
    throw new Error("session creation was not advertised");
  }

  async startRun(
    _input: string,
    options: { sessionId?: string; requestId?: string } = {},
  ): Promise<HermesRun> {
    const requestId = options.requestId ?? "missing";
    return { runId: `hermes-run-${requestId}`, requestId };
  }

  async *streamRunEvents(run: HermesRun): AsyncGenerator<AgentEvent> {
    this.#startedStreams += 1;
    if (this.#startedStreams === this.expectedStreams) this.allStreamsStarted.resolve();
    await this.releaseEvents.promise;
    const suffix = run.requestId.replace("request-backlog-", "");
    yield {
      eventId: `backlog-event-${suffix}`,
      connectionId: "hermes-connection-1",
      requestId: run.requestId,
      sequence: 2,
      occurredAt: "2026-08-11T00:00:00.000Z",
      type: "message.delta",
      payload: { delta: suffix },
    };
  }

  async stopRun(): Promise<void> {}

  async resolveApproval(): Promise<void> {}

  approvalResolutionMode(): HermesApprovalResolutionMode {
    return "exact";
  }
}

class ReceiptInjectingQueue extends AsyncQueue<ConnectNodeRequest> {
  #injected = false;

  constructor(private readonly onFirstEvent: (frame: ConnectNodeRequest) => void) {
    super();
  }

  override push(frame: ConnectNodeRequest): void {
    super.push(frame);
    if (!this.#injected && frame.body.case === "event") {
      this.#injected = true;
      this.onFirstEvent(frame);
    }
  }
}

test("reconnects the Gateway stream without resubmitting an accepted Hermes run", async () => {
  const abortController = new AbortController();
  const hermes = new ReconnectHermes();
  const connector = new HermesNodeConnector(hermes, {
    nodeId: "node-1",
    agentId: "agent-1",
    nodeDisplayName: "Node",
    agentDisplayName: "Hermes",
  });
  await connector.initialize();
  const capabilityRevision = connector.capabilityRevision();

  const firstClient = client(async function* (requests): AsyncGenerator<ConnectNodeResponse> {
    const iterator = requests[Symbol.asyncIterator]();
    assert.equal(bodyCase(await iterator.next()), "handshake");
    yield handshake("gateway-connection-1");
    assert.equal(bodyCase(await iterator.next()), "registration");
    yield dispatch(capabilityRevision);

    const acknowledgement = (await iterator.next()).value?.body;
    assert.equal(acknowledgement?.case, "dispatchAck");
    if (acknowledgement?.case === "dispatchAck") {
      assert.equal(acknowledgement.value.accepted, true);
    }
    await hermes.streamStarted.promise;
    const event = (await iterator.next()).value?.body;
    assert.equal(event?.case, "event");
    if (event?.case === "event") {
      assert.equal(event.value.eventId, "hermes-event-2");
    }
    throw new ConnectError("simulated Gateway stream loss", Code.Unavailable);
  });

  const secondClient = client(async function* (requests): AsyncGenerator<ConnectNodeResponse> {
    const iterator = requests[Symbol.asyncIterator]();
    assert.equal(bodyCase(await iterator.next()), "handshake");
    hermes.releaseSecondEvent.resolve();
    await new Promise<void>((resolve) => setImmediate(resolve));
    yield handshake("gateway-connection-2");
    assert.equal(bodyCase(await iterator.next()), "registration");

    const replayed = [] as ConnectNodeRequest[];
    for (let index = 0; index < 2; index += 1) {
      const event = (await iterator.next()).value;
      assert.equal(event?.body.case, "event");
      if (event !== undefined) replayed.push(event);
    }
    assert.deepEqual(
      replayed.map((frame) => frame.body.case === "event" ? frame.body.value.eventId : undefined),
      ["hermes-event-2", "hermes-event-3"],
    );
    for (const frame of replayed) {
      const event = frame.body;
      if (event.case === "event") {
        yield receipt(
          event.value.eventId,
          event.value.requestId,
          event.value.conversationId,
          event.value.sequence,
          event.value.eventId === "hermes-event-2",
        );
      }
    }
    await assertNoAdditionalRequest(iterator, abortController);
  });

  let attempts = 0;
  await runGatewayConnectionSupervisor(
    () => {
      attempts += 1;
      return connector.run(
        attempts === 1 ? firstClient : secondClient,
        "synthetic-node-token",
        abortController.signal,
      );
    },
    abortController.signal,
    { wait: async () => undefined },
  );

  assert.equal(attempts, 2);
  assert.deepEqual(hermes.startCalls, ["request-1"]);
});

test("does not enqueue a replayed event twice when its receipt arrives before the waiting emitter", async () => {
  const releaseEvent = deferred();
  const hermes = new ReconnectHermes();
  hermes.streamRunEvents = async function* (run: HermesRun): AsyncGenerator<AgentEvent> {
    hermes.streamStarted.resolve();
    await releaseEvent.promise;
    yield {
      eventId: "receipt-race-event",
      connectionId: "hermes-connection-1",
      requestId: run.requestId,
      sequence: 2,
      occurredAt: "2026-08-11T00:00:00.000Z",
      type: "request.completed",
      payload: {},
    };
  };
  const connector = new HermesNodeConnector(hermes, {
    nodeId: "node-1",
    agentId: "agent-1",
    nodeDisplayName: "Node",
    agentDisplayName: "Hermes",
  });
  await connector.initialize();
  const capabilityRevision = connector.capabilityRevision();
  const firstClient = client(async function* (requests): AsyncGenerator<ConnectNodeResponse> {
    const iterator = requests[Symbol.asyncIterator]();
    assert.equal(bodyCase(await iterator.next()), "handshake");
    yield handshake("gateway-connection-1");
    assert.equal(bodyCase(await iterator.next()), "registration");
    yield dispatch(capabilityRevision);
    assert.equal((await iterator.next()).value?.body.case, "dispatchAck");
    await hermes.streamStarted.promise;
    throw new ConnectError("simulated Gateway stream loss", Code.Unavailable);
  });

  await assert.rejects(
    () => connector.run(firstClient, "synthetic-node-token"),
    (error: unknown) => error instanceof ConnectError && error.code === Code.Unavailable,
  );
  releaseEvent.resolve();
  await nextTurn();
  await nextTurn();

  let output!: ReceiptInjectingQueue;
  output = new ReceiptInjectingQueue((frame) => {
    const event = frame.body;
    if (event.case !== "event") return;
    connector.handle(receipt(
      event.value.eventId,
      event.value.requestId,
      event.value.conversationId,
      event.value.sequence,
      false,
    ), output);
  });
  connector.handle(handshake("gateway-connection-2"), output);
  await nextTurn();

  const iterator = output[Symbol.asyncIterator]();
  assert.equal((await iterator.next()).value?.body.case, "registration");
  const replayed = (await iterator.next()).value?.body;
  assert.equal(replayed?.case, "event");
  if (replayed?.case === "event") assert.equal(replayed.value.eventId, "receipt-race-event");

  const extra = iterator.next();
  await nextTurn();
  output.finish();
  assert.equal((await extra).done, true);
});

test("closes a terminal run when its unreceipted v1.1 event falls back to 1.0", async () => {
  const abortController = new AbortController();
  const hermes = new ReconnectHermes();
  hermes.streamRunEvents = async function* (run: HermesRun): AsyncGenerator<AgentEvent> {
    hermes.streamStarted.resolve();
    yield {
      eventId: "hermes-terminal-event",
      connectionId: "hermes-connection-1",
      requestId: run.requestId,
      sequence: 2,
      occurredAt: "2026-08-11T00:00:00.000Z",
      type: "request.completed",
      payload: {},
    };
  };
  const connector = new HermesNodeConnector(hermes, {
    nodeId: "node-1",
    agentId: "agent-1",
    nodeDisplayName: "Node",
    agentDisplayName: "Hermes",
  });
  await connector.initialize();
  const capabilityRevision = connector.capabilityRevision();

  const firstClient = client(async function* (requests): AsyncGenerator<ConnectNodeResponse> {
    const iterator = requests[Symbol.asyncIterator]();
    assert.equal(bodyCase(await iterator.next()), "handshake");
    yield handshake("gateway-connection-1");
    assert.equal(bodyCase(await iterator.next()), "registration");
    yield dispatch(capabilityRevision);
    assert.equal((await iterator.next()).value?.body.case, "dispatchAck");
    await hermes.streamStarted.promise;
    assert.equal((await iterator.next()).value?.body.case, "event");
    throw new ConnectError("simulated Gateway stream loss", Code.Unavailable);
  });

  const secondClient = client(async function* (requests): AsyncGenerator<ConnectNodeResponse> {
    const iterator = requests[Symbol.asyncIterator]();
    assert.equal(bodyCase(await iterator.next()), "handshake");
    yield handshake("gateway-connection-2", 0);
    assert.equal(bodyCase(await iterator.next()), "registration");
    const terminal = (await iterator.next()).value?.body;
    assert.equal(terminal?.case, "event");
    if (terminal?.case === "event") {
      assert.equal(terminal.value.eventId, "hermes-terminal-event");
      assert.equal(terminal.value.protocol?.minor, 0);
    }
    yield interrupt();
    const acknowledgement = (await iterator.next()).value?.body;
    assert.equal(acknowledgement?.case, "dispatchAck");
    if (acknowledgement?.case === "dispatchAck") {
      assert.equal(acknowledgement.value.accepted, false);
      assert.equal(acknowledgement.value.failure?.code, "hermes_interrupt_unavailable");
    }
    abortController.abort();
  });

  let attempts = 0;
  await runGatewayConnectionSupervisor(
    () => {
      attempts += 1;
      return connector.run(
        attempts === 1 ? firstClient : secondClient,
        "synthetic-node-token",
        abortController.signal,
      );
    },
    abortController.signal,
    { wait: async () => undefined },
  );

  assert.equal(attempts, 2);
  assert.deepEqual(hermes.startCalls, ["request-1"]);
});

test("replays a cached rejection acknowledgement after the Gateway stream reconnects", async () => {
  const abortController = new AbortController();
  const hermes = new ReconnectHermes();
  const connector = new HermesNodeConnector(hermes, {
    nodeId: "node-1",
    agentId: "agent-1",
    nodeDisplayName: "Node",
    agentDisplayName: "Hermes",
  });
  await connector.initialize();
  const capabilityRevision = connector.capabilityRevision();

  const firstClient = client(async function* (requests): AsyncGenerator<ConnectNodeResponse> {
    const iterator = requests[Symbol.asyncIterator]();
    assert.equal(bodyCase(await iterator.next()), "handshake");
    yield handshake("gateway-connection-1");
    assert.equal(bodyCase(await iterator.next()), "registration");
    yield dispatch(capabilityRevision, "rejected-1", "wrong-node");
    await nextTurn();
    throw new ConnectError("simulated Gateway stream loss", Code.Unavailable);
  });

  const secondClient = client(async function* (requests): AsyncGenerator<ConnectNodeResponse> {
    const iterator = requests[Symbol.asyncIterator]();
    assert.equal(bodyCase(await iterator.next()), "handshake");
    yield handshake("gateway-connection-2");
    assert.equal(bodyCase(await iterator.next()), "registration");
    yield dispatch(capabilityRevision, "rejected-1", "wrong-node");
    const acknowledgement = (await iterator.next()).value?.body;
    assert.equal(acknowledgement?.case, "dispatchAck");
    if (acknowledgement?.case === "dispatchAck") {
      assert.equal(acknowledgement.value.accepted, false);
      assert.equal(acknowledgement.value.failure?.code, "hermes_dispatch_route_invalid");
    }
    abortController.abort();
  });

  let attempts = 0;
  await runGatewayConnectionSupervisor(
    () => {
      attempts += 1;
      return connector.run(
        attempts === 1 ? firstClient : secondClient,
        "synthetic-node-token",
        abortController.signal,
      );
    },
    abortController.signal,
    { wait: async () => undefined },
  );

  assert.equal(attempts, 2);
  assert.deepEqual(hermes.startCalls, []);
});

test("releases a full receipt journal when a reconnect negotiates the 1.0 fallback", async () => {
  const streamCount = 401;
  const abortController = new AbortController();
  const hermes = new BacklogHermes(streamCount);
  const connector = new HermesNodeConnector(hermes, {
    nodeId: "node-1",
    agentId: "agent-1",
    nodeDisplayName: "Node",
    agentDisplayName: "Hermes",
  });
  await connector.initialize();
  const capabilityRevision = connector.capabilityRevision();

  const firstClient = client(async function* (requests): AsyncGenerator<ConnectNodeResponse> {
    const iterator = requests[Symbol.asyncIterator]();
    assert.equal(bodyCase(await iterator.next()), "handshake");
    yield handshake("gateway-connection-1");
    assert.equal(bodyCase(await iterator.next()), "registration");
    for (let index = 1; index <= streamCount; index += 1) {
      yield dispatch(capabilityRevision, `backlog-${index}`);
      const acknowledgement = (await iterator.next()).value?.body;
      assert.equal(acknowledgement?.case, "dispatchAck");
      if (acknowledgement?.case === "dispatchAck") {
        assert.equal(acknowledgement.value.accepted, true);
      }
    }
    await hermes.allStreamsStarted.promise;
    throw new ConnectError("simulated Gateway stream loss", Code.Unavailable);
  });

  const secondClient = client(async function* (requests): AsyncGenerator<ConnectNodeResponse> {
    const iterator = requests[Symbol.asyncIterator]();
    assert.equal(bodyCase(await iterator.next()), "handshake");
    hermes.releaseEvents.resolve();
    await nextTurn();
    await nextTurn();
    yield handshake("gateway-connection-2", 0);
    assert.equal(bodyCase(await iterator.next()), "registration");

    const replayed = [] as ConnectNodeRequest[];
    for (let index = 0; index < streamCount; index += 1) {
      const frame = (await iterator.next()).value;
      assert.equal(frame?.body.case, "event");
      if (frame !== undefined) replayed.push(frame);
    }
    const eventIds = replayed.map((frame) => {
      if (frame.body.case !== "event") return undefined;
      assert.equal(frame.body.value.protocol?.minor, 0);
      return frame.body.value.eventId;
    });
    assert.equal(new Set(eventIds).size, streamCount);
    assert.deepEqual(
      new Set(eventIds),
      new Set(Array.from({ length: streamCount }, (_, index) => `backlog-event-${index + 1}`)),
    );
    abortController.abort();
  });

  let attempts = 0;
  await runGatewayConnectionSupervisor(
    () => {
      attempts += 1;
      return connector.run(
        attempts === 1 ? firstClient : secondClient,
        "synthetic-node-token",
        abortController.signal,
      );
    },
    abortController.signal,
    { wait: async () => undefined },
  );

  assert.equal(attempts, 2);
});

function client(
  connectNode: (requests: AsyncIterable<ConnectNodeRequest>) => AsyncIterable<ConnectNodeResponse>,
): Client<typeof GatewayControlService> {
  return { connectNode } as unknown as Client<typeof GatewayControlService>;
}

function handshake(connectionId: string, minor = 1): ConnectNodeResponse {
  return create(ConnectNodeResponseSchema, {
    body: {
      case: "handshake",
      value: {
        selectedProtocol: { major: 1, minor },
        connectionId,
        schemaBuild: "gateway-test",
        schemaSha256: "b".repeat(64),
        componentVersion: "test",
        componentRole: ComponentRole.GATEWAY,
        capabilityRevision: "gateway-capability-1",
        capabilities: create(AgentCapabilitiesSchema),
      },
    },
  });
}

function receipt(
  eventId: string,
  requestId: string,
  conversationId: string,
  sourceSequence: bigint,
  duplicate: boolean,
): ConnectNodeResponse {
  return create(ConnectNodeResponseSchema, {
    body: {
      case: "eventReceipt",
      value: create(NodeEventReceiptSchema, {
        eventId,
        requestId,
        conversationId,
        sourceSequence,
        gatewaySequence: 1n,
        duplicate,
      }),
    },
  });
}

function dispatch(
  capabilityRevision: string,
  suffix = "1",
  nodeId = "node-1",
): ConnectNodeResponse {
  return create(ConnectNodeResponseSchema, {
    body: {
      case: "dispatchRequest",
      value: {
        dispatchId: `dispatch-${suffix}`,
        requestId: `request-${suffix}`,
        idempotencyKey: `send-idempotency-${suffix}`,
        conversationId: `conversation-${suffix}`,
        nodeId,
        agentId: "agent-1",
        capabilityRevision,
        confirmedText: "Confirmed safe text",
      },
    },
  });
}

function interrupt(): ConnectNodeResponse {
  return create(ConnectNodeResponseSchema, {
    body: {
      case: "dispatchInterrupt",
      value: {
        dispatchId: "dispatch-interrupt-1",
        requestId: "request-1",
        idempotencyKey: "interrupt-idempotency-1",
      },
    },
  });
}

function bodyCase(result: IteratorResult<ConnectNodeRequest>): string | undefined {
  return result.value?.body.case;
}

function deferred(): { promise: Promise<void>; resolve(): void } {
  let resolvePromise!: () => void;
  const promise = new Promise<void>((resolve) => {
    resolvePromise = resolve;
  });
  return { promise, resolve: resolvePromise };
}

function nextTurn(): Promise<void> {
  return new Promise<void>((resolve) => setImmediate(resolve));
}

async function assertNoAdditionalRequest(
  iterator: AsyncIterator<ConnectNodeRequest>,
  abortController: AbortController,
): Promise<void> {
  const next = iterator.next();
  let timeout: ReturnType<typeof setTimeout> | undefined;
  const result = await Promise.race([
    next.then((value) => ({ kind: "frame" as const, value })),
    new Promise<{ kind: "timeout" }>((resolve) => {
      timeout = setTimeout(() => resolve({ kind: "timeout" }), 50);
    }),
  ]);
  if (timeout !== undefined) clearTimeout(timeout);
  if (result.kind === "frame") {
    assert.fail(`unexpected extra Node frame: ${result.value.value?.body.case ?? "end"}`);
  }
  abortController.abort();
  await next;
}
