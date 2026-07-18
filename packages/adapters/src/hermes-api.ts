import { randomUUID } from "node:crypto";

import type { AgentCapabilities, AgentEvent } from "@agent-talk/core";

import { isRecord, numberAt, stringAt } from "./guards.js";
import { parseSseStream } from "./sse.js";

export interface HermesApiOptions {
  baseUrl: string;
  token: string;
  fetch?: typeof globalThis.fetch;
  allowInsecureHttp?: boolean;
}

export interface HermesRun {
  runId: string;
  requestId: string;
  sessionId?: string;
}

export class HermesApiClient {
  readonly connectionId = randomUUID();
  readonly #baseUrl: URL;
  readonly #token: string;
  readonly #fetch: typeof globalThis.fetch;

  constructor(options: HermesApiOptions) {
    this.#baseUrl = new URL(options.baseUrl.endsWith("/") ? options.baseUrl : `${options.baseUrl}/`);
    const localHosts = new Set(["localhost", "127.0.0.1", "[::1]"]);
    if (
      this.#baseUrl.protocol === "http:" &&
      !localHosts.has(this.#baseUrl.hostname) &&
      !options.allowInsecureHttp
    ) {
      throw new Error(
        "Remote Hermes connections require HTTPS; use an SSH/private localhost tunnel or explicitly allow insecure HTTP for isolated development",
      );
    }
    if (this.#baseUrl.protocol !== "http:" && this.#baseUrl.protocol !== "https:") {
      throw new Error("Hermes base URL must use HTTP or HTTPS");
    }
    if (!options.token) throw new Error("Hermes API token is required");
    this.#token = options.token;
    this.#fetch = options.fetch ?? globalThis.fetch;
  }

  async health(): Promise<unknown> {
    return this.#json("health");
  }

  async capabilities(): Promise<AgentCapabilities> {
    const native = await this.#json("v1/capabilities");
    return normalizeHermesCapabilities(native);
  }

  async createSession(title?: string): Promise<string> {
    const result = await this.#json("api/sessions", {
      method: "POST",
      body: JSON.stringify(title ? { title } : {}),
    });
    const id = stringAt(result, "id") ?? stringAt(result, "session", "id");
    if (!id) throw new Error("Hermes session creation returned no session id");
    return id;
  }

  async startRun(
    input: string,
    options: { sessionId?: string; requestId?: string } = {},
  ): Promise<HermesRun> {
    const requestId = options.requestId ?? randomUUID();
    const result = await this.#json("v1/runs", {
      method: "POST",
      headers: { "Idempotency-Key": requestId },
      body: JSON.stringify({
        input,
        ...(options.sessionId === undefined ? {} : { session_id: options.sessionId }),
      }),
    });
    const runId = stringAt(result, "run_id") ?? stringAt(result, "id");
    if (!runId) throw new Error("Hermes run creation returned no run id");
    return {
      runId,
      requestId,
      ...(options.sessionId === undefined ? {} : { sessionId: options.sessionId }),
    };
  }

  async *streamRunEvents(
    run: HermesRun,
    signal?: AbortSignal,
  ): AsyncGenerator<AgentEvent> {
    const response = await this.#request(`v1/runs/${encodeURIComponent(run.runId)}/events`, {
      headers: { Accept: "text/event-stream" },
      ...(signal === undefined ? {} : { signal }),
    });
    if (!response.body) throw new Error("Hermes event stream returned no response body");

    let localSequence = 0;
    for await (const message of parseSseStream(response.body)) {
      if (message.data === "[DONE]") continue;
      let native: unknown;
      try {
        native = JSON.parse(message.data);
      } catch {
        native = { text: message.data };
      }
      localSequence += 1;
      yield normalizeHermesEvent({
        native,
        ...(message.event === undefined ? {} : { eventName: message.event }),
        fallbackSequence: localSequence,
        connectionId: this.connectionId,
        run,
      });
    }
  }

  async stopRun(runId: string): Promise<void> {
    await this.#json(`v1/runs/${encodeURIComponent(runId)}/stop`, {
      method: "POST",
      body: "{}",
    });
  }

  async resolveApproval(
    runId: string,
    approvalId: string,
    approved: boolean,
  ): Promise<void> {
    await this.#json(`v1/runs/${encodeURIComponent(runId)}/approval`, {
      method: "POST",
      body: JSON.stringify({ approval_id: approvalId, approved }),
    });
  }

  async #json(path: string, init: RequestInit = {}): Promise<unknown> {
    const response = await this.#request(path, init);
    const text = await response.text();
    if (!text) return {};
    try {
      return JSON.parse(text);
    } catch {
      throw new Error(`Hermes returned invalid JSON from ${path}`);
    }
  }

  async #request(path: string, init: RequestInit = {}): Promise<Response> {
    const headers = new Headers(init.headers);
    headers.set("Authorization", `Bearer ${this.#token}`);
    if (init.body !== undefined && !headers.has("Content-Type")) {
      headers.set("Content-Type", "application/json");
    }
    const response = await this.#fetch(new URL(path, this.#baseUrl), { ...init, headers });
    if (!response.ok) {
      const detail = (await response.text()).slice(0, 500);
      throw new Error(
        `Hermes HTTP ${response.status} ${response.statusText}${detail ? `: ${detail}` : ""}`,
      );
    }
    return response;
  }
}

