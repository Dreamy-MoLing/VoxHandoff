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

export interface ClaimedDispatchRecord {
  dispatchId: string;
  requestId: string;
  idempotencyKey: string;
  conversationId: string;
  sessionId: string | null;
  nodeId: string;
  agentId: string;
  capabilityRevision: string;
  confirmedText: string;
}

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
