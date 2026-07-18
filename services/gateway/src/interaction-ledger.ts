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
  allocateConversationSequence(conversationId: string): Promise<bigint | undefined>;
  insertInterruptAcceptance(facts: InterruptAcceptanceFacts): Promise<void>;
}

export interface InteractionLedger {
  interactionTransaction<T>(work: (transaction: InteractionLedgerTransaction) => Promise<T>): Promise<T>;
}
