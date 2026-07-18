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
import type {
  ApprovalRecord,
  ApprovalResolutionFacts,
  ControlCommandRecord,
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

function parseControlCommand(value: unknown): ControlCommandRecord {
  const data = row(value);
  return {
    commandId: stringAt(data, "command_id"),
    idempotencyKey: stringAt(data, "idempotency_key"),
    deviceId: stringAt(data, "device_id"),
    conversationId: stringAt(data, "conversation_id"),
    requestId: stringAt(data, "request_id"),
    kind: stringAt(data, "command_kind") as ControlCommandRecord["kind"],
    targetId: nullableStringAt(data, "target_id"),
    payloadSha256: stringAt(data, "payload_sha256"),
    state: stringAt(data, "state") as ControlCommandRecord["state"],
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
    createdAt: dateAt(data, "created_at"),
  };
}

const requestColumns = `
  request_id, command_id, idempotency_key, device_id, accepted_connection_id,
  conversation_id, session_id, node_id, agent_id, capability_revision,
  confirmed_text_sha256, accepted_sequence, accepted_at
`;

const requestColumnsFromR = `
  r.request_id AS request_id, r.command_id AS command_id, r.idempotency_key AS idempotency_key,
  r.device_id AS device_id, r.accepted_connection_id AS accepted_connection_id,
  r.conversation_id AS conversation_id, r.session_id AS session_id, r.node_id AS node_id,
  r.agent_id AS agent_id, r.capability_revision AS capability_revision,
  r.confirmed_text_sha256 AS confirmed_text_sha256,
  r.accepted_sequence AS accepted_sequence, r.accepted_at AS accepted_at
`;

const controlCommandColumns = `
  command_id, idempotency_key, device_id, conversation_id, request_id,
  command_kind, target_id, payload_sha256, state, failure_stage,
  failure_category, failure_code, failure_safe_message, failure_retryable, created_at
`;

class PostgresGatewayTransaction implements GatewayLedgerTransaction, ControlLeaseTransaction, InteractionLedgerTransaction {
  constructor(readonly client: PoolClient) {}

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

  async findControlCommandByIdempotency(
    deviceId: string,
    idempotencyKey: string,
  ): Promise<ControlCommandRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT ${controlCommandColumns} FROM agent_talk.control_commands
       WHERE device_id = $1 AND idempotency_key = $2`,
      [deviceId, idempotencyKey],
    );
    return result.rows[0] === undefined ? undefined : parseControlCommand(result.rows[0]);
  }

  async findControlCommandById(commandId: string): Promise<ControlCommandRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT ${controlCommandColumns} FROM agent_talk.control_commands WHERE command_id = $1`,
      [commandId],
    );
    return result.rows[0] === undefined ? undefined : parseControlCommand(result.rows[0]);
  }

  async findSendRequestByCommand(deviceId: string, commandId: string): Promise<AcceptedRequestRecord | undefined> {
    return this.findRequestByCommand(deviceId, commandId);
  }

  async findInterruptByRequest(requestId: string): Promise<ControlCommandRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT ${controlCommandColumns} FROM agent_talk.control_commands
       WHERE request_id = $1 AND command_kind = 'interrupt'`,
      [requestId],
    );
    return result.rows[0] === undefined ? undefined : parseControlCommand(result.rows[0]);
  }

  async lockInteractionRequest(
    requestId: string,
    conversationId: string,
  ): Promise<InteractionRequestRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT ${requestColumnsFromR}, r.state,
              COALESCE((a.capabilities->>'interrupt')::boolean, false) AS interrupt_capable
       FROM agent_talk.requests r
       JOIN agent_talk.agents a ON a.agent_id = r.agent_id AND a.node_id = r.node_id
       WHERE r.request_id = $1 AND r.conversation_id = $2
       FOR UPDATE OF r`,
      [requestId, conversationId],
    );
    if (result.rows[0] === undefined) return undefined;
    const data = row(result.rows[0]);
    return {
      ...parseRequest(data),
      state: stringAt(data, "state"),
      interruptCapable: booleanAt(data, "interrupt_capable"),
    };
  }

  async lockApproval(approvalId: string, requestId: string): Promise<ApprovalRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT approval_id, request_id, node_id, agent_id, operation_summary_sha256, state, expires_at
       FROM agent_talk.approvals
       WHERE approval_id = $1 AND request_id = $2
       FOR UPDATE`,
      [approvalId, requestId],
    );
    if (result.rows[0] === undefined) return undefined;
    const data = row(result.rows[0]);
    return {
      approvalId: stringAt(data, "approval_id"),
      requestId: stringAt(data, "request_id"),
      nodeId: stringAt(data, "node_id"),
      agentId: stringAt(data, "agent_id"),
      operationSummarySha256: stringAt(data, "operation_summary_sha256"),
      state: stringAt(data, "state") as ApprovalRecord["state"],
      expiresAt: dateAt(data, "expires_at"),
    };
  }

  async expireApproval(approvalId: string, occurredAt: Date): Promise<boolean> {
    const result = await this.client.query(
      `UPDATE agent_talk.approvals
       SET state = 'expired', resolved_at = $2
       WHERE approval_id = $1 AND state = 'pending'`,
      [approvalId, occurredAt],
    );
    return result.rowCount === 1;
  }

  async insertInterruptAcceptance(facts: InterruptAcceptanceFacts): Promise<void> {
    const command = facts.command;
    await this.client.query(
      `INSERT INTO agent_talk.control_commands (
         command_id, idempotency_key, device_id, conversation_id, request_id,
         command_kind, target_id, payload_sha256, state, created_at
       ) VALUES ($1, $2, $3, $4, $5, 'interrupt', NULL, $6, 'accepted', $7)`,
      [
        command.commandId,
        command.idempotencyKey,
        command.deviceId,
        command.conversationId,
        command.requestId,
        command.payloadSha256,
        command.createdAt,
      ],
    );
    await this.client.query(
      `INSERT INTO agent_talk.events (
         event_id, connection_id, device_id, conversation_id, session_id, request_id,
         sequence, event_type, safe_payload, occurred_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'request.interrupting',
                 '{"safeMessage":"Interrupt requested."}'::jsonb, $8)`,
      [
        facts.event.eventId,
        facts.event.connectionId,
        facts.event.deviceId,
        facts.event.conversationId,
        facts.event.sessionId,
        facts.event.requestId,
        facts.event.sequence.toString(),
        facts.event.occurredAt,
      ],
    );
    await this.client.query(
      `INSERT INTO agent_talk.gateway_dispatch_outbox (
         outbox_id, request_id, node_id, dispatch_kind, control_command_id, available_at, created_at
       ) SELECT $1, r.request_id, r.node_id, 'interrupt', $2, $3, $3
         FROM agent_talk.requests r WHERE r.request_id = $4`,
      [facts.dispatchOutboxId, command.commandId, command.createdAt, command.requestId],
    );
    await this.client.query(
      `INSERT INTO agent_talk.gateway_event_outbox (
         outbox_id, event_id, conversation_id, sequence, available_at, created_at
       ) VALUES ($1, $2, $3, $4, $5, $5)`,
      [
        facts.eventOutboxId,
        facts.event.eventId,
        facts.event.conversationId,
        facts.event.sequence.toString(),
        command.createdAt,
      ],
    );
  }

  async insertApprovalResolution(facts: ApprovalResolutionFacts): Promise<void> {
    const command = facts.command;
    const approval = await this.client.query(
      `UPDATE agent_talk.approvals
       SET state = $2, resolved_by_device_id = $3, resolution_idempotency_key = $4,
           resolution_decision = $2, resolution_command_id = $5, resolved_at = $6
       WHERE approval_id = $1 AND request_id = $7 AND state = 'pending'
         AND operation_summary_sha256 = $8`,
      [
        facts.approvalId,
        facts.decision,
        command.deviceId,
        command.idempotencyKey,
        command.commandId,
        command.createdAt,
        command.requestId,
        facts.operationSummarySha256,
      ],
    );
    if (approval.rowCount !== 1) throw new Error("locked approval changed before resolution insert");
    await this.client.query(
      `INSERT INTO agent_talk.control_commands (
         command_id, idempotency_key, device_id, conversation_id, request_id,
         command_kind, target_id, payload_sha256, state, created_at
       ) VALUES ($1, $2, $3, $4, $5, 'approval', $6, $7, 'accepted', $8)`,
      [
        command.commandId,
        command.idempotencyKey,
        command.deviceId,
        command.conversationId,
        command.requestId,
        facts.approvalId,
        command.payloadSha256,
        command.createdAt,
      ],
    );
    await this.client.query(
      `INSERT INTO agent_talk.gateway_dispatch_outbox (
         outbox_id, request_id, node_id, dispatch_kind, control_command_id, available_at, created_at
       ) SELECT $1, r.request_id, r.node_id, 'approval', $2, $3, $3
         FROM agent_talk.requests r WHERE r.request_id = $4`,
      [facts.dispatchOutboxId, command.commandId, command.createdAt, command.requestId],
    );
    await this.client.query(
      `INSERT INTO agent_talk.security_audit_events (
         audit_id, device_id, action, outcome, target_type, target_id_sha256, safe_code, occurred_at
       ) VALUES ($1, $2, 'approval.resolve', 'allowed', 'approval', $3, $4, $5)`,
      [
        facts.audit.auditId,
        command.deviceId,
        facts.audit.targetIdSha256,
        facts.decision,
        facts.audit.occurredAt,
      ],
    );
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

export class PostgresGatewayLedger implements GatewayLedger, ControlLeaseLedger, ClientLedger, NodeLedger, InteractionLedger {
  constructor(private readonly pool: Pool) {}

  async transaction<T>(work: (transaction: GatewayLedgerTransaction) => Promise<T>): Promise<T> {
    return this.runTransaction(work);
  }

  async leaseTransaction<T>(work: (transaction: ControlLeaseTransaction) => Promise<T>): Promise<T> {
    return this.runTransaction(work);
  }

  async interactionTransaction<T>(work: (transaction: InteractionLedgerTransaction) => Promise<T>): Promise<T> {
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

  async registerNode(registration: NodeRegistrationRecord, now: Date): Promise<void> {
    await this.runTransaction(async (transaction) => {
      const client = transaction.client;
      const node = await client.query(
        `INSERT INTO agent_talk.nodes (
           node_id, display_name, platform, version, status, last_seen_at, current_connection_id
         ) VALUES ($1, $2, $3, $4, 'online', $5, $6)
         ON CONFLICT (node_id) DO UPDATE
         SET display_name = EXCLUDED.display_name,
             platform = EXCLUDED.platform,
             version = EXCLUDED.version,
             status = 'online',
             last_seen_at = EXCLUDED.last_seen_at,
             current_connection_id = EXCLUDED.current_connection_id
         WHERE agent_talk.nodes.status <> 'revoked'
         RETURNING node_id`,
        [
          registration.nodeId,
          registration.displayName,
          registration.platform,
          registration.version,
          now,
          registration.connectionId,
        ],
      );
      if (node.rowCount !== 1) {
        throw new NodeLedgerError("node_revoked", "The authenticated Node has been revoked.");
      }

      const registeredAgentIds: string[] = [];
      for (const agent of registration.agents) {
        const result = await client.query(
          `INSERT INTO agent_talk.agents (
             agent_id, node_id, display_name, adapter, version, status,
             capability_revision, capabilities, max_request_bytes
           ) VALUES ($1, $2, $3, $4, $5, 'online', $6, $7::jsonb, $8)
           ON CONFLICT (agent_id) DO UPDATE
           SET display_name = EXCLUDED.display_name,
               adapter = EXCLUDED.adapter,
               version = EXCLUDED.version,
               status = 'online',
               capability_revision = EXCLUDED.capability_revision,
               capabilities = EXCLUDED.capabilities,
               max_request_bytes = EXCLUDED.max_request_bytes
           WHERE agent_talk.agents.node_id = EXCLUDED.node_id
             AND agent_talk.agents.status <> 'revoked'
           RETURNING agent_id`,
          [
            agent.agentId,
            registration.nodeId,
            agent.displayName,
            agent.adapter,
            agent.version,
            agent.capabilityRevision,
            JSON.stringify(agent.capabilities),
            agent.maxRequestBytes?.toString() ?? null,
          ],
        );
        if (result.rowCount !== 1) {
          throw new NodeLedgerError(
            "agent_identity_conflict",
            "An Agent identity belongs to another Node or has been revoked.",
          );
        }
        registeredAgentIds.push(agent.agentId);
      }

      if (registeredAgentIds.length === 0) {
        await client.query(
          "UPDATE agent_talk.agents SET status = 'offline' WHERE node_id = $1 AND status = 'online'",
          [registration.nodeId],
        );
      } else {
        await client.query(
          `UPDATE agent_talk.agents SET status = 'offline'
           WHERE node_id = $1 AND status = 'online' AND NOT (agent_id = ANY($2::text[]))`,
          [registration.nodeId, registeredAgentIds],
        );
      }
    });
  }

  async claimDispatches(
    nodeId: string,
    connectionId: string,
    now: Date,
    maximum: number,
  ): Promise<readonly ClaimedDispatchRecord[]> {
    if (!Number.isInteger(maximum) || maximum < 1 || maximum > 100) {
      throw new Error("dispatch claim maximum must be between 1 and 100");
    }
    return this.runTransaction(async (transaction) => {
      const result = await transaction.client.query<UnknownRow>(
        `WITH candidates AS (
           SELECT d.outbox_id
           FROM agent_talk.gateway_dispatch_outbox d
           JOIN agent_talk.requests r ON r.request_id = d.request_id
           JOIN agent_talk.agents a ON a.agent_id = r.agent_id AND a.node_id = r.node_id
           JOIN agent_talk.nodes n ON n.node_id = d.node_id
           WHERE d.node_id = $1
             AND n.status = 'online'
             AND n.current_connection_id = $4
             AND (d.state = 'pending' OR (d.state = 'in_flight' AND d.locked_by IS DISTINCT FROM $4))
             AND d.available_at <= $2
             AND a.status = 'online'
             AND a.capability_revision = r.capability_revision
           ORDER BY d.created_at, d.outbox_id
           FOR UPDATE OF d SKIP LOCKED
           LIMIT $3
         ), claimed AS (
           UPDATE agent_talk.gateway_dispatch_outbox d
           SET state = 'in_flight', locked_by = $4, locked_at = $2,
               attempt_count = d.attempt_count + 1
           FROM candidates c
           WHERE d.outbox_id = c.outbox_id
           RETURNING d.outbox_id, d.request_id
         )
         SELECT c.outbox_id, d.dispatch_kind, r.request_id,
                COALESCE(cc.idempotency_key, r.idempotency_key) AS dispatch_idempotency_key,
                cc.target_id, ap.resolution_decision, ap.operation_summary_sha256,
                r.conversation_id,
                r.session_id, r.node_id, r.agent_id, r.capability_revision, r.confirmed_text
         FROM claimed c
         JOIN agent_talk.gateway_dispatch_outbox d ON d.outbox_id = c.outbox_id
         JOIN agent_talk.requests r ON r.request_id = c.request_id
         LEFT JOIN agent_talk.control_commands cc ON cc.command_id = d.control_command_id
         LEFT JOIN agent_talk.approvals ap ON ap.approval_id = cc.target_id
         ORDER BY r.accepted_at, c.outbox_id`,
        [nodeId, now, maximum, connectionId],
      );
      return result.rows.map((value) => {
        const data = row(value);
        const kind = stringAt(data, "dispatch_kind");
        const base = {
          dispatchId: stringAt(data, "outbox_id"),
          requestId: stringAt(data, "request_id"),
          idempotencyKey: stringAt(data, "dispatch_idempotency_key"),
        };
        if (kind === "interrupt") {
          return { ...base, kind };
        }
        if (kind === "approval") {
          const decision = stringAt(data, "resolution_decision");
          if (decision !== "approved" && decision !== "rejected") {
            throw new Error("invalid PostgreSQL approval dispatch decision");
          }
          return {
            ...base,
            kind,
            approvalId: stringAt(data, "target_id"),
            decision,
            operationSummarySha256: stringAt(data, "operation_summary_sha256"),
          };
        }
        if (kind !== "send") {
          throw new Error("unsupported PostgreSQL dispatch kind");
        }
        return {
          ...base,
          kind,
          conversationId: stringAt(data, "conversation_id"),
          sessionId: nullableStringAt(data, "session_id"),
          nodeId: stringAt(data, "node_id"),
          agentId: stringAt(data, "agent_id"),
          capabilityRevision: stringAt(data, "capability_revision"),
          confirmedText: stringAt(data, "confirmed_text"),
        };
      });
    });
  }

  async acknowledgeDispatch(acknowledgement: DispatchAcknowledgement): Promise<void> {
    await this.runTransaction(async (transaction) => {
      const result = await transaction.client.query<UnknownRow>(
        `SELECT d.state, d.ack_accepted, d.last_failure_code, d.failure_stage,
                d.failure_category, d.failure_safe_message, d.failure_retryable,
                d.node_id, d.request_id, d.dispatch_kind, d.control_command_id,
                r.device_id, r.conversation_id, r.session_id,
                r.state AS request_state, n.current_connection_id
         FROM agent_talk.gateway_dispatch_outbox d
         JOIN agent_talk.requests r ON r.request_id = d.request_id
         JOIN agent_talk.nodes n ON n.node_id = d.node_id
         WHERE d.outbox_id = $1
         FOR UPDATE OF d, r, n`,
        [acknowledgement.dispatchId],
      );
      if (result.rows[0] === undefined) {
        throw new NodeLedgerError("dispatch_not_found", "The dispatch was not found.");
      }
      const data = row(result.rows[0]);
      if (
        stringAt(data, "node_id") !== acknowledgement.nodeId ||
        stringAt(data, "request_id") !== acknowledgement.requestId
      ) {
        throw new NodeLedgerError("dispatch_identity_conflict", "The dispatch identity does not match this Node.");
      }
      if (nullableStringAt(data, "current_connection_id") !== acknowledgement.connectionId) {
        throw new NodeLedgerError("stale_node_connection", "The Node connection is no longer current.");
      }
      const state = stringAt(data, "state");
      if (state === "delivered" || state === "dead") {
        const same =
          data.ack_accepted === acknowledgement.accepted &&
          (acknowledgement.failure === null ||
            (data.last_failure_code === acknowledgement.failure.code &&
              data.failure_stage === acknowledgement.failure.stage &&
              data.failure_category === acknowledgement.failure.category &&
              data.failure_safe_message === acknowledgement.failure.safeMessage &&
              data.failure_retryable === acknowledgement.failure.retryable));
        if (!same) {
          throw new NodeLedgerError("dispatch_ack_conflict", "The dispatch already has a different acknowledgement.");
        }
        return;
      }

      if (acknowledgement.accepted) {
        if (acknowledgement.failure !== null) {
          throw new NodeLedgerError("dispatch_ack_conflict", "An accepted dispatch cannot include a failure.");
        }
        await transaction.client.query(
          `UPDATE agent_talk.gateway_dispatch_outbox
           SET state = 'delivered', ack_accepted = true, delivered_at = $2,
               locked_by = NULL, locked_at = NULL
           WHERE outbox_id = $1`,
          [acknowledgement.dispatchId, acknowledgement.occurredAt],
        );
        const controlCommandId = nullableStringAt(data, "control_command_id");
        if (controlCommandId !== null) {
          await transaction.client.query(
            `UPDATE agent_talk.control_commands
             SET state = 'delivered', delivered_at = $2
             WHERE command_id = $1`,
            [controlCommandId, acknowledgement.occurredAt],
          );
        }
        return;
      }

      if (acknowledgement.failure === null) {
        throw new NodeLedgerError("dispatch_ack_conflict", "A rejected dispatch must include a safe failure.");
      }
      const dispatchKind = stringAt(data, "dispatch_kind");
      if (
        dispatchKind === "send" &&
        ["completed", "failed", "cancelled", "interrupted"].includes(stringAt(data, "request_state"))
      ) {
        throw new NodeLedgerError("dispatch_ack_conflict", "A terminal request cannot accept a dispatch rejection.");
      }
      await transaction.client.query(
        `UPDATE agent_talk.gateway_dispatch_outbox
         SET state = 'dead', ack_accepted = false, delivered_at = $2,
             locked_by = NULL, locked_at = NULL,
             last_failure_code = $3, failure_stage = $4, failure_category = $5,
             failure_safe_message = $6, failure_retryable = $7
         WHERE outbox_id = $1`,
        [
          acknowledgement.dispatchId,
          acknowledgement.occurredAt,
          acknowledgement.failure.code,
          acknowledgement.failure.stage,
          acknowledgement.failure.category,
          acknowledgement.failure.safeMessage,
          acknowledgement.failure.retryable,
        ],
      );
      const controlCommandId = nullableStringAt(data, "control_command_id");
      if (dispatchKind !== "send") {
        if (controlCommandId === null) throw new Error("control dispatch lost its command binding");
        await transaction.client.query(
          `UPDATE agent_talk.control_commands
           SET state = 'failed', delivered_at = $2,
               failure_code = $3, failure_stage = $4, failure_category = $5,
               failure_safe_message = $6, failure_retryable = $7
           WHERE command_id = $1`,
          [
            controlCommandId,
            acknowledgement.occurredAt,
            acknowledgement.failure.code,
            acknowledgement.failure.stage,
            acknowledgement.failure.category,
            acknowledgement.failure.safeMessage,
            acknowledgement.failure.retryable,
          ],
        );
        return;
      }
      const conversationId = stringAt(data, "conversation_id");
      const sequence = await transaction.allocateConversationSequence(conversationId);
      if (sequence === undefined) {
        throw new Error("dispatch request conversation disappeared before failure allocation");
      }
      const eventId = `dispatch-failure-${acknowledgement.dispatchId}`;
      await transaction.client.query(
        `UPDATE agent_talk.requests
         SET state = 'failed', finalized_at = $2,
             failure_code = $3, failure_stage = $4, failure_category = $5,
             failure_safe_message = $6, failure_retryable = $7
         WHERE request_id = $1`,
        [
          acknowledgement.requestId,
          acknowledgement.occurredAt,
          acknowledgement.failure.code,
          acknowledgement.failure.stage,
          acknowledgement.failure.category,
          acknowledgement.failure.safeMessage,
          acknowledgement.failure.retryable,
        ],
      );
      await transaction.client.query(
        `INSERT INTO agent_talk.events (
           event_id, connection_id, device_id, conversation_id, session_id, request_id,
           sequence, event_type, safe_payload, occurred_at
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'request.failed', $8::jsonb, $9)`,
        [
          eventId,
          acknowledgement.connectionId,
          stringAt(data, "device_id"),
          conversationId,
          nullableStringAt(data, "session_id"),
          acknowledgement.requestId,
          sequence.toString(),
          JSON.stringify({ failure: acknowledgement.failure }),
          acknowledgement.occurredAt,
        ],
      );
      await transaction.client.query(
        `INSERT INTO agent_talk.gateway_event_outbox (
           outbox_id, event_id, conversation_id, sequence, available_at, created_at
         ) VALUES ($1, $2, $3, $4, $5, $5)`,
        [`event-outbox-${eventId}`, eventId, conversationId, sequence.toString(), acknowledgement.occurredAt],
      );
    });
  }

  async ingestNodeEvent(event: NodeEventInput): Promise<StoredNodeEvent> {
    return this.runTransaction(async (transaction) => {
      const client = transaction.client;
      const existing = await client.query<UnknownRow>(
        `SELECT event_id, conversation_id, request_id, sequence, source_sequence, event_type,
                safe_payload = $2::jsonb AS same_payload
         FROM agent_talk.events WHERE event_id = $1 FOR UPDATE`,
        [event.eventId, JSON.stringify(event.safePayload)],
      );
      if (existing.rows[0] !== undefined) {
        const nodeResult = await client.query<UnknownRow>(
          "SELECT current_connection_id FROM agent_talk.nodes WHERE node_id = $1 FOR KEY SHARE",
          [event.nodeId],
        );
        if (
          nodeResult.rows[0] === undefined ||
          nullableStringAt(row(nodeResult.rows[0]), "current_connection_id") !== event.connectionId
        ) {
          throw new NodeLedgerError("stale_node_connection", "The Node connection is no longer current.");
        }
        const data = row(existing.rows[0]);
        if (
          stringAt(data, "request_id") !== event.requestId ||
          stringAt(data, "conversation_id") !== event.conversationId ||
          stringAt(data, "event_type") !== event.eventType ||
          nullableBigintAt(data, "source_sequence") !== event.sourceSequence ||
          !booleanAt(data, "same_payload")
        ) {
          throw new NodeLedgerError("event_identity_conflict", "The event identity is already bound elsewhere.");
        }
        return {
          eventId: event.eventId,
          conversationId: event.conversationId,
          sequence: bigintAt(data, "sequence"),
          duplicate: true,
        };
      }

      const requestResult = await client.query<UnknownRow>(
        `SELECT r.request_id, r.device_id, r.conversation_id, r.session_id, r.node_id, r.agent_id, r.state,
                n.current_connection_id
         FROM agent_talk.requests r
         JOIN agent_talk.nodes n ON n.node_id = r.node_id
         WHERE r.request_id = $1
         FOR UPDATE OF r, n`,
        [event.requestId],
      );
      if (requestResult.rows[0] === undefined) {
        throw new NodeLedgerError("request_not_found", "The event request was not found.");
      }
      const request = row(requestResult.rows[0]);
      if (
        stringAt(request, "node_id") !== event.nodeId ||
        stringAt(request, "conversation_id") !== event.conversationId ||
        nullableStringAt(request, "session_id") !== event.sessionId
      ) {
        throw new NodeLedgerError("event_identity_conflict", "The event does not match the accepted request route.");
      }
      if (nullableStringAt(request, "current_connection_id") !== event.connectionId) {
        throw new NodeLedgerError("stale_node_connection", "The Node connection is no longer current.");
      }
      if (["completed", "failed", "cancelled", "interrupted"].includes(stringAt(request, "state"))) {
        throw new NodeLedgerError("event_after_terminal", "A terminal request cannot accept another event.");
      }

      const latestSource = await client.query<UnknownRow>(
        `SELECT max(source_sequence) AS source_sequence
         FROM agent_talk.events
         WHERE request_id = $1 AND source_sequence IS NOT NULL`,
        [event.requestId],
      );
      const lastSourceSequence = latestSource.rows[0] === undefined
        ? null
        : nullableBigintAt(row(latestSource.rows[0]), "source_sequence");
      if (lastSourceSequence !== null && event.sourceSequence <= lastSourceSequence) {
        throw new NodeLedgerError("stale_node_event", "The Node event source sequence is stale or out of order.");
      }

      const interaction = event.interaction;
      if (interaction?.kind === "approval_required") {
        const existingApproval = await client.query(
          `SELECT 1 FROM agent_talk.approvals
           WHERE approval_id = $1 OR (request_id = $2 AND native_approval_id = $3)
           FOR UPDATE`,
          [interaction.approvalId, event.requestId, interaction.nativeApprovalId],
        );
        if (existingApproval.rowCount !== 0) {
          throw new NodeLedgerError("interaction_conflict", "The approval identity is already bound.");
        }
        await client.query(
          `INSERT INTO agent_talk.approvals (
             approval_id, request_id, node_id, agent_id, native_approval_id,
             operation_summary_sha256, safe_summary, state, expires_at, created_at
           ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending', $8, $9)`,
          [
            interaction.approvalId,
            event.requestId,
            event.nodeId,
            stringAt(request, "agent_id"),
            interaction.nativeApprovalId,
            interaction.operationSummarySha256,
            interaction.safeSummary,
            interaction.expiresAt,
            event.occurredAt,
          ],
        );
      } else if (interaction?.kind === "approval_state") {
        const approval = await client.query<UnknownRow>(
          `SELECT state, operation_summary_sha256
           FROM agent_talk.approvals
           WHERE approval_id = $1 AND request_id = $2 AND node_id = $3
           FOR UPDATE`,
          [interaction.approvalId, event.requestId, event.nodeId],
        );
        if (approval.rows[0] === undefined) {
          throw new NodeLedgerError("interaction_conflict", "The approval state event has no pending approval.");
        }
        const approvalRow = row(approval.rows[0]);
        if (stringAt(approvalRow, "operation_summary_sha256") !== interaction.operationSummarySha256) {
          throw new NodeLedgerError("interaction_conflict", "The approval summary identity changed.");
        }
        const currentState = stringAt(approvalRow, "state");
        if (interaction.state === "resolved") {
          if (!["approved", "rejected"].includes(currentState)) {
            throw new NodeLedgerError("interaction_conflict", "The approval was not resolved by an authorized Client.");
          }
        } else {
          if (currentState !== "pending") {
            throw new NodeLedgerError("interaction_conflict", "The approval is already terminal.");
          }
          await client.query(
            `UPDATE agent_talk.approvals SET state = $2, resolved_at = $3 WHERE approval_id = $1`,
            [interaction.approvalId, interaction.state, event.occurredAt],
          );
        }
      } else if (interaction?.kind === "clarification_required") {
        const existingClarification = await client.query(
          `SELECT 1 FROM agent_talk.clarifications
           WHERE clarification_id = $1 OR (request_id = $2 AND native_clarification_id = $3)
           FOR UPDATE`,
          [interaction.clarificationId, event.requestId, interaction.nativeClarificationId],
        );
        if (existingClarification.rowCount !== 0) {
          throw new NodeLedgerError("interaction_conflict", "The clarification identity is already bound.");
        }
        await client.query(
          `INSERT INTO agent_talk.clarifications (
             clarification_id, request_id, node_id, agent_id, native_clarification_id,
             safe_prompt, state, expires_at, created_at
           ) VALUES ($1, $2, $3, $4, $5, $6, 'pending', $7, $8)`,
          [
            interaction.clarificationId,
            event.requestId,
            event.nodeId,
            stringAt(request, "agent_id"),
            interaction.nativeClarificationId,
            interaction.safePrompt,
            interaction.expiresAt,
            event.occurredAt,
          ],
        );
      } else if (interaction?.kind === "clarification_state") {
        const clarification = await client.query<UnknownRow>(
          `SELECT state FROM agent_talk.clarifications
           WHERE clarification_id = $1 AND request_id = $2 AND node_id = $3
           FOR UPDATE`,
          [interaction.clarificationId, event.requestId, event.nodeId],
        );
        if (clarification.rows[0] === undefined) {
          throw new NodeLedgerError("interaction_conflict", "The clarification state event has no pending clarification.");
        }
        const currentState = stringAt(row(clarification.rows[0]), "state");
        if (interaction.state === "resolved") {
          if (currentState !== "resolved") {
            throw new NodeLedgerError("interaction_conflict", "The clarification was not resolved by an authorized Client.");
          }
        } else {
          if (currentState !== "pending") {
            throw new NodeLedgerError("interaction_conflict", "The clarification is already terminal.");
          }
          await client.query(
            `UPDATE agent_talk.clarifications SET state = $2, resolved_at = $3 WHERE clarification_id = $1`,
            [interaction.clarificationId, interaction.state, event.occurredAt],
          );
        }
      }

      const sequence = await transaction.allocateConversationSequence(event.conversationId);
      if (sequence === undefined) {
        throw new Error("event conversation disappeared before sequence allocation");
      }
      await client.query(
        `INSERT INTO agent_talk.events (
           event_id, connection_id, device_id, conversation_id, session_id, request_id,
           sequence, source_sequence, event_type, safe_payload, occurred_at
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, $11)`,
        [
          event.eventId,
          event.connectionId,
          stringAt(request, "device_id"),
          event.conversationId,
          event.sessionId,
          event.requestId,
          sequence.toString(),
          event.sourceSequence.toString(),
          event.eventType,
          JSON.stringify(event.safePayload),
          event.occurredAt,
        ],
      );
      await client.query(
        `INSERT INTO agent_talk.gateway_event_outbox (
           outbox_id, event_id, conversation_id, sequence, available_at, created_at
         ) VALUES ($1, $2, $3, $4, $5, $5)`,
        [`event-outbox-${event.eventId}`, event.eventId, event.conversationId, sequence.toString(), event.occurredAt],
      );

      if (event.requestState !== null) {
        const terminal = ["completed", "failed", "cancelled", "interrupted"].includes(event.requestState);
        if (terminal) {
          await client.query(
            `UPDATE agent_talk.approvals
             SET state = 'cancelled', resolved_at = $2
             WHERE request_id = $1 AND state = 'pending'`,
            [event.requestId, event.occurredAt],
          );
          await client.query(
            `UPDATE agent_talk.clarifications
             SET state = 'cancelled', resolved_at = $2
             WHERE request_id = $1 AND state = 'pending'`,
            [event.requestId, event.occurredAt],
          );
        }
        await client.query(
          `UPDATE agent_talk.requests
           SET state = $2,
               finalized_at = CASE WHEN $3 THEN $4 ELSE finalized_at END,
               failure_code = $5,
               failure_stage = $6,
               failure_category = $7,
               failure_safe_message = $8,
               failure_retryable = $9
           WHERE request_id = $1`,
          [
            event.requestId,
            event.requestState,
            terminal,
            event.occurredAt,
            event.failure?.code ?? null,
            event.failure?.stage ?? null,
            event.failure?.category ?? null,
            event.failure?.safeMessage ?? null,
            event.failure?.retryable ?? null,
          ],
        );
      }
      return { eventId: event.eventId, conversationId: event.conversationId, sequence, duplicate: false };
    });
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
