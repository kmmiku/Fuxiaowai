import { PrivateLog as hilog } from '../../../common/util/PrivateLog';
import { FormField, HttpClient, HttpResult } from '../../../network/http/HttpClient';
import { RawHttp, RawResponse } from '../../../network/http/RawHttp';
import { currentSemester, RsaPublicKey, Semester } from './RsaPublicKey';
import { CasOutcome, CasPrep, CasSession } from './CasAuth';
import { CAS_PORTAL_HOST, CasTicket } from './CasTicket';
import { AccountScope } from '../../../common/util/AccountScope';
import systemHilog from '@ohos.hilog';
import { QrExchange, QrProgress, QrTicket, WecomQrLogin } from './WecomQrLogin';
import { RawGrade } from '../parser/GradeAdapter';

interface TimetableEnvelope {
  kbList?: Object[];
}

interface GradePageResponse {
  items: RawGrade[];
  total?: number;
  records?: number;
  currentPage?: number;
}

const DOMAIN: number = 0x0031;
const TAG: string = 'FuxiaowaiAuth';

/** 正方教务固定入口（单校部署，地址写死） */
const BASE: string = 'http://jw.fzfu.edu.cn/jwglxt';
/** jw 的主机名，Cookie 分桶与 WebView 注入都用它 */
const JW_HOST: string = 'jw.fzfu.edu.cn';
const LOGIN_PAGE: string = '/xtgl/login_slogin.html';
const PUBLIC_KEY: string = '/xtgl/login_getPublicKey.html?time=';
const TIMETABLE: string = '/kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151&su=';
const GRADE_QUERY: string = '/cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005';
const EXAM_QUERY: string = '/kwgl/kscx_cxXsksxxIndex.html?doType=query&gnmkdm=N358105';

/** 考试安排页（给内置 WebView 直接打开用，带登录 Cookie） */
export const EXAM_PAGE_URL: string =
  'http://jw.fzfu.edu.cn/jwglxt/kwgl/kscx_cxXsksxxIndex.html?gnmkdm=N358105';
/** 教务站点根，配 Cookie 时用它 */
export const JW_BASE_URL: string = 'http://jw.fzfu.edu.cn';

export interface LoginResult {
  ok: boolean;
  message: string;
  semester: Semester;
  /**
   * 非空 = 统一身份认证要求输入验证码，这里是 JPEG 字节。
   * 此时 ok 一定是 false，调用方弹窗让用户填完再调 submitCaptcha。
   */
  captcha: ArrayBuffer;
}

export interface PublicKeyInfo {
  modulus: string;
  exponent: string;
}

/**
 * 登录入口：0 = 教务登录入口（jwglxt 直登），1 = 教学综合平台入口（portal CAS）。
 * 用户在登录页勾选哪个就走哪条协议，不偷偷换。
 */
export const LOGIN_MODE_JW: number = 0;
export const LOGIN_MODE_PORTAL: number = 1;

let loginMode: number = LOGIN_MODE_JW;

/** 由登录页在提交前设置 */
export function setLoginMode(mode: number): void {
  loginMode = mode === LOGIN_MODE_PORTAL ? LOGIN_MODE_PORTAL : LOGIN_MODE_JW;
}

export function getLoginMode(): number {
  return loginMode;
}

/**
 * 正方 jwglxt 登录（纯 HTTP，不依赖 WebView）：
 *   1. GET 登录页，取 csrftoken（同时拿到 JSESSIONID）
 *   2. GET 公钥接口，拿 modulus / exponent
 *   3. RSA(PKCS#1 v1.5) 加密密码
 *   4. POST 登录；服务端 302 到 index_initMenu 即成功
 * 之后 Cookie 复用即可直接请求课表接口。
 */
export class ZhengfangAuth {
  private client: HttpClient = new HttpClient(BASE);
  /** 教学综合平台登录会话：验证码要跨两次调用，票据和公钥都留在里面 */
  private cas: CasSession | null = null;
  /** 企业微信扫码登录：与登录共用同一个 Cookie 罐，登录态才落在本应用 */
  private qr: WecomQrLogin | null = null;

  private qrClient(): WecomQrLogin {
    if (this.qr === null) {
      this.qr = new WecomQrLogin(this.client);
    }
    return this.qr;
  }

  /** 取一张企业微信扫码登录二维码（PNG 字节） */
  async qrStart(): Promise<QrTicket> {
    return await this.qrClient().start();
  }

