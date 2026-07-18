import { Code, ConnectError } from "@connectrpc/connect";
import type { MessageInitShape } from "@bufbuild/protobuf";
import { timestampFromDate } from "@bufbuild/protobuf/wkt";
import {
  AgentEventType,
  FailureCategory,
  FailureStage,
  ConnectClientResponseSchema,
  type ClientCommand,
  type DispatchAck,
  type EventEnvelope,
  type NodeRegistration,
  type Ack,
} from "@agent-talk/protocol";

import { acceptRequest, GatewayCommandError } from "./acceptance.js";
import type { ClientLedger, GatewayRequestStatusRecord, PersistedEventRecord } from "./client-ledger.js";
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

export interface LedgerBackedGatewayStore extends GatewayLedger, ControlLeaseLedger, ClientLedger {}

export interface LedgerHandlerDependencies {
  now(): Date;
  newOpaqueId(): string;
}

export interface NodeStreamDelegate {
  onRegistration(registration: NodeRegistration, context: NodeMessageContext): Promise<void>;
  onDispatchAck(ack: DispatchAck, context: NodeMessageContext): Promise<void>;
  onEvent(event: EventEnvelope, context: NodeMessageContext): Promise<void>;
}

const noNodeDelegate: NodeStreamDelegate = {
  async onRegistration() {},
  async onDispatchAck() {},
  async onEvent() {},
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

function replayResponse(record: PersistedEventRecord): ClientResponseInit {
  const eventType = eventTypes[record.eventType];
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
          eventType === undefined
            ? {
                type: AgentEventType.UNSPECIFIED,
                payload: {
                  case: "unsupported",
                  value: { nativeTypeNumber: 0, safeMessage: "A newer Gateway event requires a protocol upgrade." },
                },
              }
            : {
                type: eventType,
                payload:
                  record.eventType === "request.accepted"
                    ? { case: "requestProgress", value: { safeMessage: "Request accepted." } }
                    : { case: undefined },
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
          return events.map(replayResponse);
        }
        default:
          throw new ConnectError("This Client command is not implemented yet.", Code.Unimplemented);
      }
    } catch (error) {
      if (error instanceof GatewayCommandError) {
        throw toConnectError(error);
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

  async onNodeRegistration(registration: NodeRegistration, context: NodeMessageContext): Promise<void> {
    await this.nodeDelegate.onRegistration(registration, context);
  }

  async onNodeDispatchAck(ack: DispatchAck, context: NodeMessageContext): Promise<void> {
    await this.nodeDelegate.onDispatchAck(ack, context);
  }

  async onNodeEvent(event: EventEnvelope, context: NodeMessageContext): Promise<void> {
    await this.nodeDelegate.onEvent(event, context);
  }
}
