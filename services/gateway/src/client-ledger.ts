import type { AcceptedRequestRecord } from "./ledger.js";

export interface GatewayRequestStatusRecord extends AcceptedRequestRecord {
  state: string;
  failure: {
    stage: string;
    category: string;
    code: string;
    safeMessage: string;
    retryable: boolean;
  } | null;
}

export interface PersistedEventRecord {
  eventId: string;
  connectionId: string;
  deviceId: string;
  conversationId: string;
  sessionId: string | null;
  requestId: string | null;
  sequence: bigint;
  eventType: string;
  safePayload: unknown;
  occurredAt: Date;
}

export interface ClientLedger {
  getRequestStatus(requestId: string, conversationId: string): Promise<GatewayRequestStatusRecord | undefined>;
  replayEvents(conversationId: string, afterSequence: bigint, maximumEvents: number): Promise<readonly PersistedEventRecord[]>;
  acknowledgeEvent(deviceId: string, conversationId: string, sequence: bigint, eventId: string, now: Date): Promise<boolean>;
}
