import type { Pool, PoolClient } from "pg";

import type { ClientLedger, GatewayRequestStatusRecord, PersistedEventRecord } from "./client-ledger.js";
import type {
  ControlLeaseChange,
  ControlLeaseLedger,
  ControlLeaseTransaction,
} from "./control-lease.js";
import type {
  AcceptanceFacts,
  AcceptedRequestRecord,
  AgentTargetRecord,
  ControlLeaseRecord,
  DeviceRecord,
  GatewayLedger,
  GatewayLedgerTransaction,
} from "./ledger.js";

type UnknownRow = Record<string, unknown>;

function row(value: unknown): UnknownRow {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error("invalid PostgreSQL row");
  }
  return value as UnknownRow;
}

function stringAt(value: UnknownRow, key: string): string {
  const field = value[key];
  if (typeof field !== "string") {
    throw new Error(`invalid PostgreSQL ${key}`);
  }
  return field;
}

function nullableStringAt(value: UnknownRow, key: string): string | null {
  const field = value[key];
  if (field === null) {
    return null;
  }
  if (typeof field !== "string") {
    throw new Error(`invalid PostgreSQL ${key}`);
  }
  return field;
}

function bigintAt(value: UnknownRow, key: string): bigint {
  const field = value[key];
  if (typeof field === "bigint") {
    return field;
  }
  if (typeof field === "number" && Number.isSafeInteger(field)) {
    return BigInt(field);
  }
  if (typeof field === "string" && /^-?\d+$/u.test(field)) {
    return BigInt(field);
  }
  throw new Error(`invalid PostgreSQL ${key}`);
}

function nullableBigintAt(value: UnknownRow, key: string): bigint | null {
  return value[key] === null ? null : bigintAt(value, key);
}

function booleanAt(value: UnknownRow, key: string): boolean {
  const field = value[key];
  if (typeof field !== "boolean") {
    throw new Error(`invalid PostgreSQL ${key}`);
  }
  return field;
}

function dateAt(value: UnknownRow, key: string): Date {
  const field = value[key];
  if (field instanceof Date && !Number.isNaN(field.getTime())) {
    return field;
  }
  throw new Error(`invalid PostgreSQL ${key}`);
}

function parseRequest(value: unknown): AcceptedRequestRecord {
  const data = row(value);
  return {
    requestId: stringAt(data, "request_id"),
    commandId: stringAt(data, "command_id"),
    idempotencyKey: stringAt(data, "idempotency_key"),
    deviceId: stringAt(data, "device_id"),
    connectionId: stringAt(data, "accepted_connection_id"),
    conversationId: stringAt(data, "conversation_id"),
    sessionId: nullableStringAt(data, "session_id"),
    nodeId: stringAt(data, "node_id"),
    agentId: stringAt(data, "agent_id"),
    capabilityRevision: stringAt(data, "capability_revision"),
    confirmedTextSha256: stringAt(data, "confirmed_text_sha256"),
    acceptedSequence: bigintAt(data, "accepted_sequence"),
    acceptedAt: dateAt(data, "accepted_at"),
  };
}

const requestColumns = `
  request_id, command_id, idempotency_key, device_id, accepted_connection_id,
  conversation_id, session_id, node_id, agent_id, capability_revision,
  confirmed_text_sha256, accepted_sequence, accepted_at
`;

class PostgresGatewayTransaction implements GatewayLedgerTransaction, ControlLeaseTransaction {
  constructor(private readonly client: PoolClient) {}