  /** 长轮询扫码状态（服务端 20 秒无事件时返回 wait，调用方继续轮） */
  async qrPoll(): Promise<QrProgress> {
    return await this.qrClient().poll();
  }

  /**
   * 扫码确认后收尾：auth_code 交给 CAS 换统一身份认证会话，
   * 再走 afterCas 把 jw 会话换出来。auth_code 里带 App 自己的 Cookie 罐，不用重复输入密码。
   */
  async loginWithQr(code: string): Promise<LoginResult> {
    const semester: Semester = currentSemester(new Date());
    try {
      const ex: QrExchange = await this.qrClient().exchange(code);
      if (!ex.ok) {
        return ZhengfangAuth.fail(
          ex.message.length > 0 ? ex.message : '扫码登录未通过，请刷新二维码再试一次', semester);
      }
      return await this.afterCas(
        { ok: true, message: '', captcha: new ArrayBuffer(0) }, semester);
    } catch (e) {
      return ZhengfangAuth.fail(
        '扫码登录异常：' + (e instanceof Error ? e.message : JSON.stringify(e)), semester);
    }
  }

  /**
   * 登录。走哪条路由登录页的圆形单选决定：
   *   - 教务登录入口：jwglxt 表单直登（快，只查教务自己的账号）
   *   - 教学综合平台入口：portal CAS 统一身份认证，拿到 portal 会话后再换 jw 会话
   * 只有选的那条失败、且另一条能通时才回落（并把回落原因写进 message）。
   * 教学综合平台要验证码时直接返回挑战，不回落——回落会把用户带进死路。
   */
  async login(user: string, pwd: string): Promise<LoginResult> {
    const semester: Semester = currentSemester(new Date());
    if (loginMode === LOGIN_MODE_PORTAL) {
      const portal: LoginResult = await this.loginViaPortal(user, pwd, semester);
      if (portal.ok || portal.captcha.byteLength > 0) {
        return portal;
      }
      // 统一身份认证明确说密码不对：不要再回落。回落进的是教务账号，会把
      // 「门户密码不对」掩盖成教务侧的另一条报错，用户根本不知道该改哪个密码。
      if (portal.message.indexOf('账号或密码不正确') >= 0) {
        return ZhengfangAuth.fail(
          '账号或密码不正确（统一身份认证的密码和教务系统的不一定相同）', semester);
      }
      hilog.info(DOMAIN, TAG, 'portal failed (%{public}s), try direct', portal.message);
      const direct: LoginResult = await this.loginDirect(user, pwd, semester);
      return direct.ok ? direct : ZhengfangAuth.fail(portal.message, semester);
    }

    const direct: LoginResult = await this.loginDirect(user, pwd, semester);
    if (direct.ok) {
      return direct;
    }
    hilog.info(DOMAIN, TAG, 'direct failed (%{public}s), try cas', direct.message);
    try {
      const cas: LoginResult = await this.loginViaPortal(user, pwd, semester);
      hilog.info(DOMAIN, TAG, 'cas result ok=%{public}s msg=%{public}s', cas.ok ? '1' : '0', cas.message);
      if (cas.ok) {
        return cas;
      }
      // 两条都不通：优先报直登的提示（「学号或密码不正确」更直白）
      return ZhengfangAuth.fail(direct.message.length > 0 ? direct.message : cas.message, semester);
    } catch (e) {
      return ZhengfangAuth.fail(direct.message, semester);
    }
  }

  /**
   * 用户填完验证码后继续同一次登录。
   * 必须复用 login() 里创建的 CasSession，不然 execution / 公钥都对不上。
   */
  async submitCaptcha(user: string, pwd: string, code: string): Promise<LoginResult> {
    const semester: Semester = currentSemester(new Date());
    if (this.cas === null) {
      return ZhengfangAuth.fail('验证码会话已失效，请重新点一次登录', semester);
    }
    try {
      const out: CasOutcome = await this.cas.attempt(user, pwd, code);
      return await this.afterCas(out, semester);
    } catch (e) {
      return ZhengfangAuth.fail(
        '统一身份认证异常：' + (e instanceof Error ? e.message : JSON.stringify(e)), semester);
    }
  }

  /** 换一张验证码图；没有活动会话时返回空 */
  async refreshCaptcha(): Promise<ArrayBuffer> {
    if (this.cas === null) {
      return new ArrayBuffer(0);
    }
    return await this.cas.refreshCaptcha();
  }

