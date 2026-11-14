import { Course, Period } from '../../domain/model/Course';
import { TERM_FIRST_MONDAY } from './TermCalendar';

const DAY_MS: number = 86400000;

/** 下节课信息 */
export interface NextClass {
  course: Course;
  /** 距开始的分钟数 */
  minutes: number;
  /** 开始时刻 HH:mm */
  start: string;
  /** 0=今天 1=明天 … */
  dayOffset: number;
}

function startOf(periods: Period[], index: number): string {
  for (let i = 0; i < periods.length; i++) {
    if (periods[i].index === index) {
      return periods[i].start;
    }
  }
  return '';
}

function absoluteTime(week: number, weekday: number, hhmm: string): number {
  const base: Date = new Date(TERM_FIRST_MONDAY.getTime()
    + (week - 1) * 7 * DAY_MS + (weekday - 1) * DAY_MS);
  const parts: string[] = hhmm.split(':');
  if (parts.length < 2) {
    return 0;
  }
  const d: Date = new Date(base.getFullYear(), base.getMonth(), base.getDate(),
    parseInt(parts[0], 10), parseInt(parts[1], 10), 0);
  return d.getTime();
}

/**
 * 找出本周内距 now 最近的一节课（只算还没开始的）
 * 用于「下节课倒计时」提示条，纯本地计算，不依赖系统提醒服务
 */
export function nextClassOf(courses: Course[], periods: Period[], week: number, now: Date): NextClass | null {
  const nowMs: number = now.getTime();
  let best: NextClass | null = null;
  let bestMs: number = Number.MAX_SAFE_INTEGER;
  for (let i = 0; i < courses.length; i++) {
    const c: Course = courses[i];
    const start: string = startOf(periods, c.startPeriod);
    if (start.length === 0) {
      continue;
    }
    const ms: number = absoluteTime(week, c.weekday, start);
    if (ms <= nowMs || ms >= bestMs) {
      continue;
    }
    const dayOffset: number = Math.floor((ms - nowMs) / DAY_MS);
    best = {
      course: c,
      minutes: Math.round((ms - nowMs) / 60000),
      start: start,
      dayOffset: dayOffset
    };
    bestMs = ms;
  }
  return best;
}

/** 提示条文案：今天 18:30 还有 25 分钟 · 虚拟化技术 · 教4203 */
export function nextClassLabel(n: NextClass | null): string {
  if (!n) {
    return '本周已经没有课了';
  }
  const when: string = n.dayOffset === 0 ? '今天' : (n.dayOffset === 1 ? '明天' : `${n.dayOffset} 天后`);
  const mins: string = n.minutes >= 60
    ? `${Math.floor(n.minutes / 60)} 小时 ${n.minutes % 60} 分`
    : `${n.minutes} 分钟`;
  return `${when} ${n.start} · 还有 ${mins} · ${n.course.name}${n.course.room.length > 0 ? ' · ' + n.course.room : ''}`;
}