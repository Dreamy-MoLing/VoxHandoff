import type { Pool } from "pg";

import type { ClientLedger, GatewayRequestStatusRecord, PersistedEventRecord } from "./client-ledger.js";
import {
  DirectoryLedgerError,
  type CreateConversationInput,
  type DirectoryConversationRecord,
  type DirectoryLedger,
  type GatewayDirectoryRecord,
} from "./directory-ledger.js";
import type { ClaimedEventPublication, EventPublicationLedger } from "./event-publication.js";
import type {
  ControlLeaseChange,
  ControlLeaseLedger,
  ControlLeaseTransaction,
} from "./control-lease.js";
import type {
  AcceptanceFacts,
  AcceptedRequestRecord,
  AgentTargetRecord,
  ConversationRouteRecord,
  ControlLeaseRecord,
  DeviceRecord,
  GatewayLedger,
  GatewayLedgerTransaction,
} from "./ledger.js";
import type {
  ApprovalRecord,
  ApprovalResolutionFacts,
  ClarificationRecord,
  ClarificationResolutionFacts,
  ControlCommandRecord,
  DeviceSignatureCredentialRecord,
  InteractionLedger,
  InteractionLedgerTransaction,
  InteractionRequestRecord,
  InterruptAcceptanceFacts,
} from "./interaction-ledger.js";
import {
  NodeLedgerError,
  type ClaimedDispatchRecord,
  type DispatchAcknowledgement,
  type NodeEventInput,
  type NodeLedger,
  type NodeRegistrationRecord,
  type StoredNodeEvent,
} from "./node-ledger.js";
import {
  bigintAt,
  booleanAt,
  dateAt,
  nullableBigintAt,
  nullableStringAt,
  parseControlCommand,
  parseDirectoryConversation,
  parseRequest,
  requestColumns,
  row,
  stringAt,
  type UnknownRow,
} from "./postgres-row-codecs.js";
import { runPostgresTransaction } from "./postgres-gateway-transaction.js";

export async function getRequestStatus(pool: Pool,
  requestId: string,
  conversationId: string,
): Promise<GatewayRequestStatusRecord | undefined> {
  const result = await pool.query<UnknownRow>(
    `SELECT ${requestColumns}, state, failure_stage, failure_category, failure_code,
            failure_safe_message, failure_retryable
     FROM agent_talk.requests WHERE request_id = $1 AND conversation_id = $2`,
    [requestId, conversationId],
  );
  if (result.rows[0] === undefined) {
    return undefined;
  }
  const data = row(result.rows[0]);
  return {
    ...parseRequest(data),
    state: stringAt(data, "state"),
    failure:
      data.failure_code === null
        ? null
        : {
            stage: stringAt(data, "failure_stage"),
            category: stringAt(data, "failure_category"),
            code: stringAt(data, "failure_code"),
            safeMessage: stringAt(data, "failure_safe_message"),
            retryable: booleanAt(data, "failure_retryable"),
          },
  };
}

export async function replayEvents(pool: Pool,
  conversationId: string,
  afterSequence: bigint,
  maximumEvents: number,
): Promise<readonly PersistedEventRecord[]> {
  if (!Number.isInteger(maximumEvents) || maximumEvents < 1 || maximumEvents > 500) {
    throw new Error("maximumEvents must be between 1 and 500");
  }
  const result = await pool.query<UnknownRow>(
    `SELECT event_id, connection_id, device_id, conversation_id, session_id, request_id,
            sequence, event_type, safe_payload, occurred_at
     FROM agent_talk.events
     WHERE conversation_id = $1 AND sequence > $2
     ORDER BY sequence
     LIMIT $3`,
    [conversationId, afterSequence.toString(), maximumEvents],
  );
  return result.rows.map((value) => {
    const data = row(value);
    return {
      eventId: stringAt(data, "event_id"),
      connectionId: stringAt(data, "connection_id"),
      deviceId: stringAt(data, "device_id"),
      conversationId: stringAt(data, "conversation_id"),
      sessionId: nullableStringAt(data, "session_id"),
      requestId: nullableStringAt(data, "request_id"),
      sequence: bigintAt(data, "sequence"),
      eventType: stringAt(data, "event_type"),
      safePayload: data.safe_payload,
      occurredAt: dateAt(data, "occurred_at"),
    };
  });
}

