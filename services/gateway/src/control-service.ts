import { Code, ConnectError, type HandlerContext, type ServiceImpl } from "@connectrpc/connect";
import type { MessageInitShape } from "@bufbuild/protobuf";
import {
  ComponentRole,
  type ConnectClientRequest,
  type ConnectClientResponse,
  type ConnectNodeRequest,
  type ConnectNodeResponse,
  type ClientCommand,
  type DispatchAck,
  GatewayControlService,
  type HandshakeOffer,
  type NodeRegistration,
  type EventEnvelope,
  type Ack,
  type AgentCapabilities,
  type ProtocolError,
  ConnectClientResponseSchema,
  ConnectNodeResponseSchema,
  HandshakeAcceptedSchema,
  negotiateHandshake,
  currentHandshakePolicy,
} from "@agent-talk/protocol";
import type { ClientLiveEventSource } from "./live-events.js";

type ClientResponseInit = MessageInitShape<typeof ConnectClientResponseSchema>;
type NodeResponseInit = MessageInitShape<typeof ConnectNodeResponseSchema>;
type HandshakeAcceptedInit = MessageInitShape<typeof HandshakeAcceptedSchema>;

export interface AuthenticatedPrincipal {
  principalId: string;
  role: "client" | "node";
  scopes: readonly string[];
}

export interface StreamIdentityVerifier {
  authenticate(headers: Headers, expectedRole: AuthenticatedPrincipal["role"]): Promise<AuthenticatedPrincipal>;
  revalidate(principal: AuthenticatedPrincipal): Promise<void>;
}

export interface ClientCommandContext {
  principal: AuthenticatedPrincipal;
  connectionId: string;
}

export interface NodeMessageContext {
  principal: AuthenticatedPrincipal;
  connectionId: string;
}

export interface GatewayStreamHandlers {
  onClientCommand(command: ClientCommand, context: ClientCommandContext): Promise<readonly ClientResponseInit[]>;
  onClientAck(ack: Ack, context: ClientCommandContext): Promise<void>;
  onNodeRegistration(registration: NodeRegistration, context: NodeMessageContext): Promise<readonly NodeResponseInit[]>;
  onNodeHeartbeat(context: NodeMessageContext): Promise<readonly NodeResponseInit[]>;
  onNodeDispatchAck(ack: DispatchAck, context: NodeMessageContext): Promise<void>;
  onNodeEvent(event: EventEnvelope, context: NodeMessageContext): Promise<void>;
}

export interface GatewayHandshakeIdentity {
  schemaBuild: string;
  schemaSha256: string;
  componentVersion: string;
  capabilityRevision: string;
  capabilities: AgentCapabilities;
}

export interface GatewayControlServiceOptions {
  identityVerifier: StreamIdentityVerifier;
  handlers: GatewayStreamHandlers;
  handshake: GatewayHandshakeIdentity;
  newConnectionId(): string;
  liveEvents?: ClientLiveEventSource;
}

function invalid(message: string): never {
  throw new ConnectError(message, Code.InvalidArgument);
}

function permission(message: string): never {
  throw new ConnectError(message, Code.PermissionDenied);
}

function assertPrincipal(principal: AuthenticatedPrincipal, role: AuthenticatedPrincipal["role"]): void {
  if (principal.role !== role || principal.principalId.length === 0) {
    permission("The authenticated principal cannot open this stream.");
  }
}

function handshakeResponse(
  remote: HandshakeOffer,
  connectionId: string,
  scopes: readonly string[],
  options: GatewayControlServiceOptions,
): HandshakeAcceptedInit {
  const negotiation = negotiateHandshake(remote);
  if (!negotiation.ok) {
    throw new ConnectError(negotiation.error.safeMessage, Code.FailedPrecondition);
  }
  return {
    selectedProtocol: negotiation.selected,
    connectionId,
    schemaBuild: options.handshake.schemaBuild,
    schemaSha256: options.handshake.schemaSha256,
    componentVersion: options.handshake.componentVersion,
    componentRole: ComponentRole.GATEWAY,
    capabilityRevision: options.handshake.capabilityRevision,
    capabilities: options.handshake.capabilities,
    scopes: [...scopes],
  };
}

