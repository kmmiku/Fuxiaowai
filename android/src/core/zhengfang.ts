import { loadTerm } from './termStore';
import { Jar } from './cookieJar';
import { accountToken, isCurrent, schoolRequestToken } from './accountScope';
import { readSecretRecord, writeSecretRecord } from './secrets';
/**
 * 正方教务接入（jw.fzfu.edu.cn）
 *
 * 三个关键点：
 *  1. 请求走 CapacitorHttp（原生 OkHttp），绕开 WebView 的 CORS 与混合内容限制
 *  2. 登录页下发的是 RSA-1024 公钥，用 BigInt 直接做模幂，语义与教务前端 jsbn 一致
 *  3. Cookie 自己维护一份（手动带 Cookie 头），同时写回原生 CookieManager 给内置网页用
 */

import { Capacitor, CapacitorCookies, CapacitorHttp } from '@capacitor/core';

import { parseExams } from './exam';
import { colorIndexOf, parseWeeks, type Course, type ExamRecord, type GradeRecord } from './types';

export const JW_BASE = 'http://jw.fzfu.edu.cn';
const ROOT = `${JW_BASE}/jwglxt`;

const LOGIN_PAGE = '/xtgl/login_slogin.html';
const PUBLIC_KEY = '/xtgl/login_getPublicKey.html?time=';
const TIMETABLE = '/kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151&su=';
const GRADE_QUERY = '/cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005';
const EXAM_QUERY = '/kwgl/kscx_cxXsksxxIndex.html?doType=query&gnmkdm=N358105';
const INIT_MENU = '/xtgl/index_initMenu.html';

export const EXAM_PAGE_URL = `${ROOT}/kwgl/kscx_cxXsksxxIndex.html?gnmkdm=N358105`;

/* ============================================================
   RSA(PKCS#1 v1.5)
   ============================================================ */

function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function bytesToBigInt(bytes: Uint8Array): bigint {
  let hex = '';
  for (let i = 0; i < bytes.length; i++) hex += bytes[i].toString(16).padStart(2, '0');
  return hex.length === 0 ? 0n : BigInt('0x' + hex);
}

function bytesToB64(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}

function modPow(base: bigint, exp: bigint, mod: bigint): bigint {
  let result = 1n;
  let b = base % mod;
  let e = exp;
  while (e > 0n) {
    if ((e & 1n) === 1n) result = (result * b) % mod;
    b = (b * b) % mod;
    e >>= 1n;
  }
  return result;
}

class RsaPublicKey {
  private modulus: bigint;
  private exponent: bigint;
  private byteSize: number;

  constructor(modulusB64: string, exponentB64: string) {
    this.modulus = bytesToBigInt(b64ToBytes(modulusB64));
    this.exponent = bytesToBigInt(b64ToBytes(exponentB64));
    this.byteSize = Math.ceil(this.modulus.toString(16).length / 2);
  }

  /** 明文 UTF-8 → Base64 密文（与教务前端一致） */
  encrypt(plain: string): string {
    const msg = new TextEncoder().encode(plain);
    const k = this.byteSize;
    if (msg.length > k - 11) throw new Error('密码过长，超过 RSA 可加密长度');
    const em = new Uint8Array(k);
    em[0] = 0x00;
    em[1] = 0x02;
    const padEnd = k - msg.length - 1;
    for (let i = 2; i < padEnd; i++) {
      const random = new Uint8Array(1);
      do { crypto.getRandomValues(random); } while (random[0] === 0);
      em[i] = random[0];
    }
    em[padEnd] = 0x00;
    em.set(msg, padEnd + 1);
    const c = modPow(bytesToBigInt(em), this.exponent, this.modulus);
    const out = new Uint8Array(k);
    let v = c;
    for (let i = k - 1; i >= 0; i--) {
      out[i] = Number(v & 255n);
      v >>= 8n;
    }
    return bytesToB64(out);
  }
}

/* ============================================================
   HTTP + Cookie
   ============================================================ */

/** 从 URL 取主机名（不含端口），用于 Cookie 分桶 */
function hostOf(url: string): string {
  let s = url;
  const scheme = s.indexOf('://');
  if (scheme >= 0) s = s.slice(scheme + 3);
  const slash = s.indexOf('/');
  if (slash >= 0) s = s.slice(0, slash);
  const colon = s.indexOf(':');
  if (colon >= 0) s = s.slice(0, colon);
  return s;
}

export interface HttpResult {
  status: number;
  body: string;
  location: string;
  headers: Record<string, unknown>;
}

const native = Capacitor.isNativePlatform();

/** CapacitorHttp 的 data 有时是字符串、有时是 ArrayBuffer / 对象，统一转成文本 */
function toText(data: unknown): string {
  if (typeof data === 'string') return data;
  if (data == null) return '';
  if (data instanceof ArrayBuffer) return new TextDecoder('utf-8').decode(new Uint8Array(data));
  if (ArrayBuffer.isView(data)) {
    const view = data as unknown as { buffer: ArrayBuffer; byteOffset: number; byteLength: number };
    return new TextDecoder('utf-8').decode(new Uint8Array(view.buffer, view.byteOffset, view.byteLength));
  }
  try {
    return JSON.stringify(data);
  } catch {
    return String(data);
  }
}

/** 登录态：进程内缓存，jar 有 Cookie 才算 */
let sessionLive = false;
/** 当前会话属于哪个学号：换账号时必须对不上就拒绝导入，避免串号 */
let sessionUser = '';

export function markSession(live: boolean): void {
  if(live && !isCurrent(schoolRequestToken()))throw new Error('账号状态已改变');
  sessionLive = live;
  if (!live) sessionUser = '';
}

