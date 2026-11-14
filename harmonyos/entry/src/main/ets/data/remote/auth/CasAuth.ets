import { PrivateLog as hilog } from '../../../common/util/PrivateLog';
import { FormField, HttpClient, HttpBinary, HttpResult } from '../../../network/http/HttpClient';
import { RawHttp, RawResponse } from '../../../network/http/RawHttp';
import { CAS_PORTAL_HOST, CasTicket, TicketLanding, JW_TIMETABLE_SERVICE } from './CasTicket';

const DOMAIN: number = 0x0031;
const TAG: string = 'FuxiaowaiCas';

/** 统一身份认证（CAS）站点 */
export const CAS_LOGIN: string = 'http://portal.fzfu.edu.cn/cas/login';
export const CAS_PUBKEY: string = 'http://portal.fzfu.edu.cn/cas/v2/getPubKey';
export const CAS_KAPTCHA: string = 'http://portal.fzfu.edu.cn/cas/v2/getKaptchaStatus';
/** 验证码图片：每次 GET 都会换一张新图，并把新答案写进会话 */
export const CAS_KAPTCHA_IMG: string = 'http://portal.fzfu.edu.cn/cas/kaptcha';
/** 教务侧的 CAS 入口：GET 之后 302 到 portal CAS，同时下发 jw 的 JSESSIONID */
export const JW_CAS_ENTRY: string = 'http://jw.fzfu.edu.cn/jwglxt/xtgl/login_cas.html';

export interface CasKeyInfo {
  modulus: string;
  exponent: string;
}

/** 打开登录页的结果：ready = 可以直接提交；否则 captcha 里是要给用户看的图 */
export interface CasPrep {
  ready: boolean;
  message: string;
  captcha: ArrayBuffer;
}

/** 提交登录的结果：ok = 拿到 ticket；captcha 非空 = 还要用户再输一次验证码 */
export interface CasOutcome {
  ok: boolean;
  message: string;
  captcha: ArrayBuffer;
}

/** 模幂：CAS 用的是原始 RSA（无填充），位数只有 512，直接平方乘即可 */
function modPow(base: bigint, exp: bigint, mod: bigint): bigint {
  let result: bigint = 1n;
  let b: bigint = base % mod;
  let e: bigint = exp;
  while (e > 0n) {
    if ((e & 1n) === 1n) {
      result = (result * b) % mod;
    }
    b = (b * b) % mod;
    e = e >> 1n;
  }
  return result;
}

/**
 * CAS 密码加密（逐位复刻 security.js 的 RSAUtils.encryptedString）：
 *   1. 明文先整体反转字符串（登录页 login.js：password.split('').reverse().join('')）
 *   2. jsbn 用 16 位 digit 装字符：digits[j] = a[2j] + (a[2j+1] << 8)，进位向上归一
 *      —— 等价于整数 m = Σ (a[2j] + (a[2j+1] << 8)) · 65536^j
 *   3. c = m^e mod n，没有填充
 *   4. 输出大端十六进制（不补零，与 jsbn 的 biToHex 一致）
 * 纯 ASCII 密码与「每字符取低 8 位」等价；密码含全角字符时两者不同，
 * 只有这份 16 位打包才和浏览器算出来的密文逐字节相同。
 */
export function casEncrypt(pwd: string, modulusHex: string, expHex: string): string {
  const reversed: string = pwd.split('').reverse().join('');
  // 末尾补 0 到偶数个字符，凑成完整的 16 位 digit
  const codes: number[] = [];
  for (let i = 0; i < reversed.length; i++) {
    codes.push(reversed.charCodeAt(i));
  }
  if (codes.length % 2 !== 0) {
    codes.push(0);
  }
  let m: bigint = 0n;
  for (let j = codes.length / 2 - 1; j >= 0; j--) {
    const digit: number = codes[2 * j] + (codes[2 * j + 1] << 8);
    m = m * 65536n + BigInt(digit);
  }
  const n: bigint = BigInt('0x' + modulusHex);
  const e: bigint = BigInt('0x' + expHex);
  const c: bigint = modPow(m, e, n);
  let hex: string = c.toString(16);
  if (hex.length % 2 !== 0) {
    hex = '0' + hex;
  }
  return hex;
}

