/** 一条成绩记录（来自正方 cjcx_cxXsgrcj 的 items[]） */
export interface GradeRecord {
  courseName: string;
  courseNo: string;
  score: number;      // 成绩（百分制；非数字成绩记 0 并用 scoreText 展示）
  scoreText: string;  // 原始成绩文本，如 "优秀" "合格"
  gpa: number;        // 绩点
  credit: number;     // 学分
  category: string;   // 课程类别：专业课 / 公共课 / 通识教育课…
  nature: string;     // 修读性质：必修课 / 限选课 / 通识选修课
  teacher: string;
  xnm: number;        // 学年，如 2025
  xqm: number;        // 学期码：3=第一学期 12=第二学期 16=第三学期
  termLabel: string;  // "2025-2026 第2学期"
}

/** 一个学期的成绩集合 */
export interface TermGrades {
  xnm: number;
  xqm: number;
  label: string;
  items: GradeRecord[];
}

/** 汇总统计 */
export interface GradeSummary {
  count: number;
  credits: number;
  weightedScore: number;
  weightedGpa: number;
  failed: number;
  best: number;
}

/** 学期码转中文 */
export function termName(xqm: number): string {
  if (xqm === 3) {
    return '第1学期';
  }
  if (xqm === 12) {
    return '第2学期';
  }
  if (xqm === 16) {
    return '第3学期';
  }
  return `第${xqm}学期`;
}

/** "2025-2026 第2学期" */
export function termLabelOf(xnm: number, xqm: number): string {
  return `${xnm}-${xnm + 1} ${termName(xqm)}`;
}

/** 汇总：加权平均分 / 加权绩点 / 总学分 / 不及格门数 */
export function summarize(items: GradeRecord[]): GradeSummary {
  let credits: number = 0;
  let scoreSum: number = 0;
  let gpaSum: number = 0;
  let failed: number = 0;
  let best: number = 0;
  for (let i = 0; i < items.length; i++) {
    const g: GradeRecord = items[i];
    const c: number = g.credit > 0 ? g.credit : 0;
    credits += c;
    scoreSum += g.score * c;
    gpaSum += g.gpa * c;
    if (g.score > 0 && g.score < 60) {
      failed++;
    }
    if (g.score > best) {
      best = g.score;
    }
  }
  const s: GradeSummary = {
    count: items.length,
    credits: Math.round(credits * 100) / 100,
    weightedScore: credits > 0 ? Math.round(scoreSum / credits * 10) / 10 : 0,
    weightedGpa: credits > 0 ? Math.round(gpaSum / credits * 100) / 100 : 0,
    failed: failed,
    best: best
  };
  return s;
}

/** 成绩等级配色：0=优 1=良 2=中 3=及格 4=不及格 5=非百分制 */
export function scoreLevel(score: number, hasScore: boolean): number {
  if (!hasScore) {
    return 5;
  }
  if (score >= 90) {
    return 0;
  }
  if (score >= 80) {
    return 1;
  }
  if (score >= 70) {
    return 2;
  }
  if (score >= 60) {
    return 3;
  }
  return 4;
}