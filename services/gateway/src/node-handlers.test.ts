import assert from "node:assert/strict";
import test from "node:test";

import { create } from "@bufbuild/protobuf";
import { timestampFromDate } from "@bufbuild/protobuf/wkt";
import { Code, ConnectError } from "@connectrpc/connect";
import {
  AgentCapabilitiesSchema,
  AgentEventType,
  DispatchAckSchema,
  EventEnvelopeSchema,
  NodeRegistrationSchema,
} from "@agent-talk/protocol";

import type { NodeMessageContext } from "./control-service.js";
import { LedgerBackedNodeHandlers } from "./node-handlers.js";
import type {
  ClaimedDispatchRecord,
  DispatchAcknowledgement,
  NodeEventInput,
  NodeLedger,
  NodeRegistrationRecord,
} from "./node-ledger.js";

class FakeNodeLedger implements NodeLedger {
  registration: NodeRegistrationRecord | undefined;
  acknowledgement: DispatchAcknowledgement | undefined;
  event: NodeEventInput | undefined;
  claims: ClaimedDispatchRecord[] = [];
  claimConnections: string[] = [];

  async registerNode(registration: NodeRegistrationRecord): Promise<void> {
    this.registration = registration;
  }

  async claimDispatches(_nodeId: string, connectionId: string): Promise<readonly ClaimedDispatchRecord[]> {
    this.claimConnections.push(connectionId);
    return this.claims;
  }

  async acknowledgeDispatch(acknowledgement: DispatchAcknowledgement): Promise<void> {
    this.acknowledgement = acknowledgement;
  }

  async ingestNodeEvent(event: NodeEventInput) {
    this.event = event;
    return { eventId: event.eventId, conversationId: event.conversationId, sequence: 9n, duplicate: false };
  }
}

const context: NodeMessageContext = {
  principal: { principalId: "node-1", role: "node", scopes: ["node:connect"] },
  connectionId: "node-connection-1",
};

function setup() {
  const ledger = new FakeNodeLedger();
  const handlers = new LedgerBackedNodeHandlers(ledger, {
    now: () => new Date("2030-01-01T00:00:00.000Z"),
  });
  return { ledger, handlers };
}

test("registers an authenticated Node and dispatches the exact accepted route", async () => {
  const { ledger, handlers } = setup();
  ledger.claims = [{
    kind: "send",
    dispatchId: "dispatch-1",
    requestId: "request-1",
    idempotencyKey: "idempotency-1",
    conversationId: "conversation-1",
    sessionId: "session-1",
    nodeId: "node-1",
    agentId: "agent-1",
    capabilityRevision: "cap-1",
    confirmedText: "confirmed text",
  }];
  const registration = create(NodeRegistrationSchema, {
    node: { nodeId: "node-1", displayName: "Node", platform: "linux", version: "1" },
    agents: [{
      agentId: "agent-1",
      displayName: "Agent",
      adapter: "fake",
      version: "1",
      capabilityRevision: "cap-1",
      capabilities: create(AgentCapabilitiesSchema, { eventStream: true, maxRequestBytes: 2048n }),
    }],
  });

  const responses = await handlers.onRegistration(registration, context);
  assert.equal(ledger.registration?.nodeId, "node-1");
  assert.equal(ledger.registration?.connectionId, "node-connection-1");
  assert.equal(ledger.registration?.agents[0]?.maxRequestBytes, 2048n);
  const dispatch = responses[0]?.body;
  assert.equal(dispatch?.case, "dispatchRequest");
  if (dispatch?.case === "dispatchRequest") {
    assert.equal(dispatch.value.dispatchId, "dispatch-1");
    assert.equal(dispatch.value.confirmedText, "confirmed text");
  }

  await handlers.onHeartbeat({ ...context, connectionId: "node-connection-2" });
  assert.deepEqual(ledger.claimConnections, ["node-connection-1", "node-connection-2"]);
});

test("normalizes a Node event and leaves authoritative identity allocation to the ledger", async () => {
  const { ledger, handlers } = setup();
  await handlers.onEvent(
    create(EventEnvelopeSchema, {
      protocol: { major: 1, minor: 0 },
      eventId: "event-1",
      connectionId: "untrusted-connection",
      deviceId: "untrusted-device",
      conversationId: "conversation-1",
      sessionId: "session-1",
      requestId: "request-1",
      sequence: 1n,
      event: {
        type: AgentEventType.MESSAGE_COMPLETED,
        payload: { case: "message", value: { text: "complete answer", revision: 2n } },
      },
    }),
    context,
  );
  assert.equal(ledger.event?.connectionId, "node-connection-1");
  assert.equal(ledger.event?.nodeId, "node-1");
  assert.equal(ledger.event?.eventType, "message.completed");
  assert.deepEqual(ledger.event?.safePayload, { text: "complete answer", revision: "2" });
});

