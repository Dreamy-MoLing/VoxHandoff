import assert from "node:assert/strict";

import { create, type MessageInitShape } from "@bufbuild/protobuf";
import { Code, ConnectError, createClient, createRouterTransport, type Client } from "@connectrpc/connect";
import type { Pool } from "pg";
import {
  AgentCapabilitiesSchema,
  AgentEventSchema,
  AgentEventType,
  ComponentRole,
  ConnectClientRequestSchema,
  ConnectNodeRequestSchema,
  EventEnvelopeSchema,
  GatewayControlService,
  HandshakeOfferSchema,
  ProtocolVersionSchema,
  type ConnectClientRequest,
  type ConnectClientResponse,
  type ConnectNodeRequest,
  type ConnectNodeResponse,
  type HandshakeOffer,
} from "@agent-talk/protocol";

import {
  createGatewayControlService,
  type AuthenticatedPrincipal,
  type StreamIdentityVerifier,
} from "./control-service.js";
import { DeviceStreamIdentityVerifier, PostgresDeviceCredentialAuthority } from "./device-identity.js";
import { LedgerBackedGatewayHandlers } from "./ledger-handlers.js";
import { LedgerBackedNodeHandlers } from "./node-handlers.js";
import { PostgresGatewayLedger } from "./postgres-ledger.js";

class InputQueue<T> implements AsyncIterable<T> {
  private readonly values: T[] = [];
  private wake: (() => void) | undefined;
  private ended = false;

  push(value: T): void {
    if (this.ended) throw new Error("cannot push to a finished integration queue");
    this.values.push(value);
    this.wake?.();
  }

  finish(): void {
    this.ended = true;
    this.wake?.();
  }

  async *[Symbol.asyncIterator](): AsyncIterator<T> {
    while (true) {
      while (this.values.length > 0) yield this.values.shift()!;
      if (this.ended) return;
      await new Promise<void>((resolve) => { this.wake = resolve; });
      this.wake = undefined;
    }
  }
}

class ClientAndNodeVerifier implements StreamIdentityVerifier {
  constructor(
    private readonly clientVerifier: DeviceStreamIdentityVerifier,
    private readonly nodeId: string,
  ) {}

  async authenticate(
    headers: Headers,
    expectedRole: AuthenticatedPrincipal["role"],
  ): Promise<AuthenticatedPrincipal> {
    if (expectedRole === "client") return this.clientVerifier.authenticate(headers, expectedRole);
    if (headers.get("authorization") !== "Bearer integration-node-token") {
      throw new Error("integration Node authentication failed");
    }
    return { principalId: this.nodeId, role: "node", scopes: ["node:connect"] };
  }

  async revalidate(principal: AuthenticatedPrincipal): Promise<void> {
    if (principal.role === "client") {
      await this.clientVerifier.revalidate(principal);
      return;
    }
    if (principal.principalId !== this.nodeId || !principal.scopes.includes("node:connect")) {
      throw new Error("integration Node identity changed");
    }
  }
}

function offer(role: ComponentRole): HandshakeOffer {
  return create(HandshakeOfferSchema, {
    currentProtocol: { major: 1, minor: 0 },
    acceptedProtocols: { major: 1, minimumMinor: 0, maximumMinor: 0 },
    schemaBuild: "convergence-fixture",
    schemaSha256: "c".repeat(64),
    componentVersion: "0.1.0-integration",
    componentRole: role,
    capabilityRevision: "convergence-capabilities-1",
    capabilities: create(AgentCapabilitiesSchema, { eventStream: true }),
  });
}

interface FixtureIdentity {
  suffix: string;
  deviceId: string;
  accessToken: string;
  nodeId: string;
  agentId: string;
}

interface FixtureService {
  client: Client<typeof GatewayControlService>;
  ledger: PostgresGatewayLedger;
}

function createFixtureService(
  pool: Pool,
  identity: FixtureIdentity,
  connectionId: () => string,
  opaqueId: () => string,
): FixtureService {
  const now = () => new Date("2030-01-01T00:05:00.000Z");
  const ledger = new PostgresGatewayLedger(pool);
  const nodeHandlers = new LedgerBackedNodeHandlers(ledger, { now, dispatchBatchSize: 10 });
  const handlers = new LedgerBackedGatewayHandlers(
    ledger,
    { now, newOpaqueId: opaqueId, gatewayAudience: "https://gateway.example" },
    nodeHandlers,
  );
  const clientVerifier = new DeviceStreamIdentityVerifier(
    new PostgresDeviceCredentialAuthority(pool),
    { gatewayAudience: "https://gateway.example", now },
  );
  const service = createGatewayControlService({
    identityVerifier: new ClientAndNodeVerifier(clientVerifier, identity.nodeId),
    handlers,
    handshake: {
      schemaBuild: "convergence-gateway",
      schemaSha256: "d".repeat(64),
      componentVersion: "0.1.0-integration",
      capabilityRevision: "gateway-capabilities-1",
      capabilities: create(AgentCapabilitiesSchema, { eventStream: true }),
    },
    newConnectionId: connectionId,
  });
  const transport = createRouterTransport((router) => router.service(GatewayControlService, service));
  return { client: createClient(GatewayControlService, transport), ledger };
}

