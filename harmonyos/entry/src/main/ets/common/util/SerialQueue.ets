/** Failures never poison the following operation. */
export class SerialQueue {
  private tail: Promise<void> = Promise.resolve();

  run<T>(work: () => Promise<T>): Promise<T> {
    const result: Promise<T> = this.tail.then(work);
    this.tail = result.then(() => {}, () => {});
    return result;
  }
}
