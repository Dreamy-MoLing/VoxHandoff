export interface SseMessage {
  event?: string;
  id?: string;
  data: string;
  retry?: number;
}

export interface SseParserOptions {
  maxEventBytes?: number;
}

export class SseTransportError extends Error {
  constructor() {
    super("SSE transport disconnected");
    this.name = "SseTransportError";
  }
}

const defaultMaxEventBytes = 256 * 1024;
const textEncoder = new TextEncoder();

function byteLength(value: string): number {
  return textEncoder.encode(value).byteLength;
}

function parseBlock(block: string): SseMessage | undefined {
  const message: SseMessage = { data: "" };
  const data: string[] = [];
  for (const rawLine of block.split(/\r?\n/)) {
    if (!rawLine || rawLine.startsWith(":")) continue;
    const separator = rawLine.indexOf(":");
    const field = separator === -1 ? rawLine : rawLine.slice(0, separator);
    const rawValue = separator === -1 ? "" : rawLine.slice(separator + 1);
    const value = rawValue.startsWith(" ") ? rawValue.slice(1) : rawValue;
    if (field === "data") data.push(value);
    else if (field === "event") message.event = value;
    else if (field === "id") message.id = value;
    else if (field === "retry" && /^\d+$/.test(value)) message.retry = Number(value);
  }
  message.data = data.join("\n");
  return data.length || message.event || message.id ? message : undefined;
}

export async function* parseSseStream(
  body: ReadableStream<Uint8Array>,
  options: SseParserOptions = {},
): AsyncGenerator<SseMessage> {
  const maxEventBytes = options.maxEventBytes ?? defaultMaxEventBytes;
  if (!Number.isSafeInteger(maxEventBytes) || maxEventBytes <= 0) {
    throw new Error("SSE maxEventBytes must be a positive safe integer");
  }

  const reader = body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  try {
    while (true) {
      let chunk: ReadableStreamReadResult<Uint8Array>;
      try {
        chunk = await reader.read();
      } catch {
        throw new SseTransportError();
      }
      const { done, value } = chunk;
      buffer += decoder.decode(value, { stream: !done });
      let boundary: number;
      while ((boundary = buffer.search(/\r?\n\r?\n/)) !== -1) {
        const block = buffer.slice(0, boundary);
        if (byteLength(block) > maxEventBytes) {
          throw new Error(`SSE event exceeds ${maxEventBytes} bytes`);
        }
        const delimiter = buffer.slice(boundary).match(/^\r?\n\r?\n/)?.[0] ?? "\n\n";
        buffer = buffer.slice(boundary + delimiter.length);
        const message = parseBlock(block);
        if (message) yield message;
      }
      if (byteLength(buffer) > maxEventBytes) {
        throw new Error(`SSE event exceeds ${maxEventBytes} bytes`);
      }
      if (done) break;
    }
    if (byteLength(buffer) > maxEventBytes) {
      throw new Error(`SSE event exceeds ${maxEventBytes} bytes`);
    }
    const finalMessage = parseBlock(buffer);
    if (finalMessage) yield finalMessage;
  } finally {
    reader.releaseLock();
  }
}