function clientHeaders(identity: FixtureIdentity): Headers {
  return new Headers({ authorization: `Bearer ${identity.accessToken}` });
}

function nodeHeaders(): Headers {
  return new Headers({ authorization: "Bearer integration-node-token" });
}

function clientHandshake() {
  return create(ConnectClientRequestSchema, {
    body: { case: "handshake", value: offer(ComponentRole.CLIENT) },
  });
}

function nodeHandshake() {
  return create(ConnectNodeRequestSchema, {
    body: { case: "handshake", value: offer(ComponentRole.NODE) },
  });
}

function nodeRegistration(identity: FixtureIdentity) {
  return create(ConnectNodeRequestSchema, {
    body: {
      case: "registration",
      value: {
        node: {
          nodeId: identity.nodeId,
          displayName: "Convergence Node",
          platform: "linux",
          version: "integration",
        },
        agents: [{
          agentId: identity.agentId,
          displayName: "Convergence Agent",
          adapter: "fake",
          version: "integration",
          capabilityRevision: "agent-capabilities-1",
          capabilities: create(AgentCapabilitiesSchema, {
            eventStream: true,
            maxRequestBytes: 4_096n,
          }),
        }],
      },
    },
  });
}

function nodeHeartbeat() {
  return create(ConnectNodeRequestSchema, {
    body: { case: "heartbeat", value: { lastReceivedSequence: 0n } },
  });
}

function nodeEvent(
  requestId: string,
  conversationId: string,
  eventId: string,
  sequence: bigint,
  type: AgentEventType,
  payload: NonNullable<MessageInitShape<typeof AgentEventSchema>["payload"]>,
): ConnectNodeRequest {
  return create(ConnectNodeRequestSchema, {
    body: {
      case: "event",
      value: create(EventEnvelopeSchema, {
        protocol: create(ProtocolVersionSchema, { major: 1, minor: 0 }),
        eventId,
        conversationId,
        requestId,
        sequence,
        event: create(AgentEventSchema, { type, payload }),
      }),
    },
  });
}

async function finishStream<T>(queue: InputQueue<T>, responses: AsyncIterator<unknown>): Promise<void> {
  queue.finish();
  assert.equal((await responses.next()).done, true);
}

