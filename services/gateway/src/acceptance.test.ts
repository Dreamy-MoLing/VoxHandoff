import assert from "node:assert/strict";
import test from "node:test";

import {
  acceptRequest,
  type AcceptRequestInput,
  type AcceptanceDependencies,
  GatewayCommandError,
} from "./acceptance.js";
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

interface MemoryState {
  devices: Map<string, DeviceRecord>;
  leases: Map<string, ControlLeaseRecord>;
  targets: Map<string, AgentTargetRecord>;
  requests: Map<string, AcceptedRequestRecord>;
  idempotency: Map<string, string>;
  sequences: Map<string, bigint>;
  routes: Map<string, ConversationRouteRecord>;
  acceptances: AcceptanceFacts[];
}

function targetKey(nodeId: string, agentId: string): string {
  return `${nodeId}\u0000${agentId}`;
}

function idempotencyKey(deviceId: string, key: string): string {
  return `${deviceId}\u0000${key}`;
}

class MemoryLedger implements GatewayLedger, GatewayLedgerTransaction {
  state: MemoryState;
  failInsert = false;
  #tail: Promise<void> = Promise.resolve();

  constructor() {
    this.state = {
      devices: new Map([
        ["device-1", { deviceId: "device-1", active: true, scopes: ["send"] }],
      ]),
      leases: new Map([
        [
          "conversation-1",
          {
            conversationId: "conversation-1",
            leaseId: "lease-1",
            deviceId: "device-1",
            revision: 7n,
            expiresAt: new Date("2030-01-01T00:00:30.000Z"),
          },
        ],
      ]),
      targets: new Map([
        [
          targetKey("node-1", "agent-1"),
          {
            nodeId: "node-1",
            agentId: "agent-1",
            available: true,
            capabilityRevision: "cap-1",
            maxRequestBytes: 1024n,
          },
        ],
      ]),
      requests: new Map(),
      idempotency: new Map(),
      sequences: new Map([["conversation-1", 0n]]),
      routes: new Map([["conversation-1", {
        conversationId: "conversation-1",
        nodeId: "node-1",
        agentId: "agent-1",
        capabilityRevision: "cap-1",
        sessionId: "session-1",
      }]]),
      acceptances: [],
    };
  }

