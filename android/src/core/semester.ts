import { loadTerm } from './termStore';
/**
 * 学期日历：把「第几周」换算成具体的日期条。
 *
 * 2026—2027 学年第一学期第 1 周的周一是 2026-08-31，
 * 因此第 N 周的周一 = 08-31 + (N-1)*7 天。
 * 换学期时只改 TERM_FIRST_MONDAY 一处。
 */

export let TERM_FIRST_MONDAY = new Date(2026, 7, 31); // 2026-08-31
const DAY_MS = 86400000;

/** 学期总周数 */
export let TOTAL_WEEKS = 20;

/** 学期标签 */
export let TERM_LABEL = '2026-2027学年 第1学期';
export function refreshTerm(): void {
  const term=loadTerm();
  TERM_FIRST_MONDAY=new Date(`${term.startMonday}T00:00:00`);
  TOTAL_WEEKS=term.totalWeeks; TERM_LABEL=term.label;
}

export interface WeekDates {
  dates: string[];
  month: string;
  todayIndex: number;
  /** 每天对应的 Date，用于日视图标题 */
  days: Date[];
}

/** 取第 week 周的 7 个日号、月份标签、以及今天在该周的下标（不在本周为 -1） */
export function weekDates(week: number): WeekDates {
  refreshTerm();
  const monday = new Date(TERM_FIRST_MONDAY.getTime() + (week - 1) * 7 * DAY_MS);
  const dates: string[] = [];
  const days: Date[] = [];
  for (let i = 0; i < 7; i++) {
    const d = new Date(monday.getTime() + i * DAY_MS);
    dates.push(String(d.getDate()));
    days.push(d);
  }
  return { dates, month: `${monday.getMonth() + 1}月`, todayIndex: todayIndexIn(monday), days };
}

/** 今天在第 week 周里的下标；不在本周返回 -1 */
function todayIndexIn(monday: Date): number {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const diff = Math.round((today.getTime() - monday.getTime()) / DAY_MS);
  return diff >= 0 && diff < 7 ? diff : -1;
}

/** 该周的日期范围标签，如 "12/7 – 12/11"（只到周五） */
export function weekRangeLabel(week: number, withWeekend = false): string {
  refreshTerm();
  const monday = new Date(TERM_FIRST_MONDAY.getTime() + (week - 1) * 7 * DAY_MS);
  const last = new Date(monday.getTime() + (withWeekend ? 6 : 4) * DAY_MS);
  return `${monday.getMonth() + 1}/${monday.getDate()} – ${last.getMonth() + 1}/${last.getDate()}`;
}

/** 今天落在第几周（用于启动时定位到当前周） */
export function currentWeek(totalWeeks?: number): number {
  refreshTerm();
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const diff = Math.floor((today.getTime() - TERM_FIRST_MONDAY.getTime()) / DAY_MS);
  const w = Math.floor(diff / 7) + 1;
  if (w < 1) return 1;
  return Math.min(w,totalWeeks ?? TOTAL_WEEKS);
}

/** 今天是周几（1..7） */
export function todayWeekday(): number {
  const d = new Date().getDay(); // 0=周日
  return d === 0 ? 7 : d;
}

const WEEK_LABEL = ['一', '二', '三', '四', '五', '六', '日'];

/** 1..7 → 周一 */
export function weekdayText(day: number): string {
  return `周${WEEK_LABEL[day - 1] ?? day}`;
}

/** 第 week 周第 day 天（1..7）的 Date */
export function dateOf(week: number, day: number): Date {
  refreshTerm();
  const monday = new Date(TERM_FIRST_MONDAY.getTime() + (week - 1) * 7 * DAY_MS);
  return new Date(monday.getTime() + (day - 1) * DAY_MS);
}