export interface SseMessage {
  event?: string;
  id?: string;
  data: string;
  retry?: number;
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
): AsyncGenerator<SseMessage> {
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  try {
    while (true) {
      const { done, value } = await reader.read();
      buffer += decoder.decode(value, { stream: !done });
      let boundary: number;
      while ((boundary = buffer.search(/\r?\n\r?\n/)) !== -1) {
        const block = buffer.slice(0, boundary);
        const delimiter = buffer.slice(boundary).match(/^\r?\n\r?\n/)?.[0] ?? "\n\n";
        buffer = buffer.slice(boundary + delimiter.length);
        const message = parseBlock(block);
        if (message) yield message;
      }
      if (done) break;
    }
    const finalMessage = parseBlock(buffer);
    if (finalMessage) yield finalMessage;
  } finally {
    reader.releaseLock();
  }
}