  async transaction<T>(work: (transaction: GatewayLedgerTransaction) => Promise<T>): Promise<T> {
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

  async findRequestByIdempotency(
    deviceId: string,
    key: string,
  ): Promise<AcceptedRequestRecord | undefined> {
    const requestId = this.state.idempotency.get(idempotencyKey(deviceId, key));
    return requestId === undefined ? undefined : this.state.requests.get(requestId);
  }

  async lockConversation(conversationId: string): Promise<boolean> {
    return this.state.sequences.has(conversationId);
  }

  async lockConversationRoute(conversationId: string): Promise<ConversationRouteRecord | undefined> {
    return this.state.routes.get(conversationId);
  }

  async findRequestById(requestId: string): Promise<AcceptedRequestRecord | undefined> {
    return this.state.requests.get(requestId);
  }

  async findRequestByCommand(deviceId: string, commandId: string): Promise<AcceptedRequestRecord | undefined> {
    return [...this.state.requests.values()].find(
      (request) => request.deviceId === deviceId && request.commandId === commandId,
    );
  }

  async getControlLease(conversationId: string): Promise<ControlLeaseRecord | undefined> {
    return this.state.leases.get(conversationId);
  }

  async getAgentTarget(nodeId: string, agentId: string): Promise<AgentTargetRecord | undefined> {
    return this.state.targets.get(targetKey(nodeId, agentId));
  }

  async allocateConversationSequence(conversationId: string): Promise<bigint | undefined> {
    const previous = this.state.sequences.get(conversationId);
    if (previous === undefined) {
      return undefined;
    }
    const next = previous + 1n;
    this.state.sequences.set(conversationId, next);
    return next;
  }

  async insertAcceptance(facts: AcceptanceFacts): Promise<void> {
    this.state.requests.set(facts.request.requestId, facts.request);
    this.state.idempotency.set(
      idempotencyKey(facts.request.deviceId, facts.request.idempotencyKey),
      facts.request.requestId,
    );
    this.state.acceptances.push(facts);
    if (this.failInsert) {
      throw new Error("injected insert failure");
    }
  }
}

function input(overrides: Partial<AcceptRequestInput> = {}): AcceptRequestInput {
  return {
    requestId: "request-1",
    commandId: "command-1",
    idempotencyKey: "idempotency-1",
    deviceId: "device-1",
    connectionId: "connection-1",
    conversationId: "conversation-1",
    sessionId: "session-1",
    leaseId: "lease-1",
    leaseRevision: 7n,
    nodeId: "node-1",
    agentId: "agent-1",
    capabilityRevision: "cap-1",
    confirmedText: "confirmed prompt",
    ...overrides,
  };
}

function dependencies(): AcceptanceDependencies {
  let nextId = 0;
  return {
    now: () => new Date("2030-01-01T00:00:00.000Z"),
    newOpaqueId: () => `generated-${++nextId}`,
  };
}

async function expectCode(promise: Promise<unknown>, code: GatewayCommandError["code"]): Promise<void> {
  await assert.rejects(promise, (error: unknown) => error instanceof GatewayCommandError && error.code === code);
}

test("accepts request, event, and both outboxes as one set of facts", async () => {
  const ledger = new MemoryLedger();
  const result = await acceptRequest(ledger, input(), dependencies());

  assert.equal(result.kind, "accepted");
  if (result.kind === "accepted") {
    assert.equal(result.facts.request.acceptedSequence, 1n);
    assert.equal(result.facts.request.confirmedTextSha256.length, 64);
    assert.equal(result.facts.event.type, "request.accepted");
    assert.equal(result.facts.event.sequence, 1n);
    assert.equal(result.facts.dispatchOutbox.nodeId, "node-1");
    assert.equal(result.facts.eventOutbox.eventId, result.facts.event.eventId);
  }
  assert.equal(ledger.state.acceptances.length, 1);
  assert.equal(ledger.state.sequences.get("conversation-1"), 1n);
});

test("returns the original acceptance for an exact retry without a second dispatch", async () => {
  const ledger = new MemoryLedger();
  const deps = dependencies();
  const first = await acceptRequest(ledger, input(), deps);
  assert.equal(first.kind, "accepted");

  ledger.state.devices.set("device-1", { deviceId: "device-1", active: false, scopes: [] });
  ledger.state.leases.get("conversation-1")!.expiresAt = new Date("2029-01-01T00:00:00.000Z");
  const retried = await acceptRequest(ledger, input(), deps);

  assert.equal(retried.kind, "existing");
  assert.equal(ledger.state.acceptances.length, 1);
  assert.equal(ledger.state.sequences.get("conversation-1"), 1n);
});

test("serializes concurrent duplicate submissions", async () => {
  const ledger = new MemoryLedger();
  const results = await Promise.all([
    acceptRequest(ledger, input(), dependencies()),
    acceptRequest(ledger, input(), dependencies()),
  ]);

  assert.deepEqual(
    results.map((result) => result.kind).sort(),
    ["accepted", "existing"],
  );
  assert.equal(ledger.state.acceptances.length, 1);
  assert.equal(ledger.state.sequences.get("conversation-1"), 1n);
});

test("allocates contiguous sequence across distinct requests and service recreation", async () => {
  const ledger = new MemoryLedger();
  await acceptRequest(ledger, input(), dependencies());
  const second = await acceptRequest(
    ledger,
    input({ requestId: "request-2", commandId: "command-2", idempotencyKey: "idempotency-2" }),
    dependencies(),
  );

  assert.equal(second.kind, "accepted");
  if (second.kind === "accepted") {
    assert.equal(second.facts.event.sequence, 2n);
  }
});

test("rejects reuse of an idempotency key with changed binding", async () => {
  const ledger = new MemoryLedger();
  await acceptRequest(ledger, input(), dependencies());
  await expectCode(
    acceptRequest(ledger, input({ confirmedText: "different confirmed prompt" }), dependencies()),
    "idempotency_conflict",
  );
  assert.equal(ledger.state.acceptances.length, 1);
});

test("rejects request identity collision independently of idempotency", async () => {
  const ledger = new MemoryLedger();
  await acceptRequest(ledger, input(), dependencies());
  await expectCode(
    acceptRequest(ledger, input({ commandId: "command-2", idempotencyKey: "idempotency-2" }), dependencies()),
    "request_id_conflict",
  );
});

test("rejects command identity collision independently of idempotency", async () => {
  const ledger = new MemoryLedger();
  await acceptRequest(ledger, input(), dependencies());
  await expectCode(
    acceptRequest(
      ledger,
      input({ requestId: "request-2", idempotencyKey: "idempotency-2" }),
      dependencies(),
    ),
    "command_id_conflict",
  );
});

test("enforces device, scope, lease, target, capability, and request size before allocation", async (context) => {
  const cases: ReadonlyArray<{
    name: string;
    arrange(ledger: MemoryLedger): void;
    overrides?: Partial<AcceptRequestInput>;
    code: GatewayCommandError["code"];
  }> = [
    {
      name: "unknown device",
      arrange: (ledger) => ledger.state.devices.clear(),
      code: "device_not_found",
    },
    {
      name: "revoked device",
      arrange: (ledger) => ledger.state.devices.set("device-1", { deviceId: "device-1", active: false, scopes: [] }),
      code: "device_revoked",
    },
    {
      name: "missing scope",
      arrange: (ledger) => ledger.state.devices.set("device-1", { deviceId: "device-1", active: true, scopes: [] }),
      code: "scope_missing",
    },
    {
      name: "unknown conversation",
      arrange: (ledger) => ledger.state.routes.clear(),
      code: "conversation_not_found",
    },
    {
      name: "stale lease",
      arrange: () => {},
      overrides: { leaseRevision: 6n },
      code: "control_lease_lost",
    },
    {
      name: "offline target",
      arrange: (ledger) => {
        ledger.state.targets.get(targetKey("node-1", "agent-1"))!.available = false;
      },
      code: "agent_unavailable",
    },
    {
      name: "changed capability",
      arrange: (ledger) => {
        ledger.state.targets.get(targetKey("node-1", "agent-1"))!.capabilityRevision = "cap-stale";
      },
      code: "capability_revision_changed",
    },
    {
      name: "oversized utf8 request",
      arrange: (ledger) => {
        ledger.state.targets.get(targetKey("node-1", "agent-1"))!.maxRequestBytes = 3n;
      },
      overrides: { confirmedText: "语音" },
      code: "request_too_large",
    },
  ];

  for (const entry of cases) {
    await context.test(entry.name, async () => {
      const ledger = new MemoryLedger();
      entry.arrange(ledger);
      await expectCode(acceptRequest(ledger, input(entry.overrides), dependencies()), entry.code);
      assert.equal(ledger.state.acceptances.length, 0);
      assert.equal(ledger.state.sequences.get("conversation-1") ?? 0n, 0n);
    });
  }
});

test("rejects a client route that differs from the persisted conversation route", async (context) => {
  const variants: ReadonlyArray<{ overrides: Partial<AcceptRequestInput>; omitSession?: true }> = [
    { overrides: { nodeId: "node-2" } },
    { overrides: { agentId: "agent-2" } },
    { overrides: { capabilityRevision: "cap-2" } },
    { overrides: { sessionId: "session-2" } },
    { overrides: {}, omitSession: true },
  ];
  for (const variant of variants) {
    await context.test(JSON.stringify(variant), async () => {
      const ledger = new MemoryLedger();
      const submitted = input(variant.overrides);
      if (variant.omitSession) delete submitted.sessionId;
      await expectCode(
        acceptRequest(ledger, submitted, dependencies()),
        "conversation_route_mismatch",
      );
      assert.equal(ledger.state.acceptances.length, 0);
    });
  }
});

test("rolls sequence and all facts back when insertion fails", async () => {
  const ledger = new MemoryLedger();
  ledger.failInsert = true;
  await assert.rejects(acceptRequest(ledger, input(), dependencies()), /injected insert failure/u);
  assert.equal(ledger.state.acceptances.length, 0);
  assert.equal(ledger.state.requests.size, 0);
  assert.equal(ledger.state.sequences.get("conversation-1"), 0n);
});