test("rejects Gateway-owned acceptance events and missing Node source sequences", async () => {
  const { handlers } = setup();
  for (const [type, sequence] of [
    [AgentEventType.REQUEST_ACCEPTED, 1n],
    [AgentEventType.AGENT_WORKING, 0n],
  ] as const) {
    await assert.rejects(
      handlers.onEvent(
        create(EventEnvelopeSchema, {
          protocol: { major: 1, minor: 0 },
          eventId: `event-${type}`,
          conversationId: "conversation-1",
          requestId: "request-1",
          sequence,
          event: {
            type,
            payload: { case: "requestProgress", value: { safeMessage: "working" } },
          },
        }),
        context,
      ),
      (error: unknown) => error instanceof ConnectError && error.code === Code.InvalidArgument,
    );
  }
});

test("records an exact dispatch acknowledgement", async () => {
  const { ledger, handlers } = setup();
  await handlers.onDispatchAck(
    create(DispatchAckSchema, { dispatchId: "dispatch-1", requestId: "request-1", accepted: true }),
    context,
  );
  assert.deepEqual(ledger.acknowledgement, {
    nodeId: "node-1",
    connectionId: "node-connection-1",
    dispatchId: "dispatch-1",
    requestId: "request-1",
    accepted: true,
    failure: null,
    occurredAt: new Date("2030-01-01T00:00:00.000Z"),
  });
});

test("maps a durable interrupt outbox record to DispatchInterrupt", async () => {
  const { ledger, handlers } = setup();
  ledger.claims = [{
    kind: "interrupt",
    dispatchId: "interrupt-dispatch-1",
    requestId: "request-1",
    idempotencyKey: "interrupt-idempotency-1",
  }];
  const responses = await handlers.onHeartbeat(context);
  const body = responses[0]?.body;
  assert.equal(body?.case, "dispatchInterrupt");
  if (body?.case === "dispatchInterrupt") {
    assert.equal(body.value.dispatchId, "interrupt-dispatch-1");
    assert.equal(body.value.idempotencyKey, "interrupt-idempotency-1");
  }
});

test("normalizes a pending approval without deriving any decision", async () => {
  const { ledger, handlers } = setup();
  await handlers.onEvent(
    create(EventEnvelopeSchema, {
      protocol: { major: 1, minor: 0 },
      eventId: "approval-event-1",
      conversationId: "conversation-1",
      requestId: "request-1",
      sequence: 1n,
      event: {
        type: AgentEventType.APPROVAL_REQUIRED,
        payload: {
          case: "approval",
          value: {
            approvalId: "approval-1",
            safeSummary: "Allow a harmless test action?",
            operationSummarySha256: "a".repeat(64),
            expiresAt: timestampFromDate(new Date("2030-01-01T00:01:00.000Z")),
          },
        },
      },
    }),
    context,
  );
  assert.deepEqual(ledger.event?.interaction, {
    kind: "approval_required",
    approvalId: "approval-1",
    nativeApprovalId: "approval-1",
    safeSummary: "Allow a harmless test action?",
    operationSummarySha256: "a".repeat(64),
    expiresAt: new Date("2030-01-01T00:01:00.000Z"),
  });
});

test("maps an authorized approval decision to DispatchApproval", async () => {
  const { ledger, handlers } = setup();
  ledger.claims = [{
    kind: "approval",
    dispatchId: "approval-dispatch-1",
    requestId: "request-1",
    idempotencyKey: "approval-idempotency-1",
    approvalId: "approval-1",
    decision: "rejected",
    operationSummarySha256: "a".repeat(64),
  }];
  const responses = await handlers.onHeartbeat(context);
  const body = responses[0]?.body;
  assert.equal(body?.case, "dispatchApproval");
  if (body?.case === "dispatchApproval") {
    assert.equal(body.value.approvalId, "approval-1");
    assert.equal(body.value.decision, 2);
  }
});

test("maps confirmed clarification text to DispatchClarification", async () => {
  const { ledger, handlers } = setup();
  ledger.claims = [{
    kind: "clarification",
    dispatchId: "clarification-dispatch-1",
    requestId: "request-1",
    idempotencyKey: "clarification-idempotency-1",
    clarificationId: "clarification-1",
    confirmedText: "Use the isolated test directory.",
  }];
  const responses = await handlers.onHeartbeat(context);
  const body = responses[0]?.body;
  assert.equal(body?.case, "dispatchClarification");
  if (body?.case === "dispatchClarification") {
    assert.equal(body.value.clarificationId, "clarification-1");
    assert.equal(body.value.confirmedText, "Use the isolated test directory.");
  }
});
