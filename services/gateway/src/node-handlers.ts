import { toJson, type MessageInitShape } from "@bufbuild/protobuf";
import { timestampDate } from "@bufbuild/protobuf/wkt";
import { Code, ConnectError } from "@connectrpc/connect";
import {
  AgentCapabilitiesSchema,
  AgentEventType,
  ConnectNodeResponseSchema,
  FailureCategory,
  FailureStage,
  type DispatchAck,
  type EventEnvelope,
  type NodeRegistration,
} from "@agent-talk/protocol";

import type { NodeMessageContext } from "./control-service.js";
import {
  NodeLedgerError,
  type NodeLedger,
  type NodeRegistrationRecord,
  type StoredFailure,
} from "./node-ledger.js";
import type { NodeStreamDelegate } from "./ledger-handlers.js";

type NodeResponseInit = MessageInitShape<typeof ConnectNodeResponseSchema>;

export interface NodeHandlerDependencies {
  now(): Date;
  dispatchBatchSize?: number;
}

const failureStages: Readonly<Record<number, string>> = {
  [FailureStage.RECORDING]: "recording",
  [FailureStage.STT]: "stt",
  [FailureStage.CONNECTION]: "connection",
  [FailureStage.AUTHENTICATION]: "authentication",
  [FailureStage.AUTHORIZATION]: "authorization",
  [FailureStage.PROTOCOL]: "protocol",
  [FailureStage.AGENT]: "agent",
  [FailureStage.SUMMARY]: "summary",
  [FailureStage.TTS]: "tts",
  [FailureStage.PLAYBACK]: "playback",
  [FailureStage.STORAGE]: "storage",
  [FailureStage.SYNC]: "sync",
  [FailureStage.CONFIGURATION]: "configuration",
};

const failureCategories: Readonly<Record<number, string>> = {
  [FailureCategory.VALIDATION]: "validation",
  [FailureCategory.UNAVAILABLE]: "unavailable",
  [FailureCategory.AUTHENTICATION]: "authentication",
  [FailureCategory.AUTHORIZATION]: "authorization",
  [FailureCategory.PROTOCOL]: "protocol",
  [FailureCategory.TIMEOUT]: "timeout",
  [FailureCategory.RATE_LIMIT]: "rate_limit",
  [FailureCategory.UPSTREAM]: "upstream",
  [FailureCategory.STORAGE]: "storage",
  [FailureCategory.PRIVACY]: "privacy",
  [FailureCategory.UNKNOWN]: "unknown",
};

const eventTypeNames: Readonly<Record<number, string>> = {
  [AgentEventType.CONNECTION_READY]: "connection.ready",
  [AgentEventType.CONNECTION_LOST]: "connection.lost",
  [AgentEventType.AGENT_WORKING]: "agent.working",
  [AgentEventType.REQUEST_INTERRUPTING]: "request.interrupting",
  [AgentEventType.MESSAGE_DELTA]: "message.delta",
  [AgentEventType.MESSAGE_COMPLETED]: "message.completed",
  [AgentEventType.TOOL_STARTED]: "tool.started",
  [AgentEventType.TOOL_COMPLETED]: "tool.completed",
  [AgentEventType.TOOL_FAILED]: "tool.failed",
  [AgentEventType.APPROVAL_REQUIRED]: "approval.required",
  [AgentEventType.APPROVAL_RESOLVED]: "approval.resolved",
  [AgentEventType.APPROVAL_EXPIRED]: "approval.expired",
  [AgentEventType.APPROVAL_CANCELLED]: "approval.cancelled",
  [AgentEventType.CLARIFICATION_REQUIRED]: "clarification.required",
  [AgentEventType.CLARIFICATION_RESOLVED]: "clarification.resolved",
  [AgentEventType.CLARIFICATION_EXPIRED]: "clarification.expired",
  [AgentEventType.CLARIFICATION_CANCELLED]: "clarification.cancelled",
  [AgentEventType.REQUEST_COMPLETED]: "request.completed",
  [AgentEventType.REQUEST_FAILED]: "request.failed",
  [AgentEventType.REQUEST_CANCELLED]: "request.cancelled",
  [AgentEventType.REQUEST_INTERRUPTED]: "request.interrupted",
};

function invalid(message: string): never {
  throw new ConnectError(message, Code.InvalidArgument);
}

function requireOpaqueId(value: string, field: string): void {
  if (value.length === 0 || value.length > 256 || /\s/u.test(value)) {
    invalid(`${field} must be a non-empty opaque identifier.`);
  }
}

function requireDisplayValue(value: string, field: string): void {
  if (value.length === 0 || value.length > 256) {
    invalid(`${field} must be between 1 and 256 characters.`);
  }
}

function storedFailure(
  failure: { stage: FailureStage; category: FailureCategory; code: string; safeMessage: string; retryable: boolean },
): StoredFailure {
  const stage = failureStages[failure.stage];
  const category = failureCategories[failure.category];
  if (stage === undefined || category === undefined || failure.code.length === 0 || failure.safeMessage.length === 0) {
    invalid("The Node failure classification is incomplete or unsupported.");
  }
  return { stage, category, code: failure.code, safeMessage: failure.safeMessage, retryable: failure.retryable };
}