export function hasSession(): boolean {
  return sessionLive && jar.header(JW_HOST).length > 0;
}

/** 当前会话的学号（未知时为空串） */
export function currentSessionUser(): string {
  return sessionUser;
}

/** 会话落盘：成绩/考试页下次冷启动还能直接用，不必再登一次 */
const SESSION_KEY = 'fxw_jw_session';

export function persistJwSession(user: string): void {
  const cookie = jar.header(JW_HOST);
  if (!cookie) return;
  try {
    writeSecretRecord(SESSION_KEY, 'cookie', { user, cookie, at: Date.now(), expiresAt: jar.expiry(JW_HOST) });
  } catch {
    /* 隐私模式下写不进去就算了，只在本次进程内有效 */
  }
  if (user) sessionUser = user;
}

export function clearPersistedJwSession(): void {
  try {
    localStorage.removeItem(SESSION_KEY);
    localStorage.removeItem(`${SESSION_KEY}_migration_v1`);
  } catch {
    /* 忽略 */
  }
}

/** 把上次留下的 jw Cookie 灌回来（和鸿蒙 SessionStore.loadJw 一致） */
export function restoreJwSession(): { user: string; cookie: string; at: number } | null {
  let raw = '';
  try {
    const record = readSecretRecord(SESSION_KEY, 'cookie');
    raw = record ? JSON.stringify(record) : '';
  } catch {
    return null;
  }
  if (!raw) return null;
  try {
    const saved = JSON.parse(raw) as { user?: string; cookie?: string; at?: number; expiresAt?: number };
    if (!saved.cookie || !saved.user || Date.now() >= (saved.expiresAt ?? (saved.at ?? 0) + 86400000)) return null;
    jar.importHeader(saved.cookie, JW_HOST);
    sessionLive = true;
    sessionUser = saved.user ?? '';
    return { user: saved.user ?? '', cookie: saved.cookie, at: saved.at ?? 0 };
  } catch {
    return null;
  }
}

/**
 * 有活会话就用；没有就从存储里捞一次。成绩/考试页入口都走这里。
 * 传了学号就只认这个账号的会话——A 的 Cookie 绝不能被 B 拿去查成绩。
 */
export function ensureJwSession(user = ''): boolean {
  const want = user.trim();
  if (hasSession()) {
    if (!want || sessionUser === want) return true;
    // 进程里握着别人的会话：清掉，不拿它去查
    jar.clear();
    markSession(false);
  }
  let raw = '';
  try {
    const record = readSecretRecord(SESSION_KEY, 'cookie');
    raw = record ? JSON.stringify(record) : '';
  } catch {
    return false;
  }
  if (!raw) return false;
  try {
    const saved = JSON.parse(raw) as { user?: string; cookie?: string; at?: number; expiresAt?: number };
    if (!saved.cookie || !saved.user || Date.now() >= (saved.expiresAt ?? (saved.at ?? 0) + 86400000)) return false;
    if (want && saved.user !== want) return false;
    jar.importHeader(saved.cookie, JW_HOST);
    sessionLive = true;
    sessionUser = saved.user ?? '';
    return true;
  } catch {
    return false;
  }
}

export function sessionAccount(): string {
  return currentSessionUser();
}

/** 清掉全部 Cookie 与登录态：换账号、退出登录、导入前都要调用 */
export function clearSessionCookies(): void {
  jar.clear();
  sessionLive = false;
  sessionUser = '';
  clearPersistedJwSession();
  try {
    void clearNativeCookies().catch(() => undefined);
  } catch {
    /* WebView 未就绪时忽略 */
  }
}

/**
 * 把网页登录窗口拿到的 Cookie 灌进 jar：
 * 门户 CAS 有动态防护，纯 HTTP 提交一律被判「登录页面闲置时间过长」，
 * 所以登录这一步交给 WebView，拿到 Cookie 后课表/成绩仍走 HTTP。
 */
export function importWebviewCookies(cookies: { jw?: string; portal?: string }): boolean {
  if (cookies.portal) jar.importHeader(cookies.portal, PORTAL_HOST);
  if (cookies.jw) jar.importHeader(cookies.jw, JW_HOST);
  const live = jar.header(JW_HOST).indexOf('JSESSIONID=') >= 0;
  markSession(live);
  return live;
}

/** 网页登录要打开的地址：CAS 登录页，service 直接指到课表页 */
export function portalLoginEntryUrl(): string {
  return `${CAS_LOGIN}?service=${encodeURIComponent(JW_TIMETABLE_SERVICE)}`;
}

/** 网页登录完成后收尾：确认教务会话可用（失败会给出提示） */
export async function completePortalLogin(): Promise<LoginResult> {
  try {
    return await finishPortal(currentSemester());
  } catch (e) {
    return {
      ok: false,
      message: `统一身份认证异常：${e instanceof Error ? e.message : String(e)}`,
      semester: currentSemester()
    };
  }
}


interface RequestInitLike {
  method?: string;
  body?: string;
  /** false = 不自动跟随 302（CAS 与扫码换码必须自己接管，否则拿不到 Set-Cookie） */
  redirect?: boolean;
}

/** 相对 Location → 绝对地址；baseOrigin 取发起请求的来源域 */
export function absoluteUrl(loc: string, baseOrigin = 'http://portal.fzfu.edu.cn'): string {
  if (!loc) return '';
  return checkedUrl(new URL(loc, baseOrigin).href);
}

function originOf(url: string): string {
  const m = /^(https?:\/\/[^/]+)/i.exec(url);
  return m ? m[1] : 'http://portal.fzfu.edu.cn';
}