  /** 走教学综合平台（portal CAS），成功后用 SSO 换出 jw 会话 */
  private async loginViaPortal(user: string, pwd: string, semester: Semester): Promise<LoginResult> {
    try {
      const session: CasSession = new CasSession(this.client);
      this.cas = session;
      const prep: CasPrep = await session.prepare();
      if (!prep.ready) {
        hilog.info(DOMAIN, TAG, 'cas need input: %{public}s', prep.message);
        return { ok: false, message: prep.message, semester: semester, captcha: prep.captcha };
      }
      const out: CasOutcome = await session.attempt(user, pwd, '');
      return await this.afterCas(out, semester);
    } catch (e) {
      return ZhengfangAuth.fail(
        '统一身份认证异常：' + (e instanceof Error ? e.message : JSON.stringify(e)), semester);
    }
  }

  /** CAS 拿到 ticket 之后：去教务的 CAS 入口换 jw 会话，再探一下首页 */
  private async afterCas(out: CasOutcome, semester: Semester): Promise<LoginResult> {
    hilog.info(DOMAIN, TAG, 'portal cas ok=%{public}s msg=%{public}s', out.ok ? '1' : '0', out.message);
    if (out.captcha.byteLength > 0 || !out.ok) {
      return { ok: false, message: out.message, semester: semester, captcha: out.captcha };
    }
    // 换票链已经用 ticket 落过 jw 会话时，任何多余的教务请求都会把 JSESSIONID 换掉：
    // login_cas.html / index_initMenu.html 一律会顶掉刚拿到的会话（换成未通过 CAS 的
    // 半吊子会话），随后课表请求就被弹回门户登录页。所以这里直接放行，真正的验证交给
    // fetchTimetable。
    if (CasTicket.hasJw(this.client)) {
      hilog.info(DOMAIN, TAG, 'jw session ready from ticket, skip bridge/probe, cookie=%{public}s',
        this.client.jar.header(JW_HOST));
      return ZhengfangAuth.success('登录成功（教学综合平台）', semester);
    }
    // 老路：CAS 会话有了但还没换过票，去教务的 CAS 入口换 ticket（CAS 已登录会直接签发）
    const bridge: HttpResult = await this.client.get('/xtgl/login_cas.html');
    hilog.info(DOMAIN, TAG, 'cas bridge status=%{public}d loc=%{public}s',
      bridge.status, bridge.location);
    const probe: HttpResult = await this.client.get('/xtgl/index_initMenu.html');
    if (probe.status === 200 && probe.body.indexOf('login_slogin') < 0) {
      hilog.info(DOMAIN, TAG, 'portal login ok, cookie=%{public}s', this.client.jar.header(JW_HOST));
      return ZhengfangAuth.success('登录成功（教学综合平台）', semester);
    }
    return ZhengfangAuth.fail('统一身份认证通过，但教务会话未建立', semester);
  }

  private static success(message: string, semester: Semester): LoginResult {
    return { ok: true, message: message, semester: semester, captcha: new ArrayBuffer(0) };
  }

  private static fail(message: string, semester: Semester): LoginResult {
    return { ok: false, message: message, semester: semester, captcha: new ArrayBuffer(0) };
  }

