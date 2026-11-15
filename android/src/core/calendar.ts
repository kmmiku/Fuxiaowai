import { accountToken, accountUser, isCurrent } from './accountScope';
import { activeTable, loadTerm } from './termStore';
import { registerPlugin } from '@capacitor/core';

import type { Course, Period } from './types';
import { dateOf } from './semester';
import { periodsLabel, weekdayLabel } from './courseFormat';

/** 一条待写入的日程（原生侧直接进 CalendarProvider） */
export interface CalendarEventInput {
  key?: string;
  title: string;
  description: string;
  location: string;
  /** 毫秒时间戳 */
  start: number;
  end: number;
  /** 提前多少分钟提醒，0 表示不提醒 */
  reminder: number;
}

export interface CalendarExportResult {
  updated?: number;
  inserted: number;
  failed: number;
  total: number;
}

interface FxwCalendarPlugin {
  export(options: { events: CalendarEventInput[]; owner?:string; table?:string }): Promise<CalendarExportResult>;
  clearOwned(options: {owner?:string}): Promise<void>;
}

const FxwCalendar = registerPlugin<FxwCalendarPlugin>('FxwCalendar');

const REMIND_MINUTES = 10;
/** 可选提前分钟数，UI 用它渲染选项 */
export const REMIND_OPTIONS: number[] = [0, 5, 10, 15, 30];
export const DEFAULT_REMIND = REMIND_MINUTES;
/** 节次时间兜底：periods 缺项时用它，避免算出 NaN */
const FALLBACK_START = '08:25';
const FALLBACK_END = '10:00';

/** 把 "08:25" 落到某一天的 Date 上 */
function atClock(day: Date, clock: string): Date {
  const m = /^(\d{1,2}):(\d{2})$/.exec(clock.trim());
  const d = new Date(day.getTime());
  if (!m) {
    d.setHours(8, 25, 0, 0);
    return d;
  }
  d.setHours(Number(m[1]), Number(m[2]), 0, 0);
  return d;
}

function clockOf(periods: Period[], index: number, fallback: string): string {
  const p = periods.find((x) => x.index === index);
  return p ? p.start : fallback;
}

function endClockOf(periods: Period[], index: number, fallback: string): string {
  const p = periods.find((x) => x.index === index);
  return p ? p.end : fallback;
}

/** 大纲：每门课 × 每个周次 → 一条日程；reminderMinutes=0 表示不提醒 */
export function buildEvents(
  courses: Course[],
  periods: Period[],
  reminderMinutes: number = REMIND_MINUTES
): CalendarEventInput[] {
  const out: CalendarEventInput[] = [];
  for (const c of courses) {
    if (!c.weeks || c.weeks.length === 0) continue;
    for (const w of c.weeks) {
      const day = dateOf(w, c.weekday);
      const start = atClock(day, clockOf(periods, c.startPeriod, FALLBACK_START));
      const end = atClock(day, endClockOf(periods, c.endPeriod, FALLBACK_END));
      const room = [c.campus, c.room].filter((s) => s && s.length > 0).join(' ');
      const desc = [
        `第${w}周 · ${weekdayLabel(c.weekday)} ${periodsLabel(c)}`,
        c.teacher ? `教师：${c.teacher}` : '',
        room ? `地点：${room}` : '',
        '由福小外导出'
      ]
        .filter((s) => s.length > 0)
        .join('\n');

      out.push({
        key: JSON.stringify([loadTerm().year,loadTerm().term,c.id,w]),
        title: c.name,
        description: desc,
        location: room,
        start: start.getTime(),
        end: end.getTime(),
        reminder: reminderMinutes
      });
    }
  }
  out.sort((a, b) => a.start - b.start);
  return out;
}

/** 写进系统日历；reminderMinutes=0 表示只建日程不提醒。失败会抛错，调用方负责提示 */
export async function exportCourses(
  courses: Course[],
  periods: Period[],
  reminderMinutes: number = REMIND_MINUTES
): Promise<CalendarExportResult> {
  const events = buildEvents(courses, periods, reminderMinutes);
  if (events.length === 0) {
    return { inserted: 0, failed: 0, total: 0 };
  }
  const token=accountToken(),owner=accountUser(),table=activeTable();
  const result=await FxwCalendar.export({events,owner,table});
  if(!isCurrent(token,owner))throw new Error('账号状态已改变，导出结果已失效');
  return result;
}
export async function clearOwnedCalendar(owner?:string):Promise<void> {
  return FxwCalendar.clearOwned({owner});
}
