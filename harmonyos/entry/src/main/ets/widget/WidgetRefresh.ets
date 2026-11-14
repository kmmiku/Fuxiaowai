import { formBindingData, formProvider } from '@kit.FormKit';
import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { Course, Period } from '../domain/model/Course';
import { currentWeek, TOTAL_WEEKS } from '../common/util/TermCalendar';
import { AccountScope } from '../common/util/AccountScope';
import { buildDayLines, todayDateLabel, todayWeekday } from './FormData';
interface WidgetPayload { ready: string; weekLabel: string; dateLabel: string; count: string; empty: string; more: string; lines: string; }
/** Push current data to already installed forms after edits and logout. */
export class WidgetRefresh {
  static async update(ctx: common.Context, courses: Course[], periods: Period[]): Promise<void> {
    const token: number = AccountScope.token();
    const week: number = currentWeek(TOTAL_WEEKS);
    const lines: string[] = buildDayLines(courses, periods, week, todayWeekday());
    const payload: WidgetPayload = {
      ready: '1', weekLabel: `第${week}周`, dateLabel: todayDateLabel(),
      count: `${lines.length}`, empty: lines.length === 0 ? '1' : '0',
      more: lines.length > 5 ? `${lines.length - 5}` : '', lines: lines.slice(0, 5).join('\n')
    };
    const p: preferences.Preferences = await preferences.getPreferences(ctx, 'fxw_forms');
    const keys: string[] = Object.keys(p.getAllSync());
    for (const key of keys) {
      if (!AccountScope.valid(token)) { return; }
      if (!key.startsWith('form_') || !/^\d+$/.test(key.substring(5))) { continue; }
      try { await formProvider.updateForm(key.substring(5), formBindingData.createFormBindingData(payload)); }
      catch (e) { /* An installed form may have been removed concurrently. */ }
    }
  }
}
