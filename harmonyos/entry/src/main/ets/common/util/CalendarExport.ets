import { Db } from '../../data/local/Db';
/**
 * 把课表写进系统日历。
 *
 * 每门课的每个上课周 → 一条日程（起止时刻取书上课时间），
 * 标题是课程名，地点写教室，描述写教师 / 节次 / 周次，并提前 10 分钟提醒。
 *
 * 会话里没有服务器，也不该有：导出是纯本地能力，只跟系统日历打交道。
 */
import { calendarManager } from '@kit.CalendarKit';
import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Course, Period } from '../../domain/model/Course';
import { SerialQueue } from './SerialQueue';
import { TimetableStateStore } from '../../data/local/TimetableStateStore';
import preferences from '@ohos.data.preferences';

const DAY_MS: number = 86400000;
const calendarQueue: SerialQueue = new SerialQueue();
/** 提前多少分钟提醒 */
const REMIND_MINUTES: number = 10;

export interface CalendarExportResult {
  ok: boolean;
  /** 实际写入的条数 */
  count: number;
  message: string;
}

/** "08:25" → 当天的毫秒时间戳 */
function atClock(dayStart: number, clock: string): number {
  const parts: string[] = clock.split(':');
  const h: number = parts.length > 0 ? Number(parts[0]) : 0;
  const m: number = parts.length > 1 ? Number(parts[1]) : 0;
  const d: Date = new Date(dayStart);
  d.setHours(Number.isFinite(h) ? h : 0, Number.isFinite(m) ? m : 0, 0, 0);
  return d.getTime();
}

