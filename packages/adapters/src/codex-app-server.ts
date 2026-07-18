import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { EventEmitter } from "node:events";
import { randomUUID } from "node:crypto";
import readline from "node:readline";

import type { AgentEvent } from "@agent-talk/core";

import { isRecord, stringAt } from "./guards.js";

interface PendingRequest {
  resolve(value: unknown): void;
  reject(error: Error): void;
}

interface RpcRequest {
  id: number | string;
  method: string;
  params?: unknown;
}

export interface CodexClientOptions {
  command?: string;
  args?: string[];
  clientName?: string;
  clientTitle?: string;
  clientVersion?: string;
  cwd?: string;
}

export interface StartThreadOptions {
  model?: string;
  cwd?: string;
}

export interface CodexTurnHandle {
  threadId: string;
  turnId: string;
  requestId: string;
}

export interface CodexNotification {
  method: string;
  params: unknown;
}

export interface CodexServerRequest extends RpcRequest {}

export class CodexAppServerClient extends EventEmitter {
  readonly connectionId = randomUUID();
  #process: ChildProcessWithoutNullStreams | undefined;
  #nextId = 1;
  #pending = new Map<number | string, PendingRequest>();
  #requestByThread = new Map<string, string>();
  #requestByTurn = new Map<string, string>();
  #sequenceByRequest = new Map<string, number>();
  readonly #options: Required<
    Pick<CodexClientOptions, "command" | "args" | "clientName" | "clientTitle" | "clientVersion">
  > &
    Pick<CodexClientOptions, "cwd">;