/** 从 CAS 登录页取 execution（hidden input，约 5KB 的票据串） */
export function extractExecution(html: string): string {
  const re: RegExp = new RegExp('name="execution"\\s+value="([^"]+)"');
  const m: RegExpExecArray | null = re.exec(html);
  if (m !== null) {
    return m[1];
  }
  const re2: RegExp = new RegExp('value="([^"]+)"[^>]*name="execution"');
  const m2: RegExpExecArray | null = re2.exec(html);
  return m2 === null ? '' : m2[1];
}

/**
 * 取登录页里的错误提示。
 * 实测页面结构是 <p class="error text-left" id="errormsg"><span id="msg">文案</span></p>，
 * 有的版本文案只落在 #msg 里、<p> 是空的，所以两级都试一遍。
 */
export function parseErrormsg(html: string): string {
  const text: string = CasSession.pickText(html,
    new RegExp('<p[^>]*id="errormsg"[^>]*>([\\s\\S]*?)</p>'));
  if (text.length > 0) {
    return text;
  }
  return CasSession.pickText(html, new RegExp('<span[^>]*id="msg"[^>]*>([\\s\\S]*?)</span>'));
}

/** 是否需要验证码 */
export async function casNeedKaptcha(client: HttpClient): Promise<boolean> {
  try {
    const r: HttpResult = await client.get(CAS_KAPTCHA);
    return r.body.indexOf('true') >= 0;
  } catch (e) {
    return false;
  }
}

/** 取一张验证码图片（JPEG 字节）。拿不到时返回空 buffer，由上层提示「获取失败」 */
export async function fetchKaptchaImage(client: HttpClient): Promise<ArrayBuffer> {
  try {
    const r: HttpBinary = await client.getBytes(CAS_KAPTCHA_IMG + '?time=' + Date.now().toString());
    hilog.info(DOMAIN, TAG, 'kaptcha image status=%{public}d bytes=%{public}d',
      r.status, r.data.byteLength);
    if (r.status !== 200) {
      return new ArrayBuffer(0);
    }
    return r.data;
  } catch (e) {
    hilog.warn(DOMAIN, TAG, 'kaptcha image failed: %{public}s', JSON.stringify(e));
    return new ArrayBuffer(0);
  }
}

/**
 * 一次统一身份认证登录会话。
 *
 * 关键顺序（缺一步服务端就判「登录页面闲置时间过长」）：
 *   GET 教务 CAS 入口 → GET 登录页取 execution → GET v2/getKaptchaStatus
 *   → GET v2/getPubKey → POST 表单（username/password/authcode/execution）
 * 所以公钥必须在提交前取，验证码图片可以在公钥之后取（换图不影响 execution）。
 *
 * 验证码错误时服务端会重绘登录页并给出新的 execution，本类把新票据留在 execution 里，
 * 同时再取一张新图返回给上层，用户填完直接 attempt 重试，不用重新走整个流程。
 */
export class CasSession {
  private client: HttpClient;
  private execution: string = '';
  private keyModulus: string = '';
  private keyExponent: string = '';
  private opened: boolean = false;
  private needCode: boolean = false;
  /** 带 service 的 CAS 登录地址，重开页面时复用 */
  private casUrl: string = '';

  constructor(client: HttpClient) {
    this.client = client;
  }

  /** 从 HTML 里按正则取一段文本并去掉标签、压掉空白 */
  static pickText(html: string, re: RegExp): string {
    const m: RegExpExecArray | null = re.exec(html);
    if (m === null) {
      return '';
    }
    const text: string = m[1].replace(new RegExp('<[^>]+>', 'g'), '');
    return text.replace(new RegExp('\\s+', 'g'), ' ').trim();
  }

  /** 这一页还是 CAS 登录表单吗（失败页都带 id="fm1"；已放行时跟随重定向拿到的是别的页面） */
  private static isLoginForm(html: string): boolean {
    return html.indexOf('id="fm1"') >= 0;
  }

  /** 打开登录页、探测验证码、取公钥；需要验证码时顺手取图，交回给界面 */
  async prepare(): Promise<CasPrep> {
    this.execution = '';
    this.keyModulus = '';
    this.keyExponent = '';
    this.opened = false;
    this.needCode = false;

    // 1) 登录页直接带上 service＝课表查询页：登录成功后 CAS 会带着 ticket 跳过去，
    //    教务随即下发 JSESSIONID，不需要再靠 login_cas.html 二次建会话。
    this.casUrl = CAS_LOGIN + '?service=' + encodeURIComponent(JW_TIMETABLE_SERVICE);

    const opened: CasPrep | null = await this.loadFlow();
    if (opened !== null) {
      return opened;
    }

    // 4) 公钥：必须在提交前取，否则服务端认为页面已过期
    const keyed: CasPrep | null = await this.loadKey();
    if (keyed !== null) {
      return keyed;
    }

    this.opened = true;
    if (this.needCode) {
      const img: ArrayBuffer = await fetchKaptchaImage(this.client);
      const msg: string = img.byteLength > 0
        ? '教学综合平台要求输入验证码' : '验证码图片获取失败，请重试';
      return { ready: false, message: msg, captcha: img };
    }
    return { ready: true, message: '', captcha: new ArrayBuffer(0) };
  }

