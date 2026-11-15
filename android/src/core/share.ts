import { validateCourses, validatePeriods } from './validation';
import { loadTerm, validateTermMetadata, type TermMetadata } from './termStore';
/**
 * 课表口令服务客户端（与鸿蒙端 entry/src/main/ets/data/remote/ShareApi.ets 对应）
 * 备案完成前使用用户授权的临时 IP 入口；备案完成后统一恢复 HTTPS 域名。
 * - POST /api/share                     上传课表，返回 32 位口令
 * - GET  /api/share/<code>              凭口令取回
 */
import { CapacitorHttp, type HttpResponse } from '@capacitor/core';
import type { Course, Period } from './types';

export const SHARE_BASE = 'http://113.45.242.182';

/** Accept a bare token or the whole shared message; never guess between tokens. */
export function extractShareCode(text: string): string | null {
  const codes = new Set<string>();
  const pattern = /(?:^|[^a-z0-9])([a-f0-9]{32})(?=$|[^a-z0-9])/gi;
  for (const match of text.matchAll(pattern)) codes.add(match[1].toLowerCase());
  return codes.size === 1 ? [...codes][0] : null;
}

export interface ShareSnapshot {
  code: string;
  termMetadata?: TermMetadata;
  createdAt: number;
  term: string;
  week: number;
  courses: Course[];
  periods: Period[];
}

interface UploadResponse {
  ok: boolean;
  code: string;
  expiresAt: number;
  msg?: string;
}

function parse<T>(data: unknown): T {
  return (typeof data === 'string' ? JSON.parse(data) : data) as T;
}

/** 上传课表，返回服务器生成的口令 */
export async function uploadShare(
  courses: Course[],
  periods: Period[],
  term: string,
  week: number
): Promise<string> {
  validateCourses(courses); validatePeriods(periods);
  const res: HttpResponse = await CapacitorHttp.request({
    url: SHARE_BASE + '/api/share',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    data: { term, week, courses, periods, termMetadata:loadTerm() },
    connectTimeout: 8000,
    readTimeout: 15000,
  }).catch((error: unknown) => {
    const message = error instanceof Error ? error.message : String(error);
    if (/connection closed|ECONNRESET|connection reset|socket hang up/i.test(message)) {
      throw new Error('分享服务连接中断，请稍后重试');
    }
    if (/timeout|timed out/i.test(message)) throw new Error('分享服务连接超时，请稍后重试');
    throw error;
  });
  if (res.status !== 200) throw new Error('HTTP ' + res.status);
  const body = parse<UploadResponse>(res.data);
  if (!body || !body.ok || !/^[a-f0-9]{32}$/.test(body.code)) throw new Error(body?.msg ?? '服务器返回异常');
  return body.code;
}

/** 凭口令取回课表；不存在或过期返回 null */
export async function fetchShare(code: string): Promise<ShareSnapshot | null> {
  if(!/^[a-f0-9]{32}$/i.test(code))throw new Error('口令格式不正确');
  const res: HttpResponse = await CapacitorHttp.request({
    url: SHARE_BASE + '/api/share/' + code,
    method: 'GET',
    connectTimeout: 8000,
    readTimeout: 15000,
  });
  if (res.status === 404) return null;
  if (res.status !== 200) throw new Error('HTTP ' + res.status);
  const snap = parse<ShareSnapshot>(res.data);
  if (!snap || !Array.isArray(snap.courses) || !snap.courses.length) throw new Error('分享课表数据不完整');
  snap.courses=validateCourses(snap.courses.map((c,i)=>c&&({...c,id:c.id||`legacy_${i}`})));
  snap.periods=validatePeriods(snap.periods??[]);
  if (snap.termMetadata) snap.termMetadata=validateTermMetadata(snap.termMetadata);
  return snap;
}

/** 转成本地课程（重发 id，避免与现有课程撞号） */
export function toLocalCourses(list: Course[]): Course[] {
  const stamp = Date.now();
  return list.map((c, i) => ({ ...c, id: `imp_${stamp}_${i}` }));
}
