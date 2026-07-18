import { createHash, randomUUID } from "node:crypto";

import type { AcceptedRequestRecord } from "./ledger.js";
import type {
  ApprovalResolutionFacts,
  ControlCommandRecord,
  InteractionLedger,
  InterruptAcceptanceFacts,
} from "./interaction-ledger.js";

export interface InterruptCommandInput {
  commandId: string;
  idempotencyKey: string;
  deviceId: string;
  connectionId: string;
  conversationId: string;
  requestId: string;
  leaseId: string;
  leaseRevision: bigint;
}

export interface InteractionCommandDependencies {
  now(): Date;
  newOpaqueId(): string;
}

export interface ApprovalCommandInput {
  commandId: string;
  idempotencyKey: string;
  deviceId: string;
  conversationId: string;
  requestId: string;
  approvalId: string;
  leaseId: string;
  leaseRevision: bigint;
  decision: "approved" | "rejected";
  operationSummarySha256: string;
}

export type ApprovalCommandResult =
  | { kind: "accepted"; request: AcceptedRequestRecord; facts: ApprovalResolutionFacts }
  | { kind: "existing"; request: AcceptedRequestRecord; command: ControlCommandRecord };

export type InterruptCommandResult =
  | { kind: "accepted"; request: AcceptedRequestRecord; facts: InterruptAcceptanceFacts }
  | { kind: "existing"; request: AcceptedRequestRecord; command: ControlCommandRecord };

export type InteractionCommandErrorCode =
  | "invalid_command"
  | "device_not_found"
  | "device_revoked"
  | "scope_missing"
  | "conversation_not_found"
  | "control_lease_lost"
  | "request_not_found"
  | "request_terminal"
  | "capability_unavailable"
  | "idempotency_conflict"
  | "command_id_conflict"
  | "interrupt_already_requested"
  | "approval_not_found"
  | "approval_summary_changed"
  | "approval_already_resolved"
  | "approval_expired";

export class InteractionCommandError extends Error {
  readonly retryable = false;

  constructor(readonly code: InteractionCommandErrorCode, message: string) {
    super(message);
    this.name = "InteractionCommandError";
  }
}

const defaultDependencies: InteractionCommandDependencies = {
  now: () => new Date(),
  newOpaqueId: () => randomUUID(),
};

function fail(code: InteractionCommandErrorCode, message: string): never {
  throw new InteractionCommandError(code, message);
}

function requireOpaqueId(value: string, field: string): void {
  if (value.length === 0 || value.length > 256 || /\s/u.test(value)) {
    fail("invalid_command", `${field} must be a non-empty opaque identifier.`);
  }
}

function payloadHash(requestId: string): string {
  return createHash("sha256").update(`interrupt\0${requestId}`, "utf8").digest("hex");
}

function sameInterrupt(command: ControlCommandRecord, input: InterruptCommandInput, hash: string): boolean {
  return command.commandId === input.commandId &&
    command.deviceId === input.deviceId &&
    command.conversationId === input.conversationId &&
    command.requestId === input.requestId &&
    command.kind === "interrupt" &&
    command.targetId === null &&
    command.payloadSha256 === hash;
}

function approvalPayloadHash(input: ApprovalCommandInput): string {
  return createHash("sha256")
    .update(
      `approval\0${input.requestId}\0${input.approvalId}\0${input.decision}\0${input.operationSummarySha256}`,
      "utf8",
    )
    .digest("hex");
}

function sameApproval(command: ControlCommandRecord, input: ApprovalCommandInput, hash: string): boolean {
  return command.commandId === input.commandId &&
    command.deviceId === input.deviceId &&
    command.conversationId === input.conversationId &&
    command.requestId === input.requestId &&
    command.kind === "approval" &&
    command.targetId === input.approvalId &&
    command.payloadSha256 === hash;
}

