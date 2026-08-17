import type { BridgeConfig, BridgeUpstreamConfig } from "./config.js";

export interface CapabilityManifest {
  chat: {
    available: boolean;
  };
  stt: {
    available: boolean;
    capabilities: Record<string, unknown>;
  };
  tts: {
    available: boolean;
    voices: string[];
    recommended_voice?: string;
  };
  hermes: {
    profile: string;
    model: string;
    capabilities: Record<string, unknown>;
  };
}

export interface CapabilityDiscoveryOptions {
  fetch?: typeof globalThis.fetch;
}

interface ProbeResult {
  available: boolean;
  capabilities: Record<string, unknown>;
}

export class CapabilityDiscovery {
  readonly #config: BridgeConfig;
  readonly #fetch: typeof globalThis.fetch;

  constructor(config: BridgeConfig, options: CapabilityDiscoveryOptions = {}) {
    this.#config = config;
    this.#fetch = options.fetch ?? globalThis.fetch;
  }

  async manifest(): Promise<CapabilityManifest> {
    const [hermes, stt, tts] = await Promise.all([
      this.#probeHermes(this.#config.hermes),
      this.#probeProvider(this.#config.stt),
      this.#probeProvider(this.#config.tts),
    ]);
    const voices = stringArray(tts.capabilities.voices);
    const recommended = typeof tts.capabilities.recommended_voice === "string"
      ? tts.capabilities.recommended_voice
      : undefined;
    return {
      chat: { available: hermes.available },
      stt,
      tts: {
        available: tts.available,
        voices,
        ...(recommended === undefined ? {} : { recommended_voice: recommended }),
      },
      hermes: {
        profile: this.#config.profileName,
        model: this.#config.model,
        capabilities: hermes.capabilities,
      },
    };
  }

  async #probeHermes(upstream: BridgeUpstreamConfig | undefined): Promise<ProbeResult> {
    if (upstream === undefined) return unavailable();
    const health = await this.#fetchJson(upstream, upstream.healthPath);
    if (!health.available) return unavailable();
    const capabilities: ProbeResult = upstream.capabilitiesPath === undefined
      ? { available: true, capabilities: {} }
      : await this.#fetchJson(upstream, upstream.capabilitiesPath);
    return {
      available: true,
      capabilities: capabilities.available ? capabilities.capabilities : {},
    };
  }

  async #probeProvider(upstream: BridgeUpstreamConfig | undefined): Promise<ProbeResult> {
    if (upstream === undefined) return unavailable();
    const health = await this.#fetchJson(upstream, upstream.healthPath);
    if (!health.available) return unavailable();
    const capabilities = upstream.capabilitiesPath === undefined
      ? health
      : await this.#fetchJson(upstream, upstream.capabilitiesPath);
    return {
      available: true,
      capabilities: capabilities.capabilities,
    };
  }

  async #fetchJson(upstream: BridgeUpstreamConfig, route: string): Promise<ProbeResult> {
    try {
      const url = new URL(route, ensureTrailingSlash(upstream.baseUrl));
      const response = await this.#fetch(url, {
        method: "GET",
        headers: {
          Accept: "application/json",
          Authorization: `Bearer ${upstream.token}`,
        },
        signal: AbortSignal.timeout(this.#config.upstreamTimeoutMs),
      });
      if (!response.ok) return unavailable();
      const contentLength = response.headers.get("content-length");
      if (contentLength !== null && (!/^\d+$/u.test(contentLength) || Number(contentLength) > 1_048_576)) return unavailable();
      const text = await response.text();
      if (Buffer.byteLength(text, "utf8") > 1_048_576) return unavailable();
      if (text.length === 0) return { available: true, capabilities: {} };
      const parsed: unknown = JSON.parse(text);
      return { available: true, capabilities: sanitizeCapabilities(parsed) };
    } catch {
      return unavailable();
    }
  }
}

function unavailable(): ProbeResult {
  return { available: false, capabilities: {} };
}

function ensureTrailingSlash(value: string): string {
  return value.endsWith("/") ? value : `${value}/`;
}

function sanitizeCapabilities(value: unknown, depth = 0): Record<string, unknown> {
  if (depth > 4 || value === null || typeof value !== "object" || Array.isArray(value)) return {};
  const output: Record<string, unknown> = {};
  for (const [key, child] of Object.entries(value)) {
    if (sensitiveCapabilityKey(key)) continue;
    const sanitized = sanitizeValue(child, depth + 1);
    if (sanitized !== undefined) output[key] = sanitized;
  }
  return output;
}

function sanitizeValue(value: unknown, depth: number): unknown {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return Number.isFinite(value) ? value : undefined;
  if (typeof value === "string") return value.length <= 256 ? value : undefined;
  if (Array.isArray(value)) {
    if (value.length > 100) return undefined;
    const items = value.map((item) => sanitizeValue(item, depth + 1)).filter((item) => item !== undefined);
    return items;
  }
  if (value !== null && typeof value === "object" && depth <= 4) return sanitizeCapabilities(value, depth);
  return undefined;
}

function sensitiveCapabilityKey(key: string): boolean {
  return /(?:token|secret|password|authorization|api[_-]?key|credential|endpoint|url|path)/iu.test(key);
}

function stringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === "string" && item.length > 0 && item.length <= 120).slice(0, 100);
}
