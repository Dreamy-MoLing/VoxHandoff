import type {
  AcceptedRequestRecord,
  ControlLeaseRecord,
  DeviceRecord,
} from "./ledger.js";
import type { StoredFailure } from "./node-ledger.js";

export type ControlCommandKind = "interrupt" | "approval" | "clarification";

export interface ControlCommandRecord {
  commandId: string;
  idempotencyKey: string;
  deviceId: string;
  conversationId: string;
  requestId: string;
  kind: ControlCommandKind;
  targetId: string | null;
  payloadSha256: string;
  state: "accepted" | "delivered" | "failed";
  failure: StoredFailure | null;
  createdAt: Date;
}

export interface InteractionRequestRecord extends AcceptedRequestRecord {
  state: string;
  interruptCapable: boolean;
  clarificationCapable: boolean;
  maxRequestBytes: bigint | null;
}

export interface ApprovalRecord {
  approvalId: string;
  requestId: string;
  nodeId: string;
  agentId: string;
  operationSummarySha256: string;
  state: "pending" | "approved" | "rejected" | "expired" | "cancelled";
  expiresAt: Date;
}

export interface DeviceSignatureCredentialRecord {
  credentialId: string;
  deviceId: string;
  active: boolean;
  deviceActive: boolean;
  publicKeySpki: Uint8Array;
  publicKeySha256: string;
  gatewayAudience: string;
  scopes: readonly string[];
}

export interface ApprovalResolutionFacts {
  command: ControlCommandRecord;
  approvalId: string;
  decision: "approved" | "rejected";
  operationSummarySha256: string;
  dispatchOutboxId: string;
  audit: {
    auditId: string;
    targetIdSha256: string;
    occurredAt: Date;
  };
}

export interface ClarificationRecord {
  clarificationId: string;
  requestId: string;
  nodeId: string;
  agentId: string;
  state: "pending" | "resolved" | "expired" | "cancelled";
  expiresAt: Date;
}

export interface ClarificationResolutionFacts {
  command: ControlCommandRecord;
  clarificationId: string;
  confirmedText: string;
  dispatchOutboxId: string;
  audit: {
    auditId: string;
    targetIdSha256: string;
    occurredAt: Date;
  };
}

export interface InterruptAcceptanceFacts {
  command: ControlCommandRecord;
  event: {
    eventId: string;
    connectionId: string;
    deviceId: string;
    conversationId: string;
    sessionId: string | null;
    requestId: string;
    sequence: bigint;
    occurredAt: Date;
  };
  dispatchOutboxId: string;
  eventOutboxId: string;
}

export interface InteractionLedgerTransaction {
  lockDevice(deviceId: string): Promise<DeviceRecord | undefined>;
  lockConversation(conversationId: string): Promise<boolean>;
  getControlLease(conversationId: string): Promise<ControlLeaseRecord | undefined>;
  findControlCommandByIdempotency(deviceId: string, idempotencyKey: string): Promise<ControlCommandRecord | undefined>;
  findControlCommandById(commandId: string): Promise<ControlCommandRecord | undefined>;
  findSendRequestByCommand(deviceId: string, commandId: string): Promise<AcceptedRequestRecord | undefined>;
  findInterruptByRequest(requestId: string): Promise<ControlCommandRecord | undefined>;
  lockInteractionRequest(requestId: string, conversationId: string): Promise<InteractionRequestRecord | undefined>;
  lockApproval(approvalId: string, requestId: string): Promise<ApprovalRecord | undefined>;
  lockDeviceSignatureCredential(credentialId: string): Promise<DeviceSignatureCredentialRecord | undefined>;
  recordDeviceSignatureNonce(
    credentialId: string,
    purpose: string,
    nonceSha256: string,
    usedAt: Date,
  ): Promise<boolean>;
  expireApproval(approvalId: string, occurredAt: Date): Promise<boolean>;
  lockClarification(clarificationId: string, requestId: string): Promise<ClarificationRecord | undefined>;
  expireClarification(clarificationId: string, occurredAt: Date): Promise<boolean>;
  allocateConversationSequence(conversationId: string): Promise<bigint | undefined>;
  insertInterruptAcceptance(facts: InterruptAcceptanceFacts): Promise<void>;
  insertApprovalResolution(facts: ApprovalResolutionFacts): Promise<void>;
  insertClarificationResolution(facts: ClarificationResolutionFacts): Promise<void>;
}

export interface InteractionLedger {
  interactionTransaction<T>(work: (transaction: InteractionLedgerTransaction) => Promise<T>): Promise<T>;
}
