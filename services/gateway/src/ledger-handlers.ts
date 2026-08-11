import { Code, ConnectError } from "@connectrpc/connect";
import { fromJson, type JsonValue, type MessageInitShape } from "@bufbuild/protobuf";
import { timestampFromDate } from "@bufbuild/protobuf/wkt";
import {
  AgentEventType,
  AgentCapabilitiesSchema,
  ConversationDescriptorSchema,
  AgentEventSchema,
  ApprovalDecision,
  FailureCategory,
  FailureStage,
  ConnectClientResponseSchema,
  ConnectNodeResponseSchema,
  type ClientCommand,
  type DispatchAck,
  type EventEnvelope,
  type NodeEventReceipt,
  type NodeRegistration,
  type Ack,
} from "@agent-talk/protocol";

import { acceptRequest, GatewayCommandError } from "./acceptance.js";
import {
  acceptApprovalCommand,
  acceptClarificationCommand,
  acceptInterruptCommand,
  InteractionCommandError,
} from "./interaction-commands.js";
import type { InteractionLedger } from "./interaction-ledger.js";
import type { ClientLedger, GatewayRequestStatusRecord, PersistedEventRecord } from "./client-ledger.js";
import {
  DirectoryLedgerError,
  type DirectoryConversationRecord,
  type DirectoryLedger,
  type GatewayDirectoryRecord,
} from "./directory-ledger.js";
import {
  acquireControlLease,
  type ControlLeaseLedger,
  renewControlLease,
} from "./control-lease.js";
import type {
  ClientCommandContext,
  GatewayStreamHandlers,
  NodeMessageContext,
} from "./control-service.js";
import type { GatewayLedger } from "./ledger.js";

type ClientResponseInit = MessageInitShape<typeof ConnectClientResponseSchema>;
type AgentPayloadInit = NonNullable<MessageInitShape<typeof AgentEventSchema>["payload"]>;

export interface LedgerBackedGatewayStore extends GatewayLedger, ControlLeaseLedger, ClientLedger, InteractionLedger, DirectoryLedger {}

export interface LedgerHandlerDependencies {
  now(): Date;
  newOpaqueId(): string;
  gatewayAudience: string;
}

export interface NodeStreamDelegate {
  onRegistration(registration: NodeRegistration, context: NodeMessageContext): Promise<readonly MessageInitShape<typeof ConnectNodeResponseSchema>[]>;
  onHeartbeat(context: NodeMessageContext): Promise<readonly MessageInitShape<typeof ConnectNodeResponseSchema>[]>;
  onDispatchAck(ack: DispatchAck, context: NodeMessageContext): Promise<void>;
  onEvent(event: EventEnvelope, context: NodeMessageContext): Promise<NodeEventReceipt>;
}

const noNodeDelegate: NodeStreamDelegate = {
  async onRegistration() { return []; },
  async onHeartbeat() { return []; },
  async onDispatchAck() {},
  async onEvent() {
    throw new ConnectError(
      "A durable Node event ledger is required before events can be acknowledged.",
      Code.FailedPrecondition,
    );
  },
};

const eventTypes: Readonly<Record<string, AgentEventType>> = {
  "connection.ready": AgentEventType.CONNECTION_READY,
  "connection.lost": AgentEventType.CONNECTION_LOST,
  "request.accepted": AgentEventType.REQUEST_ACCEPTED,
  "agent.working": AgentEventType.AGENT_WORKING,
  "request.interrupting": AgentEventType.REQUEST_INTERRUPTING,
  "message.delta": AgentEventType.MESSAGE_DELTA,
  "message.completed": AgentEventType.MESSAGE_COMPLETED,
  "tool.started": AgentEventType.TOOL_STARTED,
  "tool.completed": AgentEventType.TOOL_COMPLETED,
  "tool.failed": AgentEventType.TOOL_FAILED,
  "approval.required": AgentEventType.APPROVAL_REQUIRED,
  "approval.resolved": AgentEventType.APPROVAL_RESOLVED,
  "approval.expired": AgentEventType.APPROVAL_EXPIRED,
  "approval.cancelled": AgentEventType.APPROVAL_CANCELLED,
  "clarification.required": AgentEventType.CLARIFICATION_REQUIRED,
  "clarification.resolved": AgentEventType.CLARIFICATION_RESOLVED,
  "clarification.expired": AgentEventType.CLARIFICATION_EXPIRED,
  "clarification.cancelled": AgentEventType.CLARIFICATION_CANCELLED,
  "request.completed": AgentEventType.REQUEST_COMPLETED,
  "request.failed": AgentEventType.REQUEST_FAILED,
  "request.cancelled": AgentEventType.REQUEST_CANCELLED,
  "request.interrupted": AgentEventType.REQUEST_INTERRUPTED,
};

