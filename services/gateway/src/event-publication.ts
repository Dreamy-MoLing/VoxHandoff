import type { PersistedEventRecord } from "./client-ledger.js";
import { persistedEventResponse } from "./ledger-handlers.js";

export interface ClaimedEventPublication {
  outboxId: string;
  event: PersistedEventRecord;
}

export interface EventPublicationLedger {
  claimEventPublications(
    workerId: string,
    now: Date,
    maximum: number,
  ): Promise<readonly ClaimedEventPublication[]>;
  markEventPublicationDelivered(outboxId: string, eventId: string, workerId: string, now: Date): Promise<boolean>;
  releaseEventPublication(outboxId: string, eventId: string, workerId: string, now: Date, safeCode: string): Promise<boolean>;
}

export interface LiveEventPublisher {
  publish(response: ReturnType<typeof persistedEventResponse>): void;
}

export class EventOutboxPump {
  constructor(
    private readonly ledger: EventPublicationLedger,
    private readonly publisher: LiveEventPublisher,
    private readonly workerId: string,
    private readonly batchSize = 100,
  ) {
    if (workerId.length === 0 || !Number.isInteger(batchSize) || batchSize < 1 || batchSize > 500) {
      throw new Error("EventOutboxPump configuration is invalid");
    }
  }

  async runOnce(now = new Date()): Promise<number> {
    const publications = await this.ledger.claimEventPublications(this.workerId, now, this.batchSize);
    let delivered = 0;
    for (const publication of publications) {
      try {
        this.publisher.publish(persistedEventResponse(publication.event));
        if (
          await this.ledger.markEventPublicationDelivered(
            publication.outboxId,
            publication.event.eventId,
            this.workerId,
            now,
          )
        ) delivered += 1;
      } catch {
        await this.ledger.releaseEventPublication(
          publication.outboxId,
          publication.event.eventId,
          this.workerId,
          now,
          "live_publish_failed",
        );
      }
    }
    return delivered;
  }
}
