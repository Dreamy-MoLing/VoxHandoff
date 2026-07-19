import assert from "node:assert/strict";
import test from "node:test";

import { Code, ConnectError } from "@connectrpc/connect";
import { BoundedLiveEventHub } from "./live-events.js";

const response = (sequence: bigint) => ({
  body: {
    case: "event" as const,
    value: {
      eventId: `event-${sequence}`,
      conversationId: "conversation-1",
      sequence,
    },
  },
});

test("publishes live events to each active device subscriber", async () => {
  const hub = new BoundedLiveEventHub(2);
  const iterator = hub.subscribe("device-1")[Symbol.asyncIterator]();
  hub.publish(response(1n));
  assert.equal((await iterator.next()).value?.body?.case, "event");
  await iterator.return?.();
});

test("bounds slow consumers and requires durable replay after overflow", async () => {
  const hub = new BoundedLiveEventHub(1);
  const iterator = hub.subscribe("device-1")[Symbol.asyncIterator]();
  hub.publish(response(1n));
  hub.publish(response(2n));
  assert.equal((await iterator.next()).value?.body?.case, "event");
  await assert.rejects(
    iterator.next(),
    (error: unknown) => error instanceof ConnectError && error.code === Code.ResourceExhausted,
  );
});