const failureStages: Readonly<Record<string, FailureStage>> = {
  recording: FailureStage.RECORDING,
  stt: FailureStage.STT,
  connection: FailureStage.CONNECTION,
  authentication: FailureStage.AUTHENTICATION,
  authorization: FailureStage.AUTHORIZATION,
  protocol: FailureStage.PROTOCOL,
  agent: FailureStage.AGENT,
  summary: FailureStage.SUMMARY,
  tts: FailureStage.TTS,
  playback: FailureStage.PLAYBACK,
  storage: FailureStage.STORAGE,
  sync: FailureStage.SYNC,
  configuration: FailureStage.CONFIGURATION,
};

const failureCategories: Readonly<Record<string, FailureCategory>> = {
  validation: FailureCategory.VALIDATION,
  unavailable: FailureCategory.UNAVAILABLE,
  authentication: FailureCategory.AUTHENTICATION,
  authorization: FailureCategory.AUTHORIZATION,
  protocol: FailureCategory.PROTOCOL,
  timeout: FailureCategory.TIMEOUT,
  rate_limit: FailureCategory.RATE_LIMIT,
  upstream: FailureCategory.UPSTREAM,
  storage: FailureCategory.STORAGE,
  privacy: FailureCategory.PRIVACY,
  unknown: FailureCategory.UNKNOWN,
};

function requireObserveOrControl(context: ClientCommandContext): void {
  if (!context.principal.scopes.some((scope) => ["observe", "send", "interrupt", "approve"].includes(scope))) {
    throw new ConnectError("The device cannot observe this conversation.", Code.PermissionDenied);
  }
}

function requireSend(context: ClientCommandContext): void {
  if (!context.principal.scopes.includes("send")) {
    throw new ConnectError("The device cannot create conversations.", Code.PermissionDenied);
  }
}

function requireOpaque(value: string, label: string): void {
  if (value.length === 0 || value.length > 256 || /[\u0000-\u001f\u007f\s]/u.test(value)) {
    throw new ConnectError(`${label} is invalid.`, Code.InvalidArgument);
  }
}

function conversationValue(record: DirectoryConversationRecord): MessageInitShape<typeof ConversationDescriptorSchema> {
  return {
    conversationId: record.conversationId,
    title: record.title,
    nodeId: record.nodeId,
    agentId: record.agentId,
    capabilityRevision: record.capabilityRevision,
    sessionId: record.sessionId ?? "",
    revision: record.revision,
    lastSequence: record.lastSequence,
  };
}

function conversationResponse(record: DirectoryConversationRecord): ClientResponseInit {
  return { body: { case: "conversation", value: conversationValue(record) } };
}

function directoryResponse(commandId: string, record: GatewayDirectoryRecord): ClientResponseInit {
  return {
    body: {
      case: "directory",
      value: {
        commandId,
        nodes: record.nodes.map((node) => ({
          nodeId: node.nodeId,
          displayName: node.displayName,
          platform: node.platform,
          version: node.version,
        })),
        agents: record.agents.map((agent) => ({
          agentId: agent.agentId,
          nodeId: agent.nodeId,
          displayName: agent.displayName,
          adapter: agent.adapter,
          version: agent.version,
          capabilityRevision: agent.capabilityRevision,
          capabilities: fromJson(AgentCapabilitiesSchema, agent.capabilities as JsonValue),
        })),
        conversations: record.conversations.map(conversationValue),
      },
    },
  };
}

