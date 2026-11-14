import { TimetableStateStore } from '../data/local/TimetableStateStore';
import { FormExtensionAbility, formBindingData, formProvider, formInfo } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import hilog from '@ohos.hilog';
import preferences from '@ohos.data.preferences';
import { Db } from '../data/local/Db';
import { CourseDao } from '../data/local/dao/CourseDao';
import { PeriodStore } from '../data/local/PeriodStore';
import { Course, Period } from '../domain/model/Course';
import { currentWeek, TOTAL_WEEKS } from '../common/util/TermCalendar';
import { buildDayLines, todayDateLabel, todayWeekday } from './FormData';
import { TimetableInfo } from '../domain/repository/CourseRepository';

const DOMAIN: number = 0x0030;
const TAG: string = 'FuxiaoForm';
/** formId → 卡片名（day_card），onUpdateForm 只给 formId，得自己记 */
const FILE: string = 'fxw_forms';
/** 一天的卡片最多画几条，超出的用「还有 N 门」兜住（卡片不是列表，不能滚太多） */
const DAY_MAX_LINES: number = 5;

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId: string = this.paramOf(want, formInfo.FormParam.IDENTITY_KEY);
    const cardName: string = this.paramOf(want, formInfo.FormParam.NAME_KEY);
    hilog.info(DOMAIN, TAG, 'onAddForm id=%{public}s name=%{public}s', formId, cardName);
    this.remember(formId, cardName)
      .then(() => this.push(formId, cardName))
      .catch((e: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'onAddForm push failed: %{public}s', JSON.stringify(e));
      });
    // 先给一个占位，真实数据异步 updateForm 补上
    return formBindingData.createFormBindingData({ 'ready': '0' });
  }

  onUpdateForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onUpdateForm id=%{public}s', formId);
    this.cardOf(formId)
      .then((name: string) => {
        if (name.length > 0) {
          return this.push(formId, name);
        }
        return Promise.resolve();
      })
      .catch((e: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'onUpdateForm failed: %{public}s', JSON.stringify(e));
      });
  }

  onRemoveForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onRemoveForm id=%{public}s', formId);
    this.forget(formId).catch((e: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'forget failed: %{public}s', JSON.stringify(e));
    });
  }

  // ---------- 内部 ----------

  private paramOf(want: Want, key: string): string {
    const params: Record<string, Object> | undefined = want.parameters;
    if (params === undefined) {
      return '';
    }
    const v: Object = params[key];
    return typeof v === 'string' ? v as string : '';
  }

  private async remember(formId: string, cardName: string): Promise<void> {
    if (formId.length === 0 || cardName.length === 0) {
      return;
    }
    const p: preferences.Preferences = await preferences.getPreferences(this.context, FILE);
    await p.put(`form_${formId}`, cardName);
    await p.flush();
  }

  private async cardOf(formId: string): Promise<string> {
    const p: preferences.Preferences = await preferences.getPreferences(this.context, FILE);
    const v: string = await p.get(`form_${formId}`, '') as string;
    return v;
  }

  private async forget(formId: string): Promise<void> {
    const p: preferences.Preferences = await preferences.getPreferences(this.context, FILE);
    await p.delete(`form_${formId}`);
    await p.flush();
  }

  /** 读库 → 组装 → updateForm */
  private async push(formId: string, cardName: string): Promise<void> {
    if (formId.length === 0) {
      return;
    }
    const payload: Record<string, string> = await this.buildPayload(cardName);
    const data: formBindingData.FormBindingData = formBindingData.createFormBindingData(payload);
    await formProvider.updateForm(formId, data);
    hilog.info(DOMAIN, TAG, 'updateForm ok id=%{public}s card=%{public}s', formId, cardName);
  }

  private async buildPayload(cardName: string): Promise<Record<string, string>> {
    await Db.open(this.context);
    const auth: preferences.Preferences = await preferences.getPreferences(this.context, 'fxw_auth');
    const user: string = await auth.get('user', '') as string;
    if (user.length > 0) { await Db.claimLegacyAccount(user); }
    Db.selectAccount(user);
    await TimetableStateStore.init(this.context);
    const tableId: string = TimetableStateStore.activeTableId();
    const courses: Course[] = await CourseDao.queryAll(tableId);
    PeriodStore.init(this.context);
    const periods: Period[] = await PeriodStore.load();
    const week: number = currentWeek(TOTAL_WEEKS);

    const all: string[] = buildDayLines(courses, periods, week, todayWeekday());
    const shown: string[] = all.slice(0, DAY_MAX_LINES);
    const payload: Record<string, string> = {
      'ready': '1',
      'weekLabel': `第${week}周`,
      'dateLabel': todayDateLabel(),
      'count': `${all.length}`,
      'empty': all.length === 0 ? '1' : '0',
      'more': all.length > DAY_MAX_LINES ? `${all.length - DAY_MAX_LINES}` : '',
      'lines': shown.join('\n')
    };
    return payload;
  }
}