/** 第 week 周 weekday（1=周一）那天的 0 点时间戳 */
function dayStartOf(week: number, weekday: number, startMonday: string): number {
  const d: Date = new Date(new Date(startMonday + 'T00:00:00').getTime() + (week - 1) * 7 * DAY_MS + (weekday - 1) * DAY_MS);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

function periodClock(periods: Period[], index: number, fallback: string): string {
  const p: Period | undefined = periods.find((x: Period) => x.index === index);
  return p ? p.start : fallback;
}

function periodEndClock(periods: Period[], index: number, fallback: string): string {
  const p: Period | undefined = periods.find((x: Period) => x.index === index);
  return p ? p.end : fallback;
}

/** 全部周次展开后的事件总数（给确认弹窗用） */
export function countPlannedEvents(courses: Course[]): number {
  let n: number = 0;
  courses.forEach((c: Course) => {
    n += c.weeks.length;
  });
  return n;
}

/**
 * 申请日历读写权限。
 * 已经授予时不会再弹窗；用户拒绝会返回 false。
 */
async function ensurePermission(ctx: common.UIAbilityContext): Promise<boolean> {
  const perms: Permissions[] = ['ohos.permission.READ_CALENDAR', 'ohos.permission.WRITE_CALENDAR'];
  const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(ctx, perms);
  const granted: number[] = result.authResults;
  for (let i = 0; i < granted.length; i++) {
    if (granted[i] !== 0) {
      return false;
    }
  }
  return true;
}

/**
 * 把课程写进系统默认日历。
 * reminderMinutes=0 表示只建日程不提醒。
 * 返回实际写入条数；任一批次失败都会如实报出来，不吞异常。
 */
export async function exportCoursesToCalendar(
  ctx: common.UIAbilityContext,
  courses: Course[],
  periods: Period[],
  reminderMinutes: number = REMIND_MINUTES
): Promise<CalendarExportResult> {
  const account: string = Db.accountUser();
  const requestedTable: string = TimetableStateStore.isInitialized() ? TimetableStateStore.activeTableId() : '';
  return calendarQueue.run(async () => {
    checkCalendarAccount(account);
    await TimetableStateStore.init(ctx);
    checkCalendarAccount(account);
    const tableId: string = requestedTable.length > 0 ? requestedTable : TimetableStateStore.activeTableId();
    const startMonday: string = TimetableStateStore.term(tableId).startMonday;
    return synchronizeCalendar(ctx, courses, periods, reminderMinutes, tableId, startMonday, true, account);
  });
}

async function synchronizeCalendar(ctx: common.UIAbilityContext, courses: Course[], periods: Period[], reminderMinutes: number, tableId: string, startMonday: string, prompt: boolean, account: string): Promise<CalendarExportResult> {
  checkCalendarAccount(account);
  let allowed: boolean = false;
  try {
    allowed = prompt ? await ensurePermission(ctx) : hasCalendarPermission(ctx);
  } catch (e) {
    const err = e as BusinessError;
    return { ok: false, count: 0, message: `申请日历权限失败：${err.message ?? ''}` };
  }
  checkCalendarAccount(account);
  if (!allowed) {
    return { ok: false, count: 0, message: '没有拿到日历读写权限，无法导出' };
  }

  let calendar: calendarManager.Calendar;
  try {
    const manager: calendarManager.CalendarManager = calendarManager.getCalendarManager(ctx);
    calendar = await manager.getCalendar();
  } catch (e) {
    const err = e as BusinessError;
    return { ok: false, count: 0, message: `打不开系统日历：${err.message ?? ''}` };
  }

  // 先把事件都算出来，写入阶段再分片，避免中途失败留下半截
  const events: calendarManager.Event[] = [];
  courses.forEach((c: Course) => {
    const weeks: number[] = c.weeks.slice().sort((a: number, b: number) => a - b);
    weeks.forEach((w: number) => {
      const day: number = dayStartOf(w, c.weekday, startMonday);
      const startClock: string = periodClock(periods, c.startPeriod, '08:00');
      const endClock: string = periodEndClock(periods, c.endPeriod, '09:40');
      const startAt: number = atClock(day, startClock);
      const endAt: number = atClock(day, endClock);
      const where: string = c.room.length > 0 ? `${c.room}` : '';
      const desc: string =
        `第${w}周 · 周${'一二三四五六日'.charAt(c.weekday - 1)} 第${c.startPeriod}-${c.endPeriod}节` +
        (c.teacher.length > 0 ? ` · ${c.teacher}` : '') +
        (c.campus.length > 0 ? ` · ${c.campus}` : '');
      const ev: calendarManager.Event = {
        type: calendarManager.EventType.NORMAL,
        title: c.name,
        startTime: startAt,
        endTime: endAt,
        reminderTime: reminderMinutes > 0 ? [reminderMinutes] : [],
        description: desc
      };
      if (where.length > 0) {
        ev.location = { location: where };
      }
      ev.description = desc + `\n[fxw:${encodeURIComponent(account)}:${tableId}:${c.id}:${w}]`;
      events.push(ev);
    });
  });


  const p: preferences.Preferences = await preferences.getPreferences(ctx, 'fxw_calendar_owned');
  let owned: Record<string, number> = await migrateCalendarOwnership(p, account);
  await p.put('used', true);
  await p.put('export_' + encodeURIComponent(account) + ':' + tableId, true);
  await p.put('reminder_' + encodeURIComponent(account) + ':' + tableId, reminderMinutes);
  await p.flush();
  const legacyAccount: string = await p.get('legacyAccount', '') as string;
  checkCalendarAccount(account);
  const existing: calendarManager.Event[] = await calendar.getEvents();
  const prefix: string = '[fxw:' + encodeURIComponent(account) + ':' + tableId + ':';
  existing.forEach((event: calendarManager.Event) => {
    const description: string = event.description || '';
    const marker: number = description.lastIndexOf('\n[fxw:');
    if (marker >= 0 && event.id !== undefined) {
      const key: string = description.substring(marker + 1);
      owned[calendarOwnershipKey(key, account, legacyAccount)] = event.id;
    }
  });
  const desired: string[] = [];
  let written: number = 0;
  try {
    for (let i = 0; i < events.length; i++) {
      checkCalendarAccount(account);
      const event: calendarManager.Event = events[i];
      const description: string = event.description || '';
      const key: string = description.substring(description.lastIndexOf('\n') + 1);
      desired.push(key);
      const id: number = owned[key];
      if (id !== undefined && existing.some((item: calendarManager.Event) => item.id === id)) {
        event.id = id;
        await calendar.updateEvent(event);
      } else { owned[key] = await calendar.addEvent(event); }
      await p.put('events', JSON.stringify(owned)); await p.flush(); written++;
    }
    const keys: string[] = Object.keys(owned);
    for (let i = 0; i < keys.length; i++) {
      checkCalendarAccount(account);
      const key: string = keys[i];
      if (key.indexOf(prefix) === 0 && desired.indexOf(key) < 0) {
        if (existing.some((item: calendarManager.Event) => item.id === owned[key])) { await calendar.deleteEvent(owned[key]); }
        const retained: Record<string, number> = {};
        Object.keys(owned).forEach((keep: string) => { if (keep !== key) { retained[keep] = owned[keep]; } });
        owned = retained; await p.put('events', JSON.stringify(owned)); await p.flush();
      }
    }
  } catch (e) {
    const err = e as BusinessError;
    return { ok: false, count: written, message: '写入失败，可重试：' + (err.message || '') };
  }
  return { ok: true, count: written, message: '已写入 ' + written + ' 条日程到系统日历' };
}
export async function clearOwnedCalendarEvents(ctx: common.UIAbilityContext): Promise<void> {
  await calendarQueue.run(() => clearCalendar(ctx));
}
async function clearCalendar(ctx: common.UIAbilityContext): Promise<void> {
  const p: preferences.Preferences = await preferences.getPreferences(ctx, 'fxw_calendar_owned');
  const owned: Record<string, number> = JSON.parse(await p.get('events', '{}') as string) as Record<string, number>;
  if (Object.keys(owned).length === 0 && !(await p.get('used', false) as boolean)) { return; }
  if (!await ensurePermission(ctx)) { throw new Error('没有日历清理权限'); }
  const calendar: calendarManager.Calendar = await calendarManager.getCalendarManager(ctx).getCalendar();
  const events: calendarManager.Event[] = await calendar.getEvents();
  for (let i = 0; i < events.length; i++) {
    const event: calendarManager.Event = events[i];
    if (event.id !== undefined && (Object.keys(owned).some((key: string) => owned[key] === event.id) || (event.description || '').indexOf('\n[fxw:') >= 0)) { await calendar.deleteEvent(event.id); }
  }
  await p.clear(); await p.flush();
}

function hasCalendarPermission(ctx: common.UIAbilityContext): boolean {
  try {
    const manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const token: number = ctx.applicationInfo.accessTokenId;
    return manager.checkAccessTokenSync(token, 'ohos.permission.READ_CALENDAR') === 0 && manager.checkAccessTokenSync(token, 'ohos.permission.WRITE_CALENDAR') === 0;
  } catch (e) { return false; }
}

/** Reconcile previously exported selected-table events without showing a permission dialog. */
export async function refreshOwnedCalendarEvents(ctx: common.UIAbilityContext, courses: Course[], periods: Period[]): Promise<void> {
  const account: string = Db.accountUser();
  const requestedTable: string = TimetableStateStore.isInitialized() ? TimetableStateStore.activeTableId() : '';
  await calendarQueue.run(async () => {
    checkCalendarAccount(account);
    await TimetableStateStore.init(ctx);
    checkCalendarAccount(account);
    const tableId: string = requestedTable.length > 0 ? requestedTable : TimetableStateStore.activeTableId();
    const startMonday: string = TimetableStateStore.term(tableId).startMonday;
    const p: preferences.Preferences = await preferences.getPreferences(ctx, 'fxw_calendar_owned');
    if (!(await p.get('used', false) as boolean) || !hasCalendarPermission(ctx)) { return; }
    const owned: Record<string, number> = await migrateCalendarOwnership(p, account);
    const prefix: string = '[fxw:' + encodeURIComponent(account) + ':' + tableId + ':';
    const previous: boolean = await p.get('export_' + encodeURIComponent(account) + ':' + tableId, false) as boolean;
    if (!previous && !Object.keys(owned).some((key: string) => key.indexOf(prefix) === 0)) { return; }
    const reminderMinutes: number = await p.get('reminder_' + encodeURIComponent(account) + ':' + tableId, REMIND_MINUTES) as number;
    const result: CalendarExportResult = await synchronizeCalendar(ctx, courses, periods, reminderMinutes, tableId, startMonday, false, account);
    if (!result.ok) { throw new Error(result.message); }
  });
}



function checkCalendarAccount(account: string): void {
  if (Db.accountUser() !== account) { throw new Error('账号已切换，日历操作已取消'); }
}
function calendarOwnershipKey(key: string, account: string, legacyAccount: string): string {
  if (key.split(':').length === 4) { return '[fxw:' + encodeURIComponent(legacyAccount) + ':' + key.substring(5); }
  return key;
}
async function migrateCalendarOwnership(p: preferences.Preferences, account: string): Promise<Record<string, number>> {
  const owned: Record<string, number> = JSON.parse(await p.get('events', '{}') as string) as Record<string, number>;
  const version: number = await p.get('schemaVersion', 0) as number;
  if (version >= 2) { return owned; }
  checkCalendarAccount(account);
  const migrated: Record<string, number> = {};
  const keys: string[] = Object.keys(owned);
  for (let i = 0; i < keys.length; i++) {
    const old: string = keys[i];
    migrated[calendarOwnershipKey(old, account, account)] = owned[old];
    const table: string = old.split(':')[1];
    if (table) {
      await p.put('export_' + encodeURIComponent(account) + ':' + table, true);
      const minutes: number = await p.get('reminder_' + table, REMIND_MINUTES) as number;
      await p.put('reminder_' + encodeURIComponent(account) + ':' + table, minutes);
    }
  }
  checkCalendarAccount(account);
  await p.put('events', JSON.stringify(migrated));
  await p.put('legacyAccount', account); await p.put('schemaVersion', 2); await p.flush();
  return migrated;
}