function normalizeRegistration(
  registration: NodeRegistration,
  expectedNodeId: string,
  connectionId: string,
): NodeRegistrationRecord {
  const node = registration.node;
  if (node === undefined || node.nodeId !== expectedNodeId) {
    invalid("Node registration does not match the authenticated Node identity.");
  }
  requireOpaqueId(node.nodeId, "nodeId");
  requireDisplayValue(node.displayName, "node displayName");
  requireDisplayValue(node.platform, "node platform");
  requireDisplayValue(node.version, "node version");

  const seen = new Set<string>();
  const agents = registration.agents.map((agent) => {
    requireOpaqueId(agent.agentId, "agentId");
    if (seen.has(agent.agentId)) {
      invalid("Node registration contains a duplicate Agent identity.");
    }
    seen.add(agent.agentId);
    requireDisplayValue(agent.displayName, "agent displayName");
    requireDisplayValue(agent.adapter, "agent adapter");
    requireDisplayValue(agent.version, "agent version");
    requireOpaqueId(agent.capabilityRevision, "capabilityRevision");
    const capabilities = agent.capabilities;
    if (capabilities === undefined) {
      invalid("Agent capabilities are required.");
    }
    if (capabilities.attachments) {
      invalid("Attachments must remain disabled through M5.");
    }
    return {
      agentId: agent.agentId,
      displayName: agent.displayName,
      adapter: agent.adapter,
      version: agent.version,
      capabilityRevision: agent.capabilityRevision,
      capabilities: toJson(AgentCapabilitiesSchema, capabilities),
      maxRequestBytes: capabilities.maxRequestBytes ?? null,
    };
  });
  return {
    nodeId: node.nodeId,
    connectionId,
    displayName: node.displayName,
    platform: node.platform,
    version: node.version,
    agents,
  };
}

function requestState(type: AgentEventType): "working" | "completed" | "failed" | "cancelled" | "interrupted" | null {
  switch (type) {
    case AgentEventType.AGENT_WORKING:
      return "working";
    case AgentEventType.REQUEST_COMPLETED:
      return "completed";
    case AgentEventType.REQUEST_FAILED:
      return "failed";
    case AgentEventType.REQUEST_CANCELLED:
      return "cancelled";
    case AgentEventType.REQUEST_INTERRUPTED:
      return "interrupted";
    default:
      return null;
  }
}

function normalizePayload(event: NonNullable<EventEnvelope["event"]>): { safePayload: unknown; failure: StoredFailure | null } {
  const payload = event.payload;
  switch (event.type) {
    case AgentEventType.CONNECTION_READY:
    case AgentEventType.CONNECTION_LOST:
      if (payload.case !== "connection") invalid("Connection event payload is required.");
      return { safePayload: { safeMessage: payload.value.safeMessage }, failure: null };
    case AgentEventType.AGENT_WORKING:
    case AgentEventType.REQUEST_INTERRUPTING:
      if (payload.case !== "requestProgress") invalid("Request progress payload is required.");
      return { safePayload: { safeMessage: payload.value.safeMessage }, failure: null };
    case AgentEventType.MESSAGE_DELTA:
    case AgentEventType.MESSAGE_COMPLETED:
      if (payload.case !== "message") invalid("Message payload is required.");
      return { safePayload: { text: payload.value.text, revision: payload.value.revision.toString() }, failure: null };
    case AgentEventType.TOOL_STARTED:
    case AgentEventType.TOOL_COMPLETED:
    case AgentEventType.TOOL_FAILED:
      if (payload.case !== "tool") invalid("Tool payload is required.");
      return {
        safePayload: {
          toolName: payload.value.toolName,
          stage: payload.value.stage,
          safeSummary: payload.value.safeSummary,
        },
        failure: null,
      };
    case AgentEventType.APPROVAL_REQUIRED:
    case AgentEventType.APPROVAL_RESOLVED:
    case AgentEventType.APPROVAL_EXPIRED:
    case AgentEventType.APPROVAL_CANCELLED:
      if (payload.case !== "approval") invalid("Approval payload is required.");
      return {
        safePayload: {
          approvalId: payload.value.approvalId,
          safeSummary: payload.value.safeSummary,
          operationSummarySha256: payload.value.operationSummarySha256,
          expiresAt: payload.value.expiresAt === undefined ? null : timestampDate(payload.value.expiresAt).toISOString(),
        },
        failure: null,
      };
    case AgentEventType.CLARIFICATION_REQUIRED:
    case AgentEventType.CLARIFICATION_RESOLVED:
    case AgentEventType.CLARIFICATION_EXPIRED:
    case AgentEventType.CLARIFICATION_CANCELLED:
      if (payload.case !== "clarification") invalid("Clarification payload is required.");
      return {
        safePayload: {
          clarificationId: payload.value.clarificationId,
          safePrompt: payload.value.safePrompt,
          expiresAt: payload.value.expiresAt === undefined ? null : timestampDate(payload.value.expiresAt).toISOString(),
        },
        failure: null,
      };
    case AgentEventType.REQUEST_COMPLETED:
    case AgentEventType.REQUEST_FAILED:
    case AgentEventType.REQUEST_CANCELLED:
    case AgentEventType.REQUEST_INTERRUPTED: {
      if (payload.case !== "requestTerminal") invalid("Request terminal payload is required.");
      const failure = payload.value.failure === undefined ? null : storedFailure(payload.value.failure);
      if (event.type === AgentEventType.REQUEST_FAILED && failure === null) {
        invalid("A failed request event must include a safe failure.");
      }
      if (event.type !== AgentEventType.REQUEST_FAILED && failure !== null) {
        invalid("Only a failed request event may include a failure.");
      }
      return { safePayload: failure === null ? {} : { failure }, failure };
    }
    default:
      invalid("The Node event type is unsupported or owned by the Gateway.");
  }
}

