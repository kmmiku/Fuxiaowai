/** 把某一周的课表拼成纯文本，用于复制到剪贴板（对齐鸿蒙 ShareText.ets） */

import { isInWeek, type Course, type Period } from './types';
import { weekRangeLabel } from './semester';

const DAY_NAMES = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

function timeOf(period: number, periods: Period[]): string {
  for (const p of periods) {
    if (p.index === period) return p.start;
  }
  return '';
}

export function buildWeekText(week: number, courses: Course[], periods: Period[]): string {
  const lines: string[] = [];
  lines.push(`福小外 · 第${week}周（${weekRangeLabel(week)}）`);

  let count = 0;
  for (let d = 1; d <= 7; d++) {
    const ofDay = courses
      .filter((c) => c.weekday === d && isInWeek(c, week))
      .sort((a, b) => a.startPeriod - b.startPeriod);
    if (ofDay.length === 0) continue;
    lines.push('');
    for (const c of ofDay) {
      const span = c.startPeriod === c.endPeriod ? `${c.startPeriod}` : `${c.startPeriod}-${c.endPeriod}`;
      const time = timeOf(c.startPeriod, periods);
      const room = c.room.length > 0 ? ` @${c.room}` : '';
      const teacher = c.teacher.length > 0 ? ` ${c.teacher}` : '';
      lines.push(`${DAY_NAMES[d - 1]} ${span}节 ${time} ${c.name}${room}${teacher}`);
      count++;
    }
  }

  if (count === 0) {
    lines.push('');
    lines.push('本周没有课 🎉');
  }
  return lines.join('\n');
}