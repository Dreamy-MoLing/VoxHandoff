import assert from "node:assert/strict";
import test from "node:test";

import { create } from "@bufbuild/protobuf";
import { Code, ConnectError, createClient, createRouterTransport } from "@connectrpc/connect";
import { createGrpcTransport } from "@connectrpc/connect-node";
import {
  AgentCapabilitiesSchema,
  ComponentRole,
  ConnectClientRequestSchema,
  ConnectNodeRequestSchema,
  GatewayControlService,
  HandshakeOfferSchema,
  type HandshakeOffer,
} from "@agent-talk/protocol";

import {
  createGatewayControlService,
  type AuthenticatedPrincipal,
  type GatewayControlServiceOptions,
  type GatewayStreamHandlers,
  type StreamIdentityVerifier,
} from "./control-service.js";
import { startGatewayServer } from "./server.js";
import { BoundedLiveEventHub } from "./live-events.js";

class FakeVerifier implements StreamIdentityVerifier {
  authenticateCount = 0;
  revalidateCount = 0;
  revokeAfter: number | undefined;

  constructor(private readonly principals: Record<AuthenticatedPrincipal["role"], AuthenticatedPrincipal>) {}

  async authenticate(headers: Headers, expectedRole: AuthenticatedPrincipal["role"]): Promise<AuthenticatedPrincipal> {
    this.authenticateCount += 1;
    if (headers.get("authorization") !== `Bearer ${expectedRole}-token`) {
      throw new ConnectError("Authentication required.", Code.Unauthenticated);
    }
    return this.principals[expectedRole];
  }

  async revalidate(): Promise<void> {
    this.revalidateCount += 1;
    if (this.revokeAfter !== undefined && this.revalidateCount >= this.revokeAfter) {
      throw new ConnectError("The authenticated principal was revoked.", Code.PermissionDenied);
    }
  }
}

function offer(role: ComponentRole, attachments = false): HandshakeOffer {
  return create(HandshakeOfferSchema, {
    currentProtocol: { major: 1, minor: 0 },
    acceptedProtocols: { major: 1, minimumMinor: 0, maximumMinor: 0 },
    schemaBuild: "client-test-build",
    schemaSha256: "a".repeat(64),
    componentVersion: "0.1.0-test",
    componentRole: role,
    capabilityRevision: "client-cap-1",
    capabilities: create(AgentCapabilitiesSchema, { attachments }),
    scopes: [],
  });
}

function setup(liveEvents?: BoundedLiveEventHub) {
  const verifier = new FakeVerifier({
    client: { principalId: "device-1", role: "client", scopes: ["observe", "send"] },
    node: { principalId: "node-1", role: "node", scopes: ["node:connect"] },
  });
  const calls = {
    clientCommands: 0,
    clientAcks: 0,
    registrations: 0,
    dispatchAcks: 0,
    nodeEvents: 0,
  };
  const handlers: GatewayStreamHandlers = {
    async onClientCommand(command, context) {
      calls.clientCommands += 1;
      assert.equal(context.principal.principalId, "device-1");
      assert.equal(context.connectionId, "connection-1");
      return [{
        body: {
          case: "requestStatus",
          value: {
            requestId: command.requestId,
            conversationId: command.conversationId,
            state: "accepted",
            nodeId: "node-1",
            agentId: "agent-1",
            capabilityRevision: "cap-1",
            acceptedSequence: 1n,
          },
        },
      }];
    },
    async onClientAck() {
      calls.clientAcks += 1;
    },
    async onNodeRegistration() {
      calls.registrations += 1;
      return [];
    },
    async onNodeHeartbeat() {
      return [];
    },
    async onNodeDispatchAck() {
      calls.dispatchAcks += 1;
    },
    async onNodeEvent() {
      calls.nodeEvents += 1;
    },
  };
  let nextConnection = 0;
  const options: GatewayControlServiceOptions = {
    identityVerifier: verifier,
    handlers,
    handshake: {
      schemaBuild: "gateway-test-build",
      schemaSha256: "b".repeat(64),
      componentVersion: "0.1.0-test",
      capabilityRevision: "gateway-cap-1",
      capabilities: create(AgentCapabilitiesSchema, { attachments: false, eventStream: true }),
    },
    newConnectionId: () => `connection-${++nextConnection}`,
    ...(liveEvents === undefined ? {} : { liveEvents }),
  };
  const service = createGatewayControlService(options);
  const transport = createRouterTransport((router) => router.service(GatewayControlService, service));
  return { verifier, calls, service, client: createClient(GatewayControlService, transport) };
}

