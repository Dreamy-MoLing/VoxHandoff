export interface NodeAgentRegistration {
  agentId: string;
  displayName: string;
  adapter: string;
  version: string;
  capabilityRevision: string;
  capabilities: unknown;
  maxRequestBytes: bigint | null;
}

export interface NodeRegistrationRecord {
  nodeId: string;
  connectionId: string;
  displayName: string;
  platform: string;
  version: string;
  agents: readonly NodeAgentRegistration[];
}

interface ClaimedDispatchBase {
  dispatchId: string;
  requestId: string;
  idempotencyKey: string;
}

export interface ClaimedSendDispatchRecord extends ClaimedDispatchBase {
  kind: "send";
  conversationId: string;
  sessionId: string | null;
  nodeId: string;
  agentId: string;
  capabilityRevision: string;
  confirmedText: string;
}

export interface ClaimedInterruptDispatchRecord extends ClaimedDispatchBase {
  kind: "interrupt";
}

export interface ClaimedApprovalDispatchRecord extends ClaimedDispatchBase {
  kind: "approval";
  approvalId: string;
  decision: "approved" | "rejected";
  operationSummarySha256: string;
}

export type ClaimedDispatchRecord =
  | ClaimedSendDispatchRecord
  | ClaimedInterruptDispatchRecord
  | ClaimedApprovalDispatchRecord;

export interface StoredFailure {
  stage: string;
  category: string;
  code: string;
  safeMessage: string;
  retryable: boolean;
}

export interface DispatchAcknowledgement {
  nodeId: string;
  connectionId: string;
  dispatchId: string;
  requestId: string;
  accepted: boolean;
  failure: StoredFailure | null;
  occurredAt: Date;
}

export interface NodeEventInput {
  eventId: string;
  nodeId: string;
  connectionId: string;
  requestId: string;
  sourceSequence: bigint;
  conversationId: string;
  sessionId: string | null;
  eventType: string;
  safePayload: unknown;
  requestState: "working" | "completed" | "failed" | "cancelled" | "interrupted" | null;
  failure: StoredFailure | null;
  interaction:
    | {
        kind: "approval_required";
        approvalId: string;
        nativeApprovalId: string;
        safeSummary: string;
        operationSummarySha256: string;
        expiresAt: Date;
      }
    | {
        kind: "approval_state";
        approvalId: string;
        operationSummarySha256: string;
        state: "resolved" | "expired" | "cancelled";
      }
    | {
        kind: "clarification_required";
        clarificationId: string;
        nativeClarificationId: string;
        safePrompt: string;
        expiresAt: Date;
      }
    | {
        kind: "clarification_state";
        clarificationId: string;
        state: "resolved" | "expired" | "cancelled";
      }
    | null;
  occurredAt: Date;
}

export interface StoredNodeEvent {
  eventId: string;
  conversationId: string;
  sequence: bigint;
  duplicate: boolean;
}

export type NodeLedgerErrorCode =
  | "node_revoked"
  | "agent_identity_conflict"
  | "dispatch_not_found"
  | "dispatch_identity_conflict"
  | "dispatch_ack_conflict"
  | "request_not_found"
  | "event_identity_conflict"
  | "stale_node_connection"
  | "stale_node_event"
  | "interaction_conflict"
  | "event_after_terminal";

export class NodeLedgerError extends Error {
  constructor(readonly code: NodeLedgerErrorCode, message: string) {
    super(message);
    this.name = "NodeLedgerError";
  }
}

export interface NodeLedger {
  registerNode(registration: NodeRegistrationRecord, now: Date): Promise<void>;
  claimDispatches(
    nodeId: string,
    connectionId: string,
    now: Date,
    maximum: number,
  ): Promise<readonly ClaimedDispatchRecord[]>;
  acknowledgeDispatch(acknowledgement: DispatchAcknowledgement): Promise<void>;
  ingestNodeEvent(event: NodeEventInput): Promise<StoredNodeEvent>;
}