const SCHOOL_HOSTS = new Set(['jw.fzfu.edu.cn','portal.fzfu.edu.cn','open.work.weixin.qq.com']);
function checkedUrl(address: string): string {
  const url = new URL(address);
  if (!['http:','https:'].includes(url.protocol) || !SCHOOL_HOSTS.has(url.hostname) || url.username || url.password ||
    (url.port && url.port !== (url.protocol === 'https:' ? '443' : '80'))) throw new Error('学校请求目标不受支持');
  return url.href;
}
async function request(path: string, init: RequestInitLike = {}, cookieJar?: Jar): Promise<HttpResult> {
  const token = schoolRequestToken();
  let url = checkedUrl(path.startsWith('http') ? path : ROOT + path);
  let method = init.method ?? 'GET', data = init.body;
  const check = () => { if (!isCurrent(token)) throw new Error('账号状态已改变，请重试'); };
  for (let hop=0; hop<=8; hop++) {
    check();
    const headers: Record<string,string> = {Accept:'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8','Accept-Language':'zh-CN,zh;q=0.9'};
    const cookie = cookieJar?.header(url); if (cookie) headers.Cookie=cookie;
    if(method==='POST')headers['Content-Type']='application/x-www-form-urlencoded';
    let result: HttpResult;
    if (native) {
      const res = await CapacitorHttp.request({url,method,headers,data,responseType:'text',connectTimeout:15000,readTimeout:20000,disableRedirects:true});
      check();
      const h=(res.headers??{}) as Record<string,unknown>;
      cookieJar?.absorb(h,url);
      result={status:res.status??0,body:toText(res.data),location:String(h.location??h.Location??''),headers:h};
    } else {
      const controller=new AbortController(); const timer=setTimeout(()=>controller.abort(),20000);
      try {
        const res=await fetch(url,{method,headers,body:data,credentials:'include',redirect:'manual',signal:controller.signal});
        const body=await res.text(); check();
        result={status:res.status,body,location:res.headers.get('location')??'',headers:{}};
      } finally { clearTimeout(timer); }
    }
    if(new TextEncoder().encode(result.body).length>8*1024*1024)throw new Error('学校响应超过大小限制');
    if(init.redirect===false||![301,302,303,307,308].includes(result.status)||!result.location)return result;
    if(hop===8)throw new Error('学校重定向次数过多');
    const next=absoluteUrl(result.location,url);
    if(result.status===303||((result.status===301||result.status===302)&&method==='POST')){method='GET';data=undefined;}
    if(data && new URL(next).origin!==new URL(url).origin)throw new Error('拒绝跨站转发认证表单');
    url=next;
  }
  throw new Error('学校请求失败');
}

/** 手动跟随 302，逐跳吞下 Set-Cookie（原生不自动管理 Cookie） */
async function followRedirects(start: string, maxHops = 8): Promise<HttpResult> {
  // request() expands app-relative paths under ROOT; use that same absolute
  // address as the base for Location, including the first CAS bridge hop.
  let url = checkedUrl(start.startsWith('http') ? start : ROOT + start);
  let res = await request(url, { redirect: false }, jar);
  for (let i = 0; i < maxHops; i += 1) {
    if (res.status < 300 || res.status >= 400 || !res.location) return res;
    url = absoluteUrl(res.location, url);
    res = await request(url, { redirect: false }, jar);
  }
  throw new Error('学校重定向次数过多');
}

/** 取二进制图片（验证码、二维码），返回可直接给 <img> 的 data URL */
async function fetchImage(url: string): Promise<string> {
  checkedUrl(url);
  const token = schoolRequestToken();
  const host = hostOf(url);
  const headers: Record<string, string> = { Accept: 'image/avif,image/webp,image/*,*/*;q=0.8' };
  const cookie = jar.header(host);
  if (cookie) headers['Cookie'] = cookie;

  if (native) {
    const res = await CapacitorHttp.request({
      url,
      method: 'GET',
      headers,
      responseType: 'arraybuffer',
      connectTimeout: 15000,
      readTimeout: 20000
    });
    if (!isCurrent(token)) throw new Error('账号状态已改变');
    jar.absorb((res.headers ?? {}) as Record<string, unknown>, url);
    // arraybuffer 在原生侧以 base64 字符串回来
    const b64 = typeof res.data === 'string' ? res.data : '';
    if (res.status !== 200 || b64.length > 4*1024*1024) throw new Error('图片下载失败或过大');
    return b64 ? `data:image/png;base64,${b64}` : '';
  }

  const r = await fetch(url, { headers, credentials: 'include', cache: 'no-store' });
  if (!r.ok) return '';
  return bytesToDataUrl(new Uint8Array(await r.arrayBuffer()));
}

function bytesToDataUrl(bytes: Uint8Array): string {
  return `data:image/png;base64,${bytesToB64(bytes)}`;
}

/** 把 cookie 写回原生 CookieManager，内置网页才能复用登录态 */
let nativeCookieTail:Promise<unknown>=Promise.resolve();
function mutateNativeCookies<T>(action:()=>Promise<T>):Promise<T>{
  const task=nativeCookieTail.then(action);nativeCookieTail=task.catch(()=>undefined);return task;
}
export function clearNativeCookies():Promise<void>{
  return mutateNativeCookies(async()=>{await CapacitorCookies.clearAllCookies();});
}
export function syncCookiesToWebView(jarHeader:string):Promise<void>{
  const token=schoolRequestToken();
  return mutateNativeCookies(async()=>{
    if(!native||!jarHeader)return;
    const check=()=>{if(!isCurrent(token))throw new Error('账号状态已改变');};
    check();
    const pairs=jarHeader.split(';').map(s=>s.trim()).filter(Boolean);
    for(const scope of [JW_BASE,`${JW_BASE}/jwglxt/`])for(const pair of pairs){
      const eq=pair.indexOf('=');if(eq<1)continue;
      check();
      await CapacitorCookies.setCookie({url:scope,key:pair.slice(0,eq),value:pair.slice(eq+1),path:scope.endsWith('/jwglxt/')?'/jwglxt':'/'});
      check();
    }
  });
}