  /** 教务直登（正方 jwglxt 表单 + csrftoken + PKCS#1 v1.5） */
  private async loginDirect(user: string, pwd: string, semester: Semester): Promise<LoginResult> {
    this.client.jar.clear();

    const page: HttpResult = await this.client.get(LOGIN_PAGE);
    if (page.status !== 200) {
      return ZhengfangAuth.fail(`教务系统无法访问（HTTP ${page.status}）`, semester);
    }
    // csrftoken 只是防跨站，正方服务端并不强制；取不到时留空照样能登录（实测通过）
    const token: string = ZhengfangAuth.extractCsrf(page.body);
    if (token.length === 0) {
      hilog.warn(DOMAIN, TAG, 'csrftoken missing, continue with empty token; page len=%{public}d', page.body.length);
    }

    const pkResp: HttpResult = await this.client.get(PUBLIC_KEY + Date.now().toString());
    let pk: PublicKeyInfo;
    try {
      pk = JSON.parse(pkResp.body) as PublicKeyInfo;
    } catch (e) {
      return ZhengfangAuth.fail('公钥接口返回异常，可能被重定向到登录页', semester);
    }
    if (!pk.modulus || !pk.exponent) {
      return ZhengfangAuth.fail('公钥接口缺少 modulus/exponent', semester);
    }

    const rsa: RsaPublicKey = new RsaPublicKey(pk.modulus, pk.exponent);
    const encrypted: string = rsa.encrypt(pwd);
    hilog.info(DOMAIN, TAG, 'rsa size=%{public}d cipher=%{public}d chars',
      rsa.size(), encrypted.length);

    const fields: FormField[] = [
      { key: 'yhm', value: user },
      { key: 'mm', value: encrypted },
      { key: 'csrftoken', value: token },
      { key: 'language', value: 'zh_CN' },
      { key: 'mmsfjm', value: '1' },
      { key: 'dlsfbxyzm', value: '0' },
      { key: 'yzcskz', value: '3' }
    ];
    const res: HttpResult = await this.client.postForm(LOGIN_PAGE, fields);
    hilog.info(DOMAIN, TAG, 'post status=%{public}d loc=%{public}s len=%{public}d body=%{public}s',
      res.status, res.location, res.body.length,
      res.body.replace(/\s+/g, ' ').substring(0, 200));
    // 成功时服务端 302 到 /jwglxt/xtgl/index_initMenu.html；失败则原页返回并带错误提示。
    // ohos 的 http 会自动跟随 3xx，跟随后 location 为空、body 是落地页，
    // 所以「不再是登录表单页（没有 id="yhm"）」同样算登录成功。
    const landed: boolean = res.location.indexOf('index_initMenu') >= 0
      || res.location.indexOf('index_cxDefault') >= 0
      || (res.status === 200 && res.body.indexOf('id="yhm"') < 0
        && res.body.indexOf('用户名或密码不正确') < 0);
    if (res.body.indexOf('用户名或密码不正确') >= 0) {
      return ZhengfangAuth.fail('学号或密码不正确', semester);
    }
    if (!landed && res.body.indexOf('id="yzm"') >= 0) {
      return ZhengfangAuth.fail('教务要求输入验证码，请先用浏览器登录一次解除', semester);
    }
    if (!landed) {
      return ZhengfangAuth.fail(`登录未通过（HTTP ${res.status}）`, semester);
    }
    hilog.info(DOMAIN, TAG, 'login ok, cookie=%{public}s', this.client.jar.header(JW_HOST));
    return ZhengfangAuth.success('登录成功', semester);
  }

  /** 登录后的 Cookie 原文（形如 JSESSIONID=xxx），给内嵌 Web 注入用 */
  cookieHeader(): string {
    return this.client.jar.header(JW_HOST, '/jwglxt/');
  }

  /**
   * 把上次登录留下的会话灌回来。
   * 扫码登录没有密码，成绩/考试页没法重新登录，只能复用这条 jw Cookie。
   */
  attachSession(cookie: string): void {
    this.client.jar.absorbHeader(cookie, JW_HOST);
    hilog.info(DOMAIN, TAG, 'attach saved session, cookie=%{public}s', this.client.jar.header(JW_HOST));
  }

  /** 当前是否握着教务会话（登录接口成功后或 attachSession 后为真） */
  hasSession(): boolean {
    return this.client.jar.has('JSESSIONID', JW_HOST);
  }

  /** 会话是否已被教务踢回统一身份认证（302 或登录表单页） */
  private static sessionExpired(status: number, body: string): boolean {
    if (status === 301 || status === 302 || status === 303) {
      return true;
    }
    return body.indexOf('id="fm1"') >= 0;
  }

  /** 合法课表JSON才代表成功；网页中偶然出现kbList文本不能放行。 */
  private static validTimetable(res: RawResponse): boolean {
    if (res.status !== 200) { return false; }
    try {
      const data: TimetableEnvelope = JSON.parse(res.body) as TimetableEnvelope;
      return data !== null && typeof data === 'object' && !Array.isArray(data) && Array.isArray(data.kbList);
    } catch (_) { return false; }
  }

  /** 302/登录页只恢复一次，不通过首页菜单反复替换教务会话。 */
  async fetchTimetable(user: string, semester: Semester): Promise<string> {
    const token: number = AccountScope.token();
    let res: RawResponse = await this.postTimetable(user, semester);
    if (!AccountScope.valid(token)) { throw new Error('账号状态已变更，请重新操作'); }
    if (ZhengfangAuth.validTimetable(res)) { return res.body; }
    const needsSession: boolean = CasTicket.isRedirect(res.status) ||
      (res.status === 200 && CasTicket.isLoginPage(res.body));
    if (needsSession) {
      const restored: boolean = await CasTicket.mint(this.client, 'timetable-recovery');
      if (!AccountScope.valid(token)) { throw new Error('账号状态已变更，请重新操作'); }
      if (restored) {
        res = await this.postTimetable(user, semester);
        if (!AccountScope.valid(token)) { throw new Error('账号状态已变更，请重新操作'); }
        if (ZhengfangAuth.validTimetable(res)) { return res.body; }
      }
      if (!restored || CasTicket.isRedirect(res.status) || CasTicket.isLoginPage(res.body)) {
        throw new Error('教务会话未建立或已失效，请重新登录（已尝试恢复一次，原课表已保留）');
      }
    }
    if (res.status !== 200) { throw new Error(`课表接口 HTTP ${res.status}，原课表已保留`); }
    throw new Error(ZhengfangAuth.explainJwError(res.body));
  }