  async lockDevice(deviceId: string): Promise<DeviceRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      "SELECT device_id, status, scopes FROM agent_talk.devices WHERE device_id = $1 FOR UPDATE",
      [deviceId],
    );
    if (result.rows[0] === undefined) {
      return undefined;
    }
    const data = row(result.rows[0]);
    const scopes = data.scopes;
    if (!Array.isArray(scopes) || !scopes.every((scope) => typeof scope === "string")) {
      throw new Error("invalid PostgreSQL scopes");
    }
    return {
      deviceId: stringAt(data, "device_id"),
      active: stringAt(data, "status") === "active",
      scopes,
    };
  }

  async lockConversation(conversationId: string): Promise<boolean> {
    const result = await this.client.query(
      "SELECT 1 FROM agent_talk.conversations WHERE conversation_id = $1 FOR UPDATE",
      [conversationId],
    );
    return result.rowCount === 1;
  }

  async findRequestByIdempotency(
    deviceId: string,
    idempotencyKey: string,
  ): Promise<AcceptedRequestRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT ${requestColumns} FROM agent_talk.requests WHERE device_id = $1 AND idempotency_key = $2`,
      [deviceId, idempotencyKey],
    );
    return result.rows[0] === undefined ? undefined : parseRequest(result.rows[0]);
  }

  async findRequestById(requestId: string): Promise<AcceptedRequestRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT ${requestColumns} FROM agent_talk.requests WHERE request_id = $1`,
      [requestId],
    );
    return result.rows[0] === undefined ? undefined : parseRequest(result.rows[0]);
  }

  async findRequestByCommand(deviceId: string, commandId: string): Promise<AcceptedRequestRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT ${requestColumns} FROM agent_talk.requests WHERE device_id = $1 AND command_id = $2`,
      [deviceId, commandId],
    );
    return result.rows[0] === undefined ? undefined : parseRequest(result.rows[0]);
  }

  async getControlLease(conversationId: string): Promise<ControlLeaseRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT conversation_id, lease_id, device_id, revision, expires_at
       FROM agent_talk.control_leases WHERE conversation_id = $1 FOR UPDATE`,
      [conversationId],
    );
    if (result.rows[0] === undefined) {
      return undefined;
    }
    const data = row(result.rows[0]);
    return {
      conversationId: stringAt(data, "conversation_id"),
      leaseId: stringAt(data, "lease_id"),
      deviceId: stringAt(data, "device_id"),
      revision: bigintAt(data, "revision"),
      expiresAt: dateAt(data, "expires_at"),
    };
  }

  async insertControlLease(change: ControlLeaseChange): Promise<void> {
    await this.client.query(
      `INSERT INTO agent_talk.control_leases (
         conversation_id, lease_id, device_id, revision, expires_at, updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6)`,
      [
        change.lease.conversationId,
        change.lease.leaseId,
        change.lease.deviceId,
        change.lease.revision.toString(),
        change.lease.expiresAt,
        change.audit.occurredAt,
      ],
    );
    await this.insertAudit(change);
  }

  async replaceControlLease(
    expectedLeaseId: string,
    expectedRevision: bigint,
    change: ControlLeaseChange,
  ): Promise<boolean> {
    const result = await this.client.query(
      `UPDATE agent_talk.control_leases
       SET lease_id = $1, device_id = $2, revision = $3, expires_at = $4, updated_at = $5
       WHERE conversation_id = $6 AND lease_id = $7 AND revision = $8`,
      [
        change.lease.leaseId,
        change.lease.deviceId,
        change.lease.revision.toString(),
        change.lease.expiresAt,
        change.audit.occurredAt,
        change.lease.conversationId,
        expectedLeaseId,
        expectedRevision.toString(),
      ],
    );
    if (result.rowCount !== 1) {
      return false;
    }
    await this.insertAudit(change);
    return true;
  }

  private async insertAudit(change: ControlLeaseChange): Promise<void> {
    await this.client.query(
      `INSERT INTO agent_talk.security_audit_events (
         audit_id, device_id, action, outcome, target_type, target_id_sha256, safe_code, occurred_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        change.audit.auditId,
        change.audit.deviceId,
        change.audit.action,
        change.audit.outcome,
        change.audit.targetType,
        change.audit.targetIdSha256,
        change.audit.safeCode,
        change.audit.occurredAt,
      ],
    );
  }

  async getAgentTarget(nodeId: string, agentId: string): Promise<AgentTargetRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT a.node_id, a.agent_id, a.capability_revision, a.max_request_bytes,
              (a.status = 'online' AND n.status = 'online') AS available
       FROM agent_talk.agents a
       JOIN agent_talk.nodes n ON n.node_id = a.node_id
       WHERE a.node_id = $1 AND a.agent_id = $2
       FOR KEY SHARE OF a, n`,
      [nodeId, agentId],
    );
    if (result.rows[0] === undefined) {
      return undefined;
    }
    const data = row(result.rows[0]);
    if (typeof data.available !== "boolean") {
      throw new Error("invalid PostgreSQL available");
    }
    return {
      nodeId: stringAt(data, "node_id"),
      agentId: stringAt(data, "agent_id"),
      available: data.available,
      capabilityRevision: stringAt(data, "capability_revision"),
      maxRequestBytes: nullableBigintAt(data, "max_request_bytes"),
    };
  }

  async allocateConversationSequence(conversationId: string): Promise<bigint | undefined> {
    const result = await this.client.query<UnknownRow>(
      `UPDATE agent_talk.conversations
       SET last_sequence = last_sequence + 1, updated_at = clock_timestamp()
       WHERE conversation_id = $1
       RETURNING last_sequence`,
      [conversationId],
    );
    return result.rows[0] === undefined ? undefined : bigintAt(row(result.rows[0]), "last_sequence");
  }

  async insertAcceptance(facts: AcceptanceFacts): Promise<void> {
    const request = facts.request;
    await this.client.query(
      `INSERT INTO agent_talk.requests (
         request_id, command_id, idempotency_key, device_id, accepted_connection_id,
         conversation_id, session_id, node_id, agent_id, capability_revision,
         confirmed_text, confirmed_text_sha256, state, accepted_sequence, accepted_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, 'accepted', $13, $14)`,
      [
        request.requestId,
        request.commandId,
        request.idempotencyKey,
        request.deviceId,
        request.connectionId,
        request.conversationId,
        request.sessionId,
        request.nodeId,
        request.agentId,
        request.capabilityRevision,
        facts.confirmedText,
        request.confirmedTextSha256,
        request.acceptedSequence.toString(),
        request.acceptedAt,
      ],
    );
    await this.client.query(
      `INSERT INTO agent_talk.events (
         event_id, connection_id, device_id, conversation_id, session_id, request_id,
         sequence, event_type, safe_payload, occurred_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, '{}'::jsonb, $9)`,
      [
        facts.event.eventId,
        facts.event.connectionId,
        facts.event.deviceId,
        facts.event.conversationId,
        facts.event.sessionId,
        facts.event.requestId,
        facts.event.sequence.toString(),
        facts.event.type,
        facts.event.occurredAt,
      ],
    );
    await this.client.query(
      `INSERT INTO agent_talk.gateway_dispatch_outbox (
         outbox_id, request_id, node_id, dispatch_kind, available_at, created_at
       ) VALUES ($1, $2, $3, 'send', $4, $4)`,
      [
        facts.dispatchOutbox.outboxId,
        facts.dispatchOutbox.requestId,
        facts.dispatchOutbox.nodeId,
        facts.dispatchOutbox.createdAt,
      ],
    );
    await this.client.query(
      `INSERT INTO agent_talk.gateway_event_outbox (
         outbox_id, event_id, conversation_id, sequence, available_at, created_at
       ) VALUES ($1, $2, $3, $4, $5, $5)`,
      [
        facts.eventOutbox.outboxId,
        facts.eventOutbox.eventId,
        facts.eventOutbox.conversationId,
        facts.eventOutbox.sequence.toString(),
        facts.eventOutbox.createdAt,
      ],
    );
  }
}

