import { TimetableStateStore, TermMetadata } from '../../data/local/TimetableStateStore';
/**
 * 学期日历：把"第几周"换算成具体的日期条。
 *
 * 2026—2027 学年第一学期第 1 周的周一是 2026-08-31，
 * 因此第 N 周的周一 = 08-31 + (N-1)*7 天。
 * 日期函数读取当前所选课表的学期配置；下方常量兼容旧调用。
 */
export const TERM_FIRST_MONDAY: Date = new Date(2026, 7, 31);
const DAY_MS: number = 86400000;

/** 学期总周数 */
export const TOTAL_WEEKS: number = 20;

/** 学期标签 */
export const TERM_LABEL: string = '2026-2027学年 第1学期';

export interface WeekDates {
  dates: string[];
  month: string;
  todayIndex: number;
}

/** 取第 week 周的 7 个日号、月份标签、以及今天在该周的下标（不在本周为 -1） */
export function weekDates(week: number): WeekDates {
  const monday: Date = new Date(termFirstMonday().getTime() + (week - 1) * 7 * DAY_MS);
  const dates: string[] = [];
  for (let i = 0; i < 7; i++) {
    dates.push(new Date(monday.getTime() + i * DAY_MS).getDate().toString());
  }
  const month: string = `${monday.getMonth() + 1}月`;
  return { dates: dates, month: month, todayIndex: todayIndexIn(monday) };
}

/** 今天在第 week 周里的下标；不在本周返回 -1 */
function todayIndexIn(monday: Date): number {
  const now: Date = new Date();
  const today: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const diff: number = Math.round((today.getTime() - monday.getTime()) / DAY_MS);
  return diff >= 0 && diff < 7 ? diff : -1;
}

/** 该周的日期范围标签，如 "12/7 – 12/11"（只到周五） */
export function weekRangeLabel(week: number): string {
  const monday: Date = new Date(termFirstMonday().getTime() + (week - 1) * 7 * DAY_MS);
  const friday: Date = new Date(monday.getTime() + 4 * DAY_MS);
  return `${monday.getMonth() + 1}/${monday.getDate()} – ${friday.getMonth() + 1}/${friday.getDate()}`;
}

/** 今天落在第几周（用于启动时定位到当前周） */
export function currentWeek(totalWeeks: number): number {
  const now: Date = new Date();
  const today: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const diff: number = Math.floor((today.getTime() - termFirstMonday().getTime()) / DAY_MS);
  const w: number = Math.floor(diff / 7) + 1;
  if (w < 1) {
    return 1;
  }
  const limit: number = getTermConfig().totalWeeks;
  return w > limit ? limit : w;
}
export function getTermConfig(): TermMetadata { return TimetableStateStore.term(); }
export function termFirstMonday(): Date { return new Date(getTermConfig().startMonday + 'T00:00:00'); }