  /**
   * 把教务的错误页翻成人话。
   * 实测结构：<p class="error_title">无功能权限</p>——意思是教务没给这个账号
   * 开放「课表查询」菜单，换参数、换学期都没用，只能找教务处开权限。
   */
  private static explainJwError(body: string): string {
    const m: RegExpExecArray | null =
      new RegExp('class="error_title">([^<]*)<').exec(body);
    const title: string = m === null ? '' : m[1].trim();
    if (title.indexOf('无功能权限') >= 0) {
      return '教务未给该账号开放「课表查询」权限（教务提示：无功能权限），请联系教务处开通后再导入';
    }
    if (title.length > 0 && title !== '错误提示') {
      return `教务拒绝课表查询：${title}`;
    }
    return '课表接口未返回 kbList，可能登录状态失效';
  }

  /** 裸请求保留状态，有限处理同教务课表目录业务重定向。 */
  private async postTimetable(user: string, semester: Semester): Promise<RawResponse> {
    const token: number = AccountScope.token();
    const fields: FormField[] = [
      { key: 'xnm', value: semester.xnm.toString() },
      { key: 'xqm', value: semester.xqm.toString() },
      { key: 'kzlx', value: 'ck' }
    ];
    let path: string = '/jwglxt' + TIMETABLE + encodeURIComponent(user);
    let usePost: boolean = true;
    for (let hop = 0; hop <= 3; hop++) {
      if (!AccountScope.valid(token)) { throw new Error('账号状态已变更'); }
      const cookie: string = this.client.jar.header(JW_HOST, path);
      const res: RawResponse = usePost
        ? await RawHttp.postForm(JW_HOST, path, cookie, HttpClient.encodeForm(fields), 25000)
        : await RawHttp.get(JW_HOST, path, cookie, 25000);
      if (!AccountScope.valid(token)) { throw new Error('账号状态已变更'); }
      this.client.jar.absorb(res.setCookie, JW_HOST, path);
      let category: string = res.status === 200 ? (CasTicket.isLoginPage(res.body) ? 'login-page' : 'response') : 'http-error';
      if (CasTicket.isRedirect(res.status)) {
        if (res.location.length === 0) { throw new Error('课表接口重定向缺少目标，请重新登录'); }
        let target: string = '';
        try { target = CasTicket.resolveTarget(res.location, JW_HOST, path); }
        catch (e) {
          systemHilog.warn(DOMAIN, TAG, 'timetable status=%{public}d target=refused', res.status);
          throw new Error((e as Error).message || '课表认证跳转无效');
        }
        const host: string = RawHttp.hostOf(target);
        const nextPath: string = RawHttp.pathOf(target);
        const route: string = nextPath.split('?')[0];
        const login: boolean = (host === CAS_PORTAL_HOST && route.startsWith('/cas/')) ||
          (host === JW_HOST && route.startsWith('/jwglxt/xtgl/login'));
        category = login ? 'authentication' : 'business';
        systemHilog.info(DOMAIN, TAG, 'timetable status=%{public}d target=%{public}s', res.status, category);
        if (login) { return res; }
        if (host !== JW_HOST || !route.startsWith('/jwglxt/kbcx/')) { throw new Error('课表重定向目标不受信任，已拒绝'); }
        if (hop === 3) { throw new Error('课表接口重定向次数过多，请重新登录'); }
        if (res.status !== 307 && res.status !== 308) { usePost = false; }
        path = nextPath;
      } else {
        // 只记录固定类别和状态码，禁止正文、Cookie、查询参数或票据进入日志。
        systemHilog.info(DOMAIN, TAG, 'timetable status=%{public}d target=%{public}s', res.status, category);
        return res;
      }
    }
    throw new Error('课表接口重定向未完成');
  }

