import { Code, ConnectError } from "@connectrpc/connect";

export interface GatewayConnectionSupervisorOptions {
  initialDelayMs?: number;
  maximumDelayMs?: number;
  wait?: (delayMs: number, signal: AbortSignal) => Promise<void>;
  onReconnect?: (attempt: number) => void;
}

/**
 * Keeps the Node's authenticated Gateway stream alive without treating a
 * transient transport failure as permission to repeat an Agent submission.
 * The Connector owns retained run identity and output rebinding.
 */
export async function runGatewayConnectionSupervisor(
  runOnce: () => Promise<void>,
  signal: AbortSignal,
  options: GatewayConnectionSupervisorOptions = {},
): Promise<void> {
  const initialDelayMs = options.initialDelayMs ?? 250;
  const maximumDelayMs = options.maximumDelayMs ?? 5_000;
  assertPositiveDelay(initialDelayMs, "initialDelayMs");
  assertPositiveDelay(maximumDelayMs, "maximumDelayMs");
  if (maximumDelayMs < initialDelayMs) {
    throw new Error("Gateway reconnect maximumDelayMs must be at least initialDelayMs");
  }

  let reconnectAttempt = 0;
  while (!signal.aborted) {
    try {
      await runOnce();
    } catch (error) {
      if (signal.aborted) return;
      if (!isReconnectableGatewayError(error)) throw error;
    }
    if (signal.aborted) return;
    reconnectAttempt += 1;
    options.onReconnect?.(reconnectAttempt);
    const delayMs = Math.min(
      maximumDelayMs,
      initialDelayMs * 2 ** Math.min(reconnectAttempt - 1, 30),
    );
    await (options.wait ?? waitForReconnect)(delayMs, signal);
  }
}

function isReconnectableGatewayError(error: unknown): boolean {
  if (!(error instanceof ConnectError)) return false;
  return error.code === Code.Canceled ||
    error.code === Code.Unknown ||
    error.code === Code.DeadlineExceeded ||
    error.code === Code.Unavailable;
}

function waitForReconnect(delayMs: number, signal: AbortSignal): Promise<void> {
  if (signal.aborted) return Promise.resolve();
  return new Promise<void>((resolve) => {
    let settled = false;
    const finish = () => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      signal.removeEventListener("abort", finish);
      resolve();
    };
    const timer = setTimeout(finish, delayMs);
    signal.addEventListener("abort", finish, { once: true });
  });
}

function assertPositiveDelay(value: number, name: string): void {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error(`Gateway reconnect ${name} must be a positive safe integer`);
  }
}
