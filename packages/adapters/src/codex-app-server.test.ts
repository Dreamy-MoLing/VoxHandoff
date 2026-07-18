import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { PassThrough } from "node:stream";
import test from "node:test";
import type { ChildProcessWithoutNullStreams } from "node:child_process";

import type { AgentEvent } from "@agent-talk/core";

import {
  CodexAppServerClient,
  type CodexProcessSpawner,
  type CodexServerRequest,
} from "./codex-app-server.js";

class FakeCodexProcess extends EventEmitter {
  readonly stdin = new PassThrough();
  readonly stdout = new PassThrough();
  readonly stderr = new PassThrough();
  readonly turnStartParams: unknown[] = [];
  #buffer = "";

  constructor() {
    super();
    this.stdin.setEncoding("utf8");
    this.stdin.on("data", (chunk: string) => {
      this.#buffer += chunk;
      let boundary = this.#buffer.indexOf("\n");
      while (boundary !== -1) {
        const line = this.#buffer.slice(0, boundary);
        this.#buffer = this.#buffer.slice(boundary + 1);
        this.#handle(JSON.parse(line));
        boundary = this.#buffer.indexOf("\n");
      }
    });
    queueMicrotask(() => {
      this.stderr.write("diagnostic Authorization: Bearer fake-secret-value\n");
    });
  }

  kill(): boolean {
    this.stdin.end();
    this.stdout.end();
    this.stderr.end();
    queueMicrotask(() => this.emit("exit", 0, null));
    return true;
  }

  #write(message: unknown): void {
    queueMicrotask(() => this.stdout.write(`${JSON.stringify(message)}\n`));
  }

  #handle(value: unknown): void {
    if (value === null || typeof value !== "object") return;
    const message = value as Record<string, unknown>;
    if (message.method === "initialize") {
      this.#write({ id: message.id, result: { version: "fake" } });
    } else if (message.method === "thread/start") {
      this.#write({ id: message.id, result: { thread: { id: "thread-1" } } });
    } else if (message.method === "turn/start") {
      this.turnStartParams.push(message.params);
      this.#write({ id: message.id, result: { turn: { id: "turn-1" } } });
      setTimeout(() => {
        this.#write({
          method: "thread/status/changed",
          params: { threadId: "thread-1", status: "active" },
        });
      }, 2);
      setTimeout(() => {
        this.#write({
          method: "turn/started",
          params: { threadId: "thread-1", turn: { id: "turn-1" } },
        });
      }, 5);
      setTimeout(() => {
        this.#write({
          id: "approval-1",
          method: "item/commandExecution/requestApproval",
          params: {
            threadId: "thread-1",
            turnId: "turn-1",
            command: "safe fake command",
            token: "fixture-secret-that-must-not-enter-normalized-events",
          },
        });
      }, 10);
    } else if (message.method === "turn/interrupt") {
      this.#write({ id: message.id, result: {} });
      setTimeout(() => {
        this.#write({
          method: "turn/completed",
          params: {
            threadId: "thread-1",
            turn: { id: "turn-1", status: "interrupted" },
          },
        });
      }, 5);
    }
  }
}

function waitFor<T>(subscribe: (resolve: (value: T) => void) => void): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("Timed out waiting for fake Codex event")), 2_000);
    subscribe((value) => {
      clearTimeout(timer);
      resolve(value);
    });
  });
}

test("Codex adapter blocks approval and distinguishes interrupt confirmation", async () => {
  const fakeProcess = new FakeCodexProcess();
  const spawnFake: CodexProcessSpawner = () =>
    fakeProcess as unknown as ChildProcessWithoutNullStreams;
  const client = new CodexAppServerClient({
    command: "fake-codex",
    spawnProcess: spawnFake,
  });

  const diagnostics: unknown[] = [];
  const serverRequests: CodexServerRequest[] = [];
  const events: AgentEvent[] = [];
  client.on("diagnostic", (value) => diagnostics.push(value));
  client.on("serverRequest", (value: CodexServerRequest) => serverRequests.push(value));
  client.on("agentEvent", (value: AgentEvent) => events.push(value));

  try {
    await client.start();
    const threadId = await client.startThread();
    const handle = await client.startTurn(threadId, "fake prompt", {
      requestId: "request-1",
      approvalPolicy: "untrusted",
      approvalsReviewer: "user",
    });
    assert.deepEqual(fakeProcess.turnStartParams, [
      {
        threadId: "thread-1",
        input: [{ type: "text", text: "fake prompt" }],
        approvalPolicy: "untrusted",
        approvalsReviewer: "user",
      },
    ]);

    const approval = await waitFor<AgentEvent>((resolve) => {
      const existing = events.find((event) => event.type === "approval.required");
      if (existing) resolve(existing);
      else {
        client.on("agentEvent", (event: AgentEvent) => {
          if (event.type === "approval.required") resolve(event);
        });
      }
    });

    assert.equal(serverRequests.length, 1);
    assert.deepEqual(approval.payload, {
      approvalId: "approval-1",
      method: "item/commandExecution/requestApproval",
      responseSupported: true,
      summary: "safe fake command",
    });
    assert.equal(events.find((event) => event.type === "request.accepted")?.sequence, 1);
    assert.equal(approval.sequence, 2);
    assert.doesNotMatch(JSON.stringify(approval), /fixture-secret/);
    assert.doesNotMatch(JSON.stringify(serverRequests), /fixture-secret/);

    await client.interruptTurn(handle.threadId, handle.turnId);
    const interrupted = await waitFor<AgentEvent>((resolve) => {
      const existing = events.find((event) => event.type === "request.interrupted");
      if (existing) resolve(existing);
      else {
        client.on("agentEvent", (event: AgentEvent) => {
          if (event.type === "request.interrupted") resolve(event);
        });
      }
    });

    assert.equal(interrupted.type, "request.interrupted");
    assert.deepEqual(interrupted.payload, { reason: "interrupted" });
    assert.equal(interrupted.sequence, approval.sequence + 1);
    assert.doesNotMatch(JSON.stringify(diagnostics), /fake-secret-value/);
    assert.match(JSON.stringify(diagnostics), /\[REDACTED\]/);
  } finally {
    await client.close();
  }
});
