import { Db } from './Db';
import { SerialQueue } from '../../common/util/SerialQueue';
import { BusinessError } from '@kit.BasicServicesKit';
import reminderAgentManager from '@ohos.reminderAgentManager';
import { Course, Period } from '../../domain/model/Course';
import { CAL_TERMS, CalTerm } from '../../common/util/SchoolCalendar';
import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { AccountScope } from '../../common/util/AccountScope';

export interface TermMetadata {
  startMonday: string;
  totalWeeks: number;
  label: string;
  year: string;
  term: string;
}
export const DEFAULT_TERM: TermMetadata = {
  startMonday: '2026-08-31', totalWeeks: 20, label: '2026-2027学年 第1学期', year: '2026-2027', term: '1'
};

interface TimetableState {
  schemaVersion?: number;
  activeTableId?: string;
  activeTables?: Record<string, string>;
  terms: Record<string, TermMetadata>;
}
export class TimetableStateStore {
  private static prefs: preferences.Preferences | null = null;
  private static state: TimetableState = { schemaVersion: 2, activeTables: {}, terms: {} };
  private static writes: SerialQueue = new SerialQueue();
  static async init(ctx: common.Context): Promise<void> {
    const account: string = Db.accountUser();
    return TimetableStateStore.writes.run(async () => {
      const p: preferences.Preferences = await preferences.getPreferences(ctx, 'fxw_timetable_state');
      const raw: string = await p.get('state', '') as string;
      TimetableStateStore.checkAccount(account);
      let state: TimetableState = { schemaVersion: 2, activeTables: {}, terms: {} };
      if (raw.length > 0) {
        const saved: TimetableState = JSON.parse(raw) as TimetableState;
        if (saved.schemaVersion === 2) {
          state = { schemaVersion: 2, activeTables: saved.activeTables || {}, terms: saved.terms || {} };
        } else {
          const active: Record<string, string> = {};
          active[account] = saved.activeTableId || 't1';
          const terms: Record<string, TermMetadata> = {};
          const legacyTerms: Record<string, TermMetadata> = saved.terms || {}; Object.keys(legacyTerms).forEach((table: string) => { terms[TimetableStateStore.key(account, table)] = legacyTerms[table]; });
          state = { schemaVersion: 2, activeTables: active, terms: terms };
        }
      }
      TimetableStateStore.prefs = p;
      TimetableStateStore.state = state;
      await TimetableStateStore.persist(account);
    });
  }
  static isInitialized(): boolean { return TimetableStateStore.prefs !== null; }
  static activeTableId(): string {
    const active: Record<string, string> = TimetableStateStore.state.activeTables || {};
    return active[Db.accountUser()] || 't1';
  }
  static term(tableId: string = TimetableStateStore.activeTableId()): TermMetadata {
    const value: TermMetadata = TimetableStateStore.state.terms[TimetableStateStore.key(Db.accountUser(), tableId)] || DEFAULT_TERM;
    return { startMonday: value.startMonday, totalWeeks: value.totalWeeks, label: value.label, year: value.year, term: value.term };
  }
  static async select(tableId: string): Promise<void> {
    if (tableId.length === 0) { throw new Error('课表编号不能为空'); }
    const account: string = Db.accountUser();
    return TimetableStateStore.writes.run(async () => {
      TimetableStateStore.checkAccount(account);
      const active: Record<string, string> = TimetableStateStore.state.activeTables || {};
      active[account] = tableId;
      TimetableStateStore.state.activeTables = active;
      await TimetableStateStore.persist(account);
    });
  }
  static async saveTerm(tableId: string, metadata: TermMetadata, token?: number, canCommit?: () => boolean): Promise<void> {
    const account: string = Db.accountUser();
    const date: Date = new Date(metadata.startMonday + 'T00:00:00');
    if (!/^\d{4}-\d{2}-\d{2}$/.test(metadata.startMonday) || !Number.isFinite(date.getTime()) || date.getFullYear() !== Number(metadata.startMonday.substring(0, 4)) || date.getMonth() + 1 !== Number(metadata.startMonday.substring(5, 7)) || date.getDate() !== Number(metadata.startMonday.substring(8, 10)) || date.getDay() !== 1 || metadata.totalWeeks < 1 || metadata.totalWeeks > 60 || !Number.isInteger(metadata.totalWeeks)) {
      throw new Error('学期日期或周数无效');
    }
    return TimetableStateStore.writes.run(async () => {
      TimetableStateStore.checkAccount(account);
      if (token !== undefined && !AccountScope.valid(token)) { throw new Error('账号状态已变更'); }
      if (canCommit !== undefined && !canCommit()) { throw new Error('导入操作已取消'); }
      TimetableStateStore.state.terms[TimetableStateStore.key(account, tableId)] = { startMonday: metadata.startMonday, totalWeeks: metadata.totalWeeks, label: metadata.label, year: metadata.year, term: metadata.term };
      await TimetableStateStore.persist(account);
    });
  }
  /** 教务课表成功写入后丢弃游客选择与学期，不删除其他账号状态。 */
  static async discardGuest(): Promise<void> {
    const account: string = Db.accountUser();
    return TimetableStateStore.writes.run(async () => {
      TimetableStateStore.checkAccount(account);
      if (account.length === 0) { throw new Error('仅登录成功后可清除游客状态'); }
      const active: Record<string, string> = {};
      const previous: Record<string, string> = TimetableStateStore.state.activeTables || {};
      Object.keys(previous).forEach((key: string) => { if (key.length > 0) { active[key] = previous[key]; } });
      const terms: Record<string, TermMetadata> = {};
      Object.keys(TimetableStateStore.state.terms).forEach((key: string) => {
        if (!key.startsWith('["",')) { terms[key] = TimetableStateStore.state.terms[key]; }
      });
      TimetableStateStore.state.activeTables = active;
      TimetableStateStore.state.terms = terms;
      await TimetableStateStore.persist(account);
    });
  }
  static async clear(): Promise<void> {
    return TimetableStateStore.writes.run(async () => {
      TimetableStateStore.state = { schemaVersion: 2, activeTables: {}, terms: {} };
      if (!TimetableStateStore.prefs) { throw new Error('课表状态尚未初始化'); }
      await TimetableStateStore.prefs.clear();
      await TimetableStateStore.prefs.put('state', JSON.stringify(TimetableStateStore.state));
      await TimetableStateStore.prefs.flush();
    });
  }
  private static key(account: string, table: string): string { return JSON.stringify([account, table]); }
  private static checkAccount(account: string): void {
    if (Db.accountUser() !== account) { throw new Error('账号已切换，课表状态操作已取消'); }
  }
  private static async persist(account: string): Promise<void> {
    TimetableStateStore.checkAccount(account);
    if (!TimetableStateStore.prefs) { throw new Error('课表状态尚未初始化'); }
    await TimetableStateStore.prefs.put('state', JSON.stringify(TimetableStateStore.state));
    TimetableStateStore.checkAccount(account);
    await TimetableStateStore.prefs.flush();
  }
}