function toConnectError(error: GatewayCommandError): ConnectError {
  const code =
    error.category === "authorization"
      ? Code.PermissionDenied
      : error.category === "validation"
        ? Code.InvalidArgument
        : error.category === "unavailable"
          ? Code.Unavailable
          : error.category === "storage"
            ? Code.NotFound
            : Code.FailedPrecondition;
  return new ConnectError(error.message, code);
}

function interactionConnectError(error: InteractionCommandError): ConnectError {
  const code = error.code === "approval_signature_invalid"
    ? Code.Unauthenticated
    : ["device_not_found", "device_revoked", "scope_missing", "control_lease_lost"].includes(error.code)
    ? Code.PermissionDenied
    : ["invalid_command", "idempotency_conflict", "command_id_conflict"].includes(error.code)
      ? Code.InvalidArgument
      : error.code === "request_not_found" || error.code === "conversation_not_found" ||
          error.code === "approval_not_found" || error.code === "clarification_not_found"
        ? Code.NotFound
        : Code.FailedPrecondition;
  return new ConnectError(error.message, code);
}

function requestStatus(record: GatewayRequestStatusRecord | import("./ledger.js").AcceptedRequestRecord): ClientResponseInit {
  const state = "state" in record ? record.state : "accepted";
  const failure = "failure" in record ? record.failure : null;
  return {
    body: {
      case: "requestStatus",
      value: {
        requestId: record.requestId,
        conversationId: record.conversationId,
        state,
        nodeId: record.nodeId,
        agentId: record.agentId,
        capabilityRevision: record.capabilityRevision,
        acceptedSequence: record.acceptedSequence,
        originDeviceId: record.deviceId,
        sessionId: record.sessionId ?? "",
        failure:
          failure === null
            ? undefined
            : {
                stage: failureStages[failure.stage] ?? FailureStage.UNSPECIFIED,
                category: failureCategories[failure.category] ?? FailureCategory.UNSPECIFIED,
                code: failure.code,
                safeMessage: failure.safeMessage,
                retryable: failure.retryable,
              },
      },
    },
  };
}

function safeObject(value: unknown): Record<string, unknown> | undefined {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : undefined;
}

function safeString(value: Record<string, unknown>, key: string): string | undefined {
  return typeof value[key] === "string" ? value[key] : undefined;
}

