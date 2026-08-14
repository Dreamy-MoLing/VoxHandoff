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
} from "@agent-talk/protocol";

import type { GatewayCommandError } from "./acceptance.js";
import type { InteractionCommandError } from "./interaction-commands.js";
import type { ClientCommandContext } from "./control-service.js";
import type { GatewayRequestStatusRecord, PersistedEventRecord } from "./client-ledger.js";
import type {
  DirectoryConversationRecord,
  GatewayDirectoryRecord,
} from "./directory-ledger.js";

type ClientResponseInit = MessageInitShape<typeof ConnectClientResponseSchema>;
type AgentPayloadInit = NonNullable<MessageInitShape<typeof AgentEventSchema>["payload"]>;

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

export function requireObserveOrControl(context: ClientCommandContext): void {
  if (!context.principal.scopes.some((scope) => ["observe", "send", "interrupt", "approve"].includes(scope))) {
    throw new ConnectError("The device cannot observe this conversation.", Code.PermissionDenied);
  }
}
export function requireSend(context: ClientCommandContext): void {
  if (!context.principal.scopes.includes("send")) {
    throw new ConnectError("The device cannot create conversations.", Code.PermissionDenied);
  }
}

export function requireOpaque(value: string, label: string): void {
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

export function conversationResponse(record: DirectoryConversationRecord): ClientResponseInit {
  return { body: { case: "conversation", value: conversationValue(record) } };
}

export function directoryResponse(commandId: string, record: GatewayDirectoryRecord): ClientResponseInit {
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

export function toConnectError(error: GatewayCommandError): ConnectError {
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

export function interactionConnectError(error: InteractionCommandError): ConnectError {
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

export function requestStatus(record: GatewayRequestStatusRecord | import("./ledger.js").AcceptedRequestRecord): ClientResponseInit {
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
