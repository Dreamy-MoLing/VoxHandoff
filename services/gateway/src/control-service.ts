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
  onClientCommand(command: ClientCommand, context: ClientCommandContext): Promise<ClientResponseInit | undefined>;
  onClientAck(ack: Ack, context: ClientCommandContext): Promise<void>;
  onNodeRegistration(registration: NodeRegistration, context: NodeMessageContext): Promise<void>;
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

async function* connectClient(
  requests: AsyncIterable<ConnectClientRequest>,
  context: HandlerContext,
  options: GatewayControlServiceOptions,
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
        const response = await options.handlers.onClientCommand(body.value, commandContext);
        if (response !== undefined) {
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

async function* connectNode(
  requests: AsyncIterable<ConnectNodeRequest>,
  context: HandlerContext,
  options: GatewayControlServiceOptions,
): AsyncIterable<NodeResponseInit> {
  const principal = await options.identityVerifier.authenticate(context.requestHeader, "node");
  assertPrincipal(principal, "node");
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
        break;
      case "registration":
        if (body.value.node?.nodeId !== principal.principalId) {
          permission("Node registration identity does not match the authenticated principal.");
        }
        await options.handlers.onNodeRegistration(body.value, messageContext);
        break;
      case "dispatchAck":
        await options.handlers.onNodeDispatchAck(body.value, messageContext);
        break;
      case "event":
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
