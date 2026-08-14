import type { Pool } from "pg";

import type { ClientLedger, GatewayRequestStatusRecord, PersistedEventRecord } from "./client-ledger.js";
import type { ClaimedEventPublication, EventPublicationLedger } from "./event-publication.js";
import type {
  ControlLeaseChange,
  ControlLeaseLedger,
  ControlLeaseTransaction,
} from "./control-lease.js";
import type {
  CreateConversationInput,
  DirectoryConversationRecord,
  DirectoryLedger,
  GatewayDirectoryRecord,
} from "./directory-ledger.js";
import type {
  GatewayLedger,
  GatewayLedgerTransaction,
} from "./ledger.js";
import type { DispatchAcknowledgement } from "./node-ledger.js";
import type {
  InteractionLedger,
  InteractionLedgerTransaction,
} from "./interaction-ledger.js";
import type {
  ClaimedDispatchRecord,
  NodeEventInput,
  NodeLedger,
  NodeRegistrationRecord,
  StoredNodeEvent,
} from "./node-ledger.js";
import {
  runPostgresTransaction,
} from "./postgres-gateway-transaction.js";
import {
  createConversation as createConversationInPostgres,
  listDirectory as listDirectoryInPostgres,
} from "./postgres-directory-ledger.js";
import {
  acknowledgeEvent as acknowledgeEventInPostgres,
  claimEventPublications as claimEventPublicationsInPostgres,
  getRequestStatus as getRequestStatusInPostgres,
  markEventPublicationDelivered as markEventPublicationDeliveredInPostgres,
  releaseEventPublication as releaseEventPublicationInPostgres,
  replayEvents as replayEventsInPostgres,
} from "./postgres-event-ledger.js";
import {
  acknowledgeDispatch as acknowledgeDispatchInPostgres,
  claimDispatches as claimDispatchesInPostgres,
  ingestNodeEvent as ingestNodeEventInPostgres,
  registerNode as registerNodeInPostgres,
} from "./postgres-node-ledger.js";

export class PostgresGatewayLedger implements
  GatewayLedger,
  ControlLeaseLedger,
  ClientLedger,
  DirectoryLedger,
  NodeLedger,
  InteractionLedger,
  EventPublicationLedger
{
  constructor(private readonly pool: Pool) {}

  listDirectory(): Promise<GatewayDirectoryRecord> {
    return listDirectoryInPostgres(this.pool);
  }

  createConversation(input: CreateConversationInput): Promise<DirectoryConversationRecord> {
    return createConversationInPostgres(this.pool, input);
  }

  async transaction<T>(work: (transaction: GatewayLedgerTransaction) => Promise<T>): Promise<T> {
    return runPostgresTransaction(this.pool, (transaction) => work(transaction));
  }

  async leaseTransaction<T>(work: (transaction: ControlLeaseTransaction) => Promise<T>): Promise<T> {
    return runPostgresTransaction(this.pool, (transaction) => work(transaction));
  }

  async interactionTransaction<T>(work: (transaction: InteractionLedgerTransaction) => Promise<T>): Promise<T> {
    return runPostgresTransaction(this.pool, (transaction) => work(transaction));
  }

  getRequestStatus(
    requestId: string,
    conversationId: string,
  ): Promise<GatewayRequestStatusRecord | undefined> {
    return getRequestStatusInPostgres(this.pool, requestId, conversationId);
  }

  replayEvents(
    conversationId: string,
    afterSequence: bigint,
    maximumEvents: number,
  ): Promise<readonly PersistedEventRecord[]> {
    return replayEventsInPostgres(this.pool, conversationId, afterSequence, maximumEvents);
  }

  acknowledgeEvent(
    deviceId: string,
    conversationId: string,
    sequence: bigint,
    eventId: string,
    now: Date,
  ): Promise<boolean> {
    return acknowledgeEventInPostgres(this.pool, deviceId, conversationId, sequence, eventId, now);
  }

  claimEventPublications(
    workerId: string,
    now: Date,
    maximum: number,
  ): Promise<readonly ClaimedEventPublication[]> {
    return claimEventPublicationsInPostgres(this.pool, workerId, now, maximum);
  }

  markEventPublicationDelivered(
    outboxId: string,
    eventId: string,
    workerId: string,
    now: Date,
  ): Promise<boolean> {
    return markEventPublicationDeliveredInPostgres(this.pool, outboxId, eventId, workerId, now);
  }

  releaseEventPublication(
    outboxId: string,
    eventId: string,
    workerId: string,
    now: Date,
    safeCode: string,
  ): Promise<boolean> {
    return releaseEventPublicationInPostgres(this.pool, outboxId, eventId, workerId, now, safeCode);
  }

  registerNode(registration: NodeRegistrationRecord, now: Date): Promise<void> {
    return registerNodeInPostgres(this.pool, registration, now);
  }

  claimDispatches(
    nodeId: string,
    connectionId: string,
    now: Date,
    maximum: number,
  ): Promise<readonly ClaimedDispatchRecord[]> {
    return claimDispatchesInPostgres(this.pool, nodeId, connectionId, now, maximum);
  }

  acknowledgeDispatch(acknowledgement: DispatchAcknowledgement): Promise<void> {
    return acknowledgeDispatchInPostgres(this.pool, acknowledgement);
  }

  ingestNodeEvent(event: NodeEventInput): Promise<StoredNodeEvent> {
    return ingestNodeEventInPostgres(this.pool, event);
  }
}
