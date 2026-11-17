import { Course, Period, isInWeek } from '../../domain/model/Course';
import { weekRangeLabel } from './TermCalendar';

const DAY_NAMES: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/**
 * 把某一周的课表拼成纯文本，用于复制/分享。
 * 形如：
 *   福小外 · 第11周（11/9 – 11/13）
 *   周一 1-2 示例课程 @示例教室 示例教师
 */
export function buildWeekText(week: number, courses: Course[], periods: Period[]): string {
  const lines: string[] = [];
  lines.push(`福小外 · 第${week}周（${weekRangeLabel(week)}）`);

  let count: number = 0;
  for (let d = 1; d <= 7; d++) {
    const ofDay: Course[] = courses
      .filter((c: Course) => c.weekday === d && isInWeek(c, week))
      .sort((a: Course, b: Course) => a.startPeriod - b.startPeriod);
    if (ofDay.length === 0) {
      continue;
    }
    lines.push('');
    ofDay.forEach((c: Course) => {
      const span: string = c.startPeriod === c.endPeriod
        ? `${c.startPeriod}`
        : `${c.startPeriod}-${c.endPeriod}`;
      const time: string = timeOf(c.startPeriod, periods);
      const room: string = c.room.length > 0 ? ` @${c.room}` : '';
      const teacher: string = c.teacher.length > 0 ? ` ${c.teacher}` : '';
      lines.push(`${DAY_NAMES[d - 1]} ${span}节 ${time} ${c.name}${room}${teacher}`);
      count++;
    });
  }

  if (count === 0) {
    lines.push('');
    lines.push('本周没有课 🎉');
  }
  return lines.join('\n');
}

function timeOf(period: number, periods: Period[]): string {
  for (let i = 0; i < periods.length; i++) {
    if (periods[i].index === period) {
      return periods[i].start;
    }
  }
  return '';
}