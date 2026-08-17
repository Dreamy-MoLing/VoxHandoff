import path from "node:path";

export interface BridgeUpstreamConfig {
  baseUrl: string;
  token: string;
  healthPath: string;
  capabilitiesPath?: string;
}

export interface BridgeConfig {
  version: string;
  listenHost: string;
  listenPort: number;
  tlsKeyFile: string;
  tlsCertFile: string;
  endpoint: string;
  serverId: string;
  stateFile: string;
  profileId: string;
  profileName: string;
  model: string;
  hostAdminToken?: string;
  hermes?: BridgeUpstreamConfig;
  stt?: BridgeUpstreamConfig;
  tts?: BridgeUpstreamConfig;
  maxRequestBytes: number;
  upstreamTimeoutMs: number;
  pairingTtlMs: number;
  confirmationTtlMs: number;
  credentialTtlMs: number;
  currentSpkiPin?: string;
  backupSpkiPin?: string;
}

const LOOPBACK_HOSTS = new Set(["127.0.0.1", "localhost", "[::1]"]);
const DEFAULT_MAX_REQUEST_BYTES = 8 * 1024 * 1024;

export function readBridgeConfig(environment: NodeJS.ProcessEnv = process.env): BridgeConfig {
  const listenHost = environment.VOXHANDOFF_BRIDGE_HOST ?? "127.0.0.1";
  const listenPort = positiveInteger(environment.VOXHANDOFF_BRIDGE_PORT ?? "9443", "VOXHANDOFF_BRIDGE_PORT", 65535);
  const allowInsecureLoopback = environment.VOXHANDOFF_BRIDGE_ALLOW_INSECURE_LOOPBACK === "1";
  const endpoint = required(environment, "VOXHANDOFF_BRIDGE_ENDPOINT");
  validateEndpoint(endpoint, "VOXHANDOFF_BRIDGE_ENDPOINT", false);
  const stateFile = path.resolve(
    environment.VOXHANDOFF_BRIDGE_STATE_FILE ?? path.join(process.cwd(), ".voxhandoff", "bridge-state.json"),
  );
  const hostAdminToken = optionalSecret(environment.VOXHANDOFF_BRIDGE_HOST_ADMIN_TOKEN);
  if (!LOOPBACK_HOSTS.has(listenHost) && hostAdminToken === undefined) {
    throw new Error("VOXHANDOFF_BRIDGE_HOST_ADMIN_TOKEN is required when the bridge is not loopback-only");
  }

  const hermes = readUpstream(environment, "HERMES", allowInsecureLoopback, "/health", "/v1/capabilities");
  const stt = readUpstream(environment, "STT", allowInsecureLoopback, "/v1/health");
  const tts = readUpstream(environment, "TTS", allowInsecureLoopback, "/v1/health");

  return {
    version: "0.1.0",
    listenHost,
    listenPort,
    tlsKeyFile: absoluteRequired(environment, "VOXHANDOFF_BRIDGE_TLS_KEY_FILE"),
    tlsCertFile: absoluteRequired(environment, "VOXHANDOFF_BRIDGE_TLS_CERT_FILE"),
    endpoint,
    serverId: opaque(environment, "VOXHANDOFF_BRIDGE_SERVER_ID"),
    stateFile,
    profileId: opaqueOrDefault(environment.VOXHANDOFF_BRIDGE_PROFILE_ID, "default-profile"),
    profileName: safeLabel(environment.VOXHANDOFF_BRIDGE_PROFILE_NAME ?? "Hermes", "VOXHANDOFF_BRIDGE_PROFILE_NAME"),
    model: safeLabel(environment.VOXHANDOFF_BRIDGE_MODEL ?? "unknown", "VOXHANDOFF_BRIDGE_MODEL"),
    ...(hostAdminToken === undefined ? {} : { hostAdminToken }),
    ...(hermes === undefined ? {} : { hermes }),
    ...(stt === undefined ? {} : { stt }),
    ...(tts === undefined ? {} : { tts }),
    maxRequestBytes: boundedInteger(
      environment.VOXHANDOFF_BRIDGE_MAX_REQUEST_BYTES ?? String(DEFAULT_MAX_REQUEST_BYTES),
      "VOXHANDOFF_BRIDGE_MAX_REQUEST_BYTES",
      1024,
      32 * 1024 * 1024,
    ),
    upstreamTimeoutMs: boundedInteger(
      environment.VOXHANDOFF_BRIDGE_UPSTREAM_TIMEOUT_MS ?? "5000",
      "VOXHANDOFF_BRIDGE_UPSTREAM_TIMEOUT_MS",
      100,
      30_000,
    ),
    pairingTtlMs: boundedInteger(
      environment.VOXHANDOFF_BRIDGE_PAIRING_TTL_MS ?? String(3 * 60 * 1000),
      "VOXHANDOFF_BRIDGE_PAIRING_TTL_MS",
      1_000,
      5 * 60 * 1000,
    ),
    confirmationTtlMs: boundedInteger(
      environment.VOXHANDOFF_BRIDGE_CONFIRMATION_TTL_MS ?? String(5 * 60 * 1000),
      "VOXHANDOFF_BRIDGE_CONFIRMATION_TTL_MS",
      1_000,
      15 * 60 * 1000,
    ),
    credentialTtlMs: boundedInteger(
      environment.VOXHANDOFF_BRIDGE_CREDENTIAL_TTL_MS ?? String(365 * 24 * 60 * 60 * 1000),
      "VOXHANDOFF_BRIDGE_CREDENTIAL_TTL_MS",
      60 * 60 * 1000,
      10 * 365 * 24 * 60 * 60 * 1000,
    ),
    ...(environment.VOXHANDOFF_BRIDGE_SPKI_PIN === undefined
      ? {}
      : { currentSpkiPin: validateSpkiPin(environment.VOXHANDOFF_BRIDGE_SPKI_PIN, "VOXHANDOFF_BRIDGE_SPKI_PIN") }),
    ...(environment.VOXHANDOFF_BRIDGE_BACKUP_SPKI_PIN === undefined
      ? {}
      : { backupSpkiPin: validateSpkiPin(environment.VOXHANDOFF_BRIDGE_BACKUP_SPKI_PIN, "VOXHANDOFF_BRIDGE_BACKUP_SPKI_PIN") }),
  };
}

