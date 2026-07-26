import { createHash, randomUUID } from "node:crypto";

import type { AgentCapabilities, AgentEvent } from "@agent-talk/core";

import { isRecord, numberAt, stringAt } from "./guards.js";
import { parseSseStream, SseTransportError } from "./sse.js";

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

export interface HermesEventStreamOptions {
  signal?: AbortSignal;
  lastEventId?: string;
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
    options: HermesEventStreamOptions | AbortSignal = {},
  ): AsyncGenerator<AgentEvent> {
    const streamOptions = isAbortSignal(options) ? { signal: options } : options;
    if (streamOptions.lastEventId !== undefined && !isOpaqueIdentity(streamOptions.lastEventId)) {
      throw new Error("Hermes last event id is invalid");
    }
    const headers = new Headers({ Accept: "text/event-stream" });
    if (streamOptions.lastEventId !== undefined) {
      headers.set("Last-Event-ID", streamOptions.lastEventId);
    }
    const response = await this.#request(`v1/runs/${encodeURIComponent(run.runId)}/events`, {
      headers,
      ...(streamOptions.signal === undefined ? {} : { signal: streamOptions.signal }),
    });
    if (!response.body) throw new Error("Hermes event stream returned no response body");

    let localOrdinal = 0;
    let lastSequence = 0;
    let terminalSeen = false;
    const seenEventIds = new Set<string>();
    try {
      for await (const message of parseSseStream(response.body)) {
        if (message.data === "[DONE]") continue;
        let native: unknown;
        try {
          native = JSON.parse(message.data);
        } catch {
          throw new Error("Hermes event stream returned invalid JSON");
        }
        localOrdinal += 1;
        const event = normalizeHermesEvent({
          native,
          ...(message.event === undefined ? {} : { eventName: message.event }),
          ...(message.id === undefined ? {} : { sseEventId: message.id }),
          fallbackOrdinal: localOrdinal,
          connectionId: this.connectionId,
          run,
        });
        if (seenEventIds.has(event.eventId)) continue;
        if (event.sequence <= lastSequence) {
          throw new Error("Hermes event sequence is not strictly increasing");
        }
        seenEventIds.add(event.eventId);
        lastSequence = event.sequence;
        terminalSeen = terminalSeen || isTerminalEvent(event);
        yield event;
      }
    } catch (error) {
      if (!(error instanceof SseTransportError) || terminalSeen) throw error;
      yield connectionLostEvent(
        this.connectionId,
        run,
        lastSequence + 1,
        "transport_disconnected",
      );
      return;
    }
    if (!terminalSeen) {
      yield connectionLostEvent(this.connectionId, run, lastSequence + 1, "unexpected_eof");
    }
  }

  async stopRun(runId: string, commandId: string = randomUUID()): Promise<void> {
    if (!commandId) throw new Error("Hermes stop command id is required");
    await this.#json(`v1/runs/${encodeURIComponent(runId)}/stop`, {
      method: "POST",
      headers: { "Idempotency-Key": commandId },
      body: "{}",
    });
  }

  async resolveApproval(
    runId: string,
    approvalId: string,
    approved: boolean,
    commandId: string = randomUUID(),
  ): Promise<void> {
    if (!approvalId) throw new Error("Hermes approval id is required");
    if (!commandId) throw new Error("Hermes approval command id is required");
    await this.#json(`v1/runs/${encodeURIComponent(runId)}/approval`, {
      method: "POST",
      headers: { "Idempotency-Key": commandId },
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
      await response.body?.cancel().catch(() => undefined);
      throw new Error(`Hermes HTTP ${response.status} ${response.statusText}`);
    }
    return response;
  }
}

function isTerminalEvent(event: AgentEvent): boolean {
  return (
    event.type === "request.completed" ||
    event.type === "request.failed" ||
    event.type === "request.cancelled" ||
    event.type === "request.interrupted"
  );
}

function connectionLostEvent(
  connectionId: string,
  run: HermesRun,
  sequence: number,
  reason: "transport_disconnected" | "unexpected_eof",
): AgentEvent {
  return {
    eventId: stableEventId(run.runId, `connection:${reason}:${sequence}`),
    connectionId,
    ...(run.sessionId === undefined ? {} : { sessionId: run.sessionId }),
    requestId: run.requestId,
    sequence,
    occurredAt: new Date().toISOString(),
    type: "connection.lost",
    payload: { reason },
  };
}

