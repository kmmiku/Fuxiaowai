import { SerialQueue } from './SerialQueue';

/** School sessions are single-login; serialize authentication and business reads. */
export class SchoolTraffic {
  private static queue: SerialQueue = new SerialQueue();
  static run<T>(work: () => Promise<T>): Promise<T> { return SchoolTraffic.queue.run(work); }
}
