import { Course } from '../../domain/model/Course';

const DAY_SHORT: string[] = ['一', '二', '三', '四', '五', '六', '日'];

/** 周次数组 → "1-5周,7-17周(单)" 这样的人话 */
export function weeksLabel(weeks: number[]): string {
  if (weeks.length === 0) {
    return '未设置';
  }
  const sorted: number[] = weeks.slice().sort((a: number, b: number) => a - b);
  const parts: string[] = [];
  let i: number = 0;
  while (i < sorted.length) {
    let step: number = 1;
    if (i + 1 < sorted.length) {
      const d: number = sorted[i + 1] - sorted[i];
      step = d === 1 ? 1 : 2;
    }
    let j: number = i;
    while (j + 1 < sorted.length && sorted[j + 1] - sorted[j] === step) {
      j++;
    }
    const from: number = sorted[i];
    const to: number = sorted[j];
    let seg: string = from === to ? `${from}周` : `${from}-${to}周`;
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
  return c.startPeriod === c.endPeriod ? `${c.startPeriod}节` : `${c.startPeriod}-${c.endPeriod}节`;
}

/** 星期 → "周一" */
export function weekdayLabel(day: number): string {
  const idx: number = day - 1;
  return idx >= 0 && idx < 7 ? `周${DAY_SHORT[idx]}` : `周${day}`;
}

/** 一行摘要：周一 3-4节 · 教4203 · 梁艳 */
export function courseBrief(c: Course): string {
  const bits: string[] = [weekdayLabel(c.weekday), periodsLabel(c)];
  if (c.room.length > 0) {
    bits.push(c.room);
  }
  if (c.teacher.length > 0) {
    bits.push(c.teacher);
  }
  return bits.join(' · ');
}