test("streams committed live events after handshake and revalidates outbound delivery", async () => {
  const hub = new BoundedLiveEventHub();
  const { client, verifier } = setup(hub);
  let closeRequests!: () => void;
  const keepOpen = new Promise<void>((resolve) => { closeRequests = resolve; });
  async function* requests() {
    yield create(ConnectClientRequestSchema, {
      body: { case: "handshake", value: offer(ComponentRole.CLIENT) },
    });
    await keepOpen;
  }

  const responses = client.connectClient(requests(), {
    headers: new Headers({ authorization: "Bearer client-token" }),
  })[Symbol.asyncIterator]();
  assert.equal((await responses.next()).value?.body.case, "handshake");
  await new Promise<void>((resolve) => setImmediate(resolve));
  hub.publish({
    body: {
      case: "event",
      value: { eventId: "live-event-1", conversationId: "conversation-1", sequence: 1n },
    },
  });
  const live = await responses.next();
  assert.equal(live.value?.body.case, "event");
  assert.equal(live.value?.body.case === "event" ? live.value.body.value.eventId : undefined, "live-event-1");
  assert.equal(verifier.revalidateCount, 2);
  closeRequests();
  assert.equal((await responses.next()).done, true);
});

test("gates Client business messages behind handshake and revalidates every frame", async () => {
  const { client, verifier, calls } = setup();
  async function* requests() {
    yield create(ConnectClientRequestSchema, {
      body: { case: "heartbeat", value: { lastReceivedSequence: 0n } },
    });
    yield create(ConnectClientRequestSchema, {
      body: { case: "handshake", value: offer(ComponentRole.CLIENT) },
    });
    yield create(ConnectClientRequestSchema, {
      body: { case: "heartbeat", value: { lastReceivedSequence: 3n } },
    });
    yield create(ConnectClientRequestSchema, {
      body: {
        case: "command",
        value: {
          requestId: "request-1",
          commandId: "command-1",
          idempotencyKey: "idempotency-1",
          conversationId: "conversation-1",
          leaseId: "lease-1",
          leaseRevision: 1n,
          command: {
            case: "send",
            value: {
              agentId: "agent-1",
              nodeId: "node-1",
              confirmedText: "confirmed",
              capabilityRevision: "cap-1",
            },
          },
        },
      },
    });
  }

  const responses = [];
  for await (const response of client.connectClient(requests(), {
    headers: new Headers({ authorization: "Bearer client-token" }),
  })) {
    responses.push(response);
  }

  assert.deepEqual(
    responses.map((response) => response.body.case),
    ["heartbeat", "handshake", "heartbeat", "requestStatus"],
  );
  const acceptedHandshake = responses[1]?.body;
  assert.equal(acceptedHandshake?.case, "handshake");
  if (acceptedHandshake?.case === "handshake") {
    assert.equal(acceptedHandshake.value.connectionId, "connection-1");
    assert.deepEqual(acceptedHandshake.value.scopes, ["observe", "send"]);
    assert.equal(acceptedHandshake.value.componentRole, ComponentRole.GATEWAY);
  }
  assert.equal(verifier.authenticateCount, 1);
  assert.equal(verifier.revalidateCount, 4);
  assert.equal(calls.clientCommands, 1);
});

test("rejects a Client command before handshake", async () => {
  const { client, calls } = setup();
  async function* requests() {
    yield create(ConnectClientRequestSchema, {
      body: {
        case: "command",
        value: { requestId: "request-1", commandId: "command-1", idempotencyKey: "idempotency-1" },
      },
    });
  }

  await assert.rejects(
    async () => {
      for await (const _ of client.connectClient(requests(), {
        headers: new Headers({ authorization: "Bearer client-token" }),
      })) {
        // No response is expected.
      }
    },
    (error: unknown) => error instanceof ConnectError && error.code === Code.InvalidArgument,
  );
  assert.equal(calls.clientCommands, 0);
});

test("rejects role confusion and attachments during handshake", async () => {
  for (const invalidOffer of [offer(ComponentRole.NODE), offer(ComponentRole.CLIENT, true)]) {
    const { client } = setup();
    async function* requests() {
      yield create(ConnectClientRequestSchema, { body: { case: "handshake", value: invalidOffer } });
    }
    await assert.rejects(
      async () => {
        for await (const _ of client.connectClient(requests(), {
          headers: new Headers({ authorization: "Bearer client-token" }),
        })) {
          // No response is expected.
        }
      },
      (error: unknown) => error instanceof ConnectError,
    );
  }
});

