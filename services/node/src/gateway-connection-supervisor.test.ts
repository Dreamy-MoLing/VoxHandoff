import assert from "node:assert/strict";
import test from "node:test";

import { Code, ConnectError } from "@connectrpc/connect";

import { runGatewayConnectionSupervisor } from "./gateway-connection-supervisor.js";

test("reconnects a transient Gateway transport failure with bounded backoff", async () => {
  const abortController = new AbortController();
  const delays: number[] = [];
  let calls = 0;

  await runGatewayConnectionSupervisor(
    async () => {
      calls += 1;
      if (calls === 1) {
        throw new ConnectError("transient socket failure", Code.Unavailable);
      }
      abortController.abort();
    },
    abortController.signal,
    {
      initialDelayMs: 25,
      maximumDelayMs: 100,
      wait: async (delayMs) => {
        delays.push(delayMs);
      },
    },
  );

  assert.equal(calls, 2);
  assert.deepEqual(delays, [25]);
});

test("does not retry a non-transport Gateway rejection", async () => {
  const abortController = new AbortController();
  const rejection = new ConnectError("authentication rejected", Code.Unauthenticated);
  let calls = 0;

  await assert.rejects(
    runGatewayConnectionSupervisor(
      async () => {
        calls += 1;
        throw rejection;
      },
      abortController.signal,
      { wait: async () => undefined },
    ),
    (error: unknown) => error === rejection,
  );
  assert.equal(calls, 1);
});

test("stops before another connection attempt when cancellation arrives during backoff", async () => {
  const abortController = new AbortController();
  let calls = 0;

  await runGatewayConnectionSupervisor(
    async () => {
      calls += 1;
    },
    abortController.signal,
    {
      wait: async () => {
        abortController.abort();
      },
    },
  );

  assert.equal(calls, 1);
});
