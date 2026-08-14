import type {
  AcceptedRequestRecord,
} from "./ledger.js";
import type { DirectoryConversationRecord } from "./directory-ledger.js";
import type { ControlCommandRecord } from "./interaction-ledger.js";

export type UnknownRow = Record<string, unknown>;

export function row(value: unknown): UnknownRow {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error("invalid PostgreSQL row");
  }
  return value as UnknownRow;
}

export function stringAt(value: UnknownRow, key: string): string {
  const field = value[key];
  if (typeof field !== "string") {
    throw new Error(`invalid PostgreSQL ${key}`);
  }
  return field;
}

export function nullableStringAt(value: UnknownRow, key: string): string | null {
  const field = value[key];
  if (field === null) {
    return null;
  }
  if (typeof field !== "string") {
    throw new Error(`invalid PostgreSQL ${key}`);
  }
  return field;
}

export function bigintAt(value: UnknownRow, key: string): bigint {
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

export function nullableBigintAt(value: UnknownRow, key: string): bigint | null {
  return value[key] === null ? null : bigintAt(value, key);
}

export function booleanAt(value: UnknownRow, key: string): boolean {
  const field = value[key];
  if (typeof field !== "boolean") {
    throw new Error(`invalid PostgreSQL ${key}`);
  }
  return field;
}

export function dateAt(value: UnknownRow, key: string): Date {
  const field = value[key];
  if (field instanceof Date && !Number.isNaN(field.getTime())) {
    return field;
  }
  throw new Error(`invalid PostgreSQL ${key}`);
}

export function parseRequest(value: unknown): AcceptedRequestRecord {
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

export function parseDirectoryConversation(value: unknown): DirectoryConversationRecord {
  const data = row(value);
  return {
    conversationId: stringAt(data, "conversation_id"),
    title: stringAt(data, "title"),
    nodeId: stringAt(data, "node_id"),
    agentId: stringAt(data, "agent_id"),
    capabilityRevision: stringAt(data, "capability_revision"),
    sessionId: nullableStringAt(data, "session_id"),
    revision: bigintAt(data, "revision"),
    lastSequence: bigintAt(data, "last_sequence"),
  };
}

export function parseControlCommand(value: unknown): ControlCommandRecord {
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

export const requestColumns = `
  request_id, command_id, idempotency_key, device_id, accepted_connection_id,
  conversation_id, session_id, node_id, agent_id, capability_revision,
  confirmed_text_sha256, accepted_sequence, accepted_at
`;

export const requestColumnsFromR = `
  r.request_id AS request_id, r.command_id AS command_id, r.idempotency_key AS idempotency_key,
  r.device_id AS device_id, r.accepted_connection_id AS accepted_connection_id,
  r.conversation_id AS conversation_id, r.session_id AS session_id, r.node_id AS node_id,
  r.agent_id AS agent_id, r.capability_revision AS capability_revision,
  r.confirmed_text_sha256 AS confirmed_text_sha256,
  r.accepted_sequence AS accepted_sequence, r.accepted_at AS accepted_at
`;

export const controlCommandColumns = `
  command_id, idempotency_key, device_id, conversation_id, request_id,
  command_kind, target_id, payload_sha256, state, failure_stage,
  failure_category, failure_code, failure_safe_message, failure_retryable, created_at
`;
