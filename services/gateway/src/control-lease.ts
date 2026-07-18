import { createHash, randomUUID } from "node:crypto";

import { GatewayCommandError } from "./acceptance.js";
import type { ControlLeaseRecord, DeviceRecord } from "./ledger.js";

export const controlLeaseDurationMs = 30_000;
export const controlScopes = ["send", "interrupt", "approve"] as const;

export interface ControlLeaseAuditRecord {
  auditId: string;
  deviceId: string;
  action: "control_lease.acquire" | "control_lease.renew" | "control_lease.takeover";
  outcome: "allowed";
  targetType: "conversation";
  targetIdSha256: string;
  safeCode: "control_lease_acquired" | "control_lease_renewed" | "control_lease_taken_over";
  occurredAt: Date;
}

export interface ControlLeaseChange {
  lease: ControlLeaseRecord;
  audit: ControlLeaseAuditRecord;
}

export interface ControlLeaseTransaction {
  lockDevice(deviceId: string): Promise<DeviceRecord | undefined>;
  lockConversation(conversationId: string): Promise<boolean>;
  getControlLease(conversationId: string): Promise<ControlLeaseRecord | undefined>;
  insertControlLease(change: ControlLeaseChange): Promise<void>;
  replaceControlLease(
    expectedLeaseId: string,
    expectedRevision: bigint,
    change: ControlLeaseChange,
  ): Promise<boolean>;
}

export interface ControlLeaseLedger {
  leaseTransaction<T>(work: (transaction: ControlLeaseTransaction) => Promise<T>): Promise<T>;
}

export interface AcquireControlLeaseInput {
  deviceId: string;
  conversationId: string;
  explicitTakeover: boolean;
  expectedLeaseId?: string;
  expectedRevision?: bigint;
}

export interface RenewControlLeaseInput {
  deviceId: string;
  conversationId: string;
  leaseId: string;
  expectedRevision: bigint;
}

export interface ControlLeaseDependencies {
  now(): Date;
  newOpaqueId(): string;
  durationMs: number;
}

const defaultDependencies: ControlLeaseDependencies = {
  now: () => new Date(),
  newOpaqueId: () => randomUUID(),
  durationMs: controlLeaseDurationMs,
};

function fail(code: ConstructorParameters<typeof GatewayCommandError>[0], message: string): never {
  throw new GatewayCommandError(code, message);
}

function requireId(value: string, field: string): void {
  if (value.length === 0 || value.length > 256 || /\s/u.test(value)) {
    fail("invalid_command", `${field} must be a non-empty opaque identifier.`);
  }
}

function authorizeDevice(device: DeviceRecord | undefined): asserts device is DeviceRecord {
  if (device === undefined) {
    fail("device_not_found", "The paired device does not exist.");
  }
  if (!device.active) {
    fail("device_revoked", "The paired device has been revoked.");
  }
  if (!controlScopes.some((scope) => device.scopes.includes(scope))) {
    fail("scope_missing", "The device has no scope that can control a conversation.");
  }
}

function audit(
  dependencies: ControlLeaseDependencies,
  deviceId: string,
  conversationId: string,
  action: ControlLeaseAuditRecord["action"],
  safeCode: ControlLeaseAuditRecord["safeCode"],
  occurredAt: Date,
): ControlLeaseAuditRecord {
  return {
    auditId: dependencies.newOpaqueId(),
    deviceId,
    action,
    outcome: "allowed",
    targetType: "conversation",
    targetIdSha256: createHash("sha256").update(conversationId, "utf8").digest("hex"),
    safeCode,
    occurredAt,
  };
}

function newExpiry(now: Date, dependencies: ControlLeaseDependencies): Date {
  if (!Number.isSafeInteger(dependencies.durationMs) || dependencies.durationMs <= 0) {
    throw new Error("control lease duration must be a positive safe integer");
  }
  return new Date(now.getTime() + dependencies.durationMs);
}