export class PostgresGatewayLedger implements GatewayLedger, ControlLeaseLedger, ClientLedger {
  constructor(private readonly pool: Pool) {}

  async transaction<T>(work: (transaction: GatewayLedgerTransaction) => Promise<T>): Promise<T> {
    return this.runTransaction(work);
  }

  async leaseTransaction<T>(work: (transaction: ControlLeaseTransaction) => Promise<T>): Promise<T> {
    return this.runTransaction(work);
  }

  async getRequestStatus(
    requestId: string,
    conversationId: string,
  ): Promise<GatewayRequestStatusRecord | undefined> {
    const result = await this.pool.query<UnknownRow>(
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

  async replayEvents(
    conversationId: string,
    afterSequence: bigint,
    maximumEvents: number,
  ): Promise<readonly PersistedEventRecord[]> {
    if (!Number.isInteger(maximumEvents) || maximumEvents < 1 || maximumEvents > 500) {
      throw new Error("maximumEvents must be between 1 and 500");
    }
    const result = await this.pool.query<UnknownRow>(
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

  async acknowledgeEvent(
    deviceId: string,
    conversationId: string,
    sequence: bigint,
    eventId: string,
    now: Date,
  ): Promise<boolean> {
    const result = await this.pool.query(
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

  private async runTransaction<T>(work: (transaction: PostgresGatewayTransaction) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const result = await work(new PostgresGatewayTransaction(client));
      await client.query("COMMIT");
      return result;
    } catch (error) {
      try {
        await client.query("ROLLBACK");
      } catch {
        // Preserve the domain or database error that caused the rollback.
      }
      throw error;
    } finally {
      client.release();
    }
  }
}