interface OwnedReminder { id: number; key: string; }
let reminderQueue: Promise<string> = Promise.resolve('');
export function refreshOwnedReminders(ctx: common.Context, courses: Course[], periods: Period[], beforeMin: number, force: boolean = false): Promise<string> {
  const account: string = Db.accountUser();
  const table: string = TimetableStateStore.activeTableId();
  const term: TermMetadata = TimetableStateStore.term(table);
  const run: Promise<string> = reminderQueue.catch(() => '').then(() => scheduleOwnedReminders(ctx, courses, periods, beforeMin, force, account, table, term));
  reminderQueue = run;
  return run;
}
export async function clearOwnedReminders(ctx: common.Context): Promise<void> {
  const run: Promise<string> = reminderQueue.catch(() => '').then(async () => { await cancelOwnedReminders(ctx); return ''; });
  reminderQueue = run;
  await run;
}
async function cancelOwnedReminders(ctx: common.Context, account?: string): Promise<void> {
  const p: preferences.Preferences = await preferences.getPreferences(ctx, 'fxw_reminder_owned');
  const owned: OwnedReminder[] = JSON.parse(await p.get('ids', '[]') as string) as OwnedReminder[];
  for (let i = owned.length - 1; i >= 0; i--) {
    if (account !== undefined && owned[i].key.indexOf(encodeURIComponent(account) + ':') !== 0) { continue; }
    if (account !== undefined) { checkReminderAccount(account); }
    await cancelReminderIfPresent(owned[i].id);
    owned.splice(i, 1);
    await p.put('ids', JSON.stringify(owned)); await p.flush();
  }
  if (account === undefined) { await p.clear(); }
  else { await p.put('enabled_' + encodeURIComponent(account), false); }
  await p.flush();
}
async function scheduleOwnedReminders(ctx: common.Context, courses: Course[], periods: Period[], beforeMin: number, force: boolean, account: string, table: string, term: TermMetadata): Promise<string> {
  const p: preferences.Preferences = await preferences.getPreferences(ctx, 'fxw_reminder_owned');
  checkReminderAccount(account);
  await migrateReminderOwnership(p, account);
  if (!force && !(await p.get('enabled_' + encodeURIComponent(account), false) as boolean)) { return ''; }
  if (beforeMin <= 0) { await cancelOwnedReminders(ctx, account); return ''; }
  checkReminderAccount(account);
  await p.put('enabled_' + encodeURIComponent(account), true); await p.flush();
  const monday: Date = new Date(term.startMonday + 'T00:00:00');
  const now: Date = new Date();
  const today: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const week: number = Math.min(term.totalWeeks, Math.max(1, Math.floor((today.getTime() - monday.getTime()) / 604800000) + 1));
  const owned: OwnedReminder[] = JSON.parse(await p.get('ids', '[]') as string) as OwnedReminder[];
  const desired: string[] = [];
  const slots: Set<string> = new Set<string>();
  let published: number = 0;
  for (let i = 0; i < courses.length; i++) {
    checkReminderAccount(account);
    const c: Course = courses[i];
    if (c.weeks.indexOf(week) < 0) { continue; }
    const period: Period | undefined = periods.find((item: Period) => item.index === c.startPeriod);
    if (!period) { continue; }
    const parts: string[] = period.start.split(':');
    const date: Date = new Date(monday.getTime());
    date.setDate(date.getDate() + (week - 1) * 7 + c.weekday - 1);
    date.setHours(Number(parts[0]), Number(parts[1]), 0, 0);
    date.setTime(date.getTime() - beforeMin * 60000);
    const key: string = encodeURIComponent(account) + ':' + table + ':' + c.id + ':' + week;
    if (date.getTime() <= Date.now() || slots.has(key)) { continue; }
    slots.add(key);
    desired.push(key);
    const req: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: { year: date.getFullYear(), month: date.getMonth() + 1, day: date.getDate(), hour: date.getHours(), minute: date.getMinutes(), second: 0 },
      notificationId: notificationIdOf(key),
      title: '上课提醒', content: c.name + (c.room.length > 0 ? ' · ' + c.room : ''),
      wantAgent: { pkgName: 'com.fuxiaowai.timetable', abilityName: 'EntryAbility' }
    };
    try {
      const previous: OwnedReminder | undefined = owned.find((item: OwnedReminder) => item.key === key);
      if (previous) {
        try { await reminderAgentManager.updateReminder(previous.id, req); }
        catch (e) {
          if ((e as BusinessError).code !== 1700003) { throw new Error((e as BusinessError).message); }
          previous.id = await reminderAgentManager.publishReminder(req);
        }
      }
      else {
        const id: number = await reminderAgentManager.publishReminder(req);
        owned.push({ id: id, key: key });
      }
      checkReminderAccount(account);
      await p.put('ids', JSON.stringify(owned)); await p.flush();
      published++;
    } catch (e) {
      const err = e as Error;
      throw new Error(`已排 ${published} 条提醒；系统返回：${err.message || JSON.stringify(e)}`);
    }
  }
  for (let i = owned.length - 1; i >= 0; i--) {
    if (owned[i].key.indexOf(encodeURIComponent(account) + ':') === 0 && desired.indexOf(owned[i].key) < 0) {
      checkReminderAccount(account);
      await cancelReminderIfPresent(owned[i].id);
      owned.splice(i, 1); await p.put('ids', JSON.stringify(owned)); await p.flush();
    }
  }
  return published === 0 ? '本周剩余时间没有可提醒的课' : `已排 ${published} 条提醒（本周课程）`;
}