function validateGatewayIdentity(identity: GatewayHandshakeIdentity): void {
  if (
    identity.schemaBuild.length === 0 ||
    identity.schemaSha256.length === 0 ||
    identity.componentVersion.length === 0 ||
    identity.capabilityRevision.length === 0
  ) {
    throw new Error("Gateway handshake identity is incomplete");
  }
  if (identity.capabilities.attachments) {
    throw new Error("Gateway attachments must remain disabled through M5");
  }
}

function assertRemoteRole(offer: HandshakeOffer, expected: ComponentRole): void {
  if (offer.componentRole !== expected) {
    invalid("The handshake component role does not match this stream.");
  }
}

async function* connectClientRequests(
  requests: AsyncIterable<ConnectClientRequest>,
  context: HandlerContext,
  options: GatewayControlServiceOptions,
  onHandshake?: (principal: AuthenticatedPrincipal) => void,
): AsyncIterable<ClientResponseInit> {
  const principal = await options.identityVerifier.authenticate(context.requestHeader, "client");
  assertPrincipal(principal, "client");
  const connectionId = options.newConnectionId();
  let handshaken = false;

  for await (const request of requests) {
    await options.identityVerifier.revalidate(principal);
    const body = request.body;
    if (!handshaken) {
      if (body.case === "heartbeat") {
        yield { body: { case: "heartbeat", value: body.value } };
        continue;
      }
      if (body.case === "protocolError") {
        return;
      }
      if (body.case !== "handshake") {
        invalid("Handshake is required before Client business messages.");
      }
      assertRemoteRole(body.value, ComponentRole.CLIENT);
      yield {
        body: {
          case: "handshake",
          value: handshakeResponse(body.value, connectionId, principal.scopes, options),
        },
      };
      handshaken = true;
      onHandshake?.(principal);
      continue;
    }

    const commandContext = { principal, connectionId } satisfies ClientCommandContext;
    switch (body.case) {
      case "heartbeat":
        yield { body: { case: "heartbeat", value: body.value } };
        break;
      case "ack":
        await options.handlers.onClientAck(body.value, commandContext);
        break;
      case "command": {
        const responses = await options.handlers.onClientCommand(body.value, commandContext);
        for (const response of responses) {
          yield response;
        }
        break;
      }
      case "protocolError":
        return;
      case "handshake":
        invalid("Handshake cannot be repeated on an established Client stream.");
      default:
        invalid("Client stream message body is missing or unsupported.");
    }
  }
}

class ClientResponseQueue implements AsyncIterable<ClientResponseInit> {
  private readonly values: ClientResponseInit[] = [];
  private waiting: (() => void) | undefined;
  private ended = false;
  private error: unknown;

  constructor(private readonly maximumQueuedResponses = 500) {}

  push(value: ClientResponseInit): boolean {
    if (this.ended) return false;
    if (this.values.length >= this.maximumQueuedResponses) {
      this.fail(new ConnectError(
        "Client response buffer exceeded; reconnect and replay from the durable cursor.",
        Code.ResourceExhausted,
      ));
      return false;
    }
    this.values.push(value);
    this.waiting?.();
    return true;
  }

  finish(): void {
    this.ended = true;
    this.waiting?.();
  }

  fail(error: unknown): void {
    this.error = error;
    this.ended = true;
    this.waiting?.();
  }

  async *[Symbol.asyncIterator](): AsyncIterator<ClientResponseInit> {
    while (true) {
      while (this.values.length > 0) yield this.values.shift()!;
      if (this.ended) {
        if (this.error !== undefined) throw this.error;
        return;
      }
      await new Promise<void>((resolve) => { this.waiting = resolve; });
      this.waiting = undefined;
    }
  }
}