function mapLedgerError(error: NodeLedgerError): ConnectError {
  const code = error.code === "node_revoked" ? Code.PermissionDenied : Code.FailedPrecondition;
  return new ConnectError(error.message, code);
}

export class LedgerBackedNodeHandlers implements NodeStreamDelegate {
  constructor(
    private readonly ledger: NodeLedger,
    private readonly dependencies: NodeHandlerDependencies,
  ) {}

  async onRegistration(registration: NodeRegistration, context: NodeMessageContext): Promise<readonly NodeResponseInit[]> {
    if (!context.principal.scopes.includes("node:connect")) {
      throw new ConnectError("The Node principal cannot register.", Code.PermissionDenied);
    }
    try {
      await this.ledger.registerNode(
        normalizeRegistration(registration, context.principal.principalId, context.connectionId),
        this.dependencies.now(),
      );
      return this.claim(context);
    } catch (error) {
      if (error instanceof NodeLedgerError) throw mapLedgerError(error);
      throw error;
    }
  }

  async onHeartbeat(context: NodeMessageContext): Promise<readonly NodeResponseInit[]> {
    return this.claim(context);
  }

  async onDispatchAck(ack: DispatchAck, context: NodeMessageContext): Promise<void> {
    requireOpaqueId(ack.dispatchId, "dispatchId");
    requireOpaqueId(ack.requestId, "requestId");
    const failure = ack.failure === undefined ? null : storedFailure(ack.failure);
    try {
      await this.ledger.acknowledgeDispatch({
        nodeId: context.principal.principalId,
        connectionId: context.connectionId,
        dispatchId: ack.dispatchId,
        requestId: ack.requestId,
        accepted: ack.accepted,
        failure,
        occurredAt: this.dependencies.now(),
      });
    } catch (error) {
      if (error instanceof NodeLedgerError) throw mapLedgerError(error);
      throw error;
    }
  }

  async onEvent(envelope: EventEnvelope, context: NodeMessageContext): Promise<void> {
    requireOpaqueId(envelope.eventId, "eventId");
    requireOpaqueId(envelope.requestId, "requestId");
    requireOpaqueId(envelope.conversationId, "conversationId");
    if (envelope.sessionId.length > 0) requireOpaqueId(envelope.sessionId, "sessionId");
    if (envelope.protocol?.major !== 1 || envelope.sequence === 0n) {
      invalid("Node events must use protocol major 1 and a positive source sequence.");
    }
    const event = envelope.event;
    if (event === undefined) invalid("Node event payload is required.");
    const eventType = eventTypeNames[event.type];
    if (eventType === undefined) invalid("The Node event type is unsupported or owned by the Gateway.");
    const normalized = normalizePayload(event);
    try {
      await this.ledger.ingestNodeEvent({
        eventId: envelope.eventId,
        nodeId: context.principal.principalId,
        connectionId: context.connectionId,
        requestId: envelope.requestId,
        sourceSequence: envelope.sequence,
        conversationId: envelope.conversationId,
        sessionId: envelope.sessionId.length === 0 ? null : envelope.sessionId,
        eventType,
        safePayload: normalized.safePayload,
        requestState: requestState(event.type),
        failure: normalized.failure,
        occurredAt: this.dependencies.now(),
      });
    } catch (error) {
      if (error instanceof NodeLedgerError) throw mapLedgerError(error);
      throw error;
    }
  }

  private async claim(context: NodeMessageContext): Promise<readonly NodeResponseInit[]> {
    const records = await this.ledger.claimDispatches(
      context.principal.principalId,
      context.connectionId,
      this.dependencies.now(),
      this.dependencies.dispatchBatchSize ?? 25,
    );
    return records.map((record) => ({
      body: {
        case: "dispatchRequest",
        value: {
          dispatchId: record.dispatchId,
          requestId: record.requestId,
          idempotencyKey: record.idempotencyKey,
          conversationId: record.conversationId,
          sessionId: record.sessionId ?? "",
          nodeId: record.nodeId,
          agentId: record.agentId,
          capabilityRevision: record.capabilityRevision,
          confirmedText: record.confirmedText,
        },
      },
    }));
  }
}
