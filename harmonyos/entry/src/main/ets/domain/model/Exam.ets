/** 一场考试 */
export interface ExamRecord {
  /** 稳定 id：课程名+时间，用于 ForEach key */
  id: string;
  /** 课程名 */
  course: string;
  /** 课程号，可能为空 */
  courseCode: string;
  /** 原始时间文本，如 2026-01-12 09:00~11:00 */
  timeText: string;
  /** 解析出的开考时间戳（毫秒）；解析失败为 0 */
  startAt: number;
  /** 考试日期文本，如 1月12日 周一 */
  dateLabel: string;
  /** 时刻文本，如 09:00–11:00 */
  clockLabel: string;
  /** 考场 */
  room: string;
  /** 座位号 */
  seat: string;
  /** 考试方式：闭卷/开卷/机考… */
  method: string;
}

/** 把正方返回的时间文本解析成时间戳，失败返回 0 */
export function parseExamTime(text: string): number {
  // 2026-01-12 09:00~11:00 / 2026-01-12(09:00-11:00) / 2026-01-12
  const re: RegExp = new RegExp('(\\d{4})[-/](\\d{1,2})[-/](\\d{1,2})(?:[^0-9]{0,3}(\\d{1,2}):(\\d{2}))?');
  const m: RegExpExecArray | null = re.exec(text);
  if (m === null) {
    return 0;
  }
  const y: number = Number(m[1]);
  const mo: number = Number(m[2]);
  const d: number = Number(m[3]);
  const h: number = m[4] === undefined ? 8 : Number(m[4]);
  const mi: number = m[5] === undefined ? 0 : Number(m[5]);
  const dt: Date = new Date(y, mo - 1, d, h, mi, 0, 0);
  const ts: number = dt.getTime();
  return isNaN(ts) ? 0 : ts;
}

const WEEK_CN: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

/** 2026-01-12 09:00~11:00 → 1月12日 周一 */
export function examDateLabel(text: string, ts: number): string {
  if (ts <= 0) {
    return text.length > 0 ? text : '时间待定';
  }
  const d: Date = new Date(ts);
  return `${d.getMonth() + 1}月${d.getDate()}日 ${WEEK_CN[d.getDay()]}`;
}

/** 2026-01-12 09:00~11:00 → 09:00–11:00；取不到就退回原文里冒号后面那段 */
export function examClockLabel(text: string): string {
  const re: RegExp = new RegExp('(\\d{1,2}:\\d{2})\\s*[~\\-－至]\\s*(\\d{1,2}:\\d{2})');
  const m: RegExpExecArray | null = re.exec(text);
  if (m !== null) {
    return `${pad2(m[1])}–${pad2(m[2])}`;
  }
  const one: RegExp = new RegExp('(\\d{1,2}:\\d{2})');
  const m2: RegExpExecArray | null = one.exec(text);
  return m2 === null ? '' : pad2(m2[1]);
}

function pad2(t: string): string {
  const parts: string[] = t.split(':');
  if (parts.length !== 2) {
    return t;
  }
  const h: string = parts[0].length === 1 ? '0' + parts[0] : parts[0];
  return `${h}:${parts[1]}`;
}

/** 距开考还有几天：0=今天，1=明天，-1=已过 */
export function daysUntil(ts: number, now: number): number {
  if (ts <= 0) {
    return 0;
  }
  const a: Date = new Date(ts);
  const b: Date = new Date(now);
  const da: number = new Date(a.getFullYear(), a.getMonth(), a.getDate()).getTime();
  const db: number = new Date(b.getFullYear(), b.getMonth(), b.getDate()).getTime();
  return Math.round((da - db) / 86400000);
}