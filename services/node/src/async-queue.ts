export class AsyncQueue<T> implements AsyncIterable<T> {
  readonly #values: T[] = [];
  #waiting: (() => void) | undefined;
  #ended = false;
  #error: unknown;

  constructor(private readonly maximumSize = 500) {
    if (!Number.isSafeInteger(maximumSize) || maximumSize <= 0) {
      throw new Error("Async queue maximum size must be a positive safe integer");
    }
  }

  push(value: T): void {
    if (this.#ended) throw new Error("Cannot write to a closed async queue");
    if (this.#values.length >= this.maximumSize) {
      this.fail(new Error("Node outbound queue exceeded its safe bound"));
      throw new Error("Node outbound queue exceeded its safe bound");
    }
    this.#values.push(value);
    this.#waiting?.();
  }

  finish(): void {
    this.#ended = true;
    this.#waiting?.();
  }

  fail(error: unknown): void {
    this.#error = error;
    this.#ended = true;
    this.#waiting?.();
  }

  async *[Symbol.asyncIterator](): AsyncIterator<T> {
    while (true) {
      while (this.#values.length > 0) yield this.#values.shift()!;
      if (this.#ended) {
        if (this.#error !== undefined) throw this.#error;
        return;
      }
      await new Promise<void>((resolve) => {
        this.#waiting = resolve;
      });
      this.#waiting = undefined;
    }
  }
}