function safePayload(record: PersistedEventRecord): AgentPayloadInit | undefined {
  if (record.eventType === "request.accepted") {
    const value = safeObject(record.safePayload);
    return {
      case: "requestProgress",
      value: {
        safeMessage: "Request accepted.",
        confirmedText: value === undefined ? "" : safeString(value, "confirmedText") ?? "",
      },
    };
  }
  const value = safeObject(record.safePayload);
  if (value === undefined) return undefined;

  if (["connection.ready", "connection.lost"].includes(record.eventType)) {
    const safeMessage = safeString(value, "safeMessage");
    return safeMessage === undefined ? undefined : { case: "connection", value: { safeMessage } };
  }
  if (["agent.working", "request.interrupting"].includes(record.eventType)) {
    const safeMessage = safeString(value, "safeMessage");
    return safeMessage === undefined ? undefined : { case: "requestProgress", value: { safeMessage } };
  }
  if (["message.delta", "message.completed"].includes(record.eventType)) {
    const text = safeString(value, "text");
    const revision = safeString(value, "revision");
    return text === undefined || revision === undefined || !/^\d+$/u.test(revision)
      ? undefined
      : { case: "message", value: { text, revision: BigInt(revision) } };
  }
  if (["tool.started", "tool.completed", "tool.failed"].includes(record.eventType)) {
    const toolName = safeString(value, "toolName");
    const stage = safeString(value, "stage");
    const safeSummary = safeString(value, "safeSummary");
    return toolName === undefined || stage === undefined || safeSummary === undefined
      ? undefined
      : { case: "tool", value: { toolName, stage, safeSummary } };
  }
  if (record.eventType.startsWith("approval.")) {
    const approvalId = safeString(value, "approvalId");
    const safeSummary = safeString(value, "safeSummary");
    const operationSummarySha256 = safeString(value, "operationSummarySha256");
    const expiresAtValue = value.expiresAt;
    const expiresAt = typeof expiresAtValue === "string" ? new Date(expiresAtValue) : undefined;
    return approvalId === undefined || safeSummary === undefined || operationSummarySha256 === undefined ||
      expiresAt === undefined || Number.isNaN(expiresAt.getTime())
      ? undefined
      : {
          case: "approval",
          value: { approvalId, safeSummary, operationSummarySha256, expiresAt: timestampFromDate(expiresAt) },
        };
  }
  if (record.eventType.startsWith("clarification.")) {
    const clarificationId = safeString(value, "clarificationId");
    const safePrompt = safeString(value, "safePrompt");
    const expiresAtValue = value.expiresAt;
    const expiresAt = typeof expiresAtValue === "string" ? new Date(expiresAtValue) : undefined;
    return clarificationId === undefined || safePrompt === undefined ||
      expiresAt === undefined || Number.isNaN(expiresAt.getTime())
      ? undefined
      : { case: "clarification", value: { clarificationId, safePrompt, expiresAt: timestampFromDate(expiresAt) } };
  }
  if (["request.completed", "request.cancelled", "request.interrupted"].includes(record.eventType)) {
    return { case: "requestTerminal", value: {} };
  }
  if (record.eventType === "request.failed") {
    const failure = safeObject(value.failure);
    if (failure === undefined) return undefined;
    const stage = safeString(failure, "stage");
    const category = safeString(failure, "category");
    const code = safeString(failure, "code");
    const safeMessage = safeString(failure, "safeMessage");
    const retryable = failure.retryable;
    if (
      stage === undefined || category === undefined || code === undefined || safeMessage === undefined ||
      typeof retryable !== "boolean"
    ) return undefined;
    return {
      case: "requestTerminal",
      value: {
        failure: {
          stage: failureStages[stage] ?? FailureStage.UNSPECIFIED,
          category: failureCategories[category] ?? FailureCategory.UNSPECIFIED,
          code,
          safeMessage,
          retryable,
        },
      },
    };
  }
  return undefined;
}

export function persistedEventResponse(record: PersistedEventRecord): ClientResponseInit {
  const eventType = eventTypes[record.eventType];
  const payload = safePayload(record);
  const supported = eventType !== undefined && payload !== undefined;
  return {
    body: {
      case: "event",
      value: {
        protocol: { major: 1, minor: 0 },
        eventId: record.eventId,
        connectionId: record.connectionId,
        deviceId: record.deviceId,
        conversationId: record.conversationId,
        sessionId: record.sessionId ?? "",
        requestId: record.requestId ?? "",
        sequence: record.sequence,
        occurredAt: timestampFromDate(record.occurredAt),
        event:
          !supported
            ? {
                type: AgentEventType.UNSPECIFIED,
                payload: {
                  case: "unsupported",
                  value: { nativeTypeNumber: 0, safeMessage: "A newer Gateway event requires a protocol upgrade." },
                },
              }
            : {
                type: eventType,
                payload,
              },
      },
    },
  };
}

export class LedgerBackedGatewayHandlers implements GatewayStreamHandlers {
  constructor(
    private readonly store: LedgerBackedGatewayStore,
    private readonly dependencies: LedgerHandlerDependencies,
    private readonly nodeDelegate: NodeStreamDelegate = noNodeDelegate,
  ) {}