  /** 拉取某个学期的成绩 JSON 原文（items 可能为空数组） */
  async fetchGrades(xnm: number, xqm: number): Promise<string> {
    const all: RawGrade[] = [];
    for (let page = 1; page <= 100; page++) {
      const body: string = await this.fetchGradePage(xnm, xqm, page);
      let parsed: GradePageResponse;
      try { parsed = JSON.parse(body) as GradePageResponse; }
      catch (e) { throw new Error('成绩响应格式异常，已保留原有缓存'); }
      if (parsed === null || !Array.isArray(parsed.items)) { throw new Error('成绩响应缺少课程列表'); }
      for (const item of parsed.items) { all.push(item); }
      const pages: number = Number(parsed.total || 0);
      const records: number = Number(parsed.records || 0);
      if (parsed.items.length === 0 || (pages > 0 && page >= pages) ||
        (records > 0 && all.length >= records) || (pages === 0 && records === 0 && parsed.items.length < 100)) {
        if (records > all.length) { throw new Error('成绩分页数据不完整'); }
        const result: GradePageResponse = { items: all, records: all.length, total: 1, currentPage: 1 };
        return JSON.stringify(result);
      }
    }
    throw new Error('成绩分页超过安全上限，请稍后重试');
  }

  private async fetchGradePage(xnm: number, xqm: number, page: number): Promise<string> {
    const ts: number = Date.now();
    const fields: FormField[] = [
      { key: 'xnm', value: xnm.toString() },
      { key: 'xqm', value: xqm.toString() },
      { key: '_search', value: 'false' },
      { key: 'nd', value: ts.toString() },
      { key: 'queryModel.showCount', value: '100' },
      { key: 'queryModel.currentPage', value: page.toString() },
      { key: 'queryModel.sortName', value: '' },
      { key: 'queryModel.sortOrder', value: 'asc' },
      { key: 'time', value: '1' }
    ];
    const res: RawResponse = await RawHttp.postForm(JW_HOST, '/jwglxt' + GRADE_QUERY,
      this.client.jar.header(JW_HOST, '/jwglxt/cjcx/'), HttpClient.encodeForm(fields), 25000);
    this.client.jar.absorb(res.setCookie, JW_HOST);
    if (ZhengfangAuth.sessionExpired(res.status, res.body)) {
      throw new Error('登录状态已过期，请回首页重新导入课表');
    }
    if (res.status !== 200) {
      throw new Error(`成绩接口 HTTP ${res.status}`);
    }
    if (res.body.indexOf('error_title') >= 0) {
      throw new Error(ZhengfangAuth.explainJwError(res.body));
    }
    return res.body;
  }

  /** 拉取考试安排 JSON 原文（items 可能为空数组，表示本学期没排考） */
  async fetchExams(xnm: number, xqm: number): Promise<string> {
    const ts: number = Date.now();
    const fields: FormField[] = [
      { key: 'xnm', value: xnm.toString() },
      { key: 'xqm', value: xqm.toString() },
      { key: 'ksmcdmb_id', value: '' },
      { key: 'kch', value: '' },
      { key: 'kc', value: '' },
      { key: 'kskc', value: '' },
      { key: 'kssj', value: '' },
      { key: 'cxbj', value: '' },
      { key: 'fxbj', value: '' },
      { key: '_search', value: 'false' },
      { key: 'nd', value: ts.toString() },
      { key: 'queryModel.showCount', value: '100' },
      { key: 'queryModel.currentPage', value: '1' },
      { key: 'queryModel.sortName', value: '' },
      { key: 'queryModel.sortOrder', value: 'asc' },
      { key: 'time', value: '0' }
    ];
    const res: RawResponse = await RawHttp.postForm(JW_HOST, '/jwglxt' + EXAM_QUERY,
      this.client.jar.header(JW_HOST, '/jwglxt/kwgl/'), HttpClient.encodeForm(fields), 25000);
    this.client.jar.absorb(res.setCookie, JW_HOST);
    if (ZhengfangAuth.sessionExpired(res.status, res.body)) {
      throw new Error('登录状态已过期，请回首页重新导入课表');
    }
    if (res.status !== 200) {
      throw new Error(`考试安排接口 HTTP ${res.status}`);
    }
    if (res.body.indexOf('error_title') >= 0) {
      throw new Error(ZhengfangAuth.explainJwError(res.body));
    }
    return res.body;
  }

  static extractCsrf(html: string): string {
    const re: RegExp = new RegExp('id="csrftoken"[^>]*value="([^"]+)"');
    const m: RegExpExecArray | null = re.exec(html);
    return m === null ? '' : m[1];
  }
}
