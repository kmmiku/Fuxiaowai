import { PrivateLog as hilog } from '../../../common/util/PrivateLog';
import { HttpClient } from '../../../network/http/HttpClient';
import { RawHttp, RawResponse } from '../../../network/http/RawHttp';
import { AccountScope } from '../../../common/util/AccountScope';

const DOMAIN: number = 0x0031;
const TAG: string = 'FuxiaowaiTicket';

/** 门户（统一身份认证）主机 */
export const CAS_PORTAL_HOST: string = 'portal.fzfu.edu.cn';
/** 教务主机 */
export const JW_HOST: string = 'jw.fzfu.edu.cn';
/**
 * 换票用的 service：直接落到「学生课表查询」页（个人中心里那个入口）。
 * CAS 会带着 ticket 跳到它，教务随即下发自己的 JSESSIONID，一步就建好课表会话。
 */
export const JW_TIMETABLE_SERVICE: string =
  'http://jw.fzfu.edu.cn/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default';
/** 教务自己的 CAS 落地页：一定在白名单里，service 兜底用 */
export const JW_CAS_LANDING: string = 'http://jw.fzfu.edu.cn/jwglxt/xtgl/login_cas.html';

/**
 * 统一身份认证 → 教务 的换票工具，扫码登录与账号密码登录共用。
 *
 * 为什么要裸 HTTP：票据写在 302 那一跳的 Set-Cookie / Location 上，
 * @ohos.net.http 自动跟随会把中间跳吞掉（关掉跟随又直接抛 2300047），
 * 于是门户会话永远换不到教务的 JSESSIONID。这里逐跳自己接。
 */
export interface TicketLanding extends RawResponse {
  host: string;
  path: string;
}

export class CasTicket {
  static isRedirect(status: number): boolean {
    return status === 301 || status === 302 || status === 303 || status === 307 || status === 308;
  }

  /** 只接受学校两个已知主机；HTTPS不得静默降级为裸HTTP。 */
  static resolveTarget(location: string, origin: string, priorPath: string): string {
    if (/[\r\n]/.test(location)) { throw new Error('认证跳转地址无效'); }
    if (/^https:/i.test(location)) { throw new Error('学校要求HTTPS认证，当前裸连接不支持，请重新选择登录入口'); }
    let target: string = location;
    if (target.startsWith('//')) { target = 'http:' + target; }
    else if (target.startsWith('/')) { target = 'http://' + origin + target; }
    else if (target.indexOf('://') < 0) {
      const base: string = priorPath.split('?')[0];
      target = 'http://' + origin + (target.startsWith('?') ? base : base.substring(0, base.lastIndexOf('/') + 1)) + target;
    }
    const host: string = RawHttp.hostOf(target).toLowerCase();
    if (host !== CAS_PORTAL_HOST && host !== JW_HOST) { throw new Error('认证跳转地址不受信任，已拒绝'); }
    const rawPath: string = RawHttp.pathOf(target);
    const queryAt: number = rawPath.indexOf('?');
    const path: string = queryAt < 0 ? rawPath : rawPath.substring(0, queryAt);
    const segments: string[] = [];
    path.split('/').forEach((part: string) => {
      if (part === '..') { segments.pop(); }
      else if (part !== '.' && part.length > 0) { segments.push(part); }
    });
    const normalized: string = '/' + segments.join('/') + (path.endsWith('/') && segments.length > 0 ? '/' : '');
    return 'http://' + host + normalized + (queryAt < 0 ? '' : rawPath.substring(queryAt));
  }

  static isLoginPage(body: string): boolean {
    return /<form[^>]*id\s*=\s*["'](?:fm1|loginForm)["']/i.test(body) ||
      /<input[^>]*type\s*=\s*["']password["']/i.test(body);
  }

  /** 保留最终落地位置；Cookie存在不能替代有效业务落地。 */
  static async follow(client: HttpClient, first: RawResponse, tag: string,
    origin: string = CAS_PORTAL_HOST, priorPath: string = '/cas/login',
    token: number = AccountScope.token()): Promise<TicketLanding> {
    if (!AccountScope.valid(token)) { throw new Error('账号状态已变更'); }
    let cur: RawResponse = first;
    client.jar.absorb(cur.setCookie, origin, priorPath);
    let hops: number = 0;
    while (CasTicket.isRedirect(cur.status) && cur.location.length > 0 && hops < 6) {
      if (!AccountScope.valid(token)) { throw new Error('账号状态已变更'); }
      const target: string = CasTicket.resolveTarget(cur.location, origin, priorPath);
      origin = RawHttp.hostOf(target);
      priorPath = RawHttp.pathOf(target);
      cur = await RawHttp.get(origin, priorPath, client.jar.header(origin, priorPath));
      if (!AccountScope.valid(token)) { throw new Error('账号状态已变更'); }
      client.jar.absorb(cur.setCookie, origin, priorPath);
      hops++;
      hilog.info(DOMAIN, TAG, 'ticket hop status=%{public}d', cur.status);
    }
    if (CasTicket.isRedirect(cur.status)) { throw new Error('认证跳转未完成或次数过多，请重新登录'); }
    return { status: cur.status, body: cur.body, location: cur.location, setCookie: cur.setCookie, host: origin, path: priorPath };
  }

  static isJwLanding(client: HttpClient, landing: TicketLanding): boolean {
    const path: string = landing.path.split('?')[0];
    return landing.status === 200 && landing.host === JW_HOST && path.startsWith('/jwglxt/') &&
      path.indexOf('/xtgl/login') < 0 && path.indexOf('/cas/') < 0 && !CasTicket.isLoginPage(landing.body) &&
      /(?:^|;\s*)JSESSIONID=/.test(client.jar.header(JW_HOST, '/jwglxt/kbcx/'));
  }

  /** 罐子里有没有教务会话 */
  static hasJw(client: HttpClient): boolean {
    return client.jar.has('JSESSIONID', JW_HOST);
  }

  /**
   * 用已经登录的门户会话给教务换 ticket。
   * 先试课表页，不行再退回教务自己的 CAS 落地页。
   */
  static async mint(client: HttpClient, tag: string): Promise<boolean> {
    const token: number = AccountScope.token();
    const services: string[] = [JW_TIMETABLE_SERVICE, JW_CAS_LANDING];
    for (let i = 0; i < services.length; i++) {
      if (!AccountScope.valid(token)) { throw new Error('账号状态已变更'); }
      const service: string = services[i];
      const path: string = '/cas/login?service=' + encodeURIComponent(service);
      let res: RawResponse = await RawHttp.get(CAS_PORTAL_HOST, path, client.jar.header(CAS_PORTAL_HOST, path));
      if (!AccountScope.valid(token)) { throw new Error('账号状态已变更'); }
      client.jar.absorb(res.setCookie, CAS_PORTAL_HOST, path);
      hilog.info(DOMAIN, TAG, '%{public}s mint status=%{public}d loc=%{public}s',
        tag, res.status, res.location);
      const landing: TicketLanding = await CasTicket.follow(client, res, tag, CAS_PORTAL_HOST, path, token);
      const ok: boolean = CasTicket.isJwLanding(client, landing);
      hilog.info(DOMAIN, TAG, '%{public}s mint done service=%{public}s jwCookie=%{public}s len=%{public}d',
        tag, service, ok ? 'yes' : 'no', res.body.length);
      if (ok) {
        return true;
      }
    }
    return false;
  }
}