/** Resolve dates exclusively from the bundled school calendar; never guess another semester's start. */
export function resolveSchoolTerm(label: string): TermMetadata | null {
  const years: RegExpMatchArray | null = label.match(/(20\d{2})\s*[-—–]\s*(20\d{2})/);
  const termMatch: RegExpMatchArray | null = label.match(/第?([12一二])学期/);
  if (!years || !termMatch || Number(years[2]) !== Number(years[1]) + 1) { return null; }
  const term: string = termMatch[1] === '1' || termMatch[1] === '一' ? '1' : '2';
  const known: CalTerm | undefined = CAL_TERMS.find((item: CalTerm) => item.key === 't' + term);
  if (!known) { return null; }
  const academicYear: number = known.startMonday.getFullYear() - (term === '2' ? 1 : 0);
  if (academicYear !== Number(years[1])) { return null; }
  const date: Date = known.startMonday;
  const month: string = (date.getMonth() + 1).toString().padStart(2, '0');
  const day: string = date.getDate().toString().padStart(2, '0');
  return { startMonday: date.getFullYear() + '-' + month + '-' + day, totalWeeks: known.weeks, label: label, year: years[1] + '-' + years[2], term: term };
}

async function cancelReminderIfPresent(id: number): Promise<void> {
  try { await reminderAgentManager.cancelReminder(id); }
  catch (e) { if ((e as BusinessError).code !== 1700003) { throw new Error((e as BusinessError).message); } }
}
function notificationIdOf(key: string): number {
  let value: number = 2166136261;
  for (let i = 0; i < key.length; i++) { value = Math.imul(value ^ key.charCodeAt(i), 16777619); }
  return (value >>> 0) % 2147483646 + 1;
}


function checkReminderAccount(account: string): void {
  if (Db.accountUser() !== account) { throw new Error('账号已切换，提醒操作已取消'); }
}
async function migrateReminderOwnership(p: preferences.Preferences, account: string): Promise<void> {
  if ((await p.get('schemaVersion', 0) as number) >= 2) { return; }
  checkReminderAccount(account);
  const owned: OwnedReminder[] = JSON.parse(await p.get('ids', '[]') as string) as OwnedReminder[];
  owned.forEach((item: OwnedReminder) => { if (item.key.split(':').length === 3) { item.key = encodeURIComponent(account) + ':' + item.key; } });
  const enabled: boolean = await p.get('enabled', false) as boolean;
  checkReminderAccount(account);
  await p.put('ids', JSON.stringify(owned));
  await p.put('enabled_' + encodeURIComponent(account), enabled);
  await p.put('schemaVersion', 2); await p.flush();
}
