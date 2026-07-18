import assert from "node:assert/strict";
import test from "node:test";

import {
  acceptInterruptCommand,
  InteractionCommandError,
  type InterruptCommandInput,
} from "./interaction-commands.js";
import type {
  ControlCommandRecord,
  InteractionLedger,
  InteractionLedgerTransaction,
  InteractionRequestRecord,
  InterruptAcceptanceFacts,
} from "./interaction-ledger.js";
import type { AcceptedRequestRecord, ControlLeaseRecord, DeviceRecord } from "./ledger.js";

class FakeInteractionLedger implements InteractionLedger, InteractionLedgerTransaction {
  device: DeviceRecord | undefined = { deviceId: "device-1", active: true, scopes: ["interrupt"] };
  lease: ControlLeaseRecord | undefined = {
    conversationId: "conversation-1",
    leaseId: "lease-1",
    deviceId: "device-1",
    revision: 2n,
    expiresAt: new Date("2030-01-01T00:01:00.000Z"),
  };
  request: InteractionRequestRecord | undefined = {
    requestId: "request-1",
    commandId: "send-command-1",
    idempotencyKey: "send-idempotency-1",
    deviceId: "device-1",
    connectionId: "client-connection-original",
    conversationId: "conversation-1",
    sessionId: "session-1",
    nodeId: "node-1",
    agentId: "agent-1",
    capabilityRevision: "cap-1",
    confirmedTextSha256: "a".repeat(64),
    acceptedSequence: 1n,
    acceptedAt: new Date("2030-01-01T00:00:00.000Z"),
    state: "working",
    interruptCapable: true,
  };
  commands: ControlCommandRecord[] = [];
  facts: InterruptAcceptanceFacts | undefined;

  async interactionTransaction<T>(work: (transaction: InteractionLedgerTransaction) => Promise<T>): Promise<T> {
    return work(this);
  }
  async lockDevice(): Promise<DeviceRecord | undefined> { return this.device; }
  async lockConversation(): Promise<boolean> { return true; }
  async getControlLease(): Promise<ControlLeaseRecord | undefined> { return this.lease; }
  async findControlCommandByIdempotency(deviceId: string, key: string) {
    return this.commands.find((command) => command.deviceId === deviceId && command.idempotencyKey === key);
  }
  async findControlCommandById(commandId: string) {
    return this.commands.find((command) => command.commandId === commandId);
  }
  async findSendRequestByCommand(_deviceId: string, commandId: string): Promise<AcceptedRequestRecord | undefined> {
    return this.request?.commandId === commandId ? this.request : undefined;
  }
  async findInterruptByRequest(requestId: string) {
    return this.commands.find((command) => command.kind === "interrupt" && command.requestId === requestId);
  }
  async lockInteractionRequest(requestId: string, conversationId: string) {
    return this.request?.requestId === requestId && this.request.conversationId === conversationId
      ? this.request
      : undefined;
  }
  async allocateConversationSequence(): Promise<bigint | undefined> { return 2n; }
  async insertInterruptAcceptance(facts: InterruptAcceptanceFacts): Promise<void> {
    this.facts = facts;
    this.commands.push(facts.command);
  }
}

const input: InterruptCommandInput = {
  commandId: "interrupt-command-1",
  idempotencyKey: "interrupt-idempotency-1",
  deviceId: "device-1",
  connectionId: "client-connection-2",
  conversationId: "conversation-1",
  requestId: "request-1",
  leaseId: "lease-1",
  leaseRevision: 2n,
};

function dependencies() {
  let id = 0;
  return {
    now: () => new Date("2030-01-01T00:00:10.000Z"),
    newOpaqueId: () => `generated-${++id}`,
  };
}

test("accepts one explicit interrupt and returns the same durable result on exact retry", async () => {
  const ledger = new FakeInteractionLedger();
  const deps = dependencies();
  const accepted = await acceptInterruptCommand(ledger, input, deps);
  assert.equal(accepted.kind, "accepted");
  assert.equal(ledger.facts?.event.sequence, 2n);
  assert.equal(ledger.facts?.command.kind, "interrupt");
  const existing = await acceptInterruptCommand(ledger, input, deps);
  assert.equal(existing.kind, "existing");
  assert.equal(ledger.commands.length, 1);
});

test("rejects interrupt without scope, current lease, capability, or active request", async () => {
  const scenarios: Array<(ledger: FakeInteractionLedger) => void> = [
    (ledger) => { ledger.device = { deviceId: "device-1", active: true, scopes: ["send"] }; },
    (ledger) => { ledger.lease = { ...ledger.lease!, revision: 3n }; },
    (ledger) => { ledger.request = { ...ledger.request!, interruptCapable: false }; },
    (ledger) => { ledger.request = { ...ledger.request!, state: "completed" }; },
  ];
  for (const configure of scenarios) {
    const ledger = new FakeInteractionLedger();
    configure(ledger);
    await assert.rejects(
      acceptInterruptCommand(ledger, input, dependencies()),
      (error: unknown) => error instanceof InteractionCommandError,
    );
    assert.equal(ledger.facts, undefined);
  }
});

test("rejects command and idempotency identity reuse", async () => {
  const ledger = new FakeInteractionLedger();
  await acceptInterruptCommand(ledger, input, dependencies());
  await assert.rejects(
    acceptInterruptCommand(ledger, { ...input, requestId: "request-other" }, dependencies()),
    (error: unknown) => error instanceof InteractionCommandError && error.code === "idempotency_conflict",
  );
});
