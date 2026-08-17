export interface BridgeHealthSnapshot {
  status: "ok";
  component: "companion-bridge";
  version: string;
}

export interface BridgeReadinessSnapshot {
  status: "ready" | "not_ready";
  component: "companion-bridge";
  version: string;
  checks: Readonly<Record<string, "ok" | "not_ready">>;
}

export interface BridgeReadinessCheck {
  name: string;
  ready(): boolean;
}

export function healthSnapshot(version: string): BridgeHealthSnapshot {
  return { status: "ok", component: "companion-bridge", version };
}

export function readinessSnapshot(version: string, checks: readonly BridgeReadinessCheck[]): BridgeReadinessSnapshot {
  const values: Record<string, "ok" | "not_ready"> = {};
  for (const check of checks) values[check.name] = check.ready() ? "ok" : "not_ready";
  const ready = Object.values(values).every((value) => value === "ok");
  return {
    status: ready ? "ready" : "not_ready",
    component: "companion-bridge",
    version,
    checks: values,
  };
}