  constructor(options: CodexClientOptions = {}) {
    super();
    this.#options = {
      command: options.command ?? "codex",
      args: options.args ?? ["app-server", "--listen", "stdio://"],
      clientName: options.clientName ?? "agent_talk",
      clientTitle: options.clientTitle ?? "Agent Talk",
      clientVersion: options.clientVersion ?? "0.1.0",
      ...(options.cwd === undefined ? {} : { cwd: options.cwd }),
    };
  }

  async start(): Promise<void> {
    if (this.#process) return;
    const child = spawn(this.#options.command, this.#options.args, {
      stdio: ["pipe", "pipe", "pipe"],
      ...(this.#options.cwd === undefined ? {} : { cwd: this.#options.cwd }),
    });
    this.#process = child;

    readline.createInterface({ input: child.stdout }).on("line", (line) => {
      this.#handleLine(line);
    });
    readline.createInterface({ input: child.stderr }).on("line", (line) => {
      this.emit("diagnostic", { source: "codex.stderr", message: line });
    });
    child.once("error", (error) => this.#terminatePending(error));
    child.once("exit", (code, signal) => {
      this.#process = undefined;
      this.#terminatePending(
        new Error(`Codex app-server exited (code=${String(code)}, signal=${String(signal)})`),
      );
      this.emit("disconnect", { code, signal });
    });

    await this.request("initialize", {
      clientInfo: {
        name: this.#options.clientName,
        title: this.#options.clientTitle,
        version: this.#options.clientVersion,
      },
    });
    this.notify("initialized", {});
  }

  async close(): Promise<void> {
    const child = this.#process;
    if (!child) return;
    this.#process = undefined;
    child.kill("SIGTERM");
  }

  request<T = unknown>(method: string, params: unknown = {}): Promise<T> {
    const id = this.#nextId++;
    return new Promise<T>((resolve, reject) => {
      this.#pending.set(id, {
        resolve: (value) => resolve(value as T),
        reject,
      });
      try {
        this.#write({ method, id, params });
      } catch (error) {
        this.#pending.delete(id);
        reject(error instanceof Error ? error : new Error(String(error)));
      }
    });
  }

  notify(method: string, params: unknown = {}): void {
    this.#write({ method, params });
  }

  respond(id: number | string, result: unknown): void {
    this.#write({ id, result });
  }

  respondError(id: number | string, code: number, message: string): void {
    this.#write({ id, error: { code, message } });
  }

  async startThread(options: StartThreadOptions = {}): Promise<string> {
    const result = await this.request("thread/start", options);
    const threadId = stringAt(result, "thread", "id");
    if (!threadId) throw new Error("Codex thread/start returned no thread id");
    return threadId;
  }

  async resumeThread(threadId: string): Promise<void> {
    await this.request("thread/resume", { threadId });
  }

  async startTurn(
    threadId: string,
    text: string,
    requestId = randomUUID(),
  ): Promise<CodexTurnHandle> {
    this.#requestByThread.set(threadId, requestId);
    const result = await this.request("turn/start", {
      threadId,
      input: [{ type: "text", text }],
    });
    const turnId = stringAt(result, "turn", "id");
    if (!turnId) throw new Error("Codex turn/start returned no turn id");
    this.#requestByTurn.set(turnId, requestId);
    return { threadId, turnId, requestId };
  }

  async interruptTurn(threadId: string, turnId: string): Promise<void> {
    await this.request("turn/interrupt", { threadId, turnId });
  }

  #write(message: unknown): void {
    if (!this.#process?.stdin.writable) {
      throw new Error("Codex app-server is not running");
    }
    this.#process.stdin.write(`${JSON.stringify(message)}\n`);
  }

  #handleLine(line: string): void {
    let message: unknown;
    try {
      message = JSON.parse(line);
    } catch {
      this.emit("diagnostic", { source: "codex.stdout", message: "Invalid JSON line" });
      return;
    }
    if (!isRecord(message)) return;

    const id = message.id;
    if ((typeof id === "number" || typeof id === "string") && !message.method) {
      const pending = this.#pending.get(id);
      if (!pending) return;
      this.#pending.delete(id);
      if (isRecord(message.error)) {
        pending.reject(
          new Error(
            typeof message.error.message === "string"
              ? message.error.message
              : "Codex RPC request failed",
          ),
        );
      } else {
        pending.resolve(message.result);
      }
      return;
    }

    if (typeof message.method !== "string") return;
    if (typeof id === "number" || typeof id === "string") {
      this.emit("serverRequest", {
        id,
        method: message.method,
        params: message.params,
      } satisfies CodexServerRequest);
      this.#emitNormalized(message.method, message.params, id);
      return;
    }

    this.emit("notification", {
      method: message.method,
      params: message.params,
    } satisfies CodexNotification);
    this.#emitNormalized(message.method, message.params);
  }

  #emitNormalized(method: string, params: unknown, rpcId?: number | string): void {
    const threadId = stringAt(params, "threadId") ?? stringAt(params, "thread", "id");
    const turnId = stringAt(params, "turnId") ?? stringAt(params, "turn", "id");
    const requestId =
      (turnId ? this.#requestByTurn.get(turnId) : undefined) ??
      (threadId ? this.#requestByThread.get(threadId) : undefined);
    if (!requestId) return;

    const base = {
      connectionId: this.connectionId,
      ...(threadId === undefined ? {} : { sessionId: threadId }),
      requestId,
      sequence: (this.#sequenceByRequest.get(requestId) ?? 0) + 1,
      serverTime: new Date().toISOString(),
      payload: params,
      final: false,
    };
    this.#sequenceByRequest.set(requestId, base.sequence);

    let event: AgentEvent | undefined;
    if (method === "turn/started") {
      if (turnId) this.#requestByTurn.set(turnId, requestId);
      event = { ...base, type: "request.accepted" };
    } else if (method === "item/agentMessage/delta") {
      event = {
        ...base,
        type: "message.delta",
        payload: { delta: stringAt(params, "delta") ?? "", native: params },
      };
    } else if (method === "item/started") {
      const itemType = stringAt(params, "item", "type");
      if (itemType && itemType !== "userMessage" && itemType !== "agentMessage" && itemType !== "reasoning") {
        event = { ...base, type: "tool.started" };
      }
    } else if (method === "item/completed") {
      const itemType = stringAt(params, "item", "type");
      const text = stringAt(params, "item", "text");
      if (itemType === "agentMessage" && text !== undefined) {
        event = {
          ...base,
          type: "message.completed",
          payload: { text, native: params },
        };
      } else if (
        itemType &&
        itemType !== "userMessage" &&
        itemType !== "reasoning" &&
        itemType !== "plan"
      ) {
        event = { ...base, type: "tool.completed" };
      }
    } else if (method === "turn/completed") {
      const status = stringAt(params, "turn", "status");
      const type =
        status === "interrupted" || status === "cancelled"
          ? "request.cancelled"
          : status === "failed"
            ? "request.failed"
            : "request.completed";
      event = { ...base, type, final: true };
    } else if (/approval/i.test(method)) {
      event = {
        ...base,
        type: "approval.required",
        payload: { rpcId, method, native: params },
      };
    } else if (/elicitation|userInput|clarif/i.test(method)) {
      event = {
        ...base,
        type: "clarification.required",
        payload: { rpcId, method, native: params },
      };
    }

    if (event) this.emit("agentEvent", event);
  }

  #terminatePending(error: Error): void {
    for (const pending of this.#pending.values()) pending.reject(error);
    this.#pending.clear();
  }
}