export function normalizeHermesCapabilities(native: unknown): AgentCapabilities {
  const flag = (name: string): boolean => {
    if (!isRecord(native)) return false;
    const value = native[name];
    if (typeof value === "boolean") return value;
    if (isRecord(native.features) && typeof native.features[name] === "boolean") {
      return native.features[name];
    }
    return false;
  };
  const protocolVersion = stringAt(native, "protocol_version");
  const serverVersion = stringAt(native, "version");
  const maxRequestBytes = numberAt(native, "limits", "max_request_bytes");
  const requestTimeoutMs = numberAt(native, "limits", "request_timeout_ms");
  return {
    ...(protocolVersion === undefined ? {} : { protocolVersion }),
    ...(serverVersion === undefined ? {} : { serverVersion }),
    deltaMode: flag("streaming") && flag("append_only_delta") ? "append_only" : "none",
    eventStream: flag("runs"),
    sessionHistory: flag("session_history"),
    createSession: flag("session_create"),
    resumeSession: flag("session_resume"),
    interrupt: flag("run_stop"),
    steer: flag("steer"),
    clarification: flag("clarification"),
    approval: flag("approval"),
    toolEvents: flag("tool_progress"),
    attachments: false,
    idempotency: flag("idempotency"),
    replay: flag("event_replay"),
    sequenceRecovery: flag("sequence_recovery") && flag("stable_event_ids"),
    ...(maxRequestBytes === undefined ? {} : { maxRequestBytes }),
    ...(requestTimeoutMs === undefined ? {} : { requestTimeoutMs }),
  };
}

interface NormalizeHermesEventInput {
  native: unknown;
  eventName?: string;
  sseEventId?: string;
  fallbackOrdinal: number;
  connectionId: string;
  run: HermesRun;
}

