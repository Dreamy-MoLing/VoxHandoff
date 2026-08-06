import path from "node:path";

export interface HermesNodeRuntimeConfig {
  gatewayUrl: string;
  gatewayToken: string;
  hermesUrl: string;
  hermesToken: string;
  nodeId: string;
  agentId: string;
  nodeDisplayName: string;
  agentDisplayName: string;
  stateFile: string;
  allowInsecureLoopback: boolean;
  hermesApprovalTimeoutMs: number;
}

export function readHermesNodeConfig(
  environment: NodeJS.ProcessEnv = process.env,
): HermesNodeRuntimeConfig {
  const gatewayUrl = required(environment, "VOXHANDOFF_GATEWAY_URL");
  const hermesUrl = required(environment, "VOXHANDOFF_HERMES_URL");
  const allowInsecureLoopback =
    environment.VOXHANDOFF_ALLOW_INSECURE_LOOPBACK === "1";
  validateEndpoint(gatewayUrl, "Gateway", allowInsecureLoopback);
  validateEndpoint(hermesUrl, "Hermes", allowInsecureLoopback);
  const stateFile =
    environment.VOXHANDOFF_NODE_STATE_FILE ??
    path.join(process.cwd(), ".voxhandoff", "hermes-sessions.json");
  if (!path.isAbsolute(stateFile)) {
    throw new Error("VOXHANDOFF_NODE_STATE_FILE must be an absolute path");
  }
  return {
    gatewayUrl,
    gatewayToken: required(environment, "VOXHANDOFF_GATEWAY_NODE_TOKEN"),
    hermesUrl,
    hermesToken: required(environment, "VOXHANDOFF_HERMES_TOKEN"),
    nodeId: opaque(environment, "VOXHANDOFF_NODE_ID"),
    agentId: opaque(environment, "VOXHANDOFF_HERMES_AGENT_ID"),
    nodeDisplayName: safeLabel(
      environment.VOXHANDOFF_NODE_DISPLAY_NAME ?? "VoxHandoff Hermes Node",
      "Node display name",
    ),
    agentDisplayName: safeLabel(
      environment.VOXHANDOFF_HERMES_AGENT_DISPLAY_NAME ?? "Hermes",
      "Hermes Agent display name",
    ),
    stateFile,
    allowInsecureLoopback,
    hermesApprovalTimeoutMs:
      positiveSeconds(environment, "VOXHANDOFF_HERMES_APPROVAL_TIMEOUT_SECONDS") * 1000,
  };
}

function required(environment: NodeJS.ProcessEnv, name: string): string {
  const value = environment[name];
  if (value === undefined || value.length === 0) {
    throw new Error(`${name} is required`);
  }
  return value;
}

function opaque(environment: NodeJS.ProcessEnv, name: string): string {
  const value = required(environment, name);
  if (value.length > 256 || /[\u0000-\u001f\u007f]/u.test(value)) {
    throw new Error(`${name} must be an opaque identity`);
  }
  return value;
}

function positiveSeconds(environment: NodeJS.ProcessEnv, name: string): number {
  const raw = required(environment, name);
  if (!/^[1-9][0-9]*$/u.test(raw)) {
    throw new Error(`${name} must be a positive integer`);
  }
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value > 3600) {
    throw new Error(`${name} must be between 1 and 3600 seconds`);
  }
  return value;
}

function safeLabel(value: string, name: string): string {
  const normalized = value.trim();
  if (
    normalized.length === 0 ||
    normalized.length > 120 ||
    /[\u0000-\u001f\u007f]/u.test(normalized)
  ) {
    throw new Error(`${name} is invalid`);
  }
  return normalized;
}

function validateEndpoint(
  raw: string,
  name: string,
  allowInsecureLoopback: boolean,
): void {
  const url = new URL(raw);
  if (url.username.length > 0 || url.password.length > 0) {
    throw new Error(`${name} URL must not contain credentials`);
  }
  if (url.protocol === "https:") return;
  const loopback = new Set(["127.0.0.1", "[::1]"]);
  if (
    url.protocol !== "http:" ||
    !loopback.has(url.hostname) ||
    !allowInsecureLoopback
  ) {
    throw new Error(
      `${name} requires HTTPS, or explicit insecure literal loopback for isolated development`,
    );
  }
}
