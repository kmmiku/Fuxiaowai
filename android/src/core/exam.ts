import type { ExamRecord } from './types';

/* ---------------- 时间解析 ---------------- */

const TIME_RE = /(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:[^0-9]{0,3}(\d{1,2}):(\d{2}))?/;

/** "2027-01-12 09:00~11:00" → 时间戳；解析失败返回 0 */
export function parseExamTime(text: string): number {
  const m = TIME_RE.exec(text ?? '');
  if (!m) return 0;
  const y = parseInt(m[1], 10);
  const mo = parseInt(m[2], 10);
  const d = parseInt(m[3], 10);
  const hh = m[4] ? parseInt(m[4], 10) : 0;
  const mi = m[5] ? parseInt(m[5], 10) : 0;
  const t = new Date(y, mo - 1, d, hh, mi, 0, 0).getTime();
  return isNaN(t) ? 0 : t;
}

const WEEK = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

function pad2(n: number): string {
  return n < 10 ? `0${n}` : String(n);
}

/** → "1月12日 周一" */
export function examDateLabel(text: string, ts: number): string {
  if (ts > 0) {
    const d = new Date(ts);
    return `${d.getMonth() + 1}月${d.getDate()}日 ${WEEK[d.getDay()]}`;
  }
  const m = TIME_RE.exec(text ?? '');
  if (!m) return '时间待定';
  const d = new Date(parseInt(m[1], 10), parseInt(m[2], 10) - 1, parseInt(m[3], 10));
  return `${d.getMonth() + 1}月${d.getDate()}日 ${WEEK[d.getDay()]}`;
}

/** → "09:00–11:00"；只有开始时间时返回 "09:00" */
export function examClockLabel(text: string): string {
  const s = (text ?? '').replace(/[~～]/g, '–');
  const clocks = s.match(/\d{1,2}:\d{2}/g);
  if (!clocks || clocks.length === 0) return '';
  const norm = clocks.slice(0, 2).map((c) => {
    const [h, m] = c.split(':');
    return `${pad2(parseInt(h, 10))}:${m}`;
  });
  return norm.join('–');
}

/** 距考试还有几天（按自然日算，避免晚上看第二天考试算成 1 天） */
export function daysUntil(ts: number, now: number = Date.now()): number {
  if (ts <= 0) return -1;
  const a = new Date(now);
  const b = new Date(ts);
  const dayA = new Date(a.getFullYear(), a.getMonth(), a.getDate()).getTime();
  const dayB = new Date(b.getFullYear(), b.getMonth(), b.getDate()).getTime();
  return Math.round((dayB - dayA) / 86400000);
}

/* ---------------- 解析 ---------------- */

interface RawExam {
  kcmc?: string;
  kch?: string;
  kssj?: string;
  cdmc?: string;
  zwh?: string;
  ksfs?: string;
  ksmc?: string;
  xnm?: string;
  xqm?: string;
}

export function parseExams(json: string): ExamRecord[] {
  const data = JSON.parse(json) as { items?: RawExam[] };
  const items = data.items ?? [];
  const out: ExamRecord[] = items.map((r, i) => {
    const timeText = (r.kssj ?? '').trim();
    const startAt = parseExamTime(timeText);
    return {
      id: `${r.kch ?? 'e'}_${i}`,
      course: (r.kcmc ?? '').trim() || '未命名考试',
      courseCode: (r.kch ?? '').trim(),
      timeText,
      startAt,
      dateLabel: examDateLabel(timeText, startAt),
      clockLabel: examClockLabel(timeText) || '时间待定',
      room: (r.cdmc ?? '').trim(),
      seat: (r.zwh ?? '').trim(),
      method: (r.ksfs ?? '').trim()
    };
  });
  out.sort((a, b) => {
    if (a.startAt === 0 && b.startAt === 0) return 0;
    if (a.startAt === 0) return 1;
    if (b.startAt === 0) return -1;
    return a.startAt - b.startAt;
  });
  return out;
}

/* ---------------- 示例数据 ---------------- */

/** 学期内没有考试时用课表里的真实课名造几条，保证视觉可验证 */
export function mockExams(courseNames: string[]): ExamRecord[] {
  const picks = courseNames.length > 0
    ? courseNames.slice(0, 4)
    : ['Hadoop开发技术', '机器学习', '高级数据库', '大学英语（三）'];
  const rooms = ['实3603', '实3303', '教4203', '教3202'];
  const seats = ['07', '21', '13', '32'];
  const slots = ['09:00~11:00', '14:30~16:30', '09:00~11:00', '14:30~16:30'];
  const days = [11, 13, 15, 18];
  return picks.map((name, i) => {
    const timeText = `2027-01-${days[i]} ${slots[i]}`;
    const startAt = parseExamTime(timeText);
    return {
      id: `mock_${i}`,
      course: name,
      courseCode: `MOCK${i + 1}`,
      timeText,
      startAt,
      dateLabel: examDateLabel(timeText, startAt),
      clockLabel: examClockLabel(timeText),
      room: rooms[i],
      seat: seats[i],
      method: i % 2 === 0 ? '闭卷' : '开卷'
    };
  });
}