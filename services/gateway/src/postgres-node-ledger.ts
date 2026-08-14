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
  row,
  stringAt,
  type UnknownRow,
} from "./postgres-row-codecs.js";
import { runPostgresTransaction } from "./postgres-gateway-transaction.js";

export async function registerNode(pool: Pool, registration: NodeRegistrationRecord, now: Date): Promise<void> {
  await runPostgresTransaction(pool, async (transaction) => {
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

export async function claimDispatches(pool: Pool,
  nodeId: string,
  connectionId: string,
  now: Date,
  maximum: number,
): Promise<readonly ClaimedDispatchRecord[]> {
  if (!Number.isInteger(maximum) || maximum < 1 || maximum > 100) {
    throw new Error("dispatch claim maximum must be between 1 and 100");
  }
  return runPostgresTransaction(pool, async (transaction) => {
    const result = await transaction.client.query<UnknownRow>(
      `WITH candidates AS (
         SELECT d.outbox_id
         FROM agent_talk.gateway_dispatch_outbox d
         JOIN agent_talk.requests r ON r.request_id = d.request_id
         JOIN agent_talk.conversations c ON c.conversation_id = r.conversation_id
         JOIN agent_talk.agents a ON a.agent_id = r.agent_id AND a.node_id = r.node_id
         JOIN agent_talk.nodes n ON n.node_id = d.node_id
         WHERE d.node_id = $1
           AND n.status = 'online'
           AND n.current_connection_id = $4
           AND (d.state = 'pending' OR (d.state = 'in_flight' AND d.locked_by IS DISTINCT FROM $4))
           AND d.available_at <= $2
           AND a.status = 'online'
           AND a.capability_revision = r.capability_revision
           AND r.node_id = c.node_id
           AND r.agent_id = c.agent_id
           AND r.capability_revision = c.capability_revision
           AND r.session_id IS NOT DISTINCT FROM c.session_id
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
              cl.confirmed_text AS clarification_confirmed_text,
              r.conversation_id,
              conversation.session_id, conversation.node_id, conversation.agent_id,
              conversation.capability_revision, r.confirmed_text
       FROM claimed c
       JOIN agent_talk.gateway_dispatch_outbox d ON d.outbox_id = c.outbox_id
       JOIN agent_talk.requests r ON r.request_id = c.request_id
       JOIN agent_talk.conversations conversation ON conversation.conversation_id = r.conversation_id
       LEFT JOIN agent_talk.control_commands cc ON cc.command_id = d.control_command_id
       LEFT JOIN agent_talk.approvals ap ON ap.approval_id = cc.target_id
       LEFT JOIN agent_talk.clarifications cl ON cl.clarification_id = cc.target_id
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
      if (kind === "clarification") {
        return {
          ...base,
          kind,
          clarificationId: stringAt(data, "target_id"),
          confirmedText: stringAt(data, "clarification_confirmed_text"),
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

export async function acknowledgeDispatch(pool: Pool, acknowledgement: DispatchAcknowledgement): Promise<void> {
  await runPostgresTransaction(pool, async (transaction) => {
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

export async function ingestNodeEvent(pool: Pool, event: NodeEventInput): Promise<StoredNodeEvent> {
  return runPostgresTransaction(pool, async (transaction) => {
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
      `SELECT r.request_id, r.device_id, r.conversation_id, r.session_id, r.node_id, r.agent_id,
              r.capability_revision, r.state, c.node_id AS conversation_node_id,
              c.agent_id AS conversation_agent_id, c.capability_revision AS conversation_capability_revision,
              c.session_id AS conversation_session_id, n.current_connection_id
       FROM agent_talk.requests r
       JOIN agent_talk.conversations c ON c.conversation_id = r.conversation_id
       JOIN agent_talk.nodes n ON n.node_id = r.node_id
       WHERE r.request_id = $1
       FOR UPDATE OF r, c, n`,
      [event.requestId],
    );
    if (requestResult.rows[0] === undefined) {
      throw new NodeLedgerError("request_not_found", "The event request was not found.");
    }
    const request = row(requestResult.rows[0]);
    const conversationSessionId = nullableStringAt(request, "conversation_session_id");
    if (conversationSessionId === null && event.sessionId !== null) {
      await client.query(
        `UPDATE agent_talk.conversations
         SET session_id = $2, revision = revision + 1, updated_at = clock_timestamp()
         WHERE conversation_id = $1 AND session_id IS NULL`,
        [event.conversationId, event.sessionId],
      );
      await client.query(
        `UPDATE agent_talk.requests
         SET session_id = $2
         WHERE conversation_id = $1 AND session_id IS NULL
           AND state NOT IN ('completed', 'failed', 'cancelled', 'interrupted')`,
        [event.conversationId, event.sessionId],
      );
    }
    const effectiveSessionId = conversationSessionId ?? event.sessionId;
    if (
      stringAt(request, "node_id") !== event.nodeId ||
      stringAt(request, "conversation_id") !== event.conversationId ||
      stringAt(request, "node_id") !== nullableStringAt(request, "conversation_node_id") ||
      stringAt(request, "agent_id") !== nullableStringAt(request, "conversation_agent_id") ||
      stringAt(request, "capability_revision") !== nullableStringAt(request, "conversation_capability_revision") ||
      (conversationSessionId !== null && nullableStringAt(request, "session_id") !== conversationSessionId) ||
      effectiveSessionId !== event.sessionId
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