export async function acquireControlLease(
  ledger: ControlLeaseLedger,
  input: AcquireControlLeaseInput,
  dependencies: ControlLeaseDependencies = defaultDependencies,
): Promise<ControlLeaseChange> {
  requireId(input.deviceId, "deviceId");
  requireId(input.conversationId, "conversationId");
  if (input.expectedLeaseId !== undefined) {
    requireId(input.expectedLeaseId, "expectedLeaseId");
  }

  return ledger.leaseTransaction(async (transaction) => {
    const device = await transaction.lockDevice(input.deviceId);
    authorizeDevice(device);
    if (!(await transaction.lockConversation(input.conversationId))) {
      fail("conversation_not_found", "The selected conversation does not exist.");
    }

    const current = await transaction.getControlLease(input.conversationId);
    const now = dependencies.now();
    if (current === undefined) {
      if (input.explicitTakeover || input.expectedLeaseId !== undefined || input.expectedRevision !== undefined) {
        fail("control_lease_conflict", "The conversation has no lease matching the takeover precondition.");
      }
      const lease: ControlLeaseRecord = {
        conversationId: input.conversationId,
        leaseId: dependencies.newOpaqueId(),
        deviceId: input.deviceId,
        revision: 1n,
        expiresAt: newExpiry(now, dependencies),
      };
      const change = {
        lease,
        audit: audit(
          dependencies,
          input.deviceId,
          input.conversationId,
          "control_lease.acquire",
          "control_lease_acquired",
          now,
        ),
      } satisfies ControlLeaseChange;
      await transaction.insertControlLease(change);
      return change;
    }

    if (current.deviceId === input.deviceId) {
      fail("control_lease_conflict", "The controlling device must renew its existing lease.");
    }
    if (!input.explicitTakeover) {
      fail("control_lease_takeover_required", "Another device controls this conversation; explicit takeover is required.");
    }
    if (input.expectedLeaseId !== current.leaseId || input.expectedRevision !== current.revision) {
      fail("control_lease_conflict", "The control lease changed before takeover.");
    }

    const lease: ControlLeaseRecord = {
      conversationId: input.conversationId,
      leaseId: dependencies.newOpaqueId(),
      deviceId: input.deviceId,
      revision: current.revision + 1n,
      expiresAt: newExpiry(now, dependencies),
    };
    const change = {
      lease,
      audit: audit(
        dependencies,
        input.deviceId,
        input.conversationId,
        "control_lease.takeover",
        "control_lease_taken_over",
        now,
      ),
    } satisfies ControlLeaseChange;
    if (!(await transaction.replaceControlLease(current.leaseId, current.revision, change))) {
      fail("control_lease_conflict", "The control lease changed before takeover committed.");
    }
    return change;
  });
}

export async function renewControlLease(
  ledger: ControlLeaseLedger,
  input: RenewControlLeaseInput,
  dependencies: ControlLeaseDependencies = defaultDependencies,
): Promise<ControlLeaseChange> {
  requireId(input.deviceId, "deviceId");
  requireId(input.conversationId, "conversationId");
  requireId(input.leaseId, "leaseId");

  return ledger.leaseTransaction(async (transaction) => {
    const device = await transaction.lockDevice(input.deviceId);
    authorizeDevice(device);
    if (!(await transaction.lockConversation(input.conversationId))) {
      fail("conversation_not_found", "The selected conversation does not exist.");
    }
    const current = await transaction.getControlLease(input.conversationId);
    const now = dependencies.now();
    if (
      current === undefined ||
      current.deviceId !== input.deviceId ||
      current.leaseId !== input.leaseId ||
      current.revision !== input.expectedRevision ||
      current.expiresAt.getTime() <= now.getTime()
    ) {
      fail("control_lease_lost", "The conversation control lease is no longer current.");
    }

    const lease: ControlLeaseRecord = {
      ...current,
      revision: current.revision + 1n,
      expiresAt: newExpiry(now, dependencies),
    };
    const change = {
      lease,
      audit: audit(
        dependencies,
        input.deviceId,
        input.conversationId,
        "control_lease.renew",
        "control_lease_renewed",
        now,
      ),
    } satisfies ControlLeaseChange;
    if (!(await transaction.replaceControlLease(current.leaseId, current.revision, change))) {
      fail("control_lease_lost", "The conversation control lease changed before renewal committed.");
    }
    return change;
  });
}