function form(fields: [string,string][]):string {
  return fields.map(([key,value])=>`${encodeURIComponent(key)}=${encodeURIComponent(value)}`).join('&');
}

/* ============================================================
   学期
   ============================================================ */

export interface Semester {
  xnm: number;
  xqm: number;
  label: string;
}

/** 从当前课表读取已配置的学期标识，不按设备月份推算。 */
export function currentSemester(now: Date = new Date()): Semester {
  const term=loadTerm();
  return {xnm:term.year,xqm:term.term,label:term.label};
}

/* ============================================================
   会话
   ============================================================ */

const jar = new Jar();

/** jw 的主机名：Cookie 分桶与 WebView 注入都用它 */
const JW_HOST = 'jw.fzfu.edu.cn';
const PORTAL_HOST = 'portal.fzfu.edu.cn';

export function cookieHeader(): string {
  return jar.header(JW_HOST);
}

export interface LoginResult {
  ok: boolean;
  message: string;
  semester: Semester;
  /** 非空 = 统一身份认证要图片验证码；值是可直接给 <img> 的 data URL */
  captcha?: string;
}

/**
 * 登录。走哪条路由登录页的圆形单选决定：
 *   - 教务登录入口（jwglxt 直登）
 *   - 教学综合平台入口（portal CAS 统一身份认证）
 * 选的那条失败时才回落另一条；要验证码时直接交回界面，不回落。
 */
export type LoginMode = 'jw' | 'portal';

let loginMode: LoginMode = 'jw';

/** 由登录页在提交前设置 */
export function setLoginMode(mode: LoginMode): void {
  loginMode = mode === 'portal' ? 'portal' : 'jw';
}

export function getLoginMode(): LoginMode {
  return loginMode;
}

export async function login(user: string, pwd: string, code?: string): Promise<LoginResult> {
  const semester = currentSemester();

  // 换账号登录：先把上一个人的会话彻底扔掉，否则服务端会按旧 Cookie 把这台机器当成旧账号
  if (code === undefined) {
    clearSessionCookies();
    await clearNativeCookies();
    if (!isCurrent(schoolRequestToken())) return {ok:false,message:'账号状态已改变',semester};
  }

  // 第二次提交：带验证码，复用第一次握手留下的 CAS 会话
  if (code !== undefined) {
    const posted = await casSubmit(pwd, code);
    if (!posted.ok) return { ok: false, message: posted.message, semester, captcha: posted.captcha };
    return finishPortal(semester);
  }

  if (loginMode === 'portal') {
    const portal = await loginViaPortal(user, pwd, semester);
    if (portal.ok) sessionUser = user;
    if (portal.ok || portal.captcha) return portal;

    const direct = await loginDirect(user, pwd, semester);
    if (direct.ok) sessionUser = user;
    return direct.ok ? direct : { ok: false, message: portal.message, semester };
  }

  const direct = await loginDirect(user, pwd, semester);
  if (direct.ok) {
    sessionUser = user;
    return direct;
  }

  try {
    const cas = await loginViaPortal(user, pwd, semester);

    if (cas.ok) sessionUser = user;
    if (cas.ok || cas.captcha) return cas;
    return { ok: false, message: direct.message || cas.message, semester };
  } catch {
    return { ok: false, message: direct.message, semester };
  }
}

/** 走教学综合平台（portal CAS），成功后用 SSO 换出 jw 会话 */
async function loginViaPortal(user: string, pwd: string, semester: Semester): Promise<LoginResult> {
  try {
    const prep = await casPrepare(user);
    if (!prep.ok) return { ok: false, message: prep.message, semester };

    // 要验证码就把图交回界面，别再往下猜
    if (prep.challenge.captchaRequired) {
      return {
        ok: false,
        message: '教务系统要求输入验证码',
        semester,
        captcha: await refreshCasCaptcha()
      };
    }

    const posted = await casSubmit(pwd, '');

    if (!posted.ok) return { ok: false, message: posted.message, semester, captcha: posted.captcha };
    return finishPortal(semester);
  } catch (e) {
    return {
      ok: false,
      message: `统一身份认证异常：${e instanceof Error ? e.message : String(e)}`,
      semester
    };
  }
}

/** CAS 会话已建立：去教务的 CAS 入口换 ticket，再用首页确认 jw 会话 */
async function finishPortal(semester: Semester): Promise<LoginResult> {
  const bridge = await followRedirects('/xtgl/login_cas.html');

  const menu = await request(INIT_MENU, {}, jar);
  if (menu.status === 200 && menu.body.indexOf('login_slogin') < 0) {
    await syncCookiesToWebView(jar.header(JW_HOST));
    markSession(true);
    return { ok: true, message: '登录成功（教学综合平台）', semester };
  }
  return { ok: false, message: '统一身份认证通过，但教务会话未建立', semester };
}

