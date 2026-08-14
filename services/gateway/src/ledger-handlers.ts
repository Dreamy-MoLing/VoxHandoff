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
import {
  conversationResponse,
  directoryResponse,
  interactionConnectError,
  persistedEventResponse,
  requestStatus,
  requireObserveOrControl,
  requireOpaque,
  requireSend,
  toConnectError,
} from "./ledger-handler-codecs.js";

export { persistedEventResponse } from "./ledger-handler-codecs.js";

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
