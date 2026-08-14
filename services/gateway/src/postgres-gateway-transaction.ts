import type { Pool, PoolClient } from "pg";

import {
  bigintAt,
  booleanAt,
  dateAt,
  nullableBigintAt,
  nullableStringAt,
  parseControlCommand,
  parseRequest,
  requestColumns,
  requestColumnsFromR,
  row,
  stringAt,
  controlCommandColumns,
  type UnknownRow,
} from "./postgres-row-codecs.js";
import type {
  ControlLeaseChange,
  ControlLeaseTransaction,
} from "./control-lease.js";
import type {
  AcceptanceFacts,
  AcceptedRequestRecord,
  AgentTargetRecord,
  ControlLeaseRecord,
  ConversationRouteRecord,
  DeviceRecord,
  GatewayLedgerTransaction,
} from "./ledger.js";
import type {
  ApprovalRecord,
  ApprovalResolutionFacts,
  ClarificationRecord,
  ClarificationResolutionFacts,
  ControlCommandRecord,
  DeviceSignatureCredentialRecord,
  InteractionLedgerTransaction,
  InteractionRequestRecord,
  InterruptAcceptanceFacts,
} from "./interaction-ledger.js";
import {
  NodeLedgerError,
  type NodeRegistrationRecord,
} from "./node-ledger.js";

export class PostgresGatewayTransaction implements GatewayLedgerTransaction, ControlLeaseTransaction, InteractionLedgerTransaction {
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

