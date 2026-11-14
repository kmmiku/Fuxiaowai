/**
 * 校历数据：把教务处发布的两张校历图人工解析成结构化数据（2026-2027 学年）。
 *
 * 图源：https://www.fzfu.com/jwc/info/1084/5556.htm
 * 解析依据（图下方的「备注」表）：
 *   第一学期  开学 9月1-2日报到、9月3日正式上课、新生 9月13日报到；
 *             中秋放假1天、国庆放假3天、元旦放假1天；
 *             共20周（含运动会0.5周、考试周2周）；2027年1月18日-2月20日放寒假
 *   第二学期  2月21日报到、2月22日正式上课；
 *             清明放假1天、劳动节放假2天、端午放假1天；
 *             共19周（含考试周2周）；2027年7月5日-8月29日放暑假
 *
 * 为什么硬编码：一年只换一次，且要能离线看。换学年时改这个文件即可。
 */

export interface CalEvent {
  /** 1-12 */
  month: number;
  day: number;
  title: string;
  /** holiday 放假 / term 教学安排 / exam 考试 */
  kind: string;
}

export interface CalMonth {
  year: number;
  /** 1-12 */
  month: number;
}

export interface CalTerm {
  key: string;
  label: string;
  /** 第一周周一 */
  startMonday: Date;
  weeks: number;
  months: CalMonth[];
  events: CalEvent[];
  /** 底部四行概述 */
  summary: string[];
}

const DAY_MS = 86400000;

/** 第一学期：2026-08-31（周一）起 20 周 */
const T1_START: Date = new Date(2026, 7, 31);
/** 第二学期：2027-02-22（周一）起 19 周 */
const T2_START: Date = new Date(2027, 1, 22);

export const CAL_TERMS: CalTerm[] = [
  {
    key: 't1',
    label: '第一学期',
    startMonday: T1_START,
    weeks: 20,
    months: [
      { year: 2026, month: 9 },
      { year: 2026, month: 10 },
      { year: 2026, month: 11 },
      { year: 2026, month: 12 },
      { year: 2027, month: 1 }
    ],
    events: [
      { month: 9, day: 1, title: '老生报到', kind: 'term' },
      { month: 9, day: 2, title: '老生报到', kind: 'term' },
      { month: 9, day: 3, title: '正式上课', kind: 'term' },
      { month: 9, day: 13, title: '新生报到', kind: 'term' },
      { month: 9, day: 25, title: '中秋节 · 放假 1 天', kind: 'holiday' },
      { month: 10, day: 1, title: '国庆节 · 放假 3 天', kind: 'holiday' },
      { month: 10, day: 2, title: '国庆假期', kind: 'holiday' },
      { month: 10, day: 3, title: '国庆假期', kind: 'holiday' },
      { month: 1, day: 1, title: '元旦 · 放假 1 天', kind: 'holiday' },
      { month: 1, day: 4, title: '期末考试周开始（19–20 周）', kind: 'exam' },
      { month: 1, day: 11, title: '期末考试周', kind: 'exam' },
      { month: 1, day: 18, title: '寒假开始（至 2 月 20 日）', kind: 'term' }
    ],
    summary: [
      '开学：9 月 1–2 日报到，9 月 3 日正式上课，新生 9 月 13 日报到',
      '节假日：中秋节 1 天 · 国庆节 3 天 · 元旦 1 天',
      '周数：共 20 周，含运动会 0.5 周、期末考试周 2 周',
      '放假：2027 年 1 月 18 日 — 2 月 20 日'
    ]
  },
  {
    key: 't2',
    label: '第二学期',
    startMonday: T2_START,
    weeks: 19,
    months: [
      { year: 2027, month: 2 },
      { year: 2027, month: 3 },
      { year: 2027, month: 4 },
      { year: 2027, month: 5 },
      { year: 2027, month: 6 },
      { year: 2027, month: 7 }
    ],
    events: [
      { month: 2, day: 21, title: '报到', kind: 'term' },
      { month: 2, day: 22, title: '正式上课', kind: 'term' },
      { month: 4, day: 5, title: '清明节 · 放假 1 天', kind: 'holiday' },
      { month: 5, day: 1, title: '劳动节 · 放假 2 天', kind: 'holiday' },
      { month: 5, day: 2, title: '劳动节假期', kind: 'holiday' },
      { month: 6, day: 9, title: '端午节 · 放假 1 天', kind: 'holiday' },
      { month: 6, day: 21, title: '期末考试周开始（18–19 周）', kind: 'exam' },
      { month: 6, day: 28, title: '期末考试周', kind: 'exam' },
      { month: 7, day: 5, title: '暑假开始（至 8 月 29 日）', kind: 'term' }
    ],
    summary: [
      '开学：2 月 21 日报到，2 月 22 日正式上课',
      '节假日：清明节 1 天 · 劳动节 2 天 · 端午节 1 天',
      '周数：共 19 周，含期末考试周 2 周',
      '放假：2027 年 7 月 5 日 — 8 月 29 日'
    ]
  }
];

/** 某个日期在该学期是第几周，0 表示不在学期内 */
export function weekOfTerm(term: CalTerm, date: Date): number {
  const a: Date = new Date(term.startMonday.getFullYear(), term.startMonday.getMonth(), term.startMonday.getDate());
  const b: Date = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const diff: number = Math.round((b.getTime() - a.getTime()) / DAY_MS);
  if (diff < 0) {
    return 0;
  }
  const w: number = Math.floor(diff / 7) + 1;
  return w > term.weeks ? 0 : w;
}

/** 今天落在哪个学期（都不在返回 -1） */
export function termIndexOfToday(): number {
  const now: Date = new Date();
  for (let i = 0; i < CAL_TERMS.length; i++) {
    if (weekOfTerm(CAL_TERMS[i], now) > 0) {
      return i;
    }
  }
  return -1;
}

/** 该月的周数组：每行 7 格，0 表示空位 */
export function monthRows(year: number, month: number): number[][] {
  const firstDay: number = new Date(year, month - 1, 1).getDay();
  const total: number = new Date(year, month, 0).getDate();
  const cells: number[] = [];
  for (let i = 0; i < firstDay; i++) {
    cells.push(0);
  }
  for (let d = 1; d <= total; d++) {
    cells.push(d);
  }
  while (cells.length % 7 !== 0) {
    cells.push(0);
  }
  const rows: number[][] = [];
  for (let i = 0; i < cells.length; i += 7) {
    rows.push(cells.slice(i, i + 7));
  }
  return rows;
}

/** 该月的日程 */
export function eventsOfMonth(term: CalTerm, year: number, month: number): CalEvent[] {
  return term.events.filter((e: CalEvent) => e.month === month);
}

/** 某天是否有日程（返回第一条） */
export function eventOfDay(term: CalTerm, month: number, day: number): CalEvent | null {
  for (let i = 0; i < term.events.length; i++) {
    const e: CalEvent = term.events[i];
    if (e.month === month && e.day === day) {
      return e;
    }
  }
  return null;
}

export function isToday(year: number, month: number, day: number): boolean {
  const now: Date = new Date();
  return now.getFullYear() === year && now.getMonth() + 1 === month && now.getDate() === day;
}

export function kindColor(kind: string): string {
  if (kind === 'holiday') {
    return '#E8892B';
  }
  if (kind === 'exam') {
    return '#7C6CF0';
  }
  return '#3D5AFE';
}