export async function acceptInterruptCommand(
  ledger: InteractionLedger,
  input: InterruptCommandInput,
  dependencies: InteractionCommandDependencies = defaultDependencies,
): Promise<InterruptCommandResult> {
  for (const [field, value] of [
    ["commandId", input.commandId],
    ["idempotencyKey", input.idempotencyKey],
    ["deviceId", input.deviceId],
    ["connectionId", input.connectionId],
    ["conversationId", input.conversationId],
    ["requestId", input.requestId],
    ["leaseId", input.leaseId],
  ] as const) requireOpaqueId(value, field);
  if (input.leaseRevision === 0n) fail("invalid_command", "leaseRevision must be positive.");
  const hash = payloadHash(input.requestId);

  return ledger.interactionTransaction(async (transaction) => {
    const device = await transaction.lockDevice(input.deviceId);
    if (device === undefined) fail("device_not_found", "The paired device does not exist.");

    const existing = await transaction.findControlCommandByIdempotency(input.deviceId, input.idempotencyKey);
    if (existing !== undefined) {
      if (!sameInterrupt(existing, input, hash)) {
        fail("idempotency_conflict", "The idempotency key is already bound to another control command.");
      }
      const request = await transaction.lockInteractionRequest(input.requestId, input.conversationId);
      if (request === undefined) throw new Error("existing interrupt command lost its request binding");
      return { kind: "existing", request, command: existing };
    }
    if (
      await transaction.findControlCommandById(input.commandId) !== undefined ||
      await transaction.findSendRequestByCommand(input.deviceId, input.commandId) !== undefined
    ) {
      fail("command_id_conflict", "The command identifier is already bound to another command.");
    }
    if (!device.active) fail("device_revoked", "The paired device has been revoked.");
    if (!device.scopes.includes("interrupt")) fail("scope_missing", "The device cannot interrupt Agent requests.");
    if (!(await transaction.lockConversation(input.conversationId))) {
      fail("conversation_not_found", "The selected conversation does not exist.");
    }
    const lease = await transaction.getControlLease(input.conversationId);
    const now = dependencies.now();
    if (
      lease === undefined || lease.deviceId !== input.deviceId || lease.leaseId !== input.leaseId ||
      lease.revision !== input.leaseRevision || lease.expiresAt.getTime() <= now.getTime()
    ) fail("control_lease_lost", "The conversation control lease is no longer current.");

    const request = await transaction.lockInteractionRequest(input.requestId, input.conversationId);
    if (request === undefined) fail("request_not_found", "The request was not found in this conversation.");
    if (["completed", "failed", "cancelled", "interrupted"].includes(request.state)) {
      fail("request_terminal", "A terminal request cannot be interrupted.");
    }
    if (!request.interruptCapable) fail("capability_unavailable", "The selected Agent does not support interruption.");
    if (await transaction.findInterruptByRequest(input.requestId) !== undefined) {
      fail("interrupt_already_requested", "An interrupt is already pending or was already delivered.");
    }

    const sequence = await transaction.allocateConversationSequence(input.conversationId);
    if (sequence === undefined) throw new Error("interrupt conversation disappeared before sequence allocation");
    const occurredAt = new Date(now);
    const facts: InterruptAcceptanceFacts = {
      command: {
        commandId: input.commandId,
        idempotencyKey: input.idempotencyKey,
        deviceId: input.deviceId,
        conversationId: input.conversationId,
        requestId: input.requestId,
        kind: "interrupt",
        targetId: null,
        payloadSha256: hash,
        state: "accepted",
        failure: null,
        createdAt: occurredAt,
      },
      event: {
        eventId: dependencies.newOpaqueId(),
        connectionId: input.connectionId,
        deviceId: input.deviceId,
        conversationId: input.conversationId,
        sessionId: request.sessionId,
        requestId: input.requestId,
        sequence,
        occurredAt,
      },
      dispatchOutboxId: dependencies.newOpaqueId(),
      eventOutboxId: dependencies.newOpaqueId(),
    };
    await transaction.insertInterruptAcceptance(facts);
    return { kind: "accepted", request, facts };
  });
}

