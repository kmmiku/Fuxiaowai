import { colorIndexOf, Course, parseWeeks } from '../../../domain/model/Course';

/**
 * 正方教务课表响应 → 领域模型。
 *
 * 一条 kbList 记录 = 一个"时间段"的排课，同一门课不同周次/教室会拆成多条，
 * 所以这里按 (课程号 + 星期 + 起止节 + 周次集合) 去重，保留每条独立排课。
 */

export interface RawCourse {
  kch?: string;
  kcmc?: string;
  xm?: string;
  cdmc?: string;
  xqmc?: string;
  xqj?: string;
  jcs?: string;
  zcd?: string;
  jxb_id?: string;
  kclbmc?: string;
  kcxz?: string;
}

export interface RawTimetable {
  kbList?: RawCourse[];
  xsxx?: RawStudent;
}

export interface RawStudent {
  XM?: string;
  XH?: string;
  BJMC?: string;
  ZYMC?: string;
  XNMC?: string;
  XQMMC?: string;
}

export interface ParseResult {
  courses: Course[];
  student: RawStudent;
  dropped: number;
}

/** "1-2" / "1-8" / "9-11" / "3" / "1-2节" → [起, 止] */
export function parsePeriods(text: string): number[] {
  const clean: string = text.replace('节', '').trim();
  const parts: string[] = clean.split('-');
  const start: number = parseInt(parts[0], 10);
  if (isNaN(start)) {
    return [];
  }
  const end: number = parts.length > 1 ? parseInt(parts[1], 10) : start;
  if (isNaN(end)) {
    return [start, start];
  }
  return [start, end];
}

export function parseTimetable(json: string): ParseResult {
  const data: RawTimetable = JSON.parse(json) as RawTimetable;
  const list: RawCourse[] = data.kbList ?? [];
  const out: Course[] = [];
  const seen: Set<string> = new Set<string>();
  let dropped: number = 0;

  list.forEach((raw: RawCourse) => {
    const name: string = (raw.kcmc ?? '').trim();
    const weekday: number = parseInt(raw.xqj ?? '', 10);
    const span: number[] = parsePeriods(raw.jcs ?? '');
    const weeks: number[] = parseWeeks(raw.zcd ?? '');
    if (name.length === 0 || isNaN(weekday) || span.length < 2 || weeks.length === 0) {
      dropped++;
      return;
    }
    const id: string =
      `${raw.kch ?? name}_${weekday}_${span[0]}_${span[1]}_${weeks.join('.')}`;
    if (seen.has(id)) {
      return;
    }
    seen.add(id);
    out.push({
      id: id,
      name: name,
      teacher: (raw.xm ?? '').trim(),
      room: (raw.cdmc ?? '').trim(),
      campus: (raw.xqmc ?? '').trim(),
      weekday: weekday,
      startPeriod: span[0],
      endPeriod: span[1],
      weeks: weeks,
      colorIndex: colorIndexOf(name)
    });
  });

  out.sort((a: Course, b: Course) => {
    if (a.weekday !== b.weekday) {
      return a.weekday - b.weekday;
    }
    return a.startPeriod - b.startPeriod;
  });
  return { courses: out, student: data.xsxx ?? {} as RawStudent, dropped: dropped };
}