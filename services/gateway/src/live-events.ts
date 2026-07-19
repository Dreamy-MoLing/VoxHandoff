import { Code, ConnectError } from "@connectrpc/connect";
import type { MessageInitShape } from "@bufbuild/protobuf";
import { ConnectClientResponseSchema } from "@agent-talk/protocol";

type ClientResponseInit = MessageInitShape<typeof ConnectClientResponseSchema>;

export interface ClientLiveEventSource {
  subscribe(deviceId: string): AsyncIterable<ClientResponseInit>;
}

interface Subscriber {
  queue: ClientResponseInit[];
  waiting: (() => void) | undefined;
  closed: boolean;
  error: Error | undefined;
}

export class BoundedLiveEventHub implements ClientLiveEventSource {
  private readonly subscribers = new Map<string, Set<Subscriber>>();

  constructor(private readonly maximumQueuedEvents = 500) {
    if (!Number.isInteger(maximumQueuedEvents) || maximumQueuedEvents < 1) {
      throw new Error("maximumQueuedEvents must be a positive integer");
    }
  }

  publish(response: ClientResponseInit): void {
    for (const subscribers of this.subscribers.values()) {
      for (const subscriber of subscribers) {
        if (subscriber.closed) continue;
        if (subscriber.queue.length >= this.maximumQueuedEvents) {
          subscriber.error = new ConnectError(
            "Live event buffer exceeded; reconnect and replay from the durable cursor.",
            Code.ResourceExhausted,
          );
          subscriber.closed = true;
          subscriber.waiting?.();
          continue;
        }
        subscriber.queue.push(response);
        subscriber.waiting?.();
      }
    }
  }

  subscribe(deviceId: string): AsyncIterable<ClientResponseInit> {
    if (deviceId.length === 0) throw new Error("deviceId is required");
    const subscriber: Subscriber = { queue: [], waiting: undefined, closed: false, error: undefined };
    const subscribers = this.subscribers.get(deviceId) ?? new Set<Subscriber>();
    subscribers.add(subscriber);
    this.subscribers.set(deviceId, subscribers);
    const remove = () => {
      subscriber.closed = true;
      subscribers.delete(subscriber);
      if (subscribers.size === 0) this.subscribers.delete(deviceId);
      subscriber.waiting?.();
    };

    return {
      [Symbol.asyncIterator](): AsyncIterator<ClientResponseInit> {
        return {
          async next() {
            while (subscriber.queue.length === 0 && !subscriber.closed) {
              await new Promise<void>((resolve) => { subscriber.waiting = resolve; });
              subscriber.waiting = undefined;
            }
            if (subscriber.queue.length > 0) return { done: false, value: subscriber.queue.shift()! };
            if (subscriber.error !== undefined) throw subscriber.error;
            return { done: true, value: undefined };
          },
          async return() {
            remove();
            return { done: true, value: undefined };
          },
        };
      },
    };
  }
}
