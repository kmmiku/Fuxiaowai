import hilog from '@ohos.hilog';
import { FetchOutcome, QrProgress, QrTicket, StudentInfo, TimetableSource }
  from '../../domain/service/TimetableSource';
import { LoginResult, ZhengfangAuth } from './auth/ZhengfangAuth';
import { Semester } from './auth/RsaPublicKey';
import { SessionStore } from '../local/SessionStore';
import { parseTimetable, ParseResult } from './parser/FuwaiAdapter';
import { AccountScope } from '../../common/util/AccountScope';
import { SchoolTraffic } from '../../common/util/SchoolTraffic';
import { resolveSchoolTerm } from '../local/TimetableStateStore';
import { Db } from '../local/Db';

const DOMAIN: number = 0x0032;
const TAG: string = 'FuxiaowaiSource';

/**
 * 福州外语外贸学院 · 正方 jwglxt 数据源实现。
 * 只做"取数据"这一件事：登录 → 拉课表 → 解析 → 返回领域模型。
 *
 * 验证码：教学综合平台对异地/多次登录的账号会要求人机验证。
 * 这时 fetch 不抛错，而是回一个带 captcha 的空结果；界面弹窗拿到验证码后
 * 调 resumeCaptcha(code)，复用同一个 ZhengfangAuth（票据和公钥都在里面）继续登录。
 */
export class FuwaiTimetableSource implements TimetableSource {
  private auth: ZhengfangAuth | null = null;
  private pendingUser: string = '';
  private pendingPwd: string = '';

  async fetch(user: string, pwd: string): Promise<FetchOutcome> {
    const token: number = AccountScope.token();
    return SchoolTraffic.run(async () => {
      if (!AccountScope.valid(token)) { throw new Error('账号状态已变更'); }
      try { return await this.fetchNow(user, pwd, token); }
      catch (e) { this.clear(); throw new Error((e as Error).message || '课表同步失败'); }
    });
  }

  private async fetchNow(user: string, pwd: string, token: number): Promise<FetchOutcome> {
    const auth: ZhengfangAuth = new ZhengfangAuth();
    this.auth = auth;
    this.pendingUser = user;
    this.pendingPwd = pwd;
    const login: LoginResult = await auth.login(user, pwd);
    if (login.captcha.byteLength > 0) {
      hilog.info(DOMAIN, TAG, 'login needs captcha (%{public}s)', login.message);
      return FuwaiTimetableSource.challenge(user, login.message, login.captcha);
    }
    if (!login.ok) {
      this.clear();
      throw new Error(login.message);
    }
    const outcome: FetchOutcome = await this.collect(auth, user, login.semester, token);
    this.clear();
    return outcome;
  }

  async resumeCaptcha(code: string): Promise<FetchOutcome> {
    const token: number = AccountScope.token();
    return SchoolTraffic.run(async () => {
      if (!AccountScope.valid(token)) { throw new Error('账号状态已变更'); }
      try { return await this.resumeNow(code, token); }
      catch (e) { this.clear(); throw new Error((e as Error).message || '验证码提交失败'); }
    });
  }

  private async resumeNow(code: string, token: number): Promise<FetchOutcome> {
    const auth: ZhengfangAuth | null = this.auth;
    if (auth === null) {
      throw new Error('验证码已过期，请重新点一次登录');
    }
    const login: LoginResult = await auth.submitCaptcha(this.pendingUser, this.pendingPwd, code);
    if (login.captcha.byteLength > 0) {
      // 又错了一次：换张图继续问，不要清会话
      return FuwaiTimetableSource.challenge(this.pendingUser, login.message, login.captcha);
    }
    if (!login.ok) {
      this.clear();
      throw new Error(login.message);
    }
    const outcome: FetchOutcome = await this.collect(auth, this.pendingUser, login.semester, token);
    this.clear();
    return outcome;
  }

  /** 换一张验证码图 */
  async refreshCaptcha(): Promise<ArrayBuffer> {
    const auth: ZhengfangAuth | null = this.auth;
    if (auth === null) {
      return new ArrayBuffer(0);
    }
    return await auth.refreshCaptcha();
  }

