const sensitiveKey = /(?:authorization|api[_-]?key|token|secret|password|cookie)/i;

export function redact(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(redact);
  if (value === null || typeof value !== "object") {
    if (typeof value !== "string") return value;
    return value
      .replace(/Bearer\s+\S+/gi, "Bearer [REDACTED]")
      .replace(/\bsk-[A-Za-z0-9_-]+\b/g, "[REDACTED]");
  }

  return Object.fromEntries(
    Object.entries(value).map(([key, entry]) => [
      key,
      sensitiveKey.test(key) ? "[REDACTED]" : redact(entry),
    ]),
  );
}
