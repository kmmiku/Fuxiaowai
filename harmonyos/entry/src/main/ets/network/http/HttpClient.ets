import http from '@ohos.net.http';
import { CookieJar } from './CookieJar';


export interface FormField {
  key: string;
  value: string;
}

export interface HttpResult {
  status: number;
  body: string;
  location: string;
}

/** 二进制响应（验证码图片等） */
export interface HttpBinary {
  status: number;
  data: ArrayBuffer;
  contentType: string;
}

/**
 * 轻量 HTTP 客户端：表单 POST + Cookie 保持。
 * 教务系统全程只需要这两种能力，所以不引入第三方网络库。
 * 需要「不跟随 3xx、逐跳接票据」的地方走 RawHttp（裸 TCP）。
 */
export class HttpClient {
  readonly jar: CookieJar = new CookieJar();
  private base: string;

  constructor(base: string) {
    this.base = base;
  }

  async get(path: string, readTimeoutMs: number = 25000): Promise<HttpResult> {
    return this.send(http.RequestMethod.GET, path, '', '', false, readTimeoutMs);
  }

  /**
   * 表单 POST。readTimeoutMs 需要给长轮询单独放大：
   * 企业微信扫码接口会挂住连接 20 秒左右才回一个状态。
   */
  async postForm(path: string, fields: FormField[], ajax: boolean = false,
    readTimeoutMs: number = 25000): Promise<HttpResult> {
    const body: string = HttpClient.encodeForm(fields);
    return this.send(http.RequestMethod.POST, path, body,
      'application/x-www-form-urlencoded; charset=UTF-8', ajax, readTimeoutMs);
  }

  /** GET 二进制（验证码 JPEG 等）；字符串接口会把图片解成乱码，所以单开一条通道 */
  async getBytes(path: string): Promise<HttpBinary> {
    const url: string = this.resolveUrl(path);
    const req: http.HttpRequest = http.createHttp();
    try {
      const headers: Record<string, string> = this.baseHeaders(url, '', false);
      headers['Accept'] = 'image/jpeg,image/png,image/*,*/*;q=0.8';
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        maxLimit: 8 * 1024 * 1024,
        connectTimeout: 12000,
        readTimeout: 25000
      };
      const resp: http.HttpResponse = await req.request(url, options);
      const header: Record<string, string> = (resp.header ?? {}) as Record<string, string>;
      this.absorbCookies(header, resp, url);
      const data: ArrayBuffer = resp.result instanceof ArrayBuffer
        ? resp.result as ArrayBuffer : new ArrayBuffer(0);
      return {
        status: resp.responseCode,
        data: data,
        contentType: HttpClient.headerValue(header, 'content-type')
      };
    } finally {
      req.destroy();
    }
  }

  static encodeForm(fields: FormField[]): string {
    const parts: string[] = [];
    fields.forEach((f: FormField) => {
      parts.push(`${encodeURIComponent(f.key)}=${encodeURIComponent(f.value)}`);
    });
    return parts.join('&');
  }

  /** 从 URL 里取主机名（不含端口），用于 Cookie 分桶 */
  static hostOf(url: string): string {
    const match: RegExpMatchArray | null = url.match(/^https?:\/\/([^/?#]+)(?:[/?#]|$)/);
    if (match === null || match[1].indexOf('@') >= 0) { throw new Error('Invalid HTTP URL'); }
    return match[1].split(':')[0].toLowerCase();
  }

  private resolveUrl(path: string): string {
    const url: string = /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(path) ? path : this.base + path;
    HttpClient.hostOf(url);
    if (/[\r\n]/.test(url)) { throw new Error('Invalid HTTP URL'); }
    return url;
  }

  private static pathOf(url: string): string {
    const rest: string = url.substring(url.indexOf('://') + 3);
    const index: number = rest.search(/[/?#]/);
    if (index < 0 || rest.charAt(index) === '#') { return '/'; }
    const path: string = rest.substring(index).split('#')[0];
    return path.startsWith('?') ? '/' + path : path;
  }

  /** 响应头键名大小写不敏感；同名多个值时用换行拼接（Set-Cookie 常见） */
  private static headerValue(header: Record<string, string>, name: string): string {
    if (!header) {
      return '';
    }
    const keys: string[] = Object.keys(header);
    for (let i = 0; i < keys.length; i++) {
      if (keys[i].toLowerCase() === name) {
        const raw: string | string[] = header[keys[i]] as string | string[];
        if (Array.isArray(raw)) {
          return (raw as string[]).join('\n');
        }
        return raw as string;
      }
    }
    return '';
  }

  /** 统一的请求头：UA / 语言 / Cookie（按 host 分桶） */
  private baseHeaders(url: string, contentType: string, ajax: boolean): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['User-Agent'] =
      'Mozilla/5.0 (Linux; HarmonyOS 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36';
    headers['Accept'] = 'text/html,application/json,text/javascript,*/*;q=0.8';
    headers['Accept-Language'] = 'zh-CN,zh;q=0.9';
    if (ajax) {
      headers['X-Requested-With'] = 'XMLHttpRequest';
    }
    const cookie: string = this.jar.header(HttpClient.hostOf(url), HttpClient.pathOf(url), url.startsWith('https://'));
    if (cookie.length > 0) {
      headers['Cookie'] = cookie;
    }
    if (contentType.length > 0) {
      headers['Content-Type'] = contentType;
    }
    return headers;
  }

  /** 优先取响应头里的标准 Set-Cookie；cookies 字段是 Netscape 行，作兜底。 */
  private absorbCookies(header: Record<string, string>, resp: http.HttpResponse, url: string): void {
    let setCookie: string = HttpClient.headerValue(header, 'set-cookie');
    const fallback: string = resp.cookies ?? '';
    if (fallback.length > 0) {
      if (setCookie.length === 0) {
        setCookie = fallback;
      } else {
        // 自动跟随 3xx 时底层可能把中间跳的 Cookie 也塞进这个字段，一并吸收
        this.jar.absorb(fallback, HttpClient.hostOf(url), HttpClient.pathOf(url));
      }
    }
    if (setCookie.length > 0) {
      this.jar.absorb(setCookie, HttpClient.hostOf(url), HttpClient.pathOf(url));
    }
  }

  private async send(method: http.RequestMethod, path: string, body: string,
    contentType: string, ajax: boolean, readTimeoutMs: number = 25000): Promise<HttpResult> {
    const url: string = this.resolveUrl(path);
    const req: http.HttpRequest = http.createHttp();
    try {
      const headers: Record<string, string> = this.baseHeaders(url, contentType, ajax);
      const options: http.HttpRequestOptions = {
        method: method,
        header: headers,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        maxLimit: 8 * 1024 * 1024,
        connectTimeout: 12000,
        readTimeout: readTimeoutMs
      };
      const resp: http.HttpResponse = await req.request(url, options);
      const text: string = typeof resp.result === 'string' ? resp.result as string : '';
      const header: Record<string, string> =
        (resp.header ?? {}) as Record<string, string>;
      this.absorbCookies(header, resp, url);
      const location: string = HttpClient.headerValue(header, 'location');
      return { status: resp.responseCode, body: text, location: location };
    } finally {
      req.destroy();
    }
  }
}