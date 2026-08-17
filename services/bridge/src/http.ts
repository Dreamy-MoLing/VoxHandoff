import type { IncomingMessage, ServerResponse } from "node:http";

export const JSON_CONTENT_TYPE = "application/json; charset=utf-8";

export function writeJson(response: ServerResponse, status: number, payload: unknown): void {
  const encoded = Buffer.from(JSON.stringify(payload), "utf8");
  response.statusCode = status;
  response.setHeader("Content-Type", JSON_CONTENT_TYPE);
  response.setHeader("Content-Length", encoded.byteLength);
  response.setHeader("Cache-Control", "no-store");
  response.setHeader("Connection", "close");
  response.end(encoded);
}

export function writeError(response: ServerResponse, status: number, code: string, message: string): void {
  writeJson(response, status, { error: { code, message } });
}

export async function readJsonBody(request: IncomingMessage, maximumBytes: number): Promise<unknown> {
  const body = await readRequestBody(request, maximumBytes);
  let parsed: unknown;
  try {
    parsed = JSON.parse(body.toString("utf8"));
  } catch {
    throw new HttpRequestError(400, "request_invalid", "The request body must be valid JSON.");
  }
  return parsed;
}

export async function readRequestBody(request: IncomingMessage, maximumBytes: number): Promise<Buffer> {
  const contentLength = request.headers["content-length"];
  if (contentLength !== undefined) {
    const length = Number(contentLength);
    if (!Number.isSafeInteger(length) || length < 0 || length > maximumBytes) throw new HttpRequestError(413, "request_too_large", "The request body is too large.");
  }
  const chunks: Buffer[] = [];
  let total = 0;
  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    total += buffer.byteLength;
    if (total > maximumBytes) throw new HttpRequestError(413, "request_too_large", "The request body is too large.");
    chunks.push(buffer);
  }
  return Buffer.concat(chunks);
}

export class HttpRequestError extends Error {
  constructor(readonly status: number, readonly code: string, message: string) {
    super(message);
    this.name = "HttpRequestError";
  }
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

export function stringField(value: Record<string, unknown>, name: string): string | undefined {
  const field = value[name];
  return typeof field === "string" ? field : undefined;
}
