/**
 * 领域模型：课程 / 节次 / 学期 / 课表
 * 纯数据与纯函数，不依赖 ArkUI、不依赖 ohos API，可直接单测
 */

export interface Course {
  id: string;
  name: string;
  teacher: string;
  room: string;
  campus: string;
  weekday: number;      // 1..7
  startPeriod: number;  // 1..12
  endPeriod: number;
  weeks: number[];      // [1..20]
  colorIndex: number;
}

export interface Period {
  index: number;
  start: string;
  end: string;
}

export interface Term {
  id: string;           // 2026-2027-1
  label: string;        // 2026-2027学年 第1学期
  startDate: string;    // yyyy-MM-dd（首个周一）
  totalWeeks: number;
}

/** 第 week 周是否上这门课 */
export function isInWeek(c: Course, week: number): boolean {
  return c.weeks.indexOf(week) >= 0;
}

/** 按周过滤并按星期分组（1..7） */
export function groupByWeekday(courses: Course[], week: number): Map<number, Course[]> {
  const map: Map<number, Course[]> = new Map<number, Course[]>();
  for (let d = 1; d <= 7; d++) {
    map.set(d, []);
  }
  courses.forEach((c: Course) => {
    if (isInWeek(c, week)) {
      const list: Course[] = map.get(c.weekday) ?? [];
      list.push(c);
      map.set(c.weekday, list);
    }
  });
  return map;
}

/** 课程名 hash → 稳定配色下标（同名同色）。FNV-1a 变体，避免中文课名碰撞 */
export function colorIndexOf(name: string): number {
  let h: number = 2166136261;
  for (let i = 0; i < name.length; i++) {
    h = h ^ name.charCodeAt(i);
    h = (h * 16777619) >>> 0;
  }
  return (h >>> 3) % 8;
}

/**
 * 解析正方教务的周次串，支持单段标记：
 *   "2-4周,6-17周"      → 2,3,4,6..17
 *   "第9周"             → 9
 *   "10-16周(双)"       → 10,12,14,16
 *   "1-5周,7-13周(单),14-16周" → 单双只作用于它所在的那一段
 */
export function parseWeeks(text: string): number[] {
  const set: Set<number> = new Set<number>();
  if (!text) {
    return [];
  }
  const segments: string[] = text.split(',');
  segments.forEach((raw: string) => {
    let seg: string = raw.trim();
    if (seg.length === 0) {
      return;
    }
    const onlyOdd: boolean = seg.indexOf('单') >= 0;
    const onlyEven: boolean = seg.indexOf('双') >= 0;
    seg = seg.replace(/[第周()（）单双\s]/g, '');
    if (seg.length === 0) {
      return;
    }
    const parts: string[] = seg.split('-');
    if (parts.length === 2) {
      const s: number = parseInt(parts[0], 10);
      const e: number = parseInt(parts[1], 10);
      if (isNaN(s) || isNaN(e)) {
        return;
      }
      for (let w = s; w <= e; w++) {
        if (onlyOdd && w % 2 === 0) {
          continue;
        }
        if (onlyEven && w % 2 === 1) {
          continue;
        }
        set.add(w);
      }
    } else if (parts.length === 1) {
      const w: number = parseInt(parts[0], 10);
      if (!isNaN(w)) {
        set.add(w);
      }
    }
  });
  const result: number[] = [];
  set.forEach((w: number) => result.push(w));
  result.sort((a: number, b: number) => a - b);
  return result;
}

/** 默认节次时间（可在"上课时间"里改）；第 9 节起为晚课 */
export const DEFAULT_PERIODS: Period[] = [
  { index: 1, start: '08:25', end: '09:10' },
  { index: 2, start: '09:15', end: '10:00' },
  { index: 3, start: '10:15', end: '11:00' },
  { index: 4, start: '11:05', end: '11:50' },
  { index: 5, start: '13:55', end: '14:40' },
  { index: 6, start: '14:45', end: '15:30' },
  { index: 7, start: '15:45', end: '16:30' },
  { index: 8, start: '16:35', end: '17:20' },
  { index: 9, start: '18:30', end: '19:15' },
  { index: 10, start: '19:20', end: '20:05' },
  { index: 11, start: '20:10', end: '20:55' },
  { index: 12, start: '21:00', end: '21:45' }
];

/** 表格行数（由节次数决定，新增节次不用改 UI） */
export const PERIOD_COUNT: number = DEFAULT_PERIODS.length;