/** 教务直登（jwglxt 表单 + csrftoken + PKCS#1 v1.5） */
async function loginDirect(user: string, pwd: string, semester: Semester): Promise<LoginResult> {
  jar.clear();

  const page = await request(LOGIN_PAGE, {}, jar);
  if (page.status !== 200) {
    return { ok: false, message: `教务系统无法访问（HTTP ${page.status}）`, semester };
  }
  // csrftoken 只是防跨站，正方服务端并不强制；取不到时留空照样能登录（实测通过）
  const token = extractCsrf(page.body);
  if (!token) {

  }

  const pkResp = await request(PUBLIC_KEY + Date.now(), {}, jar);
  let pk: { modulus?: string; exponent?: string };
  try {
    pk = JSON.parse(pkResp.body);
  } catch {
    return { ok: false, message: '公钥接口返回异常，可能被重定向到登录页', semester };
  }
  if (!pk.modulus || !pk.exponent) {
    return { ok: false, message: '公钥接口缺少 modulus/exponent', semester };
  }

  const rsa = new RsaPublicKey(pk.modulus, pk.exponent);
  const encrypted = rsa.encrypt(pwd);

  const res = await request(
    LOGIN_PAGE,
    {
      method: 'POST',
      body: form([
        ['yhm', user],
        ['mm', encrypted],
        ['csrftoken', token],
        ['language', 'zh_CN'],
        ['mmsfjm', '1'],
        ['dlsfbxyzm', '0'],
        ['yzcskz', '3']
      ])
    },
    jar
  );

  if (res.body.indexOf('用户名或密码不正确') >= 0) {
    return { ok: false, message: '学号或密码不正确', semester };
  }
  if (res.body.indexOf('id="yzm"') >= 0) {
    return { ok: false, message: '教务要求输入验证码，请先用浏览器登录一次解除', semester };
  }

  // 重定向会被原生 HTTP 自动跟随，所以用「首页能不能打开」判断是否登录成功
  const menu = await request(INIT_MENU, {}, jar);
  const loggedIn = menu.status === 200 && menu.body.indexOf('login_slogin') < 0;
  if (!loggedIn) {
    return { ok: false, message: `登录未通过（HTTP ${res.status}）`, semester };
  }

  await syncCookiesToWebView(jar.header(JW_HOST));
  markSession(true);
  return { ok: true, message: '登录成功', semester };
}

/**
 * 成绩 / 考试 / 学期都要求已登录：冷启动后 jar 是空的，
 * 先用本机保存的凭据静默登录一次，避免逐个接口 302 到登录页。
 */
export async function ensureLogin(user: string, pwd: string): Promise<boolean> {
  // 会话必须是这个学号的，否则宁可重登一次，也不能拿别人的会话去查成绩/考试
  if (hasSession() && (!user || currentSessionUser() === user)) return true;
  if (!user || !pwd) return false;
  const r = await login(user, pwd);
  return r.ok;
}

export function extractCsrf(html: string): string {
  const m = /id="csrftoken"[^>]*value="([^"]+)"/.exec(html);
  return m ? m[1] : '';
}

/* ============================================================
   课表
   ============================================================ */

export interface RawCourse {
  kch?: string;
  kcmc?: string;
  xm?: string;
  cdmc?: string;
  xqmc?: string;
  xqj?: string;
  jcs?: string;
  zcd?: string;
}

export interface RawStudent {
  XM?: string;
  XH?: string;
  BJMC?: string;
  ZYMC?: string;
  XNMC?: string;
  XQMMC?: string;
}

export interface FetchTimetableResult {
  courses: Course[];
  student: RawStudent;
  dropped: number;
}

export function parsePeriods(text: string): number[] {
  const clean = text.replace('节', '').trim();
  const parts = clean.split('-');
  const start = parseInt(parts[0], 10);
  if (isNaN(start)) return [];
  const end = parts.length > 1 ? parseInt(parts[1], 10) : start;
  return [start, isNaN(end) ? start : end];
}

export function parseTimetable(json: string): FetchTimetableResult {
  const data = JSON.parse(json) as { kbList?: RawCourse[]; xsxx?: RawStudent };
  const list = data.kbList ?? [];
  const out: Course[] = [];
  const seen = new Set<string>();
  let dropped = 0;

  for (const raw of list) {
    const name = (raw.kcmc ?? '').trim();
    const weekday = parseInt(raw.xqj ?? '', 10);
    const span = parsePeriods(raw.jcs ?? '');
    const weeks = parseWeeks(raw.zcd ?? '');
    if (!name || isNaN(weekday) || span.length < 2 || weeks.length === 0) {
      dropped++;
      continue;
    }
    const id = `${raw.kch ?? name}_${weekday}_${span[0]}_${span[1]}_${weeks.join('.')}`;
    if (seen.has(id)) continue;
    seen.add(id);
    out.push({
      id,
      name,
      teacher: (raw.xm ?? '').trim(),
      room: (raw.cdmc ?? '').trim(),
      campus: (raw.xqmc ?? '').trim(),
      weekday,
      startPeriod: span[0],
      endPeriod: span[1],
      weeks,
      colorIndex: colorIndexOf(name)
    });
  }

  out.sort((a, b) => (a.weekday - b.weekday) || (a.startPeriod - b.startPeriod));
  return { courses: out, student: data.xsxx ?? {}, dropped };
}

export async function fetchTimetable(user: string, semester: Semester): Promise<FetchTimetableResult> {
  const res = await request(
    TIMETABLE + encodeURIComponent(user),
    {
      method: 'POST',
      body: form([
        ['xnm', String(semester.xnm)],
        ['xqm', String(semester.xqm)],
        ['kzlx', 'ck']
      ])
    },
    jar
  );
  if (res.status !== 200) throw new Error(`课表接口 HTTP ${res.status}`);
  if (res.body.indexOf('"kbList"') < 0) throw new Error('课表接口未返回 kbList，可能登录状态失效');
  const parsed=parseTimetable(res.body);
  const raw=JSON.parse(res.body);
  const reportedYear=String(raw.xsxx?.XNMC ?? '').match(/^(\d{4})/);
  if(reportedYear && Number(reportedYear[1])!==semester.xnm)throw new Error('学校学期标识与课表配置不一致，原课表已保留');
  return parsed;
}