export async function runGatewayConvergenceIntegration(
  pool: Pool,
  identity: FixtureIdentity,
): Promise<void> {
  const conversationId = `convergence-conversation-${identity.suffix}`;
  const requestId = `convergence-request-${identity.suffix}`;
  const commandId = `convergence-command-${identity.suffix}`;
  const idempotencyKey = `convergence-idempotency-${identity.suffix}`;
  let nextConnection = 0;
  let nextOpaque = 0;
  const connectionId = () => `convergence-connection-${++nextConnection}-${identity.suffix}`;
  const opaqueId = () => `convergence-generated-${++nextOpaque}-${identity.suffix}`;

  const firstGateway = createFixtureService(pool, identity, connectionId, opaqueId);
  const initialNodeInput = new InputQueue<ConnectNodeRequest>();
  const initialNodeResponses = firstGateway.client.connectNode(initialNodeInput, {
    headers: nodeHeaders(),
  })[Symbol.asyncIterator]();
  initialNodeInput.push(nodeHandshake());
  assert.equal((await initialNodeResponses.next()).value?.body.case, "handshake");
  initialNodeInput.push(nodeRegistration(identity));
  initialNodeInput.push(nodeHeartbeat());
  assert.equal((await initialNodeResponses.next()).value?.body.case, "heartbeat");
  await finishStream(initialNodeInput, initialNodeResponses);

  await pool.query(
    `INSERT INTO agent_talk.conversations (
       conversation_id, created_by_device_id, created_at, updated_at
     ) VALUES ($1, $2, $3, $3)`,
    [conversationId, identity.deviceId, new Date("2030-01-01T00:05:00.000Z")],
  );

  const clientInput = new InputQueue<ConnectClientRequest>();
  const clientResponses = firstGateway.client.connectClient(clientInput, {
    headers: clientHeaders(identity),
  })[Symbol.asyncIterator]();
  clientInput.push(clientHandshake());
  assert.equal((await clientResponses.next()).value?.body.case, "handshake");
  clientInput.push(create(ConnectClientRequestSchema, {
    body: {
      case: "command",
      value: {
        requestId: `lease-request-${identity.suffix}`,
        commandId: `lease-command-${identity.suffix}`,
        idempotencyKey: `lease-idempotency-${identity.suffix}`,
        conversationId,
        command: { case: "acquireLease", value: {} },
      },
    },
  }));
  const leaseBody = (await clientResponses.next()).value?.body;
  assert.equal(leaseBody?.case, "controlLease");
  if (leaseBody?.case !== "controlLease") throw new Error("control lease response is missing");
  const send = create(ConnectClientRequestSchema, {
    body: {
      case: "command",
      value: {
        requestId,
        commandId,
        idempotencyKey,
        conversationId,
        leaseId: leaseBody.value.leaseId,
        leaseRevision: leaseBody.value.revision,
        command: {
          case: "send",
          value: {
            nodeId: identity.nodeId,
            agentId: identity.agentId,
            capabilityRevision: "agent-capabilities-1",
            confirmedText: "Converge this confirmed request exactly once.",
          },
        },
      },
    },
  });
  clientInput.push(send);
  assert.equal((await clientResponses.next()).value?.body.case, "requestStatus");
  await finishStream(clientInput, clientResponses);

  const restartedGateway = createFixtureService(pool, identity, connectionId, opaqueId);
  const retryInput = new InputQueue<ConnectClientRequest>();
  const retryResponses = restartedGateway.client.connectClient(retryInput, {
    headers: clientHeaders(identity),
  })[Symbol.asyncIterator]();
  retryInput.push(clientHandshake());
  assert.equal((await retryResponses.next()).value?.body.case, "handshake");
  retryInput.push(send);
  const retryStatus = (await retryResponses.next()).value?.body;
  assert.equal(retryStatus?.case, "requestStatus");
  assert.equal(retryStatus?.case === "requestStatus" ? retryStatus.value.acceptedSequence : 0n, 1n);
  await finishStream(retryInput, retryResponses);

  let dispatchId = "";
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const nodeInput = new InputQueue<ConnectNodeRequest>();
    const nodeResponses = restartedGateway.client.connectNode(nodeInput, {
      headers: nodeHeaders(),
    })[Symbol.asyncIterator]();
    nodeInput.push(nodeHandshake());
    assert.equal((await nodeResponses.next()).value?.body.case, "handshake");
    nodeInput.push(nodeRegistration(identity));
    const dispatch = (await nodeResponses.next()).value?.body;
    assert.equal(dispatch?.case, "dispatchRequest");
    if (dispatch?.case !== "dispatchRequest") throw new Error("request dispatch is missing");
    if (attempt === 0) dispatchId = dispatch.value.dispatchId;
    assert.equal(dispatch.value.dispatchId, dispatchId);
    assert.equal(dispatch.value.requestId, requestId);
    await finishStream(nodeInput, nodeResponses);
  }

  const processingInput = new InputQueue<ConnectNodeRequest>();
  const processingResponses = restartedGateway.client.connectNode(processingInput, {
    headers: nodeHeaders(),
  })[Symbol.asyncIterator]();
  processingInput.push(nodeHandshake());
  assert.equal((await processingResponses.next()).value?.body.case, "handshake");
  processingInput.push(nodeRegistration(identity));
  assert.equal((await processingResponses.next()).value?.body.case, "dispatchRequest");
  processingInput.push(create(ConnectNodeRequestSchema, {
    body: { case: "dispatchAck", value: { dispatchId, requestId, accepted: true } },
  }));
  const working = nodeEvent(
    requestId,
    conversationId,
    `convergence-event-working-${identity.suffix}`,
    1n,
    AgentEventType.AGENT_WORKING,
    { case: "requestProgress", value: { safeMessage: "Working." } },
  );
  processingInput.push(working);
  processingInput.push(nodeHeartbeat());
  assert.equal((await processingResponses.next()).value?.body.case, "heartbeat");
  processingInput.push(nodeEvent(
    requestId,
    conversationId,
    `convergence-event-stale-${identity.suffix}`,
    1n,
    AgentEventType.AGENT_WORKING,
    { case: "requestProgress", value: { safeMessage: "Stale." } },
  ));
  await assert.rejects(
    processingResponses.next(),
    (error: unknown) => error instanceof ConnectError && error.code === Code.FailedPrecondition,
  );

  const finalGateway = createFixtureService(pool, identity, connectionId, opaqueId);
  const finalNodeInput = new InputQueue<ConnectNodeRequest>();
  const finalNodeResponses = finalGateway.client.connectNode(finalNodeInput, {
    headers: nodeHeaders(),
  })[Symbol.asyncIterator]();
  finalNodeInput.push(nodeHandshake());
  assert.equal((await finalNodeResponses.next()).value?.body.case, "handshake");
  finalNodeInput.push(nodeRegistration(identity));
  finalNodeInput.push(nodeHeartbeat());
  assert.equal((await finalNodeResponses.next()).value?.body.case, "heartbeat");
  finalNodeInput.push(working);
  finalNodeInput.push(nodeEvent(
    requestId,
    conversationId,
    `convergence-event-message-${identity.suffix}`,
    2n,
    AgentEventType.MESSAGE_COMPLETED,
    { case: "message", value: { text: "Complete durable answer.", revision: 1n } },
  ));
  finalNodeInput.push(nodeEvent(
    requestId,
    conversationId,
    `convergence-event-completed-${identity.suffix}`,
    3n,
    AgentEventType.REQUEST_COMPLETED,
    { case: "requestTerminal", value: {} },
  ));
  finalNodeInput.push(nodeHeartbeat());
  assert.equal((await finalNodeResponses.next()).value?.body.case, "heartbeat");
  await finishStream(finalNodeInput, finalNodeResponses);

  const replayInput = new InputQueue<ConnectClientRequest>();
  const replayResponses = finalGateway.client.connectClient(replayInput, {
    headers: clientHeaders(identity),
  })[Symbol.asyncIterator]();
  replayInput.push(clientHandshake());
  assert.equal((await replayResponses.next()).value?.body.case, "handshake");
  replayInput.push(create(ConnectClientRequestSchema, {
    body: {
      case: "command",
      value: {
        requestId: `replay-request-${identity.suffix}`,
        commandId: `replay-command-${identity.suffix}`,
        idempotencyKey: `replay-idempotency-${identity.suffix}`,
        conversationId,
        command: { case: "replay", value: { afterSequence: 0n, maximumEvents: 10 } },
      },
    },
  }));
  const replayed: ConnectClientResponse[] = [];
  for (let index = 0; index < 5; index += 1) {
    const response = await replayResponses.next();
    assert.equal(response.done, false);
    if (response.value !== undefined) replayed.push(response.value);
  }
  assert.deepEqual(
    replayed.map((response) => response.body.case === "event" ? response.body.value.sequence : 0n),
    [1n, 2n, 3n, 4n, 0n],
  );
  assert.equal(replayed[4]?.body.case, "replayCompleted");
  const lastEvent = replayed[3]?.body;
  if (lastEvent?.case !== "event") throw new Error("terminal replay event is missing");
  replayInput.push(create(ConnectClientRequestSchema, {
    body: {
      case: "ack",
      value: {
        conversationId,
        sequence: lastEvent.value.sequence,
        eventId: lastEvent.value.eventId,
      },
    },
  }));
  replayInput.push(create(ConnectClientRequestSchema, {
    body: { case: "heartbeat", value: { lastReceivedSequence: lastEvent.value.sequence } },
  }));
  assert.equal((await replayResponses.next()).value?.body.case, "heartbeat");
  await finishStream(replayInput, replayResponses);

  const facts = await pool.query<{
    request_state: string;
    dispatch_state: string;
    event_count: string;
    source_event_count: string;
    last_sequence: string;
    cursor_sequence: string;
  }>(
    `SELECT r.state AS request_state, d.state AS dispatch_state,
            (SELECT count(*)::text FROM agent_talk.events e WHERE e.request_id = r.request_id) AS event_count,
            (SELECT count(*)::text FROM agent_talk.events e
             WHERE e.request_id = r.request_id AND e.source_sequence IS NOT NULL) AS source_event_count,
            c.last_sequence::text AS last_sequence,
            cursor.sequence::text AS cursor_sequence
     FROM agent_talk.requests r
     JOIN agent_talk.gateway_dispatch_outbox d USING (request_id)
     JOIN agent_talk.conversations c USING (conversation_id)
     JOIN agent_talk.device_cursors cursor
       ON cursor.device_id = r.device_id AND cursor.conversation_id = r.conversation_id
     WHERE r.request_id = $1`,
    [requestId],
  );
  assert.deepEqual(facts.rows[0], {
    request_state: "completed",
    dispatch_state: "delivered",
    event_count: "4",
    source_event_count: "3",
    last_sequence: "4",
    cursor_sequence: "4",
  });
}
