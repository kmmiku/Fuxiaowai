import { accountKey, accountToken, accountUser, isCurrent, schoolTask } from './accountScope';
/**
 * 成绩离线缓存 + 拉取
 *
 * 为什么单独一层：
 * - 二维码登录只拿到「短暂的教务校验权限」，没有密码，随时可能过期；
 *   所以登录成功那一刻就在后台把成绩抓下来存好，之后即使断网/过期也能看。
 * - 缓存和课表一样按学号分开存（fxw_a_<学号>_grades），换账号绝不会串。
 */

import type { GradeRecord } from './types';
import {
  clearPersistedJwSession,
  currentSemester,
  ensureJwSession,
  fetchGrades,
  login,
  markSession,
  persistJwSession
} from './zhengfang';
import { silentPortalLogin } from './portal';

export interface TermGrades {
  xnm: number;
  xqm: number;
  label: string;
  items: GradeRecord[];
}

export interface GradeSummary {
  count: number;
  credits: number;
  weightedScore: number;
  weightedGpa: number;
  failed: number;
  best: number;
}

export interface GradesSnapshot {
  user?: string;
  /** 抓取成功的时间戳 */
  at: number;
  terms: TermGrades[];
  items: GradeRecord[];
  summary: GradeSummary;
}

/** 学期码转中文（对齐鸿蒙 Grade.ets termName） */
export function termName(xqm: number): string {
  if (xqm === 3) return '第一学期';
  if (xqm === 12) return '第二学期';
  if (xqm === 16) return '第三学期';
  return `第${xqm}学期`;
}

export function termLabelOf(xnm: number, xqm: number): string {
  return `${xnm}-${xnm + 1} ${termName(xqm)}`;
}

/** 汇总：加权平均分 / 加权绩点 / 总学分 / 不及格门数 */
export function summarize(items: GradeRecord[]): GradeSummary {
  let credits = 0;
  let scoreSum = 0;
  let gpaSum = 0;
  let failed = 0;
  let best = 0;
  for (const g of items) {
    const c = g.credit > 0 ? g.credit : 0;
    credits += c;
    scoreSum += g.score * c;
    gpaSum += g.gpa * c;
    if (g.score > 0 && g.score < 60) failed++;
    if (g.score > best) best = g.score;
  }
  return {
    count: items.length,
    credits: Math.round(credits * 100) / 100,
    weightedScore: credits > 0 ? Math.round((scoreSum / credits) * 10) / 10 : 0,
    weightedGpa: credits > 0 ? Math.round((gpaSum / credits) * 100) / 100 : 0,
    failed,
    best
  };
}

function cacheKey(user: string): string {
  const u = accountKey(user);
  return `fxw_a_${u || 'anon'}_grades`;
}

export function loadGradesCache(user: string): GradesSnapshot | null {
  if (!user) return null;
  try {
    const raw = localStorage.getItem(cacheKey(user));
    if (!raw) return null;
    const snap = JSON.parse(raw) as GradesSnapshot;
    if (!snap || !Array.isArray(snap.items) || !Array.isArray(snap.terms) || typeof snap.at !== 'number' || (snap.user && snap.user !== user)) return null;
    return snap;
  } catch {
    return null;
  }
}

export function saveGradesCache(user: string, snap: GradesSnapshot): void {
  if (!user) return;
  try {
    localStorage.setItem(cacheKey(user), JSON.stringify({...snap, user}));
  } catch {
    throw new Error('成绩缓存保存失败，旧缓存已保留');
  }
}

export function clearGradesCache(user: string): void {
  if (!user) return;
  try {
    localStorage.removeItem(cacheKey(user));
  } catch {
    /* 忽略 */
  }
}

export interface SyncGradesResult {
  ok: boolean;
  /** 抓到的新数据（离线/过期时为空） */
  snapshot?: GradesSnapshot;
  message?: string;
  /** 教务会话失效 */
  expired?: boolean;
}

/**
 * 登录态 → 逐学期拉成绩 → 汇总。会话有效即用，没会话才用账号密码（再不行走静默网页登录）。
 * 成功时返回 snapshot 供缓存；失败时不动已有缓存。
 */
const inflight = new Map<string, Promise<SyncGradesResult>>();
export function syncGrades(cred: { user: string; pwd: string }): Promise<SyncGradesResult> {
  const user = (cred?.user ?? '').trim();
  if (!user || accountUser() !== user) return Promise.resolve({ok:false,message:'账号状态已改变，请重新验证身份'});
  const token = accountToken();
  const key = JSON.stringify([user, token]);
  const existing = inflight.get(key);
  if (existing) return existing;
  const task = schoolTask(token, () => collectGrades(cred, token)).catch(() => ({ok:false,message:'账号状态已改变或无法连接教务系统'}));
  inflight.set(key, task);
  void task.finally(() => { if (inflight.get(key) === task) inflight.delete(key); });
  return task;
}
async function collectGrades(cred: {user:string;pwd:string}, token: number): Promise<SyncGradesResult> {
  const user = cred.user;
  const check = () => { if (!isCurrent(token,user)) throw new Error('账号状态已改变，请重试'); };
  try {
    check();
    if (!ensureJwSession(user)) {
      if (!cred.pwd) return {ok:false,expired:true,message:'登录状态已过期，请重新验证身份'};
      const r = await login(user, cred.pwd); check();
      if (!r.ok) {
        const viaWeb = await silentPortalLogin(user, cred.pwd); check();
        if (!viaWeb.ok) return {ok:false,message:viaWeb.message};
      }
      persistJwSession(user);
    }
    const cur = currentSemester();
    let startYear = cur.xnm - 7;
    try {
      const profile = JSON.parse(localStorage.getItem(`fxw_a_${accountKey(user)}_profile`) || '{}');
      const year = Number(profile.grade);
      if (Number.isInteger(year) && year >= 1990 && year <= cur.xnm) startYear = year;
    } catch { /* Unknown range uses a bounded fallback, never a three-year cutoff. */ }
    const cached = loadGradesCache(user);
    for (const term of cached?.terms ?? []) startYear = Math.min(startYear, term.xnm);
    if (cur.xnm - startYear > 15) return {ok:false,message:'学期范围无法确认，请重新验证身份'};
    const terms: TermGrades[] = [];
    const all: GradeRecord[] = [];
    for (let y = cur.xnm; y >= startYear; y--) {
      for (const xqm of [3,12]) {
        if (y === cur.xnm && xqm > cur.xqm) continue;
        check();
        const items = await fetchGrades(y,xqm); check();
        terms.push({xnm:y,xqm,label:termLabelOf(y,xqm),items}); all.push(...items);
      }
    }
    check();
    const snapshot: GradesSnapshot = {user,at:Date.now(),terms,items:all,summary:summarize(all)};
    saveGradesCache(user,snapshot);
    try { window.dispatchEvent(new CustomEvent('fxw:grades-updated',{detail:{user}})); } catch { /* headless */ }
    return {ok:true,snapshot};
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    const expired = message.includes('过期');
    if (expired && isCurrent(token,user)) { clearPersistedJwSession(); markSession(false); }
    return {ok:false,expired,message};
  }
}
