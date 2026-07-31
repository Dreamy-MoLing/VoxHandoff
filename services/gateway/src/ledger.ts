export const requiredSendScope = "send";

export interface DeviceRecord {
  deviceId: string;
  active: boolean;
  scopes: readonly string[];
}

export interface ControlLeaseRecord {
  conversationId: string;
  leaseId: string;
  deviceId: string;
  revision: bigint;
  expiresAt: Date;
}

export interface AgentTargetRecord {
  nodeId: string;
  agentId: string;
  available: boolean;
  capabilityRevision: string;
  maxRequestBytes: bigint | null;
}

export interface ConversationRouteRecord {
  conversationId: string;
  nodeId: string;
  agentId: string;
  capabilityRevision: string;
  sessionId: string | null;
}

export interface AcceptedRequestRecord {
  requestId: string;
  commandId: string;
  idempotencyKey: string;
  deviceId: string;
  connectionId: string;
  conversationId: string;
  sessionId: string | null;
  nodeId: string;
  agentId: string;
  capabilityRevision: string;
  confirmedTextSha256: string;
  acceptedSequence: bigint;
  acceptedAt: Date;
}

export interface AcceptedEventRecord {
  eventId: string;
  connectionId: string;
  deviceId: string;
  conversationId: string;
  sessionId: string | null;
  requestId: string;
  sequence: bigint;
  type: "request.accepted";
  occurredAt: Date;
}

export interface DispatchOutboxRecord {
  outboxId: string;
  requestId: string;
  nodeId: string;
  createdAt: Date;
}

export interface EventOutboxRecord {
  outboxId: string;
  eventId: string;
  conversationId: string;
  sequence: bigint;
  createdAt: Date;
}

export interface AcceptanceFacts {
  request: AcceptedRequestRecord;
  event: AcceptedEventRecord;
  dispatchOutbox: DispatchOutboxRecord;
  eventOutbox: EventOutboxRecord;
  confirmedText: string;
}

export interface GatewayLedgerTransaction {
  lockDevice(deviceId: string): Promise<DeviceRecord | undefined>;
  lockConversation(conversationId: string): Promise<boolean>;
  lockConversationRoute(conversationId: string): Promise<ConversationRouteRecord | undefined>;
  findRequestByIdempotency(deviceId: string, idempotencyKey: string): Promise<AcceptedRequestRecord | undefined>;
  findRequestByCommand(deviceId: string, commandId: string): Promise<AcceptedRequestRecord | undefined>;
  findRequestById(requestId: string): Promise<AcceptedRequestRecord | undefined>;
  getControlLease(conversationId: string): Promise<ControlLeaseRecord | undefined>;
  getAgentTarget(nodeId: string, agentId: string): Promise<AgentTargetRecord | undefined>;
  allocateConversationSequence(conversationId: string): Promise<bigint | undefined>;
  insertAcceptance(facts: AcceptanceFacts): Promise<void>;
}

export interface GatewayLedger {
  transaction<T>(work: (transaction: GatewayLedgerTransaction) => Promise<T>): Promise<T>;
}
