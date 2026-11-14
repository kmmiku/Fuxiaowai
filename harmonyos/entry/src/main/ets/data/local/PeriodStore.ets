import preferences from '@ohos.data.preferences';
import { DEFAULT_PERIODS, Period } from '../../domain/model/Course';
import common from '@ohos.app.ability.common';
import { AccountScope } from '../../common/util/AccountScope';
import { SerialQueue } from '../../common/util/SerialQueue';

/**
 * 上课时间本地覆盖：用户在「上课时间设置」里改过的节次时间存这里，
 * 没改过就读 DEFAULT_PERIODS。
 */
const STORE: string = 'fxw_settings';
const KEY: string = 'periods_json';

export class PeriodStore {
  private static ctx: common.Context | null = null;
  private static writes: SerialQueue = new SerialQueue();

  static init(context: common.Context): void {
    PeriodStore.ctx = context;
  }

  static async load(): Promise<Period[]> {
    try {
      if (!PeriodStore.ctx) {
        return DEFAULT_PERIODS;
      }
      const p: preferences.Preferences = await preferences.getPreferences(PeriodStore.ctx, STORE);
      const raw: string = await p.get(KEY, '') as string;
      if (!raw) {
        return DEFAULT_PERIODS;
      }
      const parsed: Period[] = JSON.parse(raw) as Period[];
      if (parsed.length === 0) {
        return DEFAULT_PERIODS;
      }
      // 允许自定义节数：只做字段校验，不锁长度
      const ok: boolean = parsed.every((it: Period) =>
        typeof it.index === 'number' && typeof it.start === 'string' && typeof it.end === 'string');
      return ok ? parsed : DEFAULT_PERIODS;
    } catch (e) {
      console.error('PeriodStore.load failed: ' + JSON.stringify(e));
      return DEFAULT_PERIODS;
    }
  }

  static async save(periods: Period[], token: number = AccountScope.token(), canCommit?: () => boolean): Promise<boolean> {
    return PeriodStore.writes.run(async () => {
      try {
      if (!PeriodStore.ctx) {
        return false;
      }
      const p: preferences.Preferences = await preferences.getPreferences(PeriodStore.ctx, STORE);
      const previous: string = await p.get(KEY, '') as string;
      if (!AccountScope.valid(token) || (canCommit !== undefined && !canCommit())) { return false; }
      await p.put(KEY, JSON.stringify(periods));
      await p.flush();
      if (!AccountScope.valid(token) || (canCommit !== undefined && !canCommit())) {
        await p.put(KEY, previous);
        await p.flush();
        return false;
      }
      return true;
      } catch (e) {
        console.error('PeriodStore.save failed: ' + JSON.stringify(e));
        return false;
      }
    });
  }
}
