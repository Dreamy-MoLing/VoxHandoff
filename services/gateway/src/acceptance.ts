import { createHash, randomUUID } from "node:crypto";

import type { FailureCategory, FailureStage } from "@agent-talk/core";

import {
  type AcceptanceFacts,
  type AcceptedRequestRecord,
  type GatewayLedger,
  requiredSendScope,
} from "./ledger.js";

export interface AcceptRequestInput {
  requestId: string;
  commandId: string;
  idempotencyKey: string;
  deviceId: string;
  connectionId: string;
  conversationId: string;
  sessionId?: string;
  leaseId: string;
  leaseRevision: bigint;
  nodeId: string;
  agentId: string;
  capabilityRevision: string;
  confirmedText: string;
}

export interface AcceptanceDependencies {
  now(): Date;
  newOpaqueId(): string;
}

export type AcceptanceResult =
  | { kind: "accepted"; facts: AcceptanceFacts }
  | { kind: "existing"; request: AcceptedRequestRecord };

export type GatewayCommandErrorCode =
  | "invalid_command"
  | "device_not_found"
  | "device_revoked"
  | "scope_missing"
  | "idempotency_conflict"
  | "command_id_conflict"
  | "request_id_conflict"
  | "conversation_not_found"
  | "conversation_route_mismatch"
  | "control_lease_lost"
  | "control_lease_conflict"
  | "control_lease_takeover_required"
  | "agent_unavailable"
  | "capability_revision_changed"
  | "request_too_large";

export class GatewayCommandError extends Error {
  readonly retryable = false;
  readonly stage: FailureStage;
  readonly category: FailureCategory;

  constructor(
    readonly code: GatewayCommandErrorCode,
    message: string,
  ) {
    super(message);
    this.name = "GatewayCommandError";
    const classification = errorClassifications[code];
    this.stage = classification.stage;
    this.category = classification.category;
  }
}

const errorClassifications: Record<
  GatewayCommandErrorCode,
  { stage: FailureStage; category: FailureCategory }
> = {
  invalid_command: { stage: "protocol", category: "validation" },
  device_not_found: { stage: "authorization", category: "authorization" },
  device_revoked: { stage: "authorization", category: "authorization" },
  scope_missing: { stage: "authorization", category: "authorization" },
  idempotency_conflict: { stage: "protocol", category: "validation" },
  command_id_conflict: { stage: "protocol", category: "validation" },
  request_id_conflict: { stage: "protocol", category: "validation" },
  conversation_not_found: { stage: "storage", category: "storage" },
  conversation_route_mismatch: { stage: "authorization", category: "authorization" },
  control_lease_lost: { stage: "authorization", category: "authorization" },
  control_lease_conflict: { stage: "authorization", category: "authorization" },
  control_lease_takeover_required: { stage: "authorization", category: "authorization" },
  agent_unavailable: { stage: "connection", category: "unavailable" },
  capability_revision_changed: { stage: "protocol", category: "protocol" },
  request_too_large: { stage: "protocol", category: "validation" },
};

const defaultDependencies: AcceptanceDependencies = {
  now: () => new Date(),
  newOpaqueId: () => randomUUID(),
};

function commandError(code: GatewayCommandErrorCode, message: string): never {
  throw new GatewayCommandError(code, message);
}

function requireOpaqueId(value: string, field: string): void {
  if (value.length === 0 || value.length > 256 || /\s/u.test(value)) {
    commandError("invalid_command", `${field} must be a non-empty opaque identifier.`);
  }
}

