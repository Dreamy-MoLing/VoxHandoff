import { chmod, mkdir, readFile, rename, writeFile } from "node:fs/promises";
import path from "node:path";

export interface HermesSessionStore {
  get(conversationId: string): Promise<string | undefined>;
  set(conversationId: string, sessionId: string): Promise<void>;
}

export class MemoryHermesSessionStore implements HermesSessionStore {
  readonly #sessions = new Map<string, string>();

  async get(conversationId: string): Promise<string | undefined> {
    return this.#sessions.get(conversationId);
  }

  async set(conversationId: string, sessionId: string): Promise<void> {
    this.#sessions.set(conversationId, sessionId);
  }
}

export class JsonHermesSessionStore implements HermesSessionStore {
  readonly #sessions = new Map<string, string>();
  #loaded = false;
  #writeChain = Promise.resolve();

  constructor(private readonly filePath: string) {
    if (!path.isAbsolute(filePath)) {
      throw new Error("Hermes session state path must be absolute");
    }
  }

  async get(conversationId: string): Promise<string | undefined> {
    await this.#load();
    return this.#sessions.get(conversationId);
  }

  async set(conversationId: string, sessionId: string): Promise<void> {
    await this.#load();
    this.#sessions.set(conversationId, sessionId);
    this.#writeChain = this.#writeChain.then(() => this.#persist());
    await this.#writeChain;
  }

  async #load(): Promise<void> {
    if (this.#loaded) return;
    this.#loaded = true;
    let text: string;
    try {
      text = await readFile(this.filePath, "utf8");
    } catch (error) {
      if (isNodeError(error) && error.code === "ENOENT") return;
      throw error;
    }
    const decoded: unknown = JSON.parse(text);
    if (
      typeof decoded !== "object" ||
      decoded === null ||
      Array.isArray(decoded)
    ) {
      throw new Error("Hermes session state is invalid");
    }
    for (const [conversationId, sessionId] of Object.entries(decoded)) {
      if (opaque(conversationId) && typeof sessionId === "string" && opaque(sessionId)) {
        this.#sessions.set(conversationId, sessionId);
      } else {
        throw new Error("Hermes session state contains an invalid identity");
      }
    }
  }

  async #persist(): Promise<void> {
    const parent = path.dirname(this.filePath);
    await mkdir(parent, { recursive: true, mode: 0o700 });
    await chmod(parent, 0o700);
    const temporary = `${this.filePath}.tmp`;
    const body = `${JSON.stringify(Object.fromEntries(this.#sessions), null, 2)}\n`;
    await writeFile(temporary, body, { encoding: "utf8", mode: 0o600 });
    await chmod(temporary, 0o600);
    await rename(temporary, this.filePath);
  }
}

function opaque(value: string): boolean {
  return value.length > 0 && value.length <= 256 && !/[\u0000-\u001f\u007f]/u.test(value);
}

function isNodeError(error: unknown): error is NodeJS.ErrnoException {
  return error instanceof Error && "code" in error;
}
