import assert from "node:assert/strict";
import test from "node:test";

import { GatewayCommandError } from "./acceptance.js";
import {
  acquireControlLease,
  type ControlLeaseChange,
  type ControlLeaseDependencies,
  type ControlLeaseLedger,
  type ControlLeaseTransaction,
  renewControlLease,
} from "./control-lease.js";
import type { ControlLeaseRecord, DeviceRecord } from "./ledger.js";

interface LeaseState {
  devices: Map<string, DeviceRecord>;
  conversations: Set<string>;
  leases: Map<string, ControlLeaseRecord>;
  audits: ControlLeaseChange["audit"][];
}

class MemoryLeaseLedger implements ControlLeaseLedger, ControlLeaseTransaction {
  state: LeaseState = {
    devices: new Map([
      ["device-1", { deviceId: "device-1", active: true, scopes: ["send"] }],
      ["device-2", { deviceId: "device-2", active: true, scopes: ["interrupt"] }],
      ["observer", { deviceId: "observer", active: true, scopes: ["observe"] }],
    ]),
    conversations: new Set(["conversation-1"]),
    leases: new Map(),
    audits: [],
  };
  #tail: Promise<void> = Promise.resolve();

  async leaseTransaction<T>(work: (transaction: ControlLeaseTransaction) => Promise<T>): Promise<T> {
    let release = () => {};
    const turn = new Promise<void>((resolve) => {
      release = resolve;
    });
    const previous = this.#tail;
    this.#tail = turn;
    await previous;
    const snapshot = structuredClone(this.state);
    try {
      return await work(this);
    } catch (error) {
      this.state = snapshot;
      throw error;
    } finally {
      release();
    }
  }

  async lockDevice(deviceId: string): Promise<DeviceRecord | undefined> {
    return this.state.devices.get(deviceId);
  }

  async lockConversation(conversationId: string): Promise<boolean> {
    return this.state.conversations.has(conversationId);
  }

  async getControlLease(conversationId: string): Promise<ControlLeaseRecord | undefined> {
    return this.state.leases.get(conversationId);
  }

  async insertControlLease(change: ControlLeaseChange): Promise<void> {
    if (this.state.leases.has(change.lease.conversationId)) {
      throw new Error("duplicate lease");
    }
    this.state.leases.set(change.lease.conversationId, change.lease);
    this.state.audits.push(change.audit);
  }

  async replaceControlLease(
    expectedLeaseId: string,
    expectedRevision: bigint,
    change: ControlLeaseChange,
  ): Promise<boolean> {
    const current = this.state.leases.get(change.lease.conversationId);
    if (current?.leaseId !== expectedLeaseId || current.revision !== expectedRevision) {
      return false;
    }
    this.state.leases.set(change.lease.conversationId, change.lease);
    this.state.audits.push(change.audit);
    return true;
  }
}

let nextOpaqueId = 0;

function dependencies(now = "2030-01-01T00:00:00.000Z"): ControlLeaseDependencies {
  return {
    now: () => new Date(now),
    newOpaqueId: () => `lease-generated-${++nextOpaqueId}`,
    durationMs: 30_000,
  };
}

async function expectCode(promise: Promise<unknown>, code: GatewayCommandError["code"]): Promise<void> {
  await assert.rejects(promise, (error: unknown) => error instanceof GatewayCommandError && error.code === code);
}

test("acquires a 30 second lease and writes a body-free audit fact", async () => {
  const ledger = new MemoryLeaseLedger();
  const change = await acquireControlLease(
    ledger,
    { deviceId: "device-1", conversationId: "conversation-1", explicitTakeover: false },
    dependencies(),
  );

  assert.equal(change.lease.deviceId, "device-1");
  assert.equal(change.lease.revision, 1n);
  assert.equal(change.lease.expiresAt.toISOString(), "2030-01-01T00:00:30.000Z");
  assert.equal(change.audit.action, "control_lease.acquire");
  assert.equal(change.audit.targetIdSha256.length, 64);
  assert.equal(JSON.stringify(change.audit).includes("conversation-1"), false);
});

test("renews only the exact live lease and increments its CAS revision", async () => {
  const ledger = new MemoryLeaseLedger();
  const acquired = await acquireControlLease(
    ledger,
    { deviceId: "device-1", conversationId: "conversation-1", explicitTakeover: false },
    dependencies(),
  );
  const renewed = await renewControlLease(
    ledger,
    {
      deviceId: "device-1",
      conversationId: "conversation-1",
      leaseId: acquired.lease.leaseId,
      expectedRevision: 1n,
    },
    dependencies("2030-01-01T00:00:09.000Z"),
  );

  assert.equal(renewed.lease.leaseId, acquired.lease.leaseId);
  assert.equal(renewed.lease.revision, 2n);
  assert.equal(renewed.lease.expiresAt.toISOString(), "2030-01-01T00:00:39.000Z");
  await expectCode(
    renewControlLease(
      ledger,
      {
        deviceId: "device-1",
        conversationId: "conversation-1",
        leaseId: acquired.lease.leaseId,
        expectedRevision: 1n,
      },
      dependencies("2030-01-01T00:00:10.000Z"),
    ),
    "control_lease_lost",
  );
});

