import assert from "node:assert/strict";
import test from "node:test";

import type { AgentCapabilities, AgentEvent } from "@agent-talk/core";
import type { HermesRun } from "@agent-talk/adapters";
import { create } from "@bufbuild/protobuf";
import { createClient, createRouterTransport } from "@connectrpc/connect";
import {
  AgentCapabilitiesSchema,
  AgentEventType,
  ComponentRole,
  ConnectNodeResponseSchema,
  GatewayControlService,
} from "@agent-talk/protocol";
import {
  createGatewayControlService,
  type AuthenticatedPrincipal,
  type GatewayStreamHandlers,
  type StreamIdentityVerifier,
} from "@agent-talk/gateway";

import {
  HermesNodeConnector,
  type HermesAgentPort,
} from "./hermes-node-connector.js";

const hermesCapabilities: AgentCapabilities = {
  serverVersion: "fake-hermes-1",
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

class IntegrationHermes implements HermesAgentPort {
  async health(): Promise<unknown> {
    return { status: "ok" };
  }

  async capabilities(): Promise<AgentCapabilities> {
    return hermesCapabilities;
  }

  async createSession(): Promise<string> {
    throw new Error("session creation was not advertised");
  }

  async startRun(
    _input: string,
    options: { sessionId?: string; requestId?: string } = {},
  ): Promise<HermesRun> {
    return { runId: "run-1", requestId: options.requestId ?? "missing" };
  }

  async *streamRunEvents(run: HermesRun): AsyncGenerator<AgentEvent> {
    yield domainEvent(run, 2, "message.completed", { text: "real vertical path" });
    yield domainEvent(run, 4, "request.completed", {});
  }

  async stopRun(): Promise<void> {}

  async resolveApproval(): Promise<void> {}
}

class IntegrationVerifier implements StreamIdentityVerifier {
  async authenticate(
    headers: Headers,
    expectedRole: AuthenticatedPrincipal["role"],
  ): Promise<AuthenticatedPrincipal> {
    assert.equal(expectedRole, "node");
    assert.equal(headers.get("authorization"), "Bearer synthetic-node-token");
    return { principalId: "node-1", role: "node", scopes: ["node:connect"] };
  }

  async revalidate(): Promise<void> {}
}

test("crosses the production Gateway stream boundary from dispatch through Hermes events", async () => {
  const abortController = new AbortController();
  const facts = {
    registrations: 0,
    acknowledgements: 0,
    eventTypes: [] as AgentEventType[],
  };
  let connector!: HermesNodeConnector;
  const handlers: GatewayStreamHandlers = {
    async onClientCommand() {
      return [];
    },
    async onClientAck() {},
    async onNodeRegistration() {
      facts.registrations += 1;
      return [create(ConnectNodeResponseSchema, {
        body: {
          case: "dispatchRequest",
          value: {
            dispatchId: "dispatch-1",
            requestId: "request-1",
            idempotencyKey: "idempotency-1",
            conversationId: "conversation-1",
            nodeId: "node-1",
            agentId: "agent-1",
            capabilityRevision: connector.capabilityRevision(),
            confirmedText: "Confirmed safe text",
          },
        },
      })];
    },
    async onNodeHeartbeat() {
      return [];
    },
    async onNodeDispatchAck(ack) {
      assert.equal(ack.accepted, true);
      facts.acknowledgements += 1;
    },
    async onNodeEvent(event) {
      const type = event.event?.type;
      if (type !== undefined) facts.eventTypes.push(type);
      if (type === AgentEventType.REQUEST_COMPLETED) {
        abortController.abort();
      }
    },
  };
  const service = createGatewayControlService({
    identityVerifier: new IntegrationVerifier(),
    handlers,
    handshake: {
      schemaBuild: "gateway-test",
      schemaSha256: "b".repeat(64),
      componentVersion: "test",
      capabilityRevision: "gateway-cap-1",
      capabilities: create(AgentCapabilitiesSchema, {
        eventStream: true,
        attachments: false,
      }),
    },
    newConnectionId: () => "gateway-connection-1",
  });
  const client = createClient(
    GatewayControlService,
    createRouterTransport((router) => router.service(GatewayControlService, service)),
  );
  connector = new HermesNodeConnector(new IntegrationHermes(), {
    nodeId: "node-1",
    agentId: "agent-1",
    nodeDisplayName: "Node",
    agentDisplayName: "Hermes",
  });
  await connector.initialize();

  await connector
    .run(client, "synthetic-node-token", abortController.signal)
    .catch(() => undefined);

  assert.equal(facts.registrations, 1);
  assert.equal(facts.acknowledgements, 1);
  assert.deepEqual(facts.eventTypes, [
    AgentEventType.MESSAGE_COMPLETED,
    AgentEventType.REQUEST_COMPLETED,
  ]);
});

function domainEvent(
  run: HermesRun,
  sequence: number,
  type: AgentEvent["type"],
  payload: unknown,
): AgentEvent {
  return {
    eventId: `integration-event-${sequence}`,
    connectionId: "hermes-connection-1",
    requestId: run.requestId,
    sequence,
    occurredAt: "2026-07-26T00:00:00.000Z",
    type,
    payload,
  };
}
