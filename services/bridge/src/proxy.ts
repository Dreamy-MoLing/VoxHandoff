import { once } from "node:events";
import { Readable } from "node:stream";
import type { IncomingMessage, ServerResponse } from "node:http";

import type { BridgeConfig, BridgeUpstreamConfig } from "./config.js";
import { readRequestBody, writeError } from "./http.js";

export type ProxyService = "hermes" | "stt" | "tts";
export type ProxyScope = "chat" | "stt" | "tts";

export interface ProxyRoute {
  service: ProxyService;
  scope: ProxyScope;
  upstreamPath: string;
  method: "GET" | "POST";
}

export interface ReverseProxyOptions {
  fetch?: typeof globalThis.fetch;
  maxResponseBytes?: number;
}

const forwardedRequestHeaders = new Set([
  "accept",
  "content-type",
  "idempotency-key",
  "last-event-id",
  "x-hermes-session-id",
  "x-hermes-session-key",
  "x-request-id",
]);
const forwardedResponseHeaders = new Set([
  "cache-control",
  "content-encoding",
  "content-length",
  "content-type",
  "etag",
  "retry-after",
]);

export class ReverseProxy {
  readonly #config: BridgeConfig;
  readonly #fetch: typeof globalThis.fetch;
  readonly #maxResponseBytes: number;

  constructor(config: BridgeConfig, options: ReverseProxyOptions = {}) {
    this.#config = config;
    this.#fetch = options.fetch ?? globalThis.fetch;
    this.#maxResponseBytes = options.maxResponseBytes ?? 16 * 1024 * 1024;
  }

  route(method: string, pathname: string): ProxyRoute | undefined {
    if (method === "POST" && pathname === "/v1/chat/completions") return { service: "hermes", scope: "chat", upstreamPath: "/v1/chat/completions", method: "POST" };
    if (method === "POST" && pathname === "/v1/stt/transcribe") return { service: "stt", scope: "stt", upstreamPath: "/v1/transcribe", method: "POST" };
    if (method === "POST" && pathname === "/v1/tts/synthesize") return { service: "tts", scope: "tts", upstreamPath: "/v1/synthesize", method: "POST" };
    const health = pathname.match(/^\/v1\/services\/(hermes|stt|tts)\/health$/u);
    if (method === "GET" && health?.[1] !== undefined) {
      const service = health[1] as ProxyService;
      const upstream = this.#upstream(service);
      return { service, scope: service === "hermes" ? "chat" : service, upstreamPath: upstream?.healthPath ?? defaultHealthPath(service), method: "GET" };
    }
    const capabilities = pathname.match(/^\/v1\/services\/(hermes|stt|tts)\/capabilities$/u);
    if (method === "GET" && capabilities?.[1] !== undefined) {
      const service = capabilities[1] as ProxyService;
      const upstream = this.#upstream(service);
      if (upstream?.capabilitiesPath === undefined) return undefined;
      return { service, scope: service === "hermes" ? "chat" : service, upstreamPath: upstream.capabilitiesPath, method: "GET" };
    }
    return undefined;
  }

  async forward(route: ProxyRoute, request: IncomingMessage, response: ServerResponse): Promise<void> {
    const upstream = this.#upstream(route.service);
    if (upstream === undefined) {
      writeError(response, 503, "upstream_not_configured", `${route.service} is not configured.`);
      return;
    }
    const body = route.method === "POST" ? await readRequestBody(request, this.#config.maxRequestBytes) : undefined;
    const headers = new Headers({ Authorization: `Bearer ${upstream.token}` });
    for (const [name, value] of Object.entries(request.headers)) {
      if (!forwardedRequestHeaders.has(name) || value === undefined) continue;
      headers.set(name, Array.isArray(value) ? value.join(",") : value);
    }
    let upstreamResponse: Response;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.#config.upstreamTimeoutMs);
    try {
      upstreamResponse = await this.#fetch(new URL(route.upstreamPath, ensureTrailingSlash(upstream.baseUrl)), {
        method: route.method,
        headers,
        ...(body === undefined || body.byteLength === 0 ? {} : { body: body as unknown as BodyInit }),
        signal: controller.signal,
      });
    } catch {
      writeError(response, 502, "upstream_unavailable", `${route.service} did not accept the request.`);
      return;
    } finally {
      clearTimeout(timeout);
    }
    if (!upstreamResponse.ok) {
      writeError(response, mapUpstreamStatus(upstreamResponse.status), "upstream_error", `${route.service} rejected the request.`);
      return;
    }
    response.statusCode = upstreamResponse.status;
    for (const [name, value] of upstreamResponse.headers) {
      if (forwardedResponseHeaders.has(name)) response.setHeader(name, value);
    }
    response.setHeader("Cache-Control", "no-store");
    if (upstreamResponse.body === null) {
      response.end();
      return;
    }
    await pipeBounded(upstreamResponse.body, response, this.#maxResponseBytes);
  }

  #upstream(service: ProxyService): BridgeUpstreamConfig | undefined {
    return this.#config[service];
  }
}

async function pipeBounded(body: ReadableStream<Uint8Array>, response: ServerResponse, maximumBytes: number): Promise<void> {
  const stream = Readable.fromWeb(body as never);
  let total = 0;
  try {
    for await (const chunk of stream) {
      const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      total += buffer.byteLength;
      if (total > maximumBytes) {
        response.destroy();
        return;
      }
      if (!response.write(buffer)) await once(response, "drain");
    }
    response.end();
  } catch {
    response.destroy();
  }
}

function ensureTrailingSlash(value: string): string {
  return value.endsWith("/") ? value : `${value}/`;
}

function mapUpstreamStatus(status: number): number {
  return status >= 400 && status < 500 ? status : 502;
}

function defaultHealthPath(service: ProxyService): string {
  return service === "hermes" ? "/health" : "/v1/health";
}
