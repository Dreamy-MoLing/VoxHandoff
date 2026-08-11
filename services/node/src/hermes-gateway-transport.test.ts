import assert from "node:assert/strict";
import { performance } from "node:perf_hooks";
import test from "node:test";

import type { AgentCapabilities, AgentEvent } from "@agent-talk/core";
import type { HermesApprovalResolutionMode, HermesRun } from "@agent-talk/adapters";
import { create } from "@bufbuild/protobuf";
import {
  AgentCapabilitiesSchema,
  GatewayControlService,
  NodeEventReceiptSchema,
} from "@agent-talk/protocol";
import {
  createGatewayControlService,
  startGatewayServer,
  type AuthenticatedPrincipal,
  type GatewayStreamHandlers,
  type StreamIdentityVerifier,
} from "@agent-talk/gateway";

import { createGatewayControlClient } from "./gateway-client.js";
import {
  HermesNodeConnector,
  type HermesAgentPort,
} from "./hermes-node-connector.js";

const capabilities: AgentCapabilities = {
  deltaMode: "append_only",
  eventStream: true,
  sessionHistory: false,
  createSession: false,
  resumeSession: false,
  interrupt: true,
  steer: false,
  clarification: false,
  approval: false,
  toolEvents: false,
  attachments: false,
  idempotency: true,
  replay: false,
  sequenceRecovery: false,
};

class IdleHermes implements HermesAgentPort {
  async health(): Promise<unknown> {
    return { status: "ok" };
  }

  async capabilities(): Promise<AgentCapabilities> {
    return capabilities;
  }

  async createSession(): Promise<string> {
    throw new Error("this transport test never dispatches a run");
  }

  async startRun(): Promise<HermesRun> {
    throw new Error("this transport test never dispatches a run");
  }

  async *streamRunEvents(): AsyncGenerator<AgentEvent> {
    return;
  }

  async stopRun(): Promise<void> {}

  async resolveApproval(): Promise<void> {}

  approvalResolutionMode(): HermesApprovalResolutionMode {
    return "exact";
  }
}

class LoopbackVerifier implements StreamIdentityVerifier {
  async authenticate(
    headers: Headers,
    expectedRole: AuthenticatedPrincipal["role"],
  ): Promise<AuthenticatedPrincipal> {
    assert.equal(expectedRole, "node");
    assert.equal(headers.get("authorization"), "Bearer loopback-node-token");
    return { principalId: "node-1", role: "node", scopes: ["node:connect"] };
  }

  async revalidate(): Promise<void> {}
}

test("keeps the production Node stream alive over real loopback HTTP/2 for more than 60 seconds", {
  skip:
    process.env.AGENT_TALK_LOOPBACK_INTEGRATION === "1"
      ? false
      : "set AGENT_TALK_LOOPBACK_INTEGRATION=1 for explicit socket integration",
  timeout: 80_000,
}, async () => {
  const abortController = new AbortController();
  const enoughHeartbeats = deferred();
  let heartbeats = 0;
  const handlers: GatewayStreamHandlers = {
    async onClientCommand() {
      return [];
    },
    async onClientAck() {},
    async onNodeRegistration() {
      return [];
    },
    async onNodeHeartbeat() {
      heartbeats += 1;
      if (heartbeats >= 6) enoughHeartbeats.resolve();
      return [];
    },
    async onNodeDispatchAck() {},
    async onNodeEvent(event) {
      return create(NodeEventReceiptSchema, {
        eventId: event.eventId,
        requestId: event.requestId,
        conversationId: event.conversationId,
        sourceSequence: event.sequence,
        gatewaySequence: 1n,
        duplicate: false,
      });
    },
  };
  const service = createGatewayControlService({
    identityVerifier: new LoopbackVerifier(),
    handlers,
    handshake: {
      schemaBuild: "gateway-transport-test",
      schemaSha256: "b".repeat(64),
      componentVersion: "test",
      capabilityRevision: "gateway-capability-1",
      capabilities: create(AgentCapabilitiesSchema, { eventStream: true, attachments: false }),
    },
    newConnectionId: () => "gateway-connection-1",
  });
  const running = await startGatewayServer({
    controlService: service,
    host: "127.0.0.1",
    port: 0,
    allowInsecureLoopbackForTests: true,
  });
  try {
    const connector = new HermesNodeConnector(new IdleHermes(), {
      nodeId: "node-1",
      agentId: "agent-1",
      nodeDisplayName: "Node",
      agentDisplayName: "Hermes",
    });
    await connector.initialize();
    const startedAt = performance.now();
    const run = connector.run(
      createGatewayControlClient(
        `http://127.0.0.1:${running.address.port}`,
        { idleConnectionTimeoutMs: 10 },
      ),
      "loopback-node-token",
      abortController.signal,
    );

    await within(enoughHeartbeats.promise, 72_000);
    const elapsedMs = performance.now() - startedAt;
    abortController.abort();
    await run;
    assert.ok(heartbeats >= 6, `expected at least six heartbeats, received ${heartbeats}`);
    assert.ok(elapsedMs > 60_000, `expected more than 60s of healthy streaming, received ${elapsedMs.toFixed(0)}ms`);
  } finally {
    abortController.abort();
    await running.close();
  }
});

function deferred(): { promise: Promise<void>; resolve(): void } {
  let resolvePromise!: () => void;
  const promise = new Promise<void>((resolve) => {
    resolvePromise = resolve;
  });
  return { promise, resolve: resolvePromise };
}

function within(promise: Promise<void>, timeoutMs: number): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error(`Timed out after ${timeoutMs}ms waiting for Node heartbeats`));
    }, timeoutMs);
    void promise.then(
      () => {
        clearTimeout(timeout);
        resolve();
      },
      (error: unknown) => {
        clearTimeout(timeout);
        reject(error);
      },
    );
  });
}