export async function acknowledgeEvent(pool: Pool,
  deviceId: string,
  conversationId: string,
  sequence: bigint,
  eventId: string,
  now: Date,
): Promise<boolean> {
  const result = await pool.query(
    `INSERT INTO agent_talk.device_cursors (device_id, conversation_id, sequence, updated_at)
     SELECT $1, e.conversation_id, e.sequence, $5
     FROM agent_talk.events e
     WHERE e.conversation_id = $2 AND e.sequence = $3 AND e.event_id = $4
     ON CONFLICT (device_id, conversation_id) DO UPDATE
     SET sequence = GREATEST(agent_talk.device_cursors.sequence, EXCLUDED.sequence),
         updated_at = EXCLUDED.updated_at
     RETURNING sequence`,
    [deviceId, conversationId, sequence.toString(), eventId, now],
  );
  return result.rowCount === 1;
}

export async function claimEventPublications(pool: Pool,
  workerId: string,
  now: Date,
  maximum: number,
): Promise<readonly ClaimedEventPublication[]> {
  if (!Number.isInteger(maximum) || maximum < 1 || maximum > 500) {
    throw new Error("event publication maximum must be between 1 and 500");
  }
  return runPostgresTransaction(pool, async (transaction) => {
    const result = await transaction.client.query<UnknownRow>(
      `WITH candidates AS (
         SELECT o.outbox_id
         FROM agent_talk.gateway_event_outbox o
         WHERE o.available_at <= $1
           AND (o.state = 'pending' OR (o.state = 'in_flight' AND o.locked_by IS DISTINCT FROM $2))
         ORDER BY o.created_at, o.outbox_id
         FOR UPDATE SKIP LOCKED
         LIMIT $3
       ), claimed AS (
         UPDATE agent_talk.gateway_event_outbox o
         SET state = 'in_flight', locked_by = $2, locked_at = $1,
             attempt_count = o.attempt_count + 1
         FROM candidates c
         WHERE o.outbox_id = c.outbox_id
         RETURNING o.outbox_id, o.event_id
       )
       SELECT c.outbox_id, e.event_id, e.connection_id, e.device_id, e.conversation_id,
              e.session_id, e.request_id, e.sequence, e.event_type, e.safe_payload, e.occurred_at
       FROM claimed c
       JOIN agent_talk.events e ON e.event_id = c.event_id
       ORDER BY e.conversation_id, e.sequence`,
      [now, workerId, maximum],
    );
    return result.rows.map((value) => {
      const data = row(value);
      return {
        outboxId: stringAt(data, "outbox_id"),
        event: {
          eventId: stringAt(data, "event_id"),
          connectionId: stringAt(data, "connection_id"),
          deviceId: stringAt(data, "device_id"),
          conversationId: stringAt(data, "conversation_id"),
          sessionId: nullableStringAt(data, "session_id"),
          requestId: nullableStringAt(data, "request_id"),
          sequence: bigintAt(data, "sequence"),
          eventType: stringAt(data, "event_type"),
          safePayload: data.safe_payload,
          occurredAt: dateAt(data, "occurred_at"),
        },
      };
    });
  });
}

export async function markEventPublicationDelivered(pool: Pool,
  outboxId: string,
  eventId: string,
  workerId: string,
  now: Date,
): Promise<boolean> {
  const result = await pool.query(
    `UPDATE agent_talk.gateway_event_outbox
     SET state = 'delivered', delivered_at = $4, locked_by = NULL, locked_at = NULL
     WHERE outbox_id = $1 AND event_id = $2 AND state = 'in_flight' AND locked_by = $3`,
    [outboxId, eventId, workerId, now],
  );
  return result.rowCount === 1;
}

export async function releaseEventPublication(pool: Pool,
  outboxId: string,
  eventId: string,
  workerId: string,
  now: Date,
  safeCode: string,
): Promise<boolean> {
  const result = await pool.query(
    `UPDATE agent_talk.gateway_event_outbox
     SET state = 'pending', available_at = $4 + interval '1 second',
         locked_by = NULL, locked_at = NULL, last_failure_code = $5
     WHERE outbox_id = $1 AND event_id = $2 AND state = 'in_flight' AND locked_by = $3`,
    [outboxId, eventId, workerId, now, safeCode],
  );
  return result.rowCount === 1;
}
