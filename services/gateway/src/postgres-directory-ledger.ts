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

export async function listDirectory(pool: Pool): Promise<GatewayDirectoryRecord> {
  const [nodes, agents, conversations] = await Promise.all([
    pool.query<UnknownRow>(
      `SELECT node_id, display_name, platform, version
       FROM agent_talk.nodes WHERE status <> 'revoked'
       ORDER BY display_name, node_id`,
    ),
    pool.query<UnknownRow>(
      `SELECT agent_id, node_id, display_name, adapter, version,
              capability_revision, capabilities
       FROM agent_talk.agents WHERE status <> 'revoked'
       ORDER BY display_name, node_id, agent_id`,
    ),
    pool.query<UnknownRow>(
      `SELECT conversation_id, title, node_id, agent_id, capability_revision,
              session_id, revision, last_sequence
       FROM agent_talk.conversations
       WHERE title IS NOT NULL
         AND node_id IS NOT NULL
         AND agent_id IS NOT NULL
         AND capability_revision IS NOT NULL
       ORDER BY updated_at DESC, conversation_id`,
    ),
  ]);
  return {
    nodes: nodes.rows.map((value) => {
      const data = row(value);
      return {
        nodeId: stringAt(data, "node_id"),
        displayName: stringAt(data, "display_name"),
        platform: stringAt(data, "platform"),
        version: stringAt(data, "version"),
      };
    }),
    agents: agents.rows.map((value) => {
      const data = row(value);
      return {
        agentId: stringAt(data, "agent_id"),
        nodeId: stringAt(data, "node_id"),
        displayName: stringAt(data, "display_name"),
        adapter: stringAt(data, "adapter"),
        version: stringAt(data, "version"),
        capabilityRevision: stringAt(data, "capability_revision"),
        capabilities: data.capabilities,
      };
    }),
    conversations: conversations.rows.map(parseDirectoryConversation),
  };
}

export async function createConversation(pool: Pool, input: CreateConversationInput): Promise<DirectoryConversationRecord> {
  const reconcileExisting = (values: readonly UnknownRow[]): DirectoryConversationRecord | undefined => {
    for (const value of values) {
      const data = row(value);
      const same =
        stringAt(data, "conversation_id") === input.conversationId &&
        nullableStringAt(data, "title") === input.title &&
        nullableStringAt(data, "node_id") === input.nodeId &&
        nullableStringAt(data, "agent_id") === input.agentId &&
        nullableStringAt(data, "capability_revision") === input.capabilityRevision &&
        nullableStringAt(data, "session_id") === input.sessionId &&
        stringAt(data, "created_by_device_id") === input.deviceId &&
        nullableStringAt(data, "created_command_id") === input.commandId &&
        nullableStringAt(data, "created_idempotency_key") === input.idempotencyKey;
      if (same) return parseDirectoryConversation(data);
      if (stringAt(data, "conversation_id") === input.conversationId) {
        throw new DirectoryLedgerError("conversation_identity_conflict", "The conversation identity is already bound.");
      }
      if (nullableStringAt(data, "created_command_id") === input.commandId) {
        throw new DirectoryLedgerError("command_id_conflict", "The command identity is already bound.");
      }
      throw new DirectoryLedgerError("idempotency_conflict", "The idempotency identity is already bound.");
    }
    return undefined;
  };
  return runPostgresTransaction(pool, async ({ client }) => {
    const existing = await client.query<UnknownRow>(
      `SELECT conversation_id, title, node_id, agent_id, capability_revision,
              session_id, revision, last_sequence, created_by_device_id,
              created_command_id, created_idempotency_key
       FROM agent_talk.conversations
       WHERE conversation_id = $1
          OR (created_by_device_id = $2 AND created_command_id = $3)
          OR (created_by_device_id = $2 AND created_idempotency_key = $4)
       FOR UPDATE`,
      [input.conversationId, input.deviceId, input.commandId, input.idempotencyKey],
    );
    const reconciled = reconcileExisting(existing.rows);
    if (reconciled !== undefined) return reconciled;

    const target = await client.query<UnknownRow>(
      `SELECT a.capability_revision
       FROM agent_talk.agents a
       JOIN agent_talk.nodes n ON n.node_id = a.node_id
       WHERE a.node_id = $1 AND a.agent_id = $2
         AND a.status <> 'revoked' AND n.status <> 'revoked'
       FOR SHARE OF a, n`,
      [input.nodeId, input.agentId],
    );
    if (target.rows[0] === undefined) {
      throw new DirectoryLedgerError("agent_not_found", "The selected Agent route does not exist.");
    }
    if (stringAt(row(target.rows[0]), "capability_revision") !== input.capabilityRevision) {
      throw new DirectoryLedgerError("capability_revision_changed", "The selected Agent capability changed.");
    }
    if (input.sessionId !== null) {
      const existingSession = await client.query<UnknownRow>(
        `SELECT conversation_id FROM agent_talk.conversations
         WHERE node_id = $1 AND agent_id = $2 AND capability_revision = $3 AND session_id = $4
         FOR KEY SHARE`,
        [input.nodeId, input.agentId, input.capabilityRevision, input.sessionId],
      );
      if (existingSession.rowCount !== 0) {
        throw new DirectoryLedgerError(
          "session_route_conflict",
          "The Hermes session is already bound to another conversation route.",
        );
      }
    }
    const inserted = await client.query<UnknownRow>(
      `INSERT INTO agent_talk.conversations (
         conversation_id, created_by_device_id, last_sequence, revision,
         created_at, updated_at, title, node_id, agent_id,
         capability_revision, session_id, created_command_id,
         created_idempotency_key
       ) VALUES ($1, $2, 0, 1, $3, $3, $4, $5, $6, $7, $8, $9, $10)
       ON CONFLICT DO NOTHING
       RETURNING conversation_id, title, node_id, agent_id,
                 capability_revision, session_id, revision, last_sequence`,
      [input.conversationId, input.deviceId, input.now, input.title,
       input.nodeId, input.agentId, input.capabilityRevision, input.sessionId,
       input.commandId, input.idempotencyKey],
    );
    if (inserted.rows[0] !== undefined) {
      return parseDirectoryConversation(row(inserted.rows[0]));
    }
    const raced = await client.query<UnknownRow>(
      `SELECT conversation_id, title, node_id, agent_id, capability_revision,
              session_id, revision, last_sequence, created_by_device_id,
              created_command_id, created_idempotency_key
       FROM agent_talk.conversations
       WHERE conversation_id = $1
          OR (created_by_device_id = $2 AND created_command_id = $3)
          OR (created_by_device_id = $2 AND created_idempotency_key = $4)
       FOR UPDATE`,
      [input.conversationId, input.deviceId, input.commandId, input.idempotencyKey],
    );
    const racedResult = reconcileExisting(raced.rows);
    if (racedResult !== undefined) return racedResult;
    if (input.sessionId !== null) {
      const sessionOwner = await client.query<UnknownRow>(
        `SELECT conversation_id FROM agent_talk.conversations
         WHERE node_id = $1 AND agent_id = $2 AND capability_revision = $3 AND session_id = $4`,
        [input.nodeId, input.agentId, input.capabilityRevision, input.sessionId],
      );
      if (sessionOwner.rowCount !== 0) {
        throw new DirectoryLedgerError(
          "session_route_conflict",
          "The Hermes session is already bound to another conversation route.",
        );
      }
    }
    throw new DirectoryLedgerError("idempotency_conflict", "The conversation identity could not be reconciled.");
  });
}
