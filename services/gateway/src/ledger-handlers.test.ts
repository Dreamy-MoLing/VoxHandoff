import assert from "node:assert/strict";
import test from "node:test";

import { create, type MessageInitShape } from "@bufbuild/protobuf";
import { Code, ConnectError } from "@connectrpc/connect";
import { AckSchema, AgentEventType, ClientCommandSchema, type ClientCommand } from "@agent-talk/protocol";

import type { ClientLedger, GatewayRequestStatusRecord, PersistedEventRecord } from "./client-ledger.js";
import type { ControlLeaseLedger, ControlLeaseTransaction } from "./control-lease.js";
import type { InteractionLedger, InteractionLedgerTransaction } from "./interaction-ledger.js";
import type { ClientCommandContext } from "./control-service.js";
import { LedgerBackedGatewayHandlers } from "./ledger-handlers.js";
import type {
  AcceptanceFacts,
  AcceptedRequestRecord,
  AgentTargetRecord,
  ControlLeaseRecord,
  DeviceRecord,
  GatewayLedger,
  GatewayLedgerTransaction,
} from "./ledger.js";

class StubStore implements GatewayLedger, ControlLeaseLedger, ClientLedger, InteractionLedger, GatewayLedgerTransaction {
  request: GatewayRequestStatusRecord | undefined;
  events: PersistedEventRecord[] = [];
  acknowledged: { deviceId: string; conversationId: string; sequence: bigint; eventId: string } | undefined;

  async transaction<T>(work: (transaction: GatewayLedgerTransaction) => Promise<T>): Promise<T> {
    return work(this);
  }

  async leaseTransaction<T>(_work: (transaction: ControlLeaseTransaction) => Promise<T>): Promise<T> {
    throw new Error("lease transaction is not configured in this stub");
  }

  async interactionTransaction<T>(_work: (transaction: InteractionLedgerTransaction) => Promise<T>): Promise<T> {
    throw new Error("interaction transaction is not configured in this stub");
  }

  async lockDevice(): Promise<DeviceRecord | undefined> {
    return undefined;
  }

  async lockConversation(): Promise<boolean> {
    return true;
  }

  async findRequestByIdempotency(): Promise<AcceptedRequestRecord | undefined> {
    return undefined;
  }

  async findRequestByCommand(): Promise<AcceptedRequestRecord | undefined> {
    return undefined;
  }

  async findRequestById(): Promise<AcceptedRequestRecord | undefined> {
    return undefined;
  }

  async getControlLease(): Promise<ControlLeaseRecord | undefined> {
    return undefined;
  }

  async getAgentTarget(): Promise<AgentTargetRecord | undefined> {
    return undefined;
  }

  async allocateConversationSequence(): Promise<bigint | undefined> {
    return 1n;
  }

  async insertAcceptance(_facts: AcceptanceFacts): Promise<void> {}

  async getRequestStatus(): Promise<GatewayRequestStatusRecord | undefined> {
    return this.request;
  }

  async replayEvents(): Promise<readonly PersistedEventRecord[]> {
    return this.events;
  }

  async acknowledgeEvent(
    deviceId: string,
    conversationId: string,
    sequence: bigint,
    eventId: string,
  ): Promise<boolean> {
    this.acknowledged = { deviceId, conversationId, sequence, eventId };
    return eventId !== "missing";
  }
}

const context: ClientCommandContext = {
  principal: { principalId: "device-1", role: "client", scopes: ["observe", "send"] },
  connectionId: "connection-1",
};

function command(value: MessageInitShape<typeof ClientCommandSchema>): ClientCommand {
  return create(ClientCommandSchema, value);
}

function setup() {
  const store = new StubStore();
  let nextId = 0;
  const handlers = new LedgerBackedGatewayHandlers(store, {
    now: () => new Date("2030-01-01T00:00:00.000Z"),
    newOpaqueId: () => `generated-${++nextId}`,
    gatewayAudience: "https://gateway.example",
  });
  return { store, handlers };
}

test("GetRequest returns durable acceptance status by known request identity", async () => {
  const { store, handlers } = setup();
  store.request = {
    requestId: "request-1",
    commandId: "command-1",
    idempotencyKey: "idempotency-1",
    deviceId: "device-1",
    connectionId: "connection-original",
    conversationId: "conversation-1",
    sessionId: null,
    nodeId: "node-1",
    agentId: "agent-1",
    capabilityRevision: "cap-1",
    confirmedTextSha256: "a".repeat(64),
    acceptedSequence: 4n,
    acceptedAt: new Date("2030-01-01T00:00:00.000Z"),
    state: "accepted",
    failure: null,
  };

  const responses = await handlers.onClientCommand(
    command({
      requestId: "lookup-command-request",
      commandId: "lookup-command",
      idempotencyKey: "lookup-idempotency",
      conversationId: "conversation-1",
      command: { case: "getRequest", value: { requestId: "request-1" } },
    }),
    context,
  );
  const statusBody = responses[0]?.body;
  assert.equal(statusBody?.case, "requestStatus");
  if (statusBody?.case === "requestStatus") {
    assert.equal(statusBody.value?.requestId, "request-1");
    assert.equal(statusBody.value?.acceptedSequence, 4n);
  }
});