async function* connectClient(
  requests: AsyncIterable<ConnectClientRequest>,
  context: HandlerContext,
  options: GatewayControlServiceOptions,
): AsyncIterable<ClientResponseInit> {
  if (options.liveEvents === undefined) {
    yield* connectClientRequests(requests, context, options);
    return;
  }

  const queue = new ClientResponseQueue();
  let liveIterator: AsyncIterator<ClientResponseInit> | undefined;
  let liveTask: Promise<void> | undefined;
  const startLive = (principal: AuthenticatedPrincipal) => {
    if (liveTask !== undefined) return;
    if (!principal.scopes.some((scope) => ["observe", "send", "interrupt", "approve"].includes(scope))) return;
    liveIterator = options.liveEvents!.subscribe(principal.principalId)[Symbol.asyncIterator]();
    liveTask = (async () => {
      try {
        while (true) {
          const next = await liveIterator!.next();
          if (next.done) return;
          await options.identityVerifier.revalidate(principal);
          if (!queue.push(next.value)) return;
        }
      } catch (error) {
        queue.fail(error);
      }
    })();
  };

  const requestTask = (async () => {
    try {
      for await (const response of connectClientRequests(requests, context, options, startLive)) {
        if (!queue.push(response)) return;
      }
      if (liveIterator?.return !== undefined) await liveIterator.return();
      queue.finish();
    } catch (error) {
      if (liveIterator?.return !== undefined) await liveIterator.return();
      queue.fail(error);
    }
  })();

  try {
    yield* queue;
  } finally {
    if (liveIterator?.return !== undefined) await liveIterator.return();
    await requestTask;
    await liveTask;
  }
}

async function* connectNode(
  requests: AsyncIterable<ConnectNodeRequest>,
  context: HandlerContext,
  options: GatewayControlServiceOptions,
): AsyncIterable<NodeResponseInit> {
  const principal = await options.identityVerifier.authenticate(context.requestHeader, "node");
  assertPrincipal(principal, "node");
  const connectionId = options.newConnectionId();
  let handshaken = false;
  let registered = false;

  for await (const request of requests) {
    await options.identityVerifier.revalidate(principal);
    const body = request.body;
    if (!handshaken) {
      if (body.case === "heartbeat") {
        yield { body: { case: "heartbeat", value: body.value } };
        continue;
      }
      if (body.case === "protocolError") {
        return;
      }
      if (body.case !== "handshake") {
        invalid("Handshake is required before Node business messages.");
      }
      assertRemoteRole(body.value, ComponentRole.NODE);
      yield {
        body: {
          case: "handshake",
          value: handshakeResponse(body.value, connectionId, principal.scopes, options),
        },
      };
      handshaken = true;
      continue;
    }

    const messageContext = { principal, connectionId } satisfies NodeMessageContext;
    switch (body.case) {
      case "heartbeat":
        yield { body: { case: "heartbeat", value: body.value } };
        if (registered) {
          for (const response of await options.handlers.onNodeHeartbeat(messageContext)) {
            yield response;
          }
        }
        break;
      case "registration":
        if (body.value.node?.nodeId !== principal.principalId) {
          permission("Node registration identity does not match the authenticated principal.");
        }
        for (const response of await options.handlers.onNodeRegistration(body.value, messageContext)) {
          yield response;
        }
        registered = true;
        break;
      case "dispatchAck":
        if (!registered) invalid("Node registration is required before dispatch acknowledgement.");
        await options.handlers.onNodeDispatchAck(body.value, messageContext);
        break;
      case "event":
        if (!registered) invalid("Node registration is required before events.");
        await options.handlers.onNodeEvent(body.value, messageContext);
        break;
      case "protocolError":
        return;
      case "handshake":
        invalid("Handshake cannot be repeated on an established Node stream.");
      default:
        invalid("Node stream message body is missing or unsupported.");
    }
  }
}

export function createGatewayControlService(
  options: GatewayControlServiceOptions,
): ServiceImpl<typeof GatewayControlService> {
  validateGatewayIdentity(options.handshake);
  return {
    connectClient: (requests, context) => connectClient(requests, context, options),
    connectNode: (requests, context) => connectNode(requests, context, options),
  };
}

export function gatewayProtocolVersion(): { major: number; minor: number } {
  return { ...currentHandshakePolicy.current };
}

export function protocolErrorResponse(error: ProtocolError): ClientResponseInit {
  return { body: { case: "protocolError", value: error } };
}
