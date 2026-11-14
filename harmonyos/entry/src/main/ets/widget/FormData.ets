import { Course, DEFAULT_PERIODS, Period } from '../domain/model/Course';

/**
 * 卡片数据组装：把课表压成"扁平的纯字符串"，供 FormExtensionAbility 塞进 formBindingData。
 *
 * 为什么全用字符串：
 * formBindingData 的对象字段在不同 API 版本上对 boolean / number / 嵌套数组的支持不一致，
 * 统一转成 string（列表用 \n 分隔，字段用 \t 分隔）最稳，卡片里 split 一下就能用。
 */

export const COURSE_BG: string[] = [
  '#EDEBFD', '#FDF0E3', '#E6F6EE', '#E5F4F8',
  '#F3E8FA', '#FCE9EE', '#F2F6DF', '#E8F0FD'
];

export const COURSE_FG: string[] = [
  '#7C6CF0', '#E8892B', '#2FA36B', '#2B9BB5',
  '#9B59C9', '#E46A8B', '#8AA61F', '#3D7EDB'
];

const WEEKDAY_CN: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

/** 节次开始时间，找不到就给默认表里的值 */
export function startClock(periods: Period[], index: number): string {
  for (let i = 0; i < periods.length; i++) {
    if (periods[i].index === index) {
      return periods[i].start;
    }
  }
  for (let i = 0; i < DEFAULT_PERIODS.length; i++) {
    if (DEFAULT_PERIODS[i].index === index) {
      return DEFAULT_PERIODS[i].start;
    }
  }
  return '';
}

/** 节次结束时间 */
export function endClock(periods: Period[], index: number): string {
  for (let i = 0; i < periods.length; i++) {
    if (periods[i].index === index) {
      return periods[i].end;
    }
  }
  for (let i = 0; i < DEFAULT_PERIODS.length; i++) {
    if (DEFAULT_PERIODS[i].index === index) {
      return DEFAULT_PERIODS[i].end;
    }
  }
  return '';
}

/** 今天/本周的日历标签 */
export function todayDateLabel(): string {
  const now: Date = new Date();
  return `${now.getMonth() + 1}月${now.getDate()}日 ${WEEKDAY_CN[now.getDay()]}`;
}

/** 今天是周几（1=周一 … 7=周日） */
export function todayWeekday(): number {
  const d: number = new Date().getDay();
  return d === 0 ? 7 : d;
}

/** 今天这一天的课程行：起始–结束\t课名\t教室\t底色\t主色\n… */
export function buildDayLines(courses: Course[], periods: Period[], week: number, weekday: number): string[] {
  const picked: Course[] = courses
    .filter((c: Course) => c.weekday === weekday && c.weeks.indexOf(week) >= 0)
    .sort((a: Course, b: Course) => a.startPeriod - b.startPeriod);
  return picked.map((c: Course) => {
    const idx: number = c.colorIndex % COURSE_BG.length;
    const st: string = startClock(periods, c.startPeriod);
    const en: string = endClock(periods, c.endPeriod);
    const time: string = st.length > 0 && en.length > 0 ? `${st}–${en}` : `第${c.startPeriod}-${c.endPeriod}节`;
    return `${time}\t${c.name}\t${c.room}\t${COURSE_BG[idx]}\t${COURSE_FG[idx]}`;
  });
}