test("closes an established stream when device revalidation reports revocation", async () => {
  const { client, verifier } = setup();
  verifier.revokeAfter = 2;
  async function* requests() {
    yield create(ConnectClientRequestSchema, {
      body: { case: "handshake", value: offer(ComponentRole.CLIENT) },
    });
    yield create(ConnectClientRequestSchema, {
      body: { case: "heartbeat", value: { lastReceivedSequence: 0n } },
    });
  }

  const cases: Array<string | undefined> = [];
  await assert.rejects(
    async () => {
      for await (const response of client.connectClient(requests(), {
        headers: new Headers({ authorization: "Bearer client-token" }),
      })) {
        cases.push(response.body.case);
      }
    },
    (error: unknown) => error instanceof ConnectError && error.code === Code.PermissionDenied,
  );
  assert.deepEqual(cases, ["handshake"]);
});

test("binds Node registration to the authenticated opaque node identity", async () => {
  const { client, calls } = setup();
  async function* requests() {
    yield create(ConnectNodeRequestSchema, {
      body: { case: "handshake", value: offer(ComponentRole.NODE) },
    });
    yield create(ConnectNodeRequestSchema, {
      body: {
        case: "registration",
        value: {
          node: { nodeId: "node-1", displayName: "display only", platform: "linux", version: "test" },
          agents: [],
        },
      },
    });
  }

  const responses = [];
  for await (const response of client.connectNode(requests(), {
    headers: new Headers({ authorization: "Bearer node-token" }),
  })) {
    responses.push(response.body.case);
  }
  assert.deepEqual(responses, ["handshake"]);
  assert.equal(calls.registrations, 1);
});

test("rejects Node business frames until the authenticated Node registers", async () => {
  const { client, calls } = setup();
  async function* requests() {
    yield create(ConnectNodeRequestSchema, {
      body: { case: "handshake", value: offer(ComponentRole.NODE) },
    });
    yield create(ConnectNodeRequestSchema, {
      body: {
        case: "dispatchAck",
        value: { dispatchId: "dispatch-1", requestId: "request-1", accepted: true },
      },
    });
  }
  await assert.rejects(
    async () => {
      for await (const _ of client.connectNode(requests(), {
        headers: new Headers({ authorization: "Bearer node-token" }),
      })) {
        // The handshake succeeds before the unregistered business frame is rejected.
      }
    },
    (error: unknown) => error instanceof ConnectError && error.code === Code.InvalidArgument,
  );
  assert.equal(calls.dispatchAcks, 0);
});

test("serves the same handshake over real loopback HTTP/2 gRPC", {
  skip:
    process.env.AGENT_TALK_LOOPBACK_INTEGRATION === "1"
      ? false
      : "set AGENT_TALK_LOOPBACK_INTEGRATION=1 for explicit socket integration",
}, async () => {
  const { service } = setup();
  const running = await startGatewayServer({
    controlService: service,
    host: "127.0.0.1",
    port: 0,
    allowInsecureLoopbackForTests: true,
  });
  try {
    const transport = createGrpcTransport({
      baseUrl: `http://127.0.0.1:${running.address.port}`,
      defaultTimeoutMs: 5_000,
      idleConnectionTimeoutMs: 10,
    });
    const client = createClient(GatewayControlService, transport);
    async function* requests() {
      yield create(ConnectClientRequestSchema, {
        body: { case: "handshake", value: offer(ComponentRole.CLIENT) },
      });
      yield create(ConnectClientRequestSchema, {
        body: { case: "heartbeat", value: { lastReceivedSequence: 4n } },
      });
    }
    const responses = [];
    for await (const response of client.connectClient(requests(), {
      headers: new Headers({ authorization: "Bearer client-token" }),
    })) {
      responses.push(response.body.case);
    }
    assert.deepEqual(responses, ["handshake", "heartbeat"]);
  } finally {
    await running.close();
  }
});

test("refuses insecure non-loopback or implicit test listeners", async () => {
  const { service } = setup();
  await assert.rejects(
    startGatewayServer({ controlService: service, host: "127.0.0.1", port: 0 }),
    /restricted to explicit literal loopback/u,
  );
  await assert.rejects(
    startGatewayServer({
      controlService: service,
      host: "0.0.0.0",
      port: 0,
      allowInsecureLoopbackForTests: true,
    }),
    /restricted to explicit literal loopback/u,
  );
});
