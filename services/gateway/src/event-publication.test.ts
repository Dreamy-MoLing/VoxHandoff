import assert from "node:assert/strict";
import test from "node:test";

import {
  EventOutboxPump,
  type ClaimedEventPublication,
  type EventPublicationLedger,
} from "./event-publication.js";

const publication: ClaimedEventPublication = {
  outboxId: "outbox-1",
  event: {
    eventId: "event-1",
    connectionId: "connection-1",
    deviceId: "device-1",
    conversationId: "conversation-1",
    sessionId: null,
    requestId: "request-1",
    sequence: 1n,
    eventType: "request.accepted",
    safePayload: {},
    occurredAt: new Date("2030-01-01T00:00:00.000Z"),
  },
};

class FakePublicationLedger implements EventPublicationLedger {
  publications: ClaimedEventPublication[] = [publication];
  delivered = 0;
  released = 0;
  async claimEventPublications() { return this.publications; }
  async markEventPublicationDelivered() { this.delivered += 1; return true; }
  async releaseEventPublication() { this.released += 1; return true; }
}

test("marks an outbox event delivered only after handing it to the live publisher", async () => {
  const ledger = new FakePublicationLedger();
  const published: string[] = [];
  const pump = new EventOutboxPump(ledger, {
    publish(value) {
      if (value.body?.case === "event") published.push(value.body.value.eventId ?? "");
    },
  }, "worker-1");
  assert.equal(await pump.runOnce(new Date("2030-01-01T00:00:01.000Z")), 1);
  assert.deepEqual(published, ["event-1"]);
  assert.equal(ledger.delivered, 1);
  assert.equal(ledger.released, 0);
});

test("releases a publication for bounded retry when the live publisher fails", async () => {
  const ledger = new FakePublicationLedger();
  const pump = new EventOutboxPump(ledger, { publish() { throw new Error("test failure"); } }, "worker-1");
  assert.equal(await pump.runOnce(new Date("2030-01-01T00:00:01.000Z")), 0);
  assert.equal(ledger.delivered, 0);
  assert.equal(ledger.released, 1);
});