function hashText(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

function sameRequestBinding(existing: AcceptedRequestRecord, input: AcceptRequestInput, textHash: string): boolean {
  return (
    existing.requestId === input.requestId &&
    existing.commandId === input.commandId &&
    existing.conversationId === input.conversationId &&
    existing.sessionId === (input.sessionId ?? null) &&
    existing.nodeId === input.nodeId &&
    existing.agentId === input.agentId &&
    existing.capabilityRevision === input.capabilityRevision &&
    existing.confirmedTextSha256 === textHash
  );
}

function validateInput(input: AcceptRequestInput): void {
  for (const [field, value] of [
    ["requestId", input.requestId],
    ["commandId", input.commandId],
    ["idempotencyKey", input.idempotencyKey],
    ["deviceId", input.deviceId],
    ["connectionId", input.connectionId],
    ["conversationId", input.conversationId],
    ["leaseId", input.leaseId],
    ["nodeId", input.nodeId],
    ["agentId", input.agentId],
    ["capabilityRevision", input.capabilityRevision],
  ] as const) {
    requireOpaqueId(value, field);
  }
  if (input.sessionId !== undefined) {
    requireOpaqueId(input.sessionId, "sessionId");
  }
  if (input.confirmedText.length === 0) {
    commandError("invalid_command", "confirmedText must not be empty.");
  }
}

export async function acceptRequest(
  ledger: GatewayLedger,
  input: AcceptRequestInput,
  dependencies: AcceptanceDependencies = defaultDependencies,
): Promise<AcceptanceResult> {
  validateInput(input);
  const confirmedTextSha256 = hashText(input.confirmedText);

  return ledger.transaction(async (transaction) => {
    const device = await transaction.lockDevice(input.deviceId);
    if (device === undefined) {
      commandError("device_not_found", "The paired device does not exist.");
    }

    const existing = await transaction.findRequestByIdempotency(input.deviceId, input.idempotencyKey);
    if (existing !== undefined) {
      if (!sameRequestBinding(existing, input, confirmedTextSha256)) {
        commandError("idempotency_conflict", "The idempotency key is already bound to another command.");
      }
      return { kind: "existing", request: existing };
    }

    const sameId = await transaction.findRequestById(input.requestId);
    if (sameId !== undefined) {
      commandError("request_id_conflict", "The request identifier is already bound to another command.");
    }

    const sameCommand = await transaction.findRequestByCommand(input.deviceId, input.commandId);
    if (sameCommand !== undefined) {
      commandError("command_id_conflict", "The command identifier is already bound to another request.");
    }

    if (!device.active) {
      commandError("device_revoked", "The paired device has been revoked.");
    }
    if (!device.scopes.includes(requiredSendScope)) {
      commandError("scope_missing", "The device is not allowed to send Agent requests.");
    }

    const route = await transaction.lockConversationRoute(input.conversationId);
    if (route === undefined) {
      commandError("conversation_not_found", "The selected conversation does not exist.");
    }
    if (
      route.nodeId !== input.nodeId ||
      route.agentId !== input.agentId ||
      route.capabilityRevision !== input.capabilityRevision ||
      route.sessionId !== (input.sessionId ?? null)
    ) {
      commandError(
        "conversation_route_mismatch",
        "The submitted route does not match the conversation's authoritative route.",
      );
    }

    const lease = await transaction.getControlLease(input.conversationId);
    const now = dependencies.now();
    if (
      lease === undefined ||
      lease.deviceId !== input.deviceId ||
      lease.leaseId !== input.leaseId ||
      lease.revision !== input.leaseRevision ||
      lease.expiresAt.getTime() <= now.getTime()
    ) {
      commandError("control_lease_lost", "The conversation control lease is no longer current.");
    }

    const target = await transaction.getAgentTarget(route.nodeId, route.agentId);
    if (target === undefined || !target.available) {
      commandError("agent_unavailable", "The selected Agent target is unavailable.");
    }
    if (target.capabilityRevision !== route.capabilityRevision) {
      commandError("capability_revision_changed", "The selected Agent capabilities changed before acceptance.");
    }

    const requestBytes = BigInt(Buffer.byteLength(input.confirmedText, "utf8"));
    if (target.maxRequestBytes !== null && requestBytes > target.maxRequestBytes) {
      commandError("request_too_large", "The confirmed text exceeds the selected Agent request limit.");
    }

    const sequence = await transaction.allocateConversationSequence(input.conversationId);
    if (sequence === undefined) {
      throw new Error("locked conversation disappeared before sequence allocation");
    }
    const occurredAt = new Date(now);
    const eventId = dependencies.newOpaqueId();
    const facts: AcceptanceFacts = {
      request: {
        requestId: input.requestId,
        commandId: input.commandId,
        idempotencyKey: input.idempotencyKey,
        deviceId: input.deviceId,
        connectionId: input.connectionId,
        conversationId: input.conversationId,
        sessionId: route.sessionId,
        nodeId: route.nodeId,
        agentId: route.agentId,
        capabilityRevision: route.capabilityRevision,
        confirmedTextSha256,
        acceptedSequence: sequence,
        acceptedAt: occurredAt,
      },
      event: {
        eventId,
        connectionId: input.connectionId,
        deviceId: input.deviceId,
        conversationId: input.conversationId,
        sessionId: route.sessionId,
        requestId: input.requestId,
        sequence,
        type: "request.accepted",
        occurredAt,
      },
      dispatchOutbox: {
        outboxId: dependencies.newOpaqueId(),
        requestId: input.requestId,
        nodeId: input.nodeId,
        createdAt: occurredAt,
      },
      eventOutbox: {
        outboxId: dependencies.newOpaqueId(),
        eventId,
        conversationId: input.conversationId,
        sequence,
        createdAt: occurredAt,
      },
      confirmedText: input.confirmedText,
    };

    await transaction.insertAcceptance(facts);
    return { kind: "accepted", facts };
  });
}