  async onClientCommand(command: ClientCommand, context: ClientCommandContext): Promise<readonly ClientResponseInit[]> {
    try {
      switch (command.command.case) {
        case "send": {
          const send = command.command.value;
          const result = await acceptRequest(
            this.store,
            {
              requestId: command.requestId,
              commandId: command.commandId,
              idempotencyKey: command.idempotencyKey,
              deviceId: context.principal.principalId,
              connectionId: context.connectionId,
              conversationId: command.conversationId,
              ...(send.sessionId.length === 0 ? {} : { sessionId: send.sessionId }),
              leaseId: command.leaseId,
              leaseRevision: command.leaseRevision,
              nodeId: send.nodeId,
              agentId: send.agentId,
              capabilityRevision: send.capabilityRevision,
              confirmedText: send.confirmedText,
            },
            this.dependencies,
          );
          return [requestStatus(result.kind === "accepted" ? result.facts.request : result.request)];
        }
        case "interrupt": {
          const interrupt = command.command.value;
          const result = await acceptInterruptCommand(
            this.store,
            {
              commandId: command.commandId,
              idempotencyKey: command.idempotencyKey,
              deviceId: context.principal.principalId,
              connectionId: context.connectionId,
              conversationId: command.conversationId,
              requestId: interrupt.requestId,
              leaseId: command.leaseId,
              leaseRevision: command.leaseRevision,
            },
            this.dependencies,
          );
          return [requestStatus(result.request)];
        }
        case "resolveApproval": {
          const approval = command.command.value;
          if (approval.decision === ApprovalDecision.UNSPECIFIED) {
            throw new ConnectError("Approval decision must be approve or deny.", Code.InvalidArgument);
          }
          const result = await acceptApprovalCommand(
            this.store,
            {
              commandId: command.commandId,
              idempotencyKey: command.idempotencyKey,
              deviceId: context.principal.principalId,
              conversationId: command.conversationId,
              requestId: approval.requestId,
              approvalId: approval.approvalId,
              leaseId: command.leaseId,
              leaseRevision: command.leaseRevision,
              decision: approval.decision === ApprovalDecision.APPROVE ? "approved" : "rejected",
              operationSummarySha256: approval.operationSummarySha256,
              credentialId: context.principal.credentialId ?? "",
              gatewayAudience: this.dependencies.gatewayAudience,
              deviceSignature: approval.deviceSignature,
            },
            this.dependencies,
          );
          return [requestStatus(result.request)];
        }
        case "resolveClarification": {
          const clarification = command.command.value;
          const result = await acceptClarificationCommand(
            this.store,
            {
              commandId: command.commandId,
              idempotencyKey: command.idempotencyKey,
              deviceId: context.principal.principalId,
              conversationId: command.conversationId,
              requestId: clarification.requestId,
              clarificationId: clarification.clarificationId,
              leaseId: command.leaseId,
              leaseRevision: command.leaseRevision,
              confirmedText: clarification.confirmedText,
            },
            this.dependencies,
          );
          return [requestStatus(result.request)];
        }
        case "acquireLease": {
          const acquire = command.command.value;
          const change = await acquireControlLease(
            this.store,
            {
              deviceId: context.principal.principalId,
              conversationId: command.conversationId,
              explicitTakeover: acquire.explicitTakeover,
              ...(acquire.expectedLeaseId.length === 0 ? {} : { expectedLeaseId: acquire.expectedLeaseId }),
              ...(acquire.expectedRevision === 0n ? {} : { expectedRevision: acquire.expectedRevision }),
            },
            { ...this.dependencies, durationMs: 30_000 },
          );
          return [{
            body: {
              case: "controlLease",
              value: {
                leaseId: change.lease.leaseId,
                conversationId: change.lease.conversationId,
                deviceId: change.lease.deviceId,
                revision: change.lease.revision,
                expiresAt: timestampFromDate(change.lease.expiresAt),
              },
            },
          }];
        }
        case "renewLease": {
          const renew = command.command.value;
          const change = await renewControlLease(
            this.store,
            {
              deviceId: context.principal.principalId,
              conversationId: command.conversationId,
              leaseId: renew.leaseId,
              expectedRevision: renew.expectedRevision,
            },
            { ...this.dependencies, durationMs: 30_000 },
          );
          return [{
            body: {
              case: "controlLease",
              value: {
                leaseId: change.lease.leaseId,
                conversationId: change.lease.conversationId,
                deviceId: change.lease.deviceId,
                revision: change.lease.revision,
                expiresAt: timestampFromDate(change.lease.expiresAt),
              },
            },
          }];
        }
        case "getRequest": {
          requireObserveOrControl(context);
          const record = await this.store.getRequestStatus(command.command.value.requestId, command.conversationId);
          if (record === undefined) {
            throw new ConnectError("The request was not found in this conversation.", Code.NotFound);
          }
          return [requestStatus(record)];
        }
        case "replay": {
          requireObserveOrControl(context);
          const maximum = command.command.value.maximumEvents;
          if (maximum === 0 || maximum > 500) {
            throw new ConnectError("Replay maximumEvents must be between 1 and 500.", Code.InvalidArgument);
          }
          const events = await this.store.replayEvents(
            command.conversationId,
            command.command.value.afterSequence,
            maximum,
          );
          const throughSequence = events.at(-1)?.sequence ?? command.command.value.afterSequence;
          return [
            ...events.map(persistedEventResponse),
            {
              body: {
                case: "replayCompleted",
                value: {
                  commandId: command.commandId,
                  conversationId: command.conversationId,
                  afterSequence: command.command.value.afterSequence,
                  throughSequence,
                  eventCount: events.length,
                  mayHaveMore: events.length === maximum,
                },
              },
            },
          ];
        }
        case "listDirectory": {
          requireObserveOrControl(context);
          return [directoryResponse(command.commandId, await this.store.listDirectory())];
        }
        case "createConversation": {
          requireSend(context);
          requireOpaque(command.conversationId, "conversationId");
          requireOpaque(command.commandId, "commandId");
          requireOpaque(command.idempotencyKey, "idempotencyKey");
          const create = command.command.value;
          requireOpaque(create.nodeId, "nodeId");
          requireOpaque(create.agentId, "agentId");
          requireOpaque(create.capabilityRevision, "capabilityRevision");
          if (create.sessionId.length > 0) requireOpaque(create.sessionId, "sessionId");
          const title = create.title.trim();
          if (title.length === 0 || Buffer.byteLength(title, "utf8") > 256 || /[\u0000-\u001f\u007f]/u.test(title)) {
            throw new ConnectError("The conversation title is invalid.", Code.InvalidArgument);
          }
          const conversation = await this.store.createConversation({
            conversationId: command.conversationId,
            commandId: command.commandId,
            idempotencyKey: command.idempotencyKey,
            deviceId: context.principal.principalId,
            title,
            nodeId: create.nodeId,
            agentId: create.agentId,
            capabilityRevision: create.capabilityRevision,
            sessionId: create.sessionId.length === 0 ? null : create.sessionId,
            now: this.dependencies.now(),
          });
          return [conversationResponse(conversation)];
        }
        default:
          throw new ConnectError("This Client command is not implemented yet.", Code.Unimplemented);
      }
    } catch (error) {
      if (error instanceof DirectoryLedgerError) {
        const code = error.code === "agent_not_found"
          ? Code.NotFound
          : error.code === "capability_revision_changed"
            ? Code.FailedPrecondition
            : Code.AlreadyExists;
        throw new ConnectError(error.message, code);
      }
      if (error instanceof GatewayCommandError) {
        throw toConnectError(error);
      }
      if (error instanceof InteractionCommandError) {
        throw interactionConnectError(error);
      }
      throw error;
    }
  }