function normalizeHermesEvent(input: NormalizeHermesEventInput): AgentEvent {
  const nativeType =
    input.eventName ?? stringAt(input.native, "type") ?? stringAt(input.native, "event") ?? "unknown";
  const nativeSequence = positiveIntegerAt(input.native, "sequence") ??
    positiveIntegerAt(input.native, "seq");
  const sourceOrdinal = nativeSequence ?? input.fallbackOrdinal;
  const sequence = sourceOrdinal * 2;
  if (!Number.isSafeInteger(sequence)) {
    throw new Error("Hermes event sequence exceeds the supported safe range");
  }
  const sourceIdentity =
    normalizedSseIdentity(input.sseEventId) ??
    normalizedNativeEventIdentity(input.native) ??
    `ordinal:${input.fallbackOrdinal}:${canonicalJson(input.native)}:${nativeType}`;
  const common = {
    eventId: stableEventId(input.run.runId, sourceIdentity),
    connectionId: input.connectionId,
    ...(input.run.sessionId === undefined ? {} : { sessionId: input.run.sessionId }),
    requestId: input.run.requestId,
    sequence,
    occurredAt: normalizedOccurredAt(input.native),
    payload: {},
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
      },
    };
  }
  if (/tool\.(start|started)/.test(nativeType)) {
    return { ...common, type: "tool.started", payload: { toolName: nativeType } };
  }
  if (/tool\.(complete|completed)/.test(nativeType)) {
    return { ...common, type: "tool.completed", payload: { toolName: nativeType } };
  }
  if (/tool\.(fail|failed)/.test(nativeType)) {
    return { ...common, type: "tool.failed", payload: { toolName: nativeType } };
  }
  if (/approval\.(resolved|approved|rejected)/.test(nativeType)) {
    const outcome = /rejected/.test(nativeType) ? "rejected" : "approved";
    return {
      ...common,
      type: "approval.resolved",
      payload: {
        approvalId:
          stringAt(input.native, "approval_id") ??
          stringAt(input.native, "id") ??
          `unresolved:${common.eventId}`,
        outcome,
      },
    };
  }
  if (/approval\.expired/.test(nativeType)) {
    return { ...common, type: "approval.expired" };
  }
  if (/approval\.cancelled/.test(nativeType)) {
    return { ...common, type: "approval.cancelled" };
  }
  if (/approval/.test(nativeType)) {
    return {
      ...common,
      type: "approval.required",
      payload: {
        approvalId:
          stringAt(input.native, "approval_id") ??
          stringAt(input.native, "id") ??
          `unresolved:${common.eventId}`,
      },
    };
  }
  if (/clarif.*\.(resolved|answered)/.test(nativeType)) {
    return { ...common, type: "clarification.resolved" };
  }
  if (/clarif.*\.expired/.test(nativeType)) {
    return { ...common, type: "clarification.expired" };
  }
  if (/clarif.*\.cancelled/.test(nativeType)) {
    return { ...common, type: "clarification.cancelled" };
  }
  if (/clarif/.test(nativeType)) {
    return {
      ...common,
      type: "clarification.required",
      payload: {
        clarificationId:
          stringAt(input.native, "clarification_id") ??
          stringAt(input.native, "id") ??
          `unresolved:${common.eventId}`,
      },
    };
  }
  if (/run\.(complete|completed)|request\.completed/.test(nativeType)) {
    return { ...common, type: "request.completed" };
  }
  if (/run\.(interrupt|interrupted)|request\.interrupted/.test(nativeType)) {
    return { ...common, type: "request.interrupted", payload: { reason: nativeType } };
  }
  if (/run\.(cancel|cancelled|stopped)/.test(nativeType)) {
    return { ...common, type: "request.cancelled", payload: { reason: nativeType } };
  }
  if (/run\.(fail|failed)|error/.test(nativeType)) {
    return {
      ...common,
      type: "request.failed",
      payload: {
        code: stringAt(input.native, "code") ?? "hermes_run_failed",
        message: stringAt(input.native, "message")?.slice(0, 500) ?? "Hermes run failed",
      },
    };
  }
  if (/run\.(accept|accepted|created)/.test(nativeType)) {
    return { ...common, type: "request.accepted" };
  }
  return { ...common, type: "agent.working", payload: { nativeType: nativeType.slice(0, 120) } };
}

function isAbortSignal(value: HermesEventStreamOptions | AbortSignal): value is AbortSignal {
  return typeof AbortSignal !== "undefined" && value instanceof AbortSignal;
}

function isOpaqueIdentity(value: string): boolean {
  return value.length > 0 && value.length <= 512 && !/[\u0000-\u001f\u007f]/.test(value);
}

function normalizedSseIdentity(value: string | undefined): string | undefined {
  return value !== undefined && isOpaqueIdentity(value) ? `sse:${value}` : undefined;
}

function normalizedNativeEventIdentity(native: unknown): string | undefined {
  const value = stringAt(native, "event_id") ?? stringAt(native, "event", "id");
  return value !== undefined && isOpaqueIdentity(value) ? `native:${value}` : undefined;
}

function positiveIntegerAt(value: unknown, key: string): number | undefined {
  const candidate = numberAt(value, key);
  return candidate !== undefined &&
      Number.isSafeInteger(candidate) &&
      candidate > 0 &&
      candidate <= Math.floor(Number.MAX_SAFE_INTEGER / 2)
    ? candidate
    : undefined;
}

function stableEventId(runId: string, sourceIdentity: string): string {
  return createHash("sha256")
    .update("voxhandoff:hermes-event:v1\0")
    .update(runId)
    .update("\0")
    .update(sourceIdentity)
    .digest("hex");
}

function normalizedOccurredAt(native: unknown): string {
  const candidate =
    stringAt(native, "occurred_at") ??
    stringAt(native, "created_at") ??
    stringAt(native, "timestamp");
  if (candidate !== undefined) {
    const parsed = new Date(candidate);
    if (!Number.isNaN(parsed.getTime())) return parsed.toISOString();
  }
  return new Date().toISOString();
}

function canonicalJson(value: unknown): string {
  if (value === undefined) return "null";
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  return `{${Object.entries(value)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, entry]) => `${JSON.stringify(key)}:${canonicalJson(entry)}`)
    .join(",")}}`;
}