test("requires an exact explicit CAS before another device can take over", async () => {
  const ledger = new MemoryLeaseLedger();
  const acquired = await acquireControlLease(
    ledger,
    { deviceId: "device-1", conversationId: "conversation-1", explicitTakeover: false },
    dependencies(),
  );

  await expectCode(
    acquireControlLease(
      ledger,
      { deviceId: "device-2", conversationId: "conversation-1", explicitTakeover: false },
      dependencies(),
    ),
    "control_lease_takeover_required",
  );
  await expectCode(
    acquireControlLease(
      ledger,
      {
        deviceId: "device-2",
        conversationId: "conversation-1",
        explicitTakeover: true,
        expectedLeaseId: acquired.lease.leaseId,
        expectedRevision: 0n,
      },
      dependencies(),
    ),
    "control_lease_conflict",
  );

  const takeover = await acquireControlLease(
    ledger,
    {
      deviceId: "device-2",
      conversationId: "conversation-1",
      explicitTakeover: true,
      expectedLeaseId: acquired.lease.leaseId,
      expectedRevision: 1n,
    },
    dependencies(),
  );
  assert.equal(takeover.lease.deviceId, "device-2");
  assert.equal(takeover.lease.revision, 2n);
  assert.notEqual(takeover.lease.leaseId, acquired.lease.leaseId);

  await expectCode(
    renewControlLease(
      ledger,
      {
        deviceId: "device-1",
        conversationId: "conversation-1",
        leaseId: acquired.lease.leaseId,
        expectedRevision: 1n,
      },
      dependencies(),
    ),
    "control_lease_lost",
  );
});

test("does not turn expiry into implicit takeover", async () => {
  const ledger = new MemoryLeaseLedger();
  const acquired = await acquireControlLease(
    ledger,
    { deviceId: "device-1", conversationId: "conversation-1", explicitTakeover: false },
    dependencies(),
  );
  await expectCode(
    acquireControlLease(
      ledger,
      { deviceId: "device-2", conversationId: "conversation-1", explicitTakeover: false },
      dependencies("2030-01-01T00:01:00.000Z"),
    ),
    "control_lease_takeover_required",
  );
  await expectCode(
    renewControlLease(
      ledger,
      {
        deviceId: "device-1",
        conversationId: "conversation-1",
        leaseId: acquired.lease.leaseId,
        expectedRevision: 1n,
      },
      dependencies("2030-01-01T00:01:00.000Z"),
    ),
    "control_lease_lost",
  );
});

test("observe-only and revoked devices cannot acquire control", async () => {
  const ledger = new MemoryLeaseLedger();
  await expectCode(
    acquireControlLease(
      ledger,
      { deviceId: "observer", conversationId: "conversation-1", explicitTakeover: false },
      dependencies(),
    ),
    "scope_missing",
  );
  ledger.state.devices.set("device-1", { deviceId: "device-1", active: false, scopes: ["send"] });
  await expectCode(
    acquireControlLease(
      ledger,
      { deviceId: "device-1", conversationId: "conversation-1", explicitTakeover: false },
      dependencies(),
    ),
    "device_revoked",
  );
});

test("only one concurrent takeover with the same revision succeeds", async () => {
  const ledger = new MemoryLeaseLedger();
  ledger.state.devices.set("device-3", { deviceId: "device-3", active: true, scopes: ["approve"] });
  const acquired = await acquireControlLease(
    ledger,
    { deviceId: "device-1", conversationId: "conversation-1", explicitTakeover: false },
    dependencies(),
  );
  const attempt = (deviceId: string) =>
    acquireControlLease(
      ledger,
      {
        deviceId,
        conversationId: "conversation-1",
        explicitTakeover: true,
        expectedLeaseId: acquired.lease.leaseId,
        expectedRevision: acquired.lease.revision,
      },
      dependencies(),
    );
  const results = await Promise.allSettled([attempt("device-2"), attempt("device-3")]);

  assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
  assert.equal(results.filter((result) => result.status === "rejected").length, 1);
  assert.equal(ledger.state.leases.get("conversation-1")?.revision, 2n);
  assert.equal(ledger.state.audits.length, 2);
});