export function normalizeHermesCapabilities(native: unknown): AgentCapabilities {
  const flag = (name: string, fallback: boolean): boolean => {
    if (!isRecord(native)) return fallback;
    const value = native[name];
    if (typeof value === "boolean") return value;
    if (isRecord(native.features) && typeof native.features[name] === "boolean") {
      return native.features[name];
    }
    return fallback;
  };
  const protocolVersion = stringAt(native, "protocol_version");
  const serverVersion = stringAt(native, "version");
  const maxRequestBytes = numberAt(native, "limits", "max_request_bytes");
  const requestTimeoutMs = numberAt(native, "limits", "request_timeout_ms");
  return {
    ...(protocolVersion === undefined ? {} : { protocolVersion }),
    ...(serverVersion === undefined ? {} : { serverVersion }),
    streamingText: flag("streaming", true),
    eventStream: flag("runs", true),
    sessionHistory: flag("session_history", true),
    createSession: flag("session_create", true),
    resumeSession: flag("session_resume", true),
    cancel: flag("run_stop", true),
    steer: flag("steer", false),
    clarification: flag("clarification", false),
    approval: flag("approval", true),
    toolProgress: flag("tool_progress", true),
    fileMessages: flag("file_messages", false),
    idempotencyKey: flag("idempotency", true),
    eventReplay: flag("event_replay", false),
    ...(maxRequestBytes === undefined ? {} : { maxRequestBytes }),
    ...(requestTimeoutMs === undefined ? {} : { requestTimeoutMs }),
  };
}

interface NormalizeHermesEventInput {
  native: unknown;
  eventName?: string;
  fallbackSequence: number;
  connectionId: string;
  run: HermesRun;
}

function normalizeHermesEvent(input: NormalizeHermesEventInput): AgentEvent {
  const nativeType =
    input.eventName ?? stringAt(input.native, "type") ?? stringAt(input.native, "event") ?? "unknown";
  const common = {
    connectionId: input.connectionId,
    ...(input.run.sessionId === undefined ? {} : { sessionId: input.run.sessionId }),
    requestId: input.run.requestId,
    sequence: numberAt(input.native, "seq") ?? input.fallbackSequence,
    serverTime: stringAt(input.native, "timestamp") ?? new Date().toISOString(),
    payload: input.native,
    final: false,
  };

  if (/assistant\.delta|message\.delta|response\.output_text\.delta/.test(nativeType)) {
    return {
      ...common,
      type: "message.delta",
      payload: {
        delta:
          stringAt(input.native, "delta") ??
          stringAt(input.native, "text") ??
          stringAt(input.native, "payload", "delta") ??
          "",
        native: input.native,
      },
    };
  }
  if (/message\.complete|message\.completed|assistant\.completed/.test(nativeType)) {
    return {
      ...common,
      type: "message.completed",
      payload: {
        text:
          stringAt(input.native, "text") ??
          stringAt(input.native, "message", "content") ??
          stringAt(input.native, "payload", "text") ??
          "",
        native: input.native,
      },
    };
  }
  if (/tool\.(start|started)/.test(nativeType)) return { ...common, type: "tool.started" };
  if (/tool\.(complete|completed)/.test(nativeType)) return { ...common, type: "tool.completed" };
  if (/approval/.test(nativeType)) return { ...common, type: "approval.required" };
  if (/clarif/.test(nativeType)) return { ...common, type: "clarification.required" };
  if (/run\.(complete|completed)|request\.completed/.test(nativeType)) {
    return { ...common, type: "request.completed", final: true };
  }
  if (/run\.(cancel|cancelled|stopped)/.test(nativeType)) {
    return { ...common, type: "request.cancelled", final: true };
  }
  if (/run\.(fail|failed)|error/.test(nativeType)) {
    return { ...common, type: "request.failed", final: true };
  }
  if (/run\.(accept|accepted|created)/.test(nativeType)) {
    return { ...common, type: "request.accepted" };
  }
  return { ...common, type: "agent.working" };
}
