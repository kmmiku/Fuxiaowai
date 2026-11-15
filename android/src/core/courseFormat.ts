/** 课程信息的格式化：周次串、节次、一行摘要；纯函数，与 UI 无关 */

import type { Course, Period } from './types';
import { weekdayText } from './semester';

/** 周次数组 → "1-5周,7-17周(单)" 这样的人话 */
export function weeksLabel(weeks: number[]): string {
  if (weeks.length === 0) return '未设置';
  const sorted = weeks.slice().sort((a, b) => a - b);
  const parts: string[] = [];
  let i = 0;
  while (i < sorted.length) {
    let step = 1;
    if (i + 1 < sorted.length) {
      const d = sorted[i + 1] - sorted[i];
      step = d === 1 ? 1 : 2;
    }
    let j = i;
    while (j + 1 < sorted.length && sorted[j + 1] - sorted[j] === step) j++;
    const from = sorted[i];
    const to = sorted[j];
    let seg = from === to ? `${from}周` : `${from}-${to}周`;
    if (step === 2 && j > i) {
      // 起点奇数为单周，偶数为双周；单元素的段推断不出单双，不加后缀
      seg += from % 2 === 1 ? '(单)' : '(双)';
    }
    parts.push(seg);
    i = j + 1;
  }
  return parts.join(',');
}

/** 节次范围 → "3-4节" / "5节" */
export function periodsLabel(c: Course): string {
  return c.startPeriod === c.endPeriod
    ? `${c.startPeriod}节`
    : `${c.startPeriod}-${c.endPeriod}节`;
}

/** 星期 → "周一" */
export function weekdayLabel(day: number): string {
  return weekdayText(day);
}

/** 一行摘要：周一 3-4节 · 教4203 · 梁艳 */
export function courseBrief(c: Course): string {
  const bits = [weekdayLabel(c.weekday), periodsLabel(c)];
  if (c.room) bits.push(c.room);
  if (c.teacher) bits.push(c.teacher);
  return bits.join(' · ');
}

/** 第 start 节的开始时间 / 第 end 节的结束时间 → "08:25 – 09:55" */
export function periodTimeText(periods: Period[], start: number, end: number): string {
  const s = periods[start - 1]?.start ?? '';
  const e = periods[end - 1]?.end ?? '';
  if (!s || !e) return '';
  return `${s} – ${e}`;
}

/** 周次起止 + 单双 → 展开成周次数组（PARITY: 0=全部 1=单 2=双） */
export function buildWeeks(from: number, to: number, parity: number): number[] {
  const out: number[] = [];
  const a = Math.min(from, to);
  const b = Math.max(from, to);
  for (let w = a; w <= b; w++) {
    if (parity === 1 && w % 2 === 0) continue;
    if (parity === 2 && w % 2 === 1) continue;
    out.push(w);
  }
  return out;
}

/** 从周次数组反推起止与单双，用于编辑已有课程 */
export function describeRange(weeks: number[]): { from: number; to: number; parity: number } {
  if (!weeks.length) return { from: 1, to: TOTAL_WEEKS_FALLBACK, parity: 0 };
  const s = weeks.slice().sort((a, b) => a - b);
  const odd = s.every((w) => w % 2 === 1);
  const even = s.every((w) => w % 2 === 0);
  let parity = 0;
  if (s.length > 1 && odd) parity = 1;
  else if (s.length > 1 && even) parity = 2;
  return { from: s[0], to: s[s.length - 1], parity };
}

const TOTAL_WEEKS_FALLBACK = 20;