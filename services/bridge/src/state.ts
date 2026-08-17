import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import path from "node:path";

export type PairingSessionStatus = "pending" | "consumed" | "expired" | "cancelled";
export type PairingRequestStatus = "awaiting_confirmation" | "confirmed" | "completed" | "expired" | "cancelled";
export type DeviceStatus = "pending" | "active" | "revoked";
export type CredentialStatus = "active" | "revoked";
export const deviceScopes = ["chat", "stt", "tts"] as const;
export type DeviceScope = (typeof deviceScopes)[number];

export interface PairingSessionRecord {
  sessionId: string;
  tokenHash: string;
  status: PairingSessionStatus;
  createdAt: string;
  expiresAt: string;
  serverId: string;
  endpoint: string;
  profileId: string;
  profileName: string;
  model: string;
  spkiPin: string;
}

export interface PairingRequestRecord {
  requestId: string;
  sessionId: string;
  deviceId: string;
  deviceName: string;
  devicePublicKeySpki: string;
  deviceFingerprint: string;
  challenge: string;
  confirmationCode: string;
  status: PairingRequestStatus;
  createdAt: string;
  expiresAt: string;
  confirmedAt?: string;
  completedAt?: string;
  credentialId?: string;
}

export interface DeviceRecord {
  deviceId: string;
  deviceName: string;
  devicePublicKeySpki: string;
  deviceFingerprint: string;
  scopes: DeviceScope[];
  status: DeviceStatus;
  createdAt: string;
  updatedAt: string;
}

export interface CredentialRecord {
  credentialId: string;
  deviceId: string;
  accessTokenHash: string;
  status: CredentialStatus;
  scopes: DeviceScope[];
  createdAt: string;
  expiresAt: string;
}

export interface BridgeStateDocument {
  version: 1;
  pairings: PairingSessionRecord[];
  pairingRequests: PairingRequestRecord[];
  devices: DeviceRecord[];
  credentials: CredentialRecord[];
}

export type StateMutation<T> = (state: BridgeStateDocument) => T;

const emptyState = (): BridgeStateDocument => ({
  version: 1,
  pairings: [],
  pairingRequests: [],
  devices: [],
  credentials: [],
});

export class BridgeStateStore {
  readonly #filePath: string | undefined;
  #state: BridgeStateDocument;
  #queue: Promise<void> = Promise.resolve();

  constructor(filePath?: string, initialState: BridgeStateDocument = emptyState()) {
    this.#filePath = filePath;
    this.#state = validateState(initialState);
  }

  async snapshot(): Promise<BridgeStateDocument> {
    await this.#queue;
    return structuredClone(this.#state);
  }

  async mutate<T>(operation: StateMutation<T>): Promise<T> {
    const pending = this.#queue.then(async () => {
      const before = structuredClone(this.#state);
      try {
        const result = operation(this.#state);
        await this.#persist();
        return result;
      } catch (error) {
        this.#state = before;
        throw error;
      }
    });
    this.#queue = pending.then(
      () => undefined,
      () => undefined,
    );
    return pending;
  }

  async flush(): Promise<void> {
    await this.#queue;
  }

  async #persist(): Promise<void> {
    if (this.#filePath === undefined) return;
    const directory = path.dirname(this.#filePath);
    await mkdir(directory, { recursive: true, mode: 0o700 });
    const temporaryPath = `${this.#filePath}.tmp`;
    await writeFile(temporaryPath, `${JSON.stringify(this.#state)}\n`, { encoding: "utf8", mode: 0o600 });
    await rename(temporaryPath, this.#filePath);
  }
}

export function createMemoryBridgeStateStore(initialState?: BridgeStateDocument): BridgeStateStore {
  return new BridgeStateStore(undefined, initialState);
}

export async function loadBridgeStateStore(filePath: string): Promise<BridgeStateStore> {
  try {
    const encoded = await readFile(filePath, "utf8");
    const parsed: unknown = JSON.parse(encoded);
    return new BridgeStateStore(filePath, validateState(parsed));
  } catch (error) {
    if (isNodeError(error) && error.code === "ENOENT") return new BridgeStateStore(filePath);
    throw new Error("The bridge state file is invalid or unreadable.");
  }
}

function validateState(value: unknown): BridgeStateDocument {
  if (value === null || typeof value !== "object" || Array.isArray(value)) throw new Error("The bridge state is not an object.");
  const state = value as Partial<BridgeStateDocument>;
  if (
    state.version !== 1 ||
    !Array.isArray(state.pairings) ||
    !Array.isArray(state.pairingRequests) ||
    !Array.isArray(state.devices) ||
    !Array.isArray(state.credentials)
  ) {
    throw new Error("The bridge state version or collections are invalid.");
  }
  return structuredClone(state as BridgeStateDocument);
}

function isNodeError(error: unknown): error is NodeJS.ErrnoException {
  return error instanceof Error && "code" in error;
}
