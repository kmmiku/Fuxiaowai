/** UTC毫秒与北京时间字段分开，避免宿主时区参与计算。 */
export class BeijingClock {
  private static epoch: number = 0;
  private static anchor: number = 0;
  private static monotonic: () => number = () => Date.now();
  static configure(read: () => number): void { BeijingClock.monotonic = read; }
  static accept(server: number): void { BeijingClock.epoch = server; BeijingClock.anchor = BeijingClock.monotonic(); }
  static now(): number { return BeijingClock.epoch > 0 ? BeijingClock.epoch + BeijingClock.monotonic() - BeijingClock.anchor : Date.now(); }
  static civil(epoch: number = BeijingClock.now()): Date { return new Date(epoch + 8 * 3600000); }
  static dayKey(): string { return BeijingClock.civil().toISOString().slice(0,10); }
}