export async function acceptApprovalCommand(
  ledger: InteractionLedger,
  input: ApprovalCommandInput,
  dependencies: InteractionCommandDependencies = defaultDependencies,
): Promise<ApprovalCommandResult> {
  for (const [field, value] of [
    ["commandId", input.commandId],
    ["idempotencyKey", input.idempotencyKey],
    ["deviceId", input.deviceId],
    ["conversationId", input.conversationId],
    ["requestId", input.requestId],
    ["approvalId", input.approvalId],
    ["leaseId", input.leaseId],
  ] as const) requireOpaqueId(value, field);
  if (input.leaseRevision === 0n || !/^[0-9a-f]{64}$/u.test(input.operationSummarySha256)) {
    fail("invalid_command", "Approval lease revision or operation summary hash is invalid.");
  }
  const hash = approvalPayloadHash(input);
  const outcome = await ledger.interactionTransaction(async (transaction) => {
    const device = await transaction.lockDevice(input.deviceId);
    if (device === undefined) fail("device_not_found", "The paired device does not exist.");
    const existing = await transaction.findControlCommandByIdempotency(input.deviceId, input.idempotencyKey);
    if (existing !== undefined) {
      if (!sameApproval(existing, input, hash)) {
        fail("idempotency_conflict", "The idempotency key is already bound to another control command.");
      }
      const request = await transaction.lockInteractionRequest(input.requestId, input.conversationId);
      if (request === undefined) throw new Error("existing approval command lost its request binding");
      return { kind: "existing" as const, request, command: existing };
    }
    if (
      await transaction.findControlCommandById(input.commandId) !== undefined ||
      await transaction.findSendRequestByCommand(input.deviceId, input.commandId) !== undefined
    ) fail("command_id_conflict", "The command identifier is already bound to another command.");
    if (!device.active) fail("device_revoked", "The paired device has been revoked.");
    if (!device.scopes.includes("approve")) fail("scope_missing", "The device cannot resolve approvals.");
    if (!(await transaction.lockConversation(input.conversationId))) {
      fail("conversation_not_found", "The selected conversation does not exist.");
    }
    const lease = await transaction.getControlLease(input.conversationId);
    const now = dependencies.now();
    if (
      lease === undefined || lease.deviceId !== input.deviceId || lease.leaseId !== input.leaseId ||
      lease.revision !== input.leaseRevision || lease.expiresAt.getTime() <= now.getTime()
    ) fail("control_lease_lost", "The conversation control lease is no longer current.");
    const request = await transaction.lockInteractionRequest(input.requestId, input.conversationId);
    if (request === undefined) fail("request_not_found", "The approval request was not found in this conversation.");
    if (["completed", "failed", "cancelled", "interrupted"].includes(request.state)) {
      fail("request_terminal", "A terminal request cannot accept an approval decision.");
    }
    const approval = await transaction.lockApproval(input.approvalId, input.requestId);
    if (approval === undefined || approval.nodeId !== request.nodeId || approval.agentId !== request.agentId) {
      fail("approval_not_found", "The approval was not found on the accepted Agent route.");
    }
    if (approval.operationSummarySha256 !== input.operationSummarySha256) {
      fail("approval_summary_changed", "The approval operation summary no longer matches.");
    }
    if (approval.state !== "pending") {
      fail("approval_already_resolved", "The approval is already resolved or unavailable.");
    }
    if (approval.expiresAt.getTime() <= now.getTime()) {
      if (!(await transaction.expireApproval(approval.approvalId, now))) {
        fail("approval_already_resolved", "The approval changed while expiry was recorded.");
      }
      return { kind: "expired" as const };
    }
    const occurredAt = new Date(now);
    const facts: ApprovalResolutionFacts = {
      command: {
        commandId: input.commandId,
        idempotencyKey: input.idempotencyKey,
        deviceId: input.deviceId,
        conversationId: input.conversationId,
        requestId: input.requestId,
        kind: "approval",
        targetId: input.approvalId,
        payloadSha256: hash,
        state: "accepted",
        failure: null,
        createdAt: occurredAt,
      },
      approvalId: input.approvalId,
      decision: input.decision,
      operationSummarySha256: input.operationSummarySha256,
      dispatchOutboxId: dependencies.newOpaqueId(),
      audit: {
        auditId: dependencies.newOpaqueId(),
        targetIdSha256: createHash("sha256").update(input.approvalId, "utf8").digest("hex"),
        occurredAt,
      },
    };
    await transaction.insertApprovalResolution(facts);
    return { kind: "accepted" as const, request, facts };
  });
  if (outcome.kind === "expired") {
    fail("approval_expired", "The approval expired before this decision was accepted.");
  }
  return outcome;
}