  async onClientAck(ack: Ack, context: ClientCommandContext): Promise<void> {
    requireObserveOrControl(context);
    if (ack.sequence === 0n || ack.eventId.length === 0 || ack.conversationId.length === 0) {
      throw new ConnectError("Ack identity is incomplete.", Code.InvalidArgument);
    }
    const stored = await this.store.acknowledgeEvent(
      context.principal.principalId,
      ack.conversationId,
      ack.sequence,
      ack.eventId,
      this.dependencies.now(),
    );
    if (!stored) {
      throw new ConnectError("Ack does not identify a persisted event.", Code.FailedPrecondition);
    }
  }

  async onNodeRegistration(registration: NodeRegistration, context: NodeMessageContext) {
    return this.nodeDelegate.onRegistration(registration, context);
  }

  async onNodeHeartbeat(context: NodeMessageContext) {
    return this.nodeDelegate.onHeartbeat(context);
  }

  async onNodeDispatchAck(ack: DispatchAck, context: NodeMessageContext): Promise<void> {
    await this.nodeDelegate.onDispatchAck(ack, context);
  }

  async onNodeEvent(event: EventEnvelope, context: NodeMessageContext): Promise<NodeEventReceipt> {
    return await this.nodeDelegate.onEvent(event, context);
  }
}