test("replay remains ordered and preserves unsupported events without inventing success", async () => {
  const { store, handlers } = setup();
  store.events = [
    {
      eventId: "event-1",
      connectionId: "connection-1",
      deviceId: "device-1",
      conversationId: "conversation-1",
      sessionId: null,
      requestId: "request-1",
      sequence: 1n,
      eventType: "request.accepted",
      safePayload: {},
      occurredAt: new Date("2030-01-01T00:00:00.000Z"),
    },
    {
      eventId: "event-2",
      connectionId: "connection-1",
      deviceId: "device-1",
      conversationId: "conversation-1",
      sessionId: null,
      requestId: "request-1",
      sequence: 2n,
      eventType: "future.event",
      safePayload: {},
      occurredAt: new Date("2030-01-01T00:00:01.000Z"),
    },
    {
      eventId: "event-3",
      connectionId: "node-connection-1",
      deviceId: "device-1",
      conversationId: "conversation-1",
      sessionId: null,
      requestId: "request-1",
      sequence: 3n,
      eventType: "message.completed",
      safePayload: { text: "complete answer", revision: "2" },
      occurredAt: new Date("2030-01-01T00:00:02.000Z"),
    },
    {
      eventId: "event-4",
      connectionId: "node-connection-1",
      deviceId: "device-1",
      conversationId: "conversation-1",
      sessionId: null,
      requestId: "request-1",
      sequence: 4n,
      eventType: "message.completed",
      safePayload: { text: "missing revision" },
      occurredAt: new Date("2030-01-01T00:00:03.000Z"),
    },
  ];
  const responses = await handlers.onClientCommand(
    command({
      requestId: "replay-command-request",
      commandId: "replay-command",
      idempotencyKey: "replay-idempotency",
      conversationId: "conversation-1",
      command: { case: "replay", value: { afterSequence: 0n, maximumEvents: 10 } },
    }),
    context,
  );

  assert.deepEqual(
    responses.map((response) =>
      response.body?.case === "event" ? (response.body.value?.sequence ?? -1n) : -1n,
    ),
    [1n, 2n, 3n, 4n],
  );
  const firstEvent = responses[0]?.body;
  const secondEvent = responses[1]?.body;
  assert.equal(firstEvent?.case === "event" ? firstEvent.value.event?.type : undefined, AgentEventType.REQUEST_ACCEPTED);
  assert.equal(secondEvent?.case === "event" ? secondEvent.value.event?.type : undefined, AgentEventType.UNSPECIFIED);
  if (secondEvent?.case === "event") {
    assert.equal(secondEvent.value?.event?.payload?.case, "unsupported");
  }
  const completeMessage = responses[2]?.body;
  assert.equal(completeMessage?.case === "event" ? completeMessage.value.event?.payload?.case : undefined, "message");
  const malformedMessage = responses[3]?.body;
  assert.equal(malformedMessage?.case === "event" ? malformedMessage.value.event?.type : undefined, AgentEventType.UNSPECIFIED);
});

test("Ack advances only an exact persisted event identity", async () => {
  const { store, handlers } = setup();
  await handlers.onClientAck(
    create(AckSchema, {
      conversationId: "conversation-1",
      sequence: 2n,
      eventId: "event-2",
    }),
    context,
  );
  assert.deepEqual(store.acknowledged, {
    deviceId: "device-1",
    conversationId: "conversation-1",
    sequence: 2n,
    eventId: "event-2",
  });
});

test("maps durable authorization rejection to a safe Connect permission error", async () => {
  const { handlers } = setup();
  await assert.rejects(
    handlers.onClientCommand(
      command({
        requestId: "request-1",
        commandId: "command-1",
        idempotencyKey: "idempotency-1",
        conversationId: "conversation-1",
        leaseId: "lease-1",
        leaseRevision: 1n,
        command: {
          case: "send",
          value: {
            nodeId: "node-1",
            agentId: "agent-1",
            capabilityRevision: "cap-1",
            confirmedText: "confirmed",
          },
        },
      }),
      context,
    ),
    (error: unknown) => error instanceof ConnectError && error.code === Code.PermissionDenied,
  );
});
