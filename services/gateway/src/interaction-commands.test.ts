import assert from "node:assert/strict";
import { generateKeyPairSync, sign } from "node:crypto";
import test from "node:test";

import { DeviceSignatureAlgorithm, approvalDecisionPayload } from "@agent-talk/protocol";
import { normalizeEd25519PublicKey } from "./device-crypto.js";

import {
  acceptApprovalCommand,
  acceptClarificationCommand,
  acceptInterruptCommand,
  InteractionCommandError,
  type InterruptCommandInput,
} from "./interaction-commands.js";
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
    clarificationCapable: true,
    maxRequestBytes: 1024n,
  };
  commands: ControlCommandRecord[] = [];
  facts: InterruptAcceptanceFacts | undefined;
  approval: ApprovalRecord | undefined = {
    approvalId: "approval-1",
    requestId: "request-1",
    nodeId: "node-1",
    agentId: "agent-1",
    operationSummarySha256: "b".repeat(64),
    state: "pending",
    expiresAt: new Date("2030-01-01T00:01:00.000Z"),
  };
  approvalFacts: ApprovalResolutionFacts | undefined;
  clarification: ClarificationRecord | undefined = {
    clarificationId: "clarification-1",
    requestId: "request-1",
    nodeId: "node-1",
    agentId: "agent-1",
    state: "pending",
    expiresAt: new Date("2030-01-01T00:01:00.000Z"),
  };
  clarificationFacts: ClarificationResolutionFacts | undefined;
  signatureCredential: DeviceSignatureCredentialRecord | undefined;
  signatureNonces = new Set<string>();

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
  async lockApproval(approvalId: string, requestId: string) {
    return this.approval?.approvalId === approvalId && this.approval.requestId === requestId
      ? this.approval
      : undefined;
  }
  async lockDeviceSignatureCredential(credentialId: string) {
    return this.signatureCredential?.credentialId === credentialId ? this.signatureCredential : undefined;
  }
  async recordDeviceSignatureNonce(credentialId: string, purpose: string, nonceSha256: string) {
    const identity = `${credentialId}\0${purpose}\0${nonceSha256}`;
    if (this.signatureNonces.has(identity)) return false;
    this.signatureNonces.add(identity);
    return true;
  }
  async expireApproval(approvalId: string): Promise<boolean> {
    if (this.approval?.approvalId !== approvalId || this.approval.state !== "pending") return false;
    this.approval = { ...this.approval, state: "expired" };
    return true;
  }
  async lockClarification(clarificationId: string, requestId: string) {
    return this.clarification?.clarificationId === clarificationId && this.clarification.requestId === requestId
      ? this.clarification
      : undefined;
  }
  async expireClarification(clarificationId: string): Promise<boolean> {
    if (this.clarification?.clarificationId !== clarificationId || this.clarification.state !== "pending") return false;
    this.clarification = { ...this.clarification, state: "expired" };
    return true;
  }
  async allocateConversationSequence(): Promise<bigint | undefined> { return 2n; }
  async insertInterruptAcceptance(facts: InterruptAcceptanceFacts): Promise<void> {
    this.facts = facts;
    this.commands.push(facts.command);
  }
  async insertApprovalResolution(facts: ApprovalResolutionFacts): Promise<void> {
    this.approvalFacts = facts;
    this.commands.push(facts.command);
    this.approval = { ...this.approval!, state: facts.decision };
  }
  async insertClarificationResolution(facts: ClarificationResolutionFacts): Promise<void> {
    this.clarificationFacts = facts;
    this.commands.push(facts.command);
    this.clarification = { ...this.clarification!, state: "resolved" };
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

const approvalKeys = generateKeyPairSync("ed25519");
const approvalSpki = new Uint8Array(approvalKeys.publicKey.export({ format: "der", type: "spki" }));
const approvalPublicKey = normalizeEd25519PublicKey(approvalSpki);

function enableApprovalCredential(ledger: FakeInteractionLedger): void {
  ledger.signatureCredential = {
    credentialId: "credential-1",
    deviceId: "device-1",
    active: true,
    deviceActive: true,
    publicKeySpki: approvalSpki,
    publicKeySha256: approvalPublicKey.sha256,
    gatewayAudience: "https://gateway.example",
    scopes: ["approve"],
  };
}

function approvalInput(overrides: Partial<{
  commandId: string;
  idempotencyKey: string;
  decision: "approved" | "rejected";
  operationSummarySha256: string;
  nonceFill: number;
}> = {}) {
  const nonce = new Uint8Array(32).fill(overrides.nonceFill ?? 6);
  const values = {
    commandId: overrides.commandId ?? "approval-command-1",
    idempotencyKey: overrides.idempotencyKey ?? "approval-idempotency-1",
    deviceId: "device-1",
    conversationId: "conversation-1",
    requestId: "request-1",
    approvalId: "approval-1",
    leaseId: "lease-1",
    leaseRevision: 2n,
    decision: overrides.decision ?? "approved",
    operationSummarySha256: overrides.operationSummarySha256 ?? "b".repeat(64),
    credentialId: "credential-1",
    gatewayAudience: "https://gateway.example",
  } as const;
  return {
    ...values,
    deviceSignature: {
      $typeName: "agent_talk.v1.DeviceSignature" as const,
      credentialId: values.credentialId,
      nonce,
      signature: new Uint8Array(sign(null, approvalDecisionPayload({
        credentialId: values.credentialId,
        deviceId: values.deviceId,
        hostIdentity: "node-1",
        gatewayAudience: values.gatewayAudience,
        requestId: values.requestId,
        approvalId: values.approvalId,
        decision: values.decision === "approved" ? "approve" : "deny",
        operationSummarySha256: values.operationSummarySha256,
        nonce,
      }), approvalKeys.privateKey)),
      algorithm: DeviceSignatureAlgorithm.ED25519,
    },
  };
}

test("resolves a pending approval once and returns the original decision on exact retry", async () => {
  const ledger = new FakeInteractionLedger();
  ledger.device = { deviceId: "device-1", active: true, scopes: ["approve"] };
  enableApprovalCredential(ledger);
  const deps = dependencies();
  assert.equal((await acceptApprovalCommand(ledger, approvalInput(), deps)).kind, "accepted");
  assert.equal(ledger.approval?.state, "approved");
  assert.equal(ledger.approvalFacts?.command.targetId, "approval-1");
  assert.equal((await acceptApprovalCommand(ledger, approvalInput(), deps)).kind, "existing");
  await assert.rejects(
    acceptApprovalCommand(
      ledger,
      approvalInput({ commandId: "approval-command-2", idempotencyKey: "approval-idempotency-2", nonceFill: 7 }),
      deps,
    ),
    (error: unknown) => error instanceof InteractionCommandError && error.code === "approval_already_resolved",
  );
  await assert.rejects(
    acceptApprovalCommand(ledger, approvalInput({ decision: "rejected", nonceFill: 8 }), deps),
    (error: unknown) => error instanceof InteractionCommandError && error.code === "idempotency_conflict",
  );
  assert.equal(ledger.commands.length, 1);
});

test("never dispatches approval without exact scope, summary, pending state, and expiry", async () => {
  const scenarios: Array<(ledger: FakeInteractionLedger) => void> = [
    () => {},
    (ledger) => { ledger.device = { deviceId: "device-1", active: true, scopes: ["approve"] }; },
    (ledger) => {
      ledger.device = { deviceId: "device-1", active: true, scopes: ["approve"] };
      ledger.approval = { ...ledger.approval!, state: "cancelled" };
    },
    (ledger) => {
      ledger.device = { deviceId: "device-1", active: true, scopes: ["approve"] };
      ledger.approval = { ...ledger.approval!, expiresAt: new Date("2030-01-01T00:00:01.000Z") };
    },
  ];
  const inputs = [
    approvalInput(),
    approvalInput({ operationSummarySha256: "c".repeat(64) }),
    approvalInput(),
    approvalInput(),
  ];
  for (let index = 0; index < scenarios.length; index += 1) {
    const ledger = new FakeInteractionLedger();
    enableApprovalCredential(ledger);
    scenarios[index]!(ledger);
    await assert.rejects(
      acceptApprovalCommand(ledger, inputs[index]!, dependencies()),
      (error: unknown) => error instanceof InteractionCommandError,
    );
    assert.equal(ledger.approvalFacts, undefined);
  }
});

test("never accepts an approval with a missing or altered device signature", async () => {
  const ledger = new FakeInteractionLedger();
  ledger.device = { deviceId: "device-1", active: true, scopes: ["approve"] };
  enableApprovalCredential(ledger);
  const altered = approvalInput();
  altered.deviceSignature.signature[0] = (altered.deviceSignature.signature[0] ?? 0) ^ 1;
  for (const candidate of [altered, { ...approvalInput(), deviceSignature: undefined }]) {
    await assert.rejects(
      acceptApprovalCommand(ledger, candidate, dependencies()),
      (error: unknown) =>
        error instanceof InteractionCommandError &&
        ["approval_signature_invalid", "invalid_command"].includes(error.code),
    );
  }
  assert.equal(ledger.approvalFacts, undefined);
});

const clarificationInput = {
  commandId: "clarification-command-1",
  idempotencyKey: "clarification-idempotency-1",
  deviceId: "device-1",
  conversationId: "conversation-1",
  requestId: "request-1",
  clarificationId: "clarification-1",
  leaseId: "lease-1",
  leaseRevision: 2n,
  confirmedText: "Use the isolated test directory.",
};

test("submits confirmed clarification text with send scope and exact retry semantics", async () => {
  const ledger = new FakeInteractionLedger();
  ledger.device = { deviceId: "device-1", active: true, scopes: ["send"] };
  const deps = dependencies();
  assert.equal((await acceptClarificationCommand(ledger, clarificationInput, deps)).kind, "accepted");
  assert.equal(ledger.clarification?.state, "resolved");
  assert.equal(ledger.clarificationFacts?.confirmedText, "Use the isolated test directory.");
  assert.equal((await acceptClarificationCommand(ledger, clarificationInput, deps)).kind, "existing");
  await assert.rejects(
    acceptClarificationCommand(ledger, { ...clarificationInput, confirmedText: "changed" }, deps),
    (error: unknown) => error instanceof InteractionCommandError && error.code === "idempotency_conflict",
  );
});

test("clarification never borrows approve scope and enforces capability, size, state, and expiry", async () => {
  const scenarios: Array<(ledger: FakeInteractionLedger) => void> = [
    (ledger) => { ledger.device = { deviceId: "device-1", active: true, scopes: ["approve"] }; },
    (ledger) => {
      ledger.device = { deviceId: "device-1", active: true, scopes: ["send"] };
      ledger.request = { ...ledger.request!, clarificationCapable: false };
    },
    (ledger) => {
      ledger.device = { deviceId: "device-1", active: true, scopes: ["send"] };
      ledger.request = { ...ledger.request!, maxRequestBytes: 1n };
    },
    (ledger) => {
      ledger.device = { deviceId: "device-1", active: true, scopes: ["send"] };
      ledger.clarification = { ...ledger.clarification!, state: "cancelled" };
    },
    (ledger) => {
      ledger.device = { deviceId: "device-1", active: true, scopes: ["send"] };
      ledger.clarification = { ...ledger.clarification!, expiresAt: new Date("2030-01-01T00:00:01.000Z") };
    },
  ];
  for (const configure of scenarios) {
    const ledger = new FakeInteractionLedger();
    configure(ledger);
    await assert.rejects(
      acceptClarificationCommand(ledger, clarificationInput, dependencies()),
      (error: unknown) => error instanceof InteractionCommandError,
    );
    assert.equal(ledger.clarificationFacts, undefined);
  }
});
