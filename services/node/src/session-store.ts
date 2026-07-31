import { chmod, mkdir, readFile, rename, writeFile } from "node:fs/promises";
import path from "node:path";

export interface HermesSessionStore {
  get(conversationId: string): Promise<string | undefined>;
  set(conversationId: string, sessionId: string): Promise<void>;
}

export interface HermesSessionStoreFileSystem {
  readFile(filePath: string, encoding: "utf8"): Promise<string>;
  mkdir(directory: string, options: { recursive: true; mode: number }): Promise<string | undefined>;
  chmod(filePath: string, mode: number): Promise<void>;
  writeFile(
    filePath: string,
    body: string,
    options: { encoding: "utf8"; mode: number },
  ): Promise<void>;
  rename(from: string, to: string): Promise<void>;
}

const defaultFileSystem: HermesSessionStoreFileSystem = {
  readFile,
  mkdir,
  chmod,
  writeFile,
  rename,
};

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
  #loadPromise: Promise<void> | undefined;
  #writeChain = Promise.resolve();

  constructor(
    private readonly filePath: string,
    private readonly fileSystem: HermesSessionStoreFileSystem = defaultFileSystem,
  ) {
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
    if (this.#loadPromise === undefined) {
      this.#loadPromise = this.#loadFromDisk();
    }
    await this.#loadPromise;
  }

  async #loadFromDisk(): Promise<void> {
    let text: string;
    try {
      text = await this.fileSystem.readFile(this.filePath, "utf8");
    } catch (error) {
      if (isNodeError(error) && error.code === "ENOENT") {
        this.#loaded = true;
        return;
      }
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
    this.#loaded = true;
  }

  async #persist(): Promise<void> {
    const parent = path.dirname(this.filePath);
    await this.fileSystem.mkdir(parent, { recursive: true, mode: 0o700 });
    await this.fileSystem.chmod(parent, 0o700);
    const temporary = `${this.filePath}.tmp`;
    const body = `${JSON.stringify(Object.fromEntries(this.#sessions), null, 2)}\n`;
    await this.fileSystem.writeFile(temporary, body, { encoding: "utf8", mode: 0o600 });
    await this.fileSystem.chmod(temporary, 0o600);
    await this.fileSystem.rename(temporary, this.filePath);
  }
}

function opaque(value: string): boolean {
  return value.length > 0 && value.length <= 256 && !/[\u0000-\u001f\u007f]/u.test(value);
}

function isNodeError(error: unknown): error is NodeJS.ErrnoException {
  return error instanceof Error && "code" in error;
}