  /** 取一张企业微信扫码登录的二维码 */
  async qrStart(): Promise<QrTicket> {
    if (this.auth === null) {
      this.auth = new ZhengfangAuth();
    }
    return await this.auth.qrStart();
  }

  /** 轮询扫码状态（同一张码，auth 会话不能换） */
  async qrPoll(): Promise<QrProgress> {
    const auth: ZhengfangAuth | null = this.auth;
    if (auth === null) {
      return { state: 'error', code: '', message: '二维码已失效，请刷新' };
    }
    return await auth.qrPoll();
  }

  /** 扫码确认后：换登录态并直接取课表 */
  async qrLogin(code: string): Promise<FetchOutcome> {
    const token: number = AccountScope.token();
    return SchoolTraffic.run(async () => {
      if (!AccountScope.valid(token)) { throw new Error('账号状态已变更'); }
      try { return await this.qrNow(code, token); }
      catch (e) { this.clear(); throw new Error((e as Error).message || '扫码同步失败'); }
    });
  }

  private async qrNow(code: string, token: number): Promise<FetchOutcome> {
    const auth: ZhengfangAuth | null = this.auth;
    if (auth === null) {
      throw new Error('二维码会话已失效，请刷新后重试');
    }
    const login: LoginResult = await auth.loginWithQr(code);
    if (!login.ok) {
      this.clear();
      throw new Error(login.message);
    }
    const outcome: FetchOutcome = await this.collect(auth, '', login.semester, token);
    this.clear();
    return outcome;
  }

  /** 登录已通过：拉课表 + 解析 */
  private async collect(auth: ZhengfangAuth, user: string, semester: Semester, token: number): Promise<FetchOutcome> {
    if (!AccountScope.valid(token)) { throw new Error('账号状态已变更'); }
    const json: string = await auth.fetchTimetable(user, semester);
    if (!AccountScope.valid(token)) { throw new Error('账号状态已变更'); }
    const parsed: ParseResult = parseTimetable(json);
    if (parsed.courses.length === 0) {
      throw new Error('教务返回的课表为空，可能本学期还没排课');
    }
    if (resolveSchoolTerm(semester.label) === null) {
      throw new Error('该学期的开学日期尚未配置，已保留原课表');
    }
    const student: StudentInfo = {
      name: parsed.student.XM ?? '',
      studentId: parsed.student.XH ?? user,
      clazz: parsed.student.BJMC ?? '',
      major: parsed.student.ZYMC ?? ''
    };
    hilog.info(DOMAIN, TAG, 'parsed %{public}d courses, dropped %{public}d',
      parsed.courses.length, parsed.dropped);
    // 会话留一份：扫码登录没有密码，成绩/考试页只能靠这条 Cookie 继续调接口
    const sid: string = student.studentId;
    if (user.length > 0 && sid !== user) { throw new Error('教务返回的账号与当前账号不一致'); }
    await SessionStore.bindUser(sid);
    if (!AccountScope.valid(token)) { throw new Error('账号状态已变更'); }
    AccountScope.adopt(sid);
    await SessionStore.saveJw(auth.cookieHeader());
    if (!AccountScope.valid(token)) { throw new Error('账号状态已变更'); }
    Db.selectAccount(sid);
    return {
      courses: parsed.courses,
      student: student,
      semesterLabel: semester.label,
      dropped: parsed.dropped,
      captcha: new ArrayBuffer(0),
      message: ''
    };
  }

  private clear(): void {
    this.auth = null;
    this.pendingPwd = '';
  }

  private static challenge(user: string, message: string, captcha: ArrayBuffer): FetchOutcome {
    const student: StudentInfo = {
      name: '',
      studentId: user,
      clazz: '',
      major: ''
    };
    return {
      courses: [],
      student: student,
      semesterLabel: '',
      dropped: 0,
      captcha: captcha,
      message: message
    };
  }
}
