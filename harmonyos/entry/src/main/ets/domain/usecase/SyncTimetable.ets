import { CourseRepository } from '../repository/CourseRepository';
import { AccountScope } from '../../common/util/AccountScope';
import { FetchOutcome, QrProgress, QrTicket, StudentInfo, TimetableSource }
  from '../service/TimetableSource';

export interface SyncResult {
  ok: boolean;
  message: string;
  count: number;
  student: StudentInfo;
  semesterLabel: string;
  /**
   * 非空 = 教务要人机验证，这次没有导入。属于「等待用户输入」，不是错误。
   * 界面拿到它就弹验证码窗，填完调 SyncTimetable.resumeCaptcha 继续。
   */
  captcha: ArrayBuffer;
}

/**
 * 同步课表用例：登录 → 取数 → 落库（整表替换）。
 * 依赖两个抽象（TimetableSource / CourseRepository），不碰 UI、不碰 HTTP 细节。
 */
export class SyncTimetable {
  private source: TimetableSource;
  private repo: CourseRepository;

  constructor(source: TimetableSource, repo: CourseRepository) {
    this.source = source;
    this.repo = repo;
  }

  async run(user: string, pwd: string, tableId: string): Promise<SyncResult> {
    const token: number = AccountScope.token();
    const empty: StudentInfo = { name: '', studentId: user, clazz: '', major: '' };
    try {
      const outcome: FetchOutcome = await this.source.fetch(user, pwd);
      if (outcome.captcha.byteLength > 0) {
        // 需要人机验证：不落库，原样把挑战交回界面
        return {
          ok: false,
          message: outcome.message,
          count: 0,
          student: empty,
          semesterLabel: '',
          captcha: outcome.captcha
        };
      }
      return await this.commit(outcome, tableId, token);
    } catch (e) {
      const msg: string = e instanceof Error ? e.message : JSON.stringify(e);
      return { ok: false, message: msg, count: 0, student: empty, semesterLabel: '', captcha: new ArrayBuffer(0) };
    }
  }

  /** 人机验证填完之后，用同一个数据源会话继续跑完剩下的流程 */
  async resumeCaptcha(code: string, user: string, tableId: string): Promise<SyncResult> {
    const token: number = AccountScope.token();
    const empty: StudentInfo = { name: '', studentId: user, clazz: '', major: '' };
    try {
      const outcome: FetchOutcome = await this.source.resumeCaptcha(code);
      if (outcome.captcha.byteLength > 0) {
        return {
          ok: false,
          message: outcome.message,
          count: 0,
          student: empty,
          semesterLabel: '',
          captcha: outcome.captcha
        };
      }
      return await this.commit(outcome, tableId, token);
    } catch (e) {
      const msg: string = e instanceof Error ? e.message : JSON.stringify(e);
      return { ok: false, message: msg, count: 0, student: empty, semesterLabel: '', captcha: new ArrayBuffer(0) };
    }
  }

  /** 换一张验证码图（用户在浮层里点「看不清」时用） */
  async refreshCaptcha(): Promise<ArrayBuffer> {
    return await this.source.refreshCaptcha();
  }

  /** 企业微信扫码登录：取二维码 */
  async qrStart(): Promise<QrTicket> {
    return await this.source.qrStart();
  }

  /** 企业微信扫码登录：轮询状态 */
  async qrPoll(): Promise<QrProgress> {
    return await this.source.qrPoll();
  }

  /** 企业微信扫码确认后：取课表并落库 */
  async qrLogin(code: string, tableId: string): Promise<SyncResult> {
    const token: number = AccountScope.token();
    const empty: StudentInfo = { name: '', studentId: '', clazz: '', major: '' };
    try {
      const outcome: FetchOutcome = await this.source.qrLogin(code);
      if (outcome.captcha.byteLength > 0) {
        return {
          ok: false,
          message: outcome.message,
          count: 0,
          student: empty,
          semesterLabel: '',
          captcha: outcome.captcha
        };
      }
      return await this.commit(outcome, tableId, token);
    } catch (e) {
      const msg: string = e instanceof Error ? e.message : JSON.stringify(e);
      return { ok: false, message: msg, count: 0, student: empty, semesterLabel: '', captcha: new ArrayBuffer(0) };
    }
  }

  /** 数据到手了：整表替换 + 组装结果 */
  private async commit(outcome: FetchOutcome, tableId: string, token: number): Promise<SyncResult> {
    if (!AccountScope.valid(token)) { throw new Error('账号状态已变更，请重新操作'); }
    await this.repo.replaceAll(tableId, outcome.courses, true, token);
    if (!AccountScope.valid(token)) { throw new Error('账号状态已变更，请重新操作'); }
    return {
      ok: true,
      message: `已导入 ${outcome.courses.length} 条课程`,
      count: outcome.courses.length,
      student: outcome.student,
      semesterLabel: outcome.semesterLabel,
      captcha: new ArrayBuffer(0)
    };
  }
}