  /** 重开一次流程（服务端偶尔判「登录页面闲置时间过长」，换个 execution 再试） */
  private async reopen(): Promise<boolean> {
    this.execution = '';
    this.keyModulus = '';
    this.keyExponent = '';
    const page: CasPrep | null = await this.loadFlow();
    if (page !== null) {
      return false;
    }
    const keyed: CasPrep | null = await this.loadKey();
    return keyed === null;
  }

  /** 步骤 2、3：登录页取 execution + 验证码开关。出错时返回要透出的结果，成功返回 null */
  private async loadFlow(): Promise<CasPrep | null> {
    const page: HttpResult = await this.client.get(this.casUrl);
    if (page.status !== 200) {
      return CasSession.prep(false, `统一身份认证无法访问（HTTP ${page.status}）`);
    }
    this.execution = extractExecution(page.body);
    if (this.execution.length === 0) {
      return CasSession.prep(false, '统一身份认证页面结构变化：未取到 execution');
    }
    this.needCode = await casNeedKaptcha(this.client);
    return null;
  }

  /** 步骤 4：取公钥。出错时返回要透出的结果，成功返回 null */
  private async loadKey(): Promise<CasPrep | null> {
    try {
      const pkResp: HttpResult = await this.client.get(CAS_PUBKEY + '?t=' + Date.now().toString());
      const key: CasKeyInfo = JSON.parse(pkResp.body) as CasKeyInfo;
      if (key.modulus.length === 0 || key.exponent.length === 0) {
        return CasSession.prep(false, '统一身份认证公钥缺少 modulus/exponent');
      }
      this.keyModulus = key.modulus;
      this.keyExponent = key.exponent;
      return null;
    } catch (e) {
      return CasSession.prep(false, '统一身份认证公钥接口异常');
    }
  }

  /** 提交账号密码（code 为空表示服务端还没要求验证码） */
  async attempt(user: string, pwd: string, code: string): Promise<CasOutcome> {
    if (!this.opened) {
      return CasSession.out(false, '统一身份认证会话已失效，请重新登录');
    }
    const first: CasOutcome | null = await this.submit(user, pwd, code);
    if (first !== null) {
      return first;
    }
    // 「登录页面闲置时间过长」是服务端流程状态的偶发噪声（实测约三成概率），
    // 换一个新 execution 再提交一次即可，不必让用户重输。
    hilog.info(DOMAIN, TAG, 'cas reopen once after stale-flow');
    if (!(await this.reopen())) {
      return CasSession.out(false, '统一身份认证页面已失效，请重新点一次登录');
    }
    const second: CasOutcome | null = await this.submit(user, pwd, code);
    return second === null
      ? CasSession.out(false, '统一身份认证页面已失效，请重新点一次登录') : second;
  }

  /**
   * 真正发一次表单。返回 null 表示遇到可重试的「闲置时间过长」。
   *
   * 必须用裸 TCP：登录成功时 CAS 回 302，ticket 在 Location 上、会话票据在 Set-Cookie 上，
   * 而 @ohos.net.http 会自动跟随 3xx（关掉又抛 2300047），两样都拿不到，
   * 于是「登录成功」这件事根本无从判断，教务会话也建不起来。
   */
  private async submit(user: string, pwd: string, code: string): Promise<CasOutcome | null> {
    const encrypted: string = casEncrypt(pwd, this.keyModulus, this.keyExponent);
    hilog.info(DOMAIN, TAG, 'cas submit user=%{public}s cipher=%{public}d code=%{public}d',
      user, encrypted.length, code.length);
    const fields: FormField[] = [
      { key: 'username', value: user },
      { key: 'password', value: encrypted },
      { key: 'authcode', value: code },
      { key: 'execution', value: this.execution },
      { key: '_eventId', value: 'submit' },
      { key: 'rememberMe', value: 'true' }
    ];
    const form: string = HttpClient.encodeForm(fields);
    let post: RawResponse;
    try {
      post = await RawHttp.postForm(CAS_PORTAL_HOST, '/cas/login?v=' + Date.now().toString(),
        this.client.jar.header(CAS_PORTAL_HOST, '/cas/login'), form, 20000);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'cas post failed: %{public}s', JSON.stringify(e));
      return CasSession.out(false, '统一身份认证连接失败，请检查网络后重试');
    }
    this.client.jar.absorb(post.setCookie, CAS_PORTAL_HOST, '/cas/login');
    hilog.info(DOMAIN, TAG, 'cas post status=%{public}d loc=%{public}s len=%{public}d setCookie=%{public}s',
      post.status, post.location, post.body.length, post.setCookie);

