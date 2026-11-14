import { PrivateLog as hilog } from '../../../common/util/PrivateLog';
import { HttpClient, HttpBinary, HttpResult } from '../../../network/http/HttpClient';
import { RawHttp, RawResponse } from '../../../network/http/RawHttp';
import { CasTicket } from './CasTicket';

const DOMAIN: number = 0x0031;
const TAG: string = 'FuxiaowaiQr';

/** 企业微信扫码登录（portal.fzfu.edu.cn 的 CAS 用的是这个应用的 qrConnect） */
export const WEcom_APPID: string = 'ww6854f7b058a8cb51';
export const WEcom_AGENTID: string = '1000019';
/** CAS 的「企业微信客户端」回调地址，扫码成功后 CAS 会在带 code 的情况下接受它 */
export const CAS_QR_CALLBACK: string =
  'https://portal.fzfu.edu.cn/cas/login?client_name=QyWeiXinClient';
const QR_CONNECT: string =
  'https://open.work.weixin.qq.com/wwopen/sso/qrConnect?appid=' + WEcom_APPID +
  '&agentid=' + WEcom_AGENTID +
  '&redirect_uri=https%3a%2f%2fportal.fzfu.edu.cn%2fcas%2flogin%3fclient_name%3dQyWeiXinClient' +
  '&state=STATE';
const QR_IMG: string = 'https://open.work.weixin.qq.com/wwopen/sso/qrImg?key=';
/**
 * 长轮询地址（GET 版）。服务端最多挂 20 秒，没人扫就回
 * `jsonpCallback({"status":"QRCODE_SCAN_NEVER","auth_code":""})`。
 * 页面里给浏览器用的是同路径的 POST 版（/lp/），实测应用侧 GET 版更稳。
 */
const QR_POLL: string = 'https://open.work.weixin.qq.com/wwopen/sso/l/qrConnect?key=';
/** 门户主机名：换票后会话票据落在这一桶里 */
const CAS_HOST: string = 'portal.fzfu.edu.cn';

/** 一张待扫的二维码 */
export interface QrTicket {
  ok: boolean;
  message: string;
  key: string;
  image: ArrayBuffer;
}

export const QR_STATE_WAIT: string = 'wait';
export const QR_STATE_SCANNED: string = 'scanned';
export const QR_STATE_DONE: string = 'done';
export const QR_STATE_CANCEL: string = 'cancel';
export const QR_STATE_EXPIRED: string = 'expired';
export const QR_STATE_ERROR: string = 'error';

/** 一次轮询结果；state 见上面的常量，done 时 code 是 CAS 的 auth_code */
export interface QrProgress {
  state: string;
  code: string;
  message: string;
}

/** 拿 auth_code 换登录态的结果 */
export interface QrExchange {
  ok: boolean;
  message: string;
}

/**
 * 企业微信「扫码登录」协议。
 *
 * 1) GET qrConnect 页面 → HTML 里 `"key":"<16位>"`；
 * 2) GET /wwopen/sso/qrImg?key=<key> → PNG 二维码，给用户用企业微信扫；
 * 3) POST /wwopen/sso/lp/qrConnect 表单 key=<key> → 长轮询，
 *    返回 JSON `{"status":"QRCODE_SCAN_NEVER|QRCODE_SCAN_WAIT|QRCODE_SCAN_SUCCESS|...","auth_code":"..."}`；
 * 4) 成功后拿 auth_code 去 `CAS_QR_CALLBACK&code=<auth_code>&state=STATE`，
 *    CAS 会用这串 code 向企业微信换身份并下发自己的会话票据。
 *
 * 全过程都用应用自己的 Cookie 罐，所以扫码成功后登录态落在 App 而不是浏览器。
 */
export class WecomQrLogin {
  private client: HttpClient;
  private key: string = '';

  constructor(client: HttpClient) {
    this.client = client;
  }

  get ticketKey(): string {
    return this.key;
  }