/* ============================================================
   成绩 / 考试
   ============================================================ */

/** 教务错误页 <p class="error_title">无功能权限</p> 翻成人话（与鸿蒙 explainJwError 一致） */
export function jwErrorText(body: string): string {
  const m = /class="error_title">([^<]*)</.exec(body);
  const title = m ? m[1].trim() : '';
  if (title.indexOf('无功能权限') >= 0) {
    return '教务未给该账号开放这个查询权限（教务提示：无功能权限），请联系教务处开通';
  }
  if (title.length > 0 && title !== '错误提示') return `教务拒绝查询：${title}`;
  return '教务没有返回数据，可能登录状态失效';
}

/**
 * 成绩/考试接口的返回校验。
 * 判登录态不能只看状态码：教务会 200 回登录页（`id="fm1"` 或 login_slogin），
 * 以前只判 HTTP 200，于是被当成「这学期没成绩」——成绩页永远空。
 */
function assertJwJson(body: string, status: number, what: string): void {
  if (status !== 200) throw new Error(`${what} HTTP ${status}`);
  if (body.indexOf('"items"') >= 0) return;
  if (body.indexOf('id="fm1"') >= 0 || body.indexOf('login_slogin') >= 0 || body.indexOf('/cas/login') >= 0) {
    throw new Error('登录状态已过期，请回首页重新导入课表');
  }
  if (body.indexOf('error_title') >= 0) throw new Error(jwErrorText(body));
  throw new Error(`${what}返回异常（${body.length} 字节）`);
}

export async function fetchGrades(xnm: number, xqm: number): Promise<GradeRecord[]> {
  const all: GradeRecord[]=[]; const pages=new Set<string>();
  for(let page=1;page<=100;page++) {
    const res=await request(GRADE_QUERY,{method:'POST',body:form([
      ['xnm',String(xnm)],['xqm',String(xqm)],['_search','false'],['nd',String(Date.now())],
      ['queryModel.showCount','100'],['queryModel.currentPage',String(page)],
      ['queryModel.sortName',''],['queryModel.sortOrder','asc'],['time','1']
    ])},jar);
    assertJwJson(res.body,res.status,'成绩接口');
    const data=JSON.parse(res.body);
    if(!Array.isArray(data.items))throw new Error('成绩数据不完整');
    if(data.currentPage!==undefined && Number(data.currentPage)!==page)throw new Error('成绩分页未完整返回');
    const fingerprint=JSON.stringify(data.items);
    if(data.items.length && pages.has(fingerprint))throw new Error('成绩分页重复');
    pages.add(fingerprint);
    all.push(...parseGrades(res.body).map((g,i)=>({...g,id:`${xnm}_${xqm}_${g.id}_${(page-1)*100+i}`})));
    const total=data.total===undefined?undefined:Number(data.total);
    const records=data.records===undefined?undefined:Number(data.records);
    if((total!==undefined&&(!Number.isInteger(total)||total<0))||(records!==undefined&&(!Number.isInteger(records)||records<0)))throw new Error('成绩分页计数不正确');
    if(records!==undefined&&all.length>records)throw new Error('成绩数量发生变化，请重试');
    if(total!==undefined&&(page>=total)) {
      if((total===0&&all.length>0)||(records!==undefined&&all.length!==records))throw new Error('成绩分页缺失，旧缓存已保留');
      return all;
    }
    if(records!==undefined&&all.length===records){
      if(total!==undefined&&page<total)throw new Error('成绩分页计数不一致');
      return all;
    }
    if(!data.items.length){
      if(total!==undefined||records!==undefined)throw new Error('成绩分页缺失');
      return all;
    }
    if(total===undefined&&records===undefined&&data.items.length<100)return all;
  }
  throw new Error('成绩分页超过保护上限，旧缓存已保留');
}

function num(v: unknown): number {
  const n = parseFloat(String(v ?? ''));
  return isNaN(n) ? 0 : n;
}

export function parseGrades(json: string): GradeRecord[] {
  interface Raw {
    kcmc?: string;
    xf?: string;
    cj?: string;
    jd?: string;
    xnmc?: string;
    kcxz?: string;
    kch?: string;
  }
  const data = JSON.parse(json) as { items?: Raw[] };
  const items = data.items ?? [];
  return items.map((r, i) => ({
    id: `${r.kch ?? 'g'}_${i}`,
    course: (r.kcmc ?? '').trim(),
    credit: num(r.xf),
    score: num(r.cj),
    gpa: num(r.jd),
    term: (r.xnmc ?? '').trim(),
    nature: (r.kcxz ?? '').trim()
  }));
}

export async function fetchExams(xnm: number, xqm: number): Promise<ExamRecord[]> {
  const res = await request(
    EXAM_QUERY,
    {
      method: 'POST',
      body: form([
        ['xnm', String(xnm)],
        ['xqm', String(xqm)],
        ['ksmcdmb_id', ''],
        ['kch', ''],
        ['kc', ''],
        ['kskc', ''],
        ['kssj', ''],
        ['cxbj', ''],
        ['fxbj', ''],
        ['_search', 'false'],
        ['nd', String(Date.now())],
        ['queryModel.showCount', '100'],
        ['queryModel.currentPage', '1'],
        ['queryModel.sortName', ''],
        ['queryModel.sortOrder', 'asc'],
        ['time', '0']
      ])
    },
    jar
  );
  if (res.status !== 200) throw new Error(`考试安排接口 HTTP ${res.status}`);
  assertJwJson(res.body, res.status, '考试安排接口');
  const list = parseExams(res.body);

  return list;
}

