export function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

export function stringAt(value: unknown, ...path: string[]): string | undefined {
  let current: unknown = value;
  for (const part of path) {
    if (!isRecord(current)) return undefined;
    current = current[part];
  }
  return typeof current === "string" ? current : undefined;
}

export function numberAt(value: unknown, ...path: string[]): number | undefined {
  let current: unknown = value;
  for (const part of path) {
    if (!isRecord(current)) return undefined;
    current = current[part];
  }
  return typeof current === "number" && Number.isFinite(current)
    ? current
    : undefined;
}
