/** 领域模型：课程 / 节次 / 学期 / 课表 / 成绩 / 考试 */
/** 与鸿蒙版 entry/src/main/ets/domain/model/Course.ets 一一对应 */

export interface Course {
  id: string;
  name: string;
  teacher: string;
  room: string;
  campus: string;
  weekday: number; // 1..7
  startPeriod: number; // 1..12
  endPeriod: number;
  weeks: number[]; // [1..20]
  colorIndex: number;
  /** Explicit user choice, kept separately from automatic colors. */
  colorOverride?: boolean;
  /** One-time automatic palette assignment, stored with the course. */
  autoColorIndex?: number;
}

export interface Period {
  index: number;
  start: string;
  end: string;
}

export interface Term {
  id: string; // 2026-2027-1
  label: string; // 2026-2027学年 第1学期
  startDate: string; // yyyy-MM-dd（首个周一）
  totalWeeks: number;
}

export interface TableOption {
  id: string;
  name: string;
}

export interface AppSettings {
  showWeekend: boolean;
  /** 是否显示「非本周」的浅色幽灵块：只显示还没上完的课，且同段只留最近的一门 */
  showGhost: boolean;
  /** 0=紧凑 1=标准 2=宽松，仅用于把老数据迁移成 cellHeight */
  density: number;
  /** 课表格子高度（vp），由课表设置里的滑块实时调 */
  cellHeight: number;
  /** 课程块占列宽的比例（0.65–1），越小学左右两侧留白越多 */
  dark: boolean;
  /** 主题占位，目前只有 'default' */
  theme: string;
  /** 上课提醒提前分钟数，0 表示不提醒 */
  remindBefore: number;
  /** 导出到系统日历时，日程是否也带提前提醒 */
  calendarRemind: boolean;
}

export interface Profile {
  name: string;
  studentId: string;
  clazz: string;
  major: string;
  grade: string;
}

export interface Credential {
  user: string;
  pwd: string;
  /** 记住密码：勾选才把密码留在本机，用于定期更新课表 */
  remember: boolean;
  lastSyncAt: number;
  /** 每天首次打开 App 时自动同步一次课表 */
  autoUpdate: boolean;
  /** 上次自动更新课表的自然日（yyyy-MM-dd），空串表示从未 */
  autoDay: string;
}

export interface GradeRecord {
  id: string;
  course: string;
  credit: number;
  score: number;
  gpa: number;
  term: string;
  nature: string;
}

export interface ExamRecord {
  id: string;
  course: string;
  courseCode: string;
  timeText: string;
  startAt: number;
  dateLabel: string;
  clockLabel: string;
  room: string;
  seat: string;
  method: string;
}

export interface FeedbackItem {
  id: string;
  text: string;
  contact: string;
  images: string[];
  createdAt: number;
  sent: boolean;
  retryAt?: number;
}

/* ---------------- 纯函数 ---------------- */

/** 第 week 周是否上这门课 */
export function isInWeek(c: Course, week: number): boolean {
  return c.weeks.indexOf(week) >= 0;
}

/** 按周过滤并按星期分组（1..7） */
export function groupByWeekday(courses: Course[], week: number): Map<number, Course[]> {
  const map = new Map<number, Course[]>();
  for (let d = 1; d <= 7; d++) map.set(d, []);
  for (const c of courses) {
    if (isInWeek(c, week)) {
      const list = map.get(c.weekday);
      if (list) list.push(c);
    }
  }
  return map;
}

/** 课程名 hash → 稳定配色下标（同名同色）。FNV-1a 变体，避免中文课名碰撞 */
export function colorIndexOf(name: string): number {
  let h = 2166136261;
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
  const set = new Set<number>();
  if (!text) return [];
  for (const raw of text.split(',')) {
    let seg = raw.trim();
    if (!seg) continue;
    const onlyOdd = seg.indexOf('单') >= 0;
    const onlyEven = seg.indexOf('双') >= 0;
    seg = seg.replace(/[第周()（）单双\s]/g, '');
    if (!seg) continue;
    const parts = seg.split('-');
    if (parts.length === 2) {
      const s = parseInt(parts[0], 10);
      const e = parseInt(parts[1], 10);
      if (isNaN(s) || isNaN(e)) continue;
      for (let w = s; w <= e; w++) {
        if (onlyOdd && w % 2 === 0) continue;
        if (onlyEven && w % 2 === 1) continue;
        set.add(w);
      }
    } else if (parts.length === 1) {
      const w = parseInt(parts[0], 10);
      if (!isNaN(w)) set.add(w);
    }
  }
  return Array.from(set).sort((a, b) => a - b);
}

/** 默认节次时间（可在「上课时间」里改）；第 9 节起为晚课 */
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