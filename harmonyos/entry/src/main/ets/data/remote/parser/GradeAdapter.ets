import { GradeRecord, termLabelOf } from '../../../domain/model/Grade';

/** 正方成绩接口返回的原始 item（只声明用得到的字段） */
export interface RawGrade {
  kcmc?: string;
  kch?: string;
  cj?: string;
  bfzcj?: string;
  jd?: string;
  xf?: string;
  kclbmc?: string;
  kcxzmc?: string;
  jsxm?: string;
  xnm?: string;
  xqm?: string;
}

interface RawGradeResp {
  items?: RawGrade[];
  totalResult?: number;
}

function num(v: string | undefined): number {
  if (v === undefined || v === null || v.length === 0) {
    return 0;
  }
  const n: number = Number(v);
  return isNaN(n) ? 0 : n;
}

/**
 * 解析正方成绩响应。
 * 注意 cj 可能是文字（"优秀" / "合格" / "缓考"），此时 score=0、scoreText 保留原文。
 */
export class GradeAdapter {
  static parse(body: string): GradeRecord[] {
    let resp: RawGradeResp;
    try {
      resp = JSON.parse(body) as RawGradeResp;
    } catch (e) {
      throw new Error('成绩响应不是有效 JSON');
    }
    if (resp === null || typeof resp !== 'object' || !Array.isArray(resp.items)) {
      throw new Error('成绩响应缺少有效的 items 列表');
    }
    const out: GradeRecord[] = [];
    for (let i = 0; i < resp.items.length; i++) {
      const r: RawGrade = resp.items[i];
      if (r === null || typeof r !== 'object' || typeof r.kcmc !== 'string') { throw new Error('成绩记录格式无效'); }
      const name: string = r.kcmc;
      if (name.trim().length === 0) { throw new Error('成绩记录缺少课程名称'); }
      const scoreText: string = r.cj === undefined ? '' : r.cj;
      const scoreNum: number = num(r.bfzcj !== undefined && r.bfzcj.length > 0 ? r.bfzcj : r.cj);
      const xnm: number = num(r.xnm);
      const xqm: number = num(r.xqm);
      const g: GradeRecord = {
        courseName: name,
        courseNo: r.kch === undefined ? '' : r.kch,
        score: scoreNum,
        scoreText: scoreText.length > 0 ? scoreText : (scoreNum > 0 ? scoreNum.toString() : '—'),
        gpa: num(r.jd),
        credit: num(r.xf),
        category: r.kclbmc === undefined ? '' : r.kclbmc,
        nature: r.kcxzmc === undefined ? '' : r.kcxzmc,
        teacher: r.jsxm === undefined ? '' : r.jsxm,
        xnm: xnm,
        xqm: xqm,
        termLabel: termLabelOf(xnm, xqm)
      };
      out.push(g);
    }
    return out;
  }
}