/* ============================================================
   统一身份认证（CAS，portal.fzfu.edu.cn）
   ============================================================ */

const CAS_BASE = 'http://portal.fzfu.edu.cn/cas';
const CAS_LOGIN = `${CAS_BASE}/login`;
const CAS_PUBKEY = `${CAS_BASE}/v2/getPubKey`;
const CAS_KAPTCHA = `${CAS_BASE}/v2/getKaptchaStatus`;
const JW_CAS_ENTRY = 'http://jw.fzfu.edu.cn/jwglxt/xtgl/login_cas.html';
/** 换票的 service：一定要指到课表页，和鸿蒙 CasAuth 一致 */
const JW_TIMETABLE_SERVICE =
  'http://jw.fzfu.edu.cn/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default';

/**
 * CAS 密码加密（复刻 security.js 的 RSAUtils.encryptedString）：
 *   1. 明文整体反转（登录页 login.js 里做的）
 *   2. 字节按小端拼成大整数（jsbn digits[j] = a[k] + (a[k+1] << 8)）
 *   3. c = m^e mod n，无任何填充
 *   4. 输出大端十六进制（偶数长度）
 * 已用 node 跑原版 security.js 与 Python 双端比对，四组密码全部一致。
 */
export function casEncrypt(pwd: string, modulusHex: string, expHex: string): string {
  const reversed = Array.from(pwd).reverse().join('');
  let m = 0n;
  for (let i = reversed.length - 1; i >= 0; i--) {
    m = (m << 8n) | BigInt(reversed.charCodeAt(i) & 0xff);
  }
  const c = modPow(m, BigInt('0x' + modulusHex), BigInt('0x' + expHex));
  let hex = c.toString(16);
  if (hex.length % 2 !== 0) hex = '0' + hex;
  return hex;
}

function extractExecution(html: string): string {
  const m = /name="execution"\s+value="([^"]+)"/.exec(html);
  if (m) return m[1];
  const m2 = /value="([^"]+)"[^>]*name="execution"/.exec(html);
  return m2 ? m2[1] : '';
}

/**
 * CAS 握手第一步：教务 CAS 入口 → 登录页取 execution → 验证码开关 → 公钥。
 * 结果留在模块级 casChallenge 里，验证码第二次提交时直接用。
 */
interface CasChallenge {
  casUrl: string;
  execution: string;
  modulus: string;
  exponent: string;
  captchaRequired: boolean;
  user: string;
}

let casChallenge: CasChallenge | null = null;

async function casPrepare(
  user: string
): Promise<{ ok: true; challenge: CasChallenge } | { ok: false; message: string }> {
  // 1) 打教务的 CAS 入口，拿 jw 的 JSESSIONID 与带 service 的 CAS 地址
  let casUrl = `${CAS_LOGIN}?service=${encodeURIComponent(JW_CAS_ENTRY)}`;
  try {
    const kick = await request(JW_CAS_ENTRY, {}, jar);
    if (kick.location.includes('/cas/login')) casUrl = absoluteUrl(kick.location);
  } catch {
    /* 用默认地址继续 */
  }

  // 2) 打开登录页取 execution
  const page = await request(casUrl, {}, jar);
  if (page.status !== 200) return { ok: false, message: `统一身份认证无法访问（HTTP ${page.status}）` };
  const execution = extractExecution(page.body);
  if (!execution) return { ok: false, message: '统一身份认证页面结构变化：未取到 execution' };

  // 3) 验证码开关
  let captchaRequired = false;
  try {
    const kap = await request(CAS_KAPTCHA, {}, jar);
    captchaRequired = kap.body.includes('true');
  } catch {
    /* 忽略，先按不需要处理 */
  }

  // 4) 公钥
  const pkResp = await request(`${CAS_PUBKEY}?t=${Date.now()}`, {}, jar);
  let key: { modulus?: string; exponent?: string };
  try {
    key = JSON.parse(pkResp.body);
  } catch {
    return { ok: false, message: '统一身份认证公钥接口异常' };
  }
  if (!key.modulus || !key.exponent) {
    return { ok: false, message: '统一身份认证公钥缺少 modulus/exponent' };
  }

  casChallenge = {
    casUrl,
    execution,
    modulus: key.modulus,
    exponent: key.exponent,
    captchaRequired,
    user
  };
  return { ok: true, challenge: casChallenge };
}

/** 换一张验证码图：每次 GET 都会让上一张作废 */
export async function refreshCasCaptcha(): Promise<string> {
  try {
    return await fetchImage(`${CAS_BASE}/kaptcha?time=${Date.now()}`);
  } catch {
    return '';
  }
}

