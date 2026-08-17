import { createHash, X509Certificate } from "node:crypto";

import type { BridgeConfig } from "./config.js";
import type { BridgeStateStore, PinStateRecord } from "./state.js";

const spkiPinPattern = /^sha256\/[A-Za-z0-9+/]{43}={0,2}$/u;

export type PinningErrorCode = "pin_invalid" | "pin_mismatch" | "pin_rotation_rejected" | "pinning_not_ready";

export class PinningError extends Error {
  constructor(readonly code: PinningErrorCode, message: string, readonly status: number) {
    super(message);
    this.name = "PinningError";
  }
}

export interface PinSnapshot {
  currentSpkiPin: string;
  backupSpkiPin: string;
  generation: number;
}

export interface PinRotationInput {
  presentedPin: string;
  nextBackupPin: string;
}

export class PinManager {
  readonly #store: BridgeStateStore | undefined;
  readonly #onChange: ((snapshot: PinSnapshot) => void) | undefined;
  #currentSpkiPin: string;
  #backupSpkiPin: string;
  #generation: number;

  constructor(
    currentSpkiPin: string,
    backupSpkiPin: string,
    store?: BridgeStateStore,
    onChange?: (snapshot: PinSnapshot) => void,
    generation = 1,
  ) {
    validateSpkiPin(currentSpkiPin);
    validateSpkiPin(backupSpkiPin);
    if (currentSpkiPin === backupSpkiPin) throw new PinningError("pin_invalid", "The current and backup SPKI pins must differ.", 500);
    if (!Number.isSafeInteger(generation) || generation < 1) throw new PinningError("pin_invalid", "The pin generation is invalid.", 500);
    this.#currentSpkiPin = currentSpkiPin;
    this.#backupSpkiPin = backupSpkiPin;
    this.#store = store;
    this.#onChange = onChange;
    this.#generation = generation;
  }

  static async load(
    config: BridgeConfig,
    store: BridgeStateStore,
    onChange?: (snapshot: PinSnapshot) => void,
  ): Promise<PinManager> {
    const state = await store.snapshot();
    if (state.pinState !== undefined) {
      const manager = new PinManager(
        state.pinState.currentSpkiPin,
        state.pinState.backupSpkiPin,
        store,
        onChange,
        state.pinState.generation,
      );
      onChange?.(manager.snapshot());
      return manager;
    }
    if (config.currentSpkiPin === undefined || config.backupSpkiPin === undefined) {
      throw new PinningError("pinning_not_ready", "Both SPKI pins must be configured before the bridge starts.", 503);
    }
    const manager = new PinManager(config.currentSpkiPin, config.backupSpkiPin, store, onChange);
    await manager.#persist(manager.snapshot());
    onChange?.(manager.snapshot());
    return manager;
  }

  snapshot(): PinSnapshot {
    return {
      currentSpkiPin: this.#currentSpkiPin,
      backupSpkiPin: this.#backupSpkiPin,
      generation: this.#generation,
    };
  }

  isPinned(pin: string): boolean {
    return pin === this.#currentSpkiPin || pin === this.#backupSpkiPin;
  }

  assertPinned(pin: string): void {
    if (!this.isPinned(pin)) throw new PinningError("pin_mismatch", "The server SPKI pin is not trusted.", 495);
  }

  assertCertificate(certificate: string | Buffer): void {
    this.assertPinned(spkiPinFromCertificate(certificate));
  }

  async rotate(input: PinRotationInput): Promise<PinSnapshot> {
    validateSpkiPin(input.presentedPin);
    validateSpkiPin(input.nextBackupPin);
    if (input.presentedPin !== this.#currentSpkiPin) {
      throw new PinningError("pin_rotation_rejected", "Pin rotation requires the current pinned channel.", 409);
    }
    if (input.nextBackupPin === this.#currentSpkiPin || input.nextBackupPin === this.#backupSpkiPin) {
      throw new PinningError("pin_rotation_rejected", "The new backup pin must be distinct from both active pins.", 409);
    }
    const next: PinSnapshot = {
      currentSpkiPin: this.#backupSpkiPin,
      backupSpkiPin: input.nextBackupPin,
      generation: this.#generation + 1,
    };
    await this.#persist(next);
    this.#currentSpkiPin = next.currentSpkiPin;
    this.#backupSpkiPin = next.backupSpkiPin;
    this.#generation = next.generation;
    this.#onChange?.(next);
    return next;
  }

  async #persist(snapshot: PinSnapshot): Promise<void> {
    if (this.#store === undefined) return;
    const record: PinStateRecord = {
      currentSpkiPin: snapshot.currentSpkiPin,
      backupSpkiPin: snapshot.backupSpkiPin,
      generation: snapshot.generation,
    };
    await this.#store.mutate((state) => {
      state.pinState = record;
    });
  }
}

export function spkiPinFromCertificate(certificate: string | Buffer): string {
  let parsed: X509Certificate;
  try {
    parsed = new X509Certificate(certificate);
  } catch {
    throw new PinningError("pin_invalid", "The TLS certificate cannot be parsed.", 500);
  }
  const spki = parsed.publicKey.export({ format: "der", type: "spki" });
  return `sha256/${createHash("sha256").update(spki).digest("base64")}`;
}

export function validateSpkiPin(value: string): string {
  if (!spkiPinPattern.test(value)) throw new PinningError("pin_invalid", "The SPKI pin is invalid.", 400);
  return value;
}