  /** 取一张新二维码 */
  async start(): Promise<QrTicket> {
    this.key = '';
    let page: HttpResult;
    try {
      page = await this.client.get(QR_CONNECT, 20000);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'qr page failed: %{public}s', JSON.stringify(e));
      return WecomQrLogin.fail('无法连接企业微信，请检查网络后重试');
    }
    if (page.status !== 200) {
      return WecomQrLogin.fail('企业微信返回异常（HTTP ' + page.status.toString() + '）');
    }
    const key: string = WecomQrLogin.pickKey(page.body);
    if (key.length === 0) {
      hilog.warn(DOMAIN, TAG, 'qr key not found, len=%{public}d', page.body.length);
      return WecomQrLogin.fail('没有取到二维码，请重试');
    }
    this.key = key;
    let img: HttpBinary;
    try {
      img = await this.client.getBytes(QR_IMG + key);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'qr img failed: %{public}s', JSON.stringify(e));
      return WecomQrLogin.fail('二维码图片获取失败，请重试');
    }
    hilog.info(DOMAIN, TAG, 'qr key=%{public}s img=%{public}d %{public}d bytes',
      key, img.status, img.data.byteLength);
    if (img.status !== 200 || img.data.byteLength === 0) {
      return WecomQrLogin.fail('二维码图片获取失败，请重试');
    }
    return { ok: true, message: '', key: key, image: img.data };
  }

  /** 长轮询一次；调用方循环调用即可（服务端 20 秒无事件时回 wait） */
  async poll(): Promise<QrProgress> {
    if (this.key.length === 0) {
      return { state: QR_STATE_ERROR, code: '', message: '二维码已失效' };
    }
    let res: HttpResult;
    try {
      res = await this.client.get(QR_POLL + this.key, 30000);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'qr poll failed: %{public}s', JSON.stringify(e));
      return { state: QR_STATE_WAIT, code: '', message: '' };
    }
    const status: string = WecomQrLogin.field(res.body, 'status');
    const code: string = WecomQrLogin.field(res.body, 'auth_code');
    hilog.info(DOMAIN, TAG, 'qr poll http=%{public}d len=%{public}d status=%{public}s code=%{public}d head=%{public}s',
      res.status, res.body.length, status, code.length,
      res.body.substring(0, 120).replace(/\s+/g, ' '));

    // 成功态：服务端实际回的是 QRCODE_SCAN_SUCC（少一个 ESS），
    // 有的环境回 QRCODE_SCAN_SUCCESS，所以按前缀认，避免又空转到过期。
    if (status.indexOf('QRCODE_SCAN_SUCC') === 0) {
      if (code.length === 0) {
        return { state: QR_STATE_ERROR, code: '', message: '扫码结果缺少凭证，请刷新二维码重试' };
      }
      return { state: QR_STATE_DONE, code: code, message: '扫码成功，正在导入课表' };
    }
    if (status.indexOf('QRCODE_SCAN_WAIT') === 0 || status.indexOf('QRCODE_SCAN_ING') === 0) {
      return { state: QR_STATE_SCANNED, code: '', message: '已扫码，请在手机上确认登录' };
    }
    if (status.indexOf('QRCODE_SCAN_CANCEL') === 0 || status.indexOf('QRCODE_CANCEL') === 0) {
      return { state: QR_STATE_CANCEL, code: '', message: '已在手机上取消登录' };
    }
    if (status.indexOf('QRCODE_SCAN_EXPIRED') === 0 || status.indexOf('QRCODE_EXPIRED') === 0) {
      return { state: QR_STATE_EXPIRED, code: '', message: '二维码已过期，请刷新' };
    }
    if (status.indexOf('QRCODE_SCAN_ERR') === 0) {
      return { state: QR_STATE_EXPIRED, code: '', message: '二维码已失效，请刷新' };
    }
    // QRCODE_SCAN_NEVER 或网络抖动：继续等
    return { state: QR_STATE_WAIT, code: '', message: '' };
  }

  /**
   * 拿 auth_code 去 CAS 换登录态。
   *
   * 判据（实测：假 code 会被 302 到 /cas/runTimeAccountError.html，页面写「您获取用户信息失败」，
   * 那个页面同样没有登录表单，所以「没有 fm1」这一条单独用会误判成功）：
   *   1) 落到 runTimeAccountError / 出现「获取用户信息失败」→ 失败；
   *   2) 新版 CASTGC 票据 cookie 落进罐里 → 成功；
   *   3) 否则没有登录表单（已跳出 CAS 登录页）→ 成功。
   */
  async exchange(code: string): Promise<QrExchange> {
    const portal: string = CAS_HOST;
    try {
      // 1) auth_code → 门户会话。这里必须用裸 HTTP：票据写在 302 的 Set-Cookie 里，
      //    @ohos.net.http 跟随重定向会把这一跳吃掉。
      const cbPath: string = '/cas/login?client_name=QyWeiXinClient&code=' +
        encodeURIComponent(code) + '&state=STATE';
      const first: RawResponse = await RawHttp.get(portal, cbPath, this.client.jar.header(portal, cbPath));
      this.client.jar.absorb(first.setCookie, portal);
      hilog.info(DOMAIN, TAG, 'qr cas 1st status=%{public}d loc=%{public}s cookie=%{public}s',
        first.status, first.location, first.setCookie);
      if (first.location.indexOf('runTimeAccountError') >= 0 ||
        first.body.indexOf('获取用户信息失败') >= 0) {
        return { ok: false, message: '企业微信身份没被统一身份认证接受，请重新扫码（账号未开通门户时也会这样）' };
      }
      if (first.setCookie.length === 0) {
        return { ok: false, message: `统一身份认证未返回会话（HTTP ${first.status}），请重新扫码` };
      }
      // 2) 门户会话 → 教务 ticket，落到课表页
      const jwOk: boolean = await CasTicket.mint(this.client, 'qr');
      if (!jwOk) {
        return { ok: false, message: '统一身份认证已通过，但换取教务会话失败，请重试一次' };
      }
      return { ok: true, message: '' };
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'qr exchange failed: %{public}s', JSON.stringify(e));
      return { ok: false, message: '无法连接统一身份认证，请检查网络后重新扫码' };
    }
  }

  private static fail(message: string): QrTicket {
    return { ok: false, message: message, key: '', image: new ArrayBuffer(0) };
  }

  /** 从 qrConnect 页面里取 key */
  private static pickKey(html: string): string {
    const m: RegExpMatchArray | null = html.match(/"key":"([0-9a-zA-Z]+)"/);
    return m === null ? '' : m[1];
  }

  /** 从 JSON 里取一个字符串字段（不引第三方 JSON 依赖） */
  private static field(json: string, name: string): string {
    const m: RegExpMatchArray | null = json.match(new RegExp('"' + name + '"\\s*:\\s*"([^"]*)"'));
    return m === null ? '' : m[1];
  }
}
