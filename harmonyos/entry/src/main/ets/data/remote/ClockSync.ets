import hilog from '@ohos.hilog';
import http from '@ohos.net.http';
import systemDateTime from '@ohos.systemDateTime';
import { BeijingClock } from '../../common/util/BeijingClock';

export class ClockSync {
  private static started: boolean = false;
  private static attempt: number = -1000000;
  private static busy: boolean = false;
  static start(): void {
    if (ClockSync.started) { return; }
    ClockSync.started = true;
    BeijingClock.configure(() => systemDateTime.getUptime(systemDateTime.TimeType.STARTUP));
    AppStorage.setOrCreate('clockEpoch', BeijingClock.now());
    setInterval(() => { AppStorage.set('clockEpoch', BeijingClock.now()); }, 1000);
    ClockSync.sync();
    setInterval(() => { ClockSync.sync(); }, 300000);
  }
  static async sync(): Promise<void> {
    const begin: number = systemDateTime.getUptime(systemDateTime.TimeType.STARTUP);
    if (ClockSync.busy || begin - ClockSync.attempt < 60000) { return; }
    ClockSync.attempt = begin;
    ClockSync.busy = true;
    const request = http.createHttp();
    try {
      const response = await request.request('https://www.fzfu.com/', {
        method: http.RequestMethod.HEAD,
        header: { 'Cache-Control': 'no-cache' },
        connectTimeout: 5000, readTimeout: 5000
      });
      const headers = response.header as Record<string, string>;
      let date: string = '';
      let age: number = 0;
      Object.keys(headers).forEach((key: string) => {
        if (key.toLowerCase() === 'date') { date = headers[key]; }
        if (key.toLowerCase() === 'age') { age = Number(headers[key]); }
      });
      const server: number = Date.parse(date);
      const elapsed: number = systemDateTime.getUptime(systemDateTime.TimeType.STARTUP) - begin;
      if (response.responseCode === 200 && isFinite(server) && server > 0 && age === 0 && elapsed < 10000) {
        BeijingClock.accept(server + elapsed / 2);
        hilog.info(0x0001, 'Fuxiaowai', 'HTTPS clock calibrated');
      }
    } catch (e) { /* 保留旧校准，无会话或个人数据发送。 */ }
    finally { request.destroy(); ClockSync.busy = false; }
  }
}