function readUpstream(
  environment: NodeJS.ProcessEnv,
  name: "HERMES" | "STT" | "TTS",
  allowInsecureLoopback: boolean,
  healthPath: string,
  capabilitiesPath?: string,
): BridgeUpstreamConfig | undefined {
  const rawUrl = environment[`VOXHANDOFF_BRIDGE_${name}_URL`];
  const rawToken = environment[`VOXHANDOFF_BRIDGE_${name}_TOKEN`];
  if (rawUrl === undefined && rawToken === undefined) return undefined;
  if (rawUrl === undefined || rawToken === undefined || rawToken.length === 0) {
    throw new Error(`VOXHANDOFF_BRIDGE_${name}_URL and VOXHANDOFF_BRIDGE_${name}_TOKEN must be configured together`);
  }
  validateEndpoint(rawUrl, `VOXHANDOFF_BRIDGE_${name}_URL`, allowInsecureLoopback);
  return {
    baseUrl: rawUrl,
    token: rawToken,
    healthPath,
    ...(capabilitiesPath === undefined ? {} : { capabilitiesPath }),
  };
}

function required(environment: NodeJS.ProcessEnv, name: string): string {
  const value = environment[name];
  if (value === undefined || value.length === 0) throw new Error(`${name} is required`);
  return value;
}

function absoluteRequired(environment: NodeJS.ProcessEnv, name: string): string {
  const value = required(environment, name);
  if (!path.isAbsolute(value)) throw new Error(`${name} must be an absolute path`);
  return value;
}

function optionalSecret(value: string | undefined): string | undefined {
  if (value === undefined) return undefined;
  if (value.length < 32 || value.length > 512 || !/^[A-Za-z0-9._~-]+$/u.test(value)) {
    throw new Error("VOXHANDOFF_BRIDGE_HOST_ADMIN_TOKEN must be a 32-512 character opaque secret");
  }
  return value;
}

function opaque(environment: NodeJS.ProcessEnv, name: string): string {
  const value = required(environment, name);
  if (value.length > 256 || /[\u0000-\u001f\u007f]/u.test(value)) throw new Error(`${name} must be an opaque identity`);
  return value;
}

function opaqueOrDefault(value: string | undefined, fallback: string): string {
  if (value === undefined) return fallback;
  if (value.length === 0 || value.length > 256 || /[\u0000-\u001f\u007f]/u.test(value)) {
    throw new Error("VOXHANDOFF_BRIDGE_PROFILE_ID must be an opaque identity");
  }
  return value;
}

function safeLabel(value: string, name: string): string {
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > 120 || /[\u0000-\u001f\u007f]/u.test(normalized)) {
    throw new Error(`${name} is invalid`);
  }
  return normalized;
}

function positiveInteger(value: string, name: string, maximum: number): number {
  return boundedInteger(value, name, 1, maximum);
}

function boundedInteger(value: string, name: string, minimum: number, maximum: number): number {
  if (!/^[1-9][0-9]*$/u.test(value)) throw new Error(`${name} must be a positive integer`);
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < minimum || parsed > maximum) {
    throw new Error(`${name} must be between ${minimum} and ${maximum}`);
  }
  return parsed;
}

function validateEndpoint(raw: string, name: string, allowInsecureLoopback: boolean): void {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error(`${name} must be an absolute URL`);
  }
  if (url.username !== "" || url.password !== "" || url.hash !== "") throw new Error(`${name} must not contain credentials or a fragment`);
  const loopback = LOOPBACK_HOSTS.has(url.hostname);
  if (url.protocol === "https:") return;
  if (allowInsecureLoopback && url.protocol === "http:" && loopback) return;
  throw new Error(`${name} requires HTTPS, or explicit insecure literal loopback for isolated development`);
}

function validateSpkiPin(value: string, name: string): string {
  if (!/^sha256\/[A-Za-z0-9+/]{43}={0,2}$/u.test(value)) throw new Error(`${name} must be a SHA-256 SPKI pin`);
  return value;
}
