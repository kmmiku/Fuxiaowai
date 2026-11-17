import { ExamRecord, examClockLabel, examDateLabel, parseExamTime } from '../../../domain/model/Exam';

/** 正方考试查询接口返回的原始 item（只声明用得到的字段） */
interface RawExam {
  kcmc?: string;
  kch?: string;
  jsxm?: string;
  xm?: string;
  kssj?: string;
  cdmc?: string;
  zwh?: string;
  ksfs?: string;
  ksmc?: string;
  xnm?: string;
  xqm?: string;
}

interface RawExamResp {
  items?: RawExam[];
  totalResult?: number;
}

function str(v: string | undefined): string {
  return v === undefined || v === null ? '' : v;
}

/**
 * 解析正方「考试安排」响应。
 * items 里字段随版本略有差异，这里只认最稳的几个：
 * kcmc 课程名 / kssj 考试时间 / cdmc 考场 / zwh 座位号 / ksfs 考试方式
 */
export class ExamAdapter {
  static parse(body: string): ExamRecord[] {
    let resp: RawExamResp;
    try {
      resp = JSON.parse(body) as RawExamResp;
    } catch (e) {
      return [];
    }
    if (resp.items === undefined || resp.items === null) {
      return [];
    }
    const out: ExamRecord[] = [];
    for (let i = 0; i < resp.items.length; i++) {
      const r: RawExam = resp.items[i];
      const course: string = str(r.kcmc);
      if (course.length === 0) {
        continue;
      }
      const timeText: string = str(r.kssj);
      const startAt: number = parseExamTime(timeText);
      const e: ExamRecord = {
        id: `${course}_${timeText}_${i}`,
        course: course,
        courseCode: str(r.kch),
        teacher: str(r.jsxm) || str(r.xm),
        timeText: timeText,
        startAt: startAt,
        dateLabel: examDateLabel(timeText, startAt),
        clockLabel: examClockLabel(timeText),
        room: str(r.cdmc),
        seat: str(r.zwh),
        method: str(r.ksfs).length > 0 ? str(r.ksfs) : str(r.ksmc)
      };
      out.push(e);
    }
    // 按开考时间升序；解析失败（0）的排最后
    out.sort((a: ExamRecord, b: ExamRecord) => {
      const x: number = a.startAt === 0 ? Number.MAX_SAFE_INTEGER : a.startAt;
      const y: number = b.startAt === 0 ? Number.MAX_SAFE_INTEGER : b.startAt;
      return x - y;
    });
    return out;
  }
}