    // ① 直接带 ticket 跳走：跟着走完，教务会话就建立好了
    if (post.status === 302 && post.location.indexOf('ticket=') >= 0) {
      const landing: TicketLanding = await CasTicket.follow(this.client, post, 'cas');
      if (CasTicket.isJwLanding(this.client, landing)) {
        hilog.info(DOMAIN, TAG, 'cas ok ticket -> jw session, landing=%{public}d len=%{public}d',
          landing.status, landing.body.length);
        return CasSession.out(true, '登录成功（教学综合平台）');
      }
      hilog.warn(DOMAIN, TAG, 'cas ticket but no jw cookie, landing=%{public}d len=%{public}d',
        landing.status, landing.body.length);
      return CasSession.out(false, '统一身份认证已通过，但换取教务会话失败，请重试一次');
    }
    if (post.location.indexOf('runTimeAccountError') >= 0 ||
      post.body.indexOf('获取用户信息失败') >= 0) {
      return CasSession.out(false, '统一身份认证拒绝了这次登录，请重试一次');
    }

    // ② 其余 3xx：跟一脚再看落地页
    let body: string = post.body;
    if (post.status >= 300 && post.status < 400 && post.location.length > 0) {
      const next: RawResponse = await CasTicket.follow(this.client, post, 'cas');
      body = next.body;
    }
    const stillForm: boolean = CasSession.isLoginForm(body);
    const msg: string = stillForm ? parseErrormsg(body) : '';
    hilog.info(DOMAIN, TAG, 'cas page form=%{public}s errormsg=%{public}s title=%{public}s',
      stillForm ? '1' : '0', msg,
      CasSession.pickText(body, new RegExp('<title>([\\s\\S]*?)</title>')));

    // ③ 没停在登录表单：可能已经放行，补一次换票兜底
    if (!stillForm) {
      if (await CasTicket.mint(this.client, 'cas')) {
        return CasSession.out(true, '登录成功（教学综合平台）');
      }
      return CasSession.out(false, `统一身份认证未通过（HTTP ${post.status}）`);
    }

    // ④ 失败：错误页里带着新的 execution，重试必须用它，否则又是「闲置时间过长」
    const fresh: string = extractExecution(body);
    if (fresh.length > 0) {
      this.execution = fresh;
    }
    if (msg.indexOf('闲置') >= 0 || msg.indexOf('过期') >= 0) {
      return null;
    }
    if (msg.indexOf('验证码') >= 0) {
      const img: ArrayBuffer = await fetchKaptchaImage(this.client);
      return {
        ok: false,
        message: msg.length > 0 ? msg : '验证码不正确，请重新输入',
        captcha: img
      };
    }
    if (msg.indexOf('密码错误') >= 0) {
      return CasSession.out(false, '账号或密码不正确');
    }
    if (msg.length > 0) {
      return CasSession.out(false, msg);
    }
    // 没给可读提示：本来就要验证码的话，多半还是验证码不对，换一张让用户重试
    if (this.needCode) {
      const img: ArrayBuffer = await fetchKaptchaImage(this.client);
      return { ok: false, message: '验证码不正确，请重新输入', captcha: img };
    }
    return CasSession.out(false, `统一身份认证未通过（HTTP ${post.status}）`);
  }

  /** 换一张验证码图（图看不清时用）。每次 GET 服务端都会换答案，旧图随之失效 */
  async refreshCaptcha(): Promise<ArrayBuffer> {
    return await fetchKaptchaImage(this.client);
  }

  private static prep(ready: boolean, message: string): CasPrep {
    return { ready: ready, message: message, captcha: new ArrayBuffer(0) };
  }

  private static out(ok: boolean, message: string): CasOutcome {
    return { ok: ok, message: message, captcha: new ArrayBuffer(0) };
  }
}