/** CAS 握手第二步：加密提交；302 自己接管，ticket 与 Set-Cookie 都要留住 */
async function casSubmit(pwd: string, code: string): Promise<{ ok: boolean; message: string; captcha?: string }> {
  const ch = casChallenge;
  if (!ch) return { ok: false, message: '登录会话已过期，请重新点一次登录' };

  if (ch.captchaRequired && code.length === 0) {
    return { ok: false, message: '请输入图片中的字符', captcha: await refreshCasCaptcha() };
  }

  const encrypted = casEncrypt(pwd, ch.modulus, ch.exponent);
  const body = new URLSearchParams();
  body.set('username', ch.user);
  body.set('password', encrypted);
  body.set('authcode', code);
  body.set('execution', ch.execution);
  body.set('_eventId', 'submit');
  body.set('rememberMe', 'true');

  const post = await request(
    `${CAS_LOGIN}?v=${Date.now()}`,
    { method: 'POST', body: body.toString(), redirect: false },
    jar
  );

  const ticketUrl = absoluteUrl(post.location);
  if (post.status === 302 && ticketUrl.includes('ticket=')) {
    const landing = await followRedirects(ticketUrl);
    if (landing.status !== 200 && landing.status !== 302) {
      return { ok: false, message: `票据校验失败（HTTP ${landing.status}）` };
    }
    casChallenge = null;
    return { ok: true, message: '登录成功' };
  }

  // 失败页：换新 execution 方便重试，并按文案区分类别
  const fresh = extractExecution(post.body);
  if (fresh) ch.execution = fresh;

  const errRaw =
    /id="errormsg"[^>]*>([\s\S]{0,200}?)</i.exec(post.body)?.[1] ??
    /id="msg"[^>]*>([\s\S]{0,200}?)</i.exec(post.body)?.[1] ??
    '';
  const err = errRaw.replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();

  if (err.includes('验证码')) {
    return { ok: false, message: '验证码不正确，请重新输入', captcha: await refreshCasCaptcha() };
  }
  if (err.includes('密码') || post.body.includes('用户名或密码错误')) {
    return { ok: false, message: '账号或密码不正确' };
  }
  if (err.includes('闲置') || err.includes('过期')) {
    return { ok: false, message: '页面已过期，请重新点一次登录' };
  }
  if (/authcode|验证码/.test(post.body.slice(0, 3000)) && ch.captchaRequired) {
    return { ok: false, message: '验证码不正确，请重新输入', captcha: await refreshCasCaptcha() };
  }
  return { ok: false, message: err ? `验证失败：${err}` : `统一身份认证未通过（HTTP ${post.status}）` };
}

/* ============================================================
   企业微信扫码登录
   ============================================================ */

const WEcom_APPID = 'ww6854f7b058a8cb51';
const WEcom_AGENTID = '1000019';
const QR_REDIRECT = 'https://portal.fzfu.edu.cn/cas/login?client_name=QyWeiXinClient';
const QR_CONNECT =
  'https://open.work.weixin.qq.com/wwopen/sso/qrConnect' +
  `?appid=${WEcom_APPID}&agentid=${WEcom_AGENTID}` +
  `&redirect_uri=${encodeURIComponent(QR_REDIRECT)}&state=STATE`;
const QR_IMG = 'https://open.work.weixin.qq.com/wwopen/sso/qrImg?key=';
const QR_POLL = 'https://open.work.weixin.qq.com/wwopen/sso/l/qrConnect?key=';

export interface QrTicket {
  key: string;
  /** 二维码图片（data URL） */
  image: string;
}

export type QrState = 'wait' | 'scanned' | 'expired' | 'cancel' | 'done';

export interface QrPollResult {
  state: QrState;
  code: string;
}

/** 取一张新二维码 */
export async function qrStart(): Promise<QrTicket> {
  const page = await request(QR_CONNECT, {}, jar);
  const key = /"key"\s*:\s*"([0-9A-Za-z]+)"/.exec(page.body)?.[1] ?? '';
  if (!key) throw new Error('未取到二维码 key');
  const image = await fetchImage(QR_IMG + encodeURIComponent(key));
  if (!image) throw new Error('二维码图片下载失败');
  return { key, image };
}

/** 轮询扫码状态（企业微信这一侧最多挂 20s，回来一次就继续下一次） */
export async function qrPoll(key: string): Promise<QrPollResult> {
  const res = await request(`${QR_POLL}${encodeURIComponent(key)}`, {}, jar);
  const status = (/"status"\s*:\s*"([A-Z_]+)"/.exec(res.body)?.[1] ?? '').toUpperCase();
  const code = /"auth_code"\s*:\s*"([^"]+)"/.exec(res.body)?.[1] ?? '';
  if (status.startsWith('QRCODE_SCAN_SUCC')) return { state: 'done', code };
  if (status.startsWith('QRCODE_SCAN_WAIT') || status.startsWith('QRCODE_SCAN_ING')) {
    return { state: 'scanned', code: '' };
  }
  if (status.startsWith('QRCODE_CANCEL') || status.startsWith('QRCODE_SCAN_CANCEL')) {
    return { state: 'cancel', code: '' };
  }
  if (
    status.startsWith('QRCODE_EXPIRED') ||
    status.startsWith('QRCODE_SCAN_EXPIRED') ||
    status.startsWith('QRCODE_SCAN_ERR')
  ) {
    return { state: 'expired', code: '' };
  }
  return { state: 'wait', code: '' };
}

/** 用扫码拿到的 code 换 CAS 会话，再换 jw 会话 */
export async function qrLogin(code: string): Promise<LoginResult> {
  const semester = currentSemester();
  const url =
    'http://portal.fzfu.edu.cn/cas/login?client_name=QyWeiXinClient' +
    `&code=${encodeURIComponent(code)}&state=STATE`;
  try {
    const res = await request(url, { redirect: false }, jar);
    if (res.body.includes('runTimeAccountError') || res.body.includes('获取用户信息失败')) {
      return { ok: false, message: '企业微信未返回用户信息，请重新扫码', semester };
    }
    if (!jar.header('portal.fzfu.edu.cn')) {
      return { ok: false, message: '统一身份认证未建立会话，请改用密码登录', semester };
    }
    return finishPortal(semester);
  } catch (e) {
    return {
      ok: false,
      message: `扫码登录异常：${e instanceof Error ? e.message : String(e)}`,
      semester
    };
  }
}