  async lockConversationRoute(conversationId: string): Promise<ConversationRouteRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT conversation_id, node_id, agent_id, capability_revision, session_id
       FROM agent_talk.conversations
       WHERE conversation_id = $1
       FOR UPDATE`,
      [conversationId],
    );
    if (result.rows[0] === undefined) return undefined;
    const data = row(result.rows[0]);
    const nodeId = nullableStringAt(data, "node_id");
    const agentId = nullableStringAt(data, "agent_id");
    const capabilityRevision = nullableStringAt(data, "capability_revision");
    if (nodeId === null || agentId === null || capabilityRevision === null) {
      throw new Error("conversation has no authoritative Agent route");
    }
    return {
      conversationId: stringAt(data, "conversation_id"),
      nodeId,
      agentId,
      capabilityRevision,
      sessionId: nullableStringAt(data, "session_id"),
    };
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
              COALESCE((a.capabilities->>'interrupt')::boolean, false) AS interrupt_capable,
              COALESCE((a.capabilities->>'clarification')::boolean, false) AS clarification_capable,
              a.max_request_bytes
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
      clarificationCapable: booleanAt(data, "clarification_capable"),
      maxRequestBytes: nullableBigintAt(data, "max_request_bytes"),
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

  async lockDeviceSignatureCredential(
    credentialId: string,
  ): Promise<DeviceSignatureCredentialRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT c.credential_id, c.device_id, c.state = 'active' AS active,
              d.status = 'active' AS device_active, c.public_key_spki,
              c.public_key_sha256, c.gateway_audience, c.scopes
       FROM agent_talk.device_credentials c
       JOIN agent_talk.devices d ON d.device_id = c.device_id
       WHERE c.credential_id = $1 FOR UPDATE OF c`,
      [credentialId],
    );
    const current = result.rows[0];
    if (current === undefined) return undefined;
    const data = row(current);
    const key = data.public_key_spki;
    const scopes = data.scopes;
    if (!(key instanceof Uint8Array) || !Array.isArray(scopes) || !scopes.every((scope) => typeof scope === "string")) {
      throw new Error("invalid PostgreSQL device signature credential");
    }
    return {
      credentialId: stringAt(data, "credential_id"),
      deviceId: stringAt(data, "device_id"),
      active: booleanAt(data, "active"),
      deviceActive: booleanAt(data, "device_active"),
      publicKeySpki: new Uint8Array(key),
      publicKeySha256: stringAt(data, "public_key_sha256"),
      gatewayAudience: stringAt(data, "gateway_audience"),
      scopes,
    };
  }

  async recordDeviceSignatureNonce(
    credentialId: string,
    purpose: string,
    nonceSha256: string,
    usedAt: Date,
  ): Promise<boolean> {
    const result = await this.client.query(
      `INSERT INTO agent_talk.device_signature_nonces (credential_id, purpose, nonce_sha256, used_at)
       VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING`,
      [credentialId, purpose, nonceSha256, usedAt],
    );
    return result.rowCount === 1;
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

  async lockClarification(
    clarificationId: string,
    requestId: string,
  ): Promise<ClarificationRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT clarification_id, request_id, node_id, agent_id, state, expires_at
       FROM agent_talk.clarifications
       WHERE clarification_id = $1 AND request_id = $2
       FOR UPDATE`,
      [clarificationId, requestId],
    );
    if (result.rows[0] === undefined) return undefined;
    const data = row(result.rows[0]);
    return {
      clarificationId: stringAt(data, "clarification_id"),
      requestId: stringAt(data, "request_id"),
      nodeId: stringAt(data, "node_id"),
      agentId: stringAt(data, "agent_id"),
      state: stringAt(data, "state") as ClarificationRecord["state"],
      expiresAt: dateAt(data, "expires_at"),
    };
  }

  async expireClarification(clarificationId: string, occurredAt: Date): Promise<boolean> {
    const result = await this.client.query(
      `UPDATE agent_talk.clarifications
       SET state = 'expired', resolved_at = $2
       WHERE clarification_id = $1 AND state = 'pending'`,
      [clarificationId, occurredAt],
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

  async insertClarificationResolution(facts: ClarificationResolutionFacts): Promise<void> {
    const command = facts.command;
    const clarification = await this.client.query(
      `UPDATE agent_talk.clarifications
       SET state = 'resolved', resolved_by_device_id = $2, resolution_idempotency_key = $3,
           resolution_command_id = $4, confirmed_text = $5, resolved_at = $6
       WHERE clarification_id = $1 AND request_id = $7 AND state = 'pending'`,
      [
        facts.clarificationId,
        command.deviceId,
        command.idempotencyKey,
        command.commandId,
        facts.confirmedText,
        command.createdAt,
        command.requestId,
      ],
    );
    if (clarification.rowCount !== 1) throw new Error("locked clarification changed before resolution insert");
    await this.client.query(
      `INSERT INTO agent_talk.control_commands (
         command_id, idempotency_key, device_id, conversation_id, request_id,
         command_kind, target_id, payload_sha256, state, created_at
       ) VALUES ($1, $2, $3, $4, $5, 'clarification', $6, $7, 'accepted', $8)`,
      [
        command.commandId,
        command.idempotencyKey,
        command.deviceId,
        command.conversationId,
        command.requestId,
        facts.clarificationId,
        command.payloadSha256,
        command.createdAt,
      ],
    );
    await this.client.query(
      `INSERT INTO agent_talk.gateway_dispatch_outbox (
         outbox_id, request_id, node_id, dispatch_kind, control_command_id, available_at, created_at
       ) SELECT $1, r.request_id, r.node_id, 'clarification', $2, $3, $3
         FROM agent_talk.requests r WHERE r.request_id = $4`,
      [facts.dispatchOutboxId, command.commandId, command.createdAt, command.requestId],
    );
    await this.client.query(
      `INSERT INTO agent_talk.security_audit_events (
         audit_id, device_id, action, outcome, target_type, target_id_sha256, safe_code, occurred_at
       ) VALUES ($1, $2, 'clarification.resolve', 'allowed', 'clarification', $3, 'submitted', $4)`,
      [facts.audit.auditId, command.deviceId, facts.audit.targetIdSha256, facts.audit.occurredAt],
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
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8,
                 jsonb_build_object('confirmedText', $9::text), $10)`,
      [
        facts.event.eventId,
        facts.event.connectionId,
        facts.event.deviceId,
        facts.event.conversationId,
        facts.event.sessionId,
        facts.event.requestId,
        facts.event.sequence.toString(),
        facts.event.type,
        facts.confirmedText,
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

export async function runPostgresTransaction<T>(
  pool: Pool,
  work: (transaction: PostgresGatewayTransaction) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
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
