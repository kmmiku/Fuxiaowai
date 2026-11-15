/** 下节课：从当前时刻往后找最近一门还没开始的课 */

import type { Course, Period } from './types';
import { isInWeek } from './types';
import { dateOf } from './semester';

export interface NextClass {
  course: Course;
  /** 距离上课还有多少分钟 */
  minutes: number;
  start: Date;
  /** 0=今天 1=明天 … */
  dayOffset: number;
}

/** 把「第 week 周 weekday 第 startPeriod 节」换算成绝对时刻 */
export function absoluteTime(week: number, weekday: number, periods: Period[], startPeriod: number): Date {
  const day = dateOf(week, weekday);
  const hm = periods[startPeriod - 1]?.start ?? '08:00';
  const [h, m] = hm.split(':').map((x) => parseInt(x, 10));
  return new Date(day.getFullYear(), day.getMonth(), day.getDate(), h || 0, m || 0, 0, 0);
}

function clock(d: Date): string {
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

/** 找本周内最近一门未开始的课；找不到返回 null */
export function nextClassOf(
  courses: Course[],
  periods: Period[],
  week: number,
  now: Date = new Date()
): NextClass | null {
  let best: NextClass | null = null;
  for (const c of courses) {
    if (!isInWeek(c, week)) continue;
    const start = absoluteTime(week, c.weekday, periods, c.startPeriod);
    const diffMs = start.getTime() - now.getTime();
    if (diffMs <= 0) continue;
    if (!best || start.getTime() < best.start.getTime()) {
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const day = new Date(start.getFullYear(), start.getMonth(), start.getDate());
      best = {
        course: c,
        minutes: Math.round(diffMs / 60000),
        start,
        dayOffset: Math.round((day.getTime() - today.getTime()) / 86400000)
      };
    }
  }
  return best;
}

/** "今天 08:38 · 还有 8 小时 8 分 · Hadoop开发技术 · 实3603" */
export function nextClassLabel(n: NextClass): string {
  const dayText = n.dayOffset === 0 ? '今天' : n.dayOffset === 1 ? '明天' : `${n.dayOffset} 天后`;
  const h = Math.floor(n.minutes / 60);
  const m = n.minutes % 60;
  const left = h > 0 ? `${h} 小时${m > 0 ? ` ${m} 分` : ''}` : `${m} 分`;
  const bits = [dayText + ' ' + clock(n.start), `还有 ${left}`, n.course.name];
  if (n.course.room) bits.push(n.course.room);
  return bits.join(' · ');
}