import { CapacitorHttp } from '@capacitor/core';

/**
 * 反馈上报 —— 对应鸿蒙 entry/src/main/ets/data/remote/ShareApi.ets 的 uploadFeedback
 * 走 CapacitorHttp 原生通道，绕开 WebView 的 CORS。
 */

export const FEEDBACK_BASE = 'https://fuxiaowai.xyz';
export const FEEDBACK_URL = `${FEEDBACK_BASE}/api/feedback`;

const CONNECT_TIMEOUT = 8000;
const READ_TIMEOUT = 20000;

export interface FeedbackPayload {
  text: string;
  requestId?: string;
  contact?: string;
  images?: string[];
  app?: string;
  version?: string;
  device?: string;
}

interface PostResult {
  ok?: boolean;
  id?: string;
  msg?: string;
  retryAfter?: number;
}

/** 带 HTTP 状态的错误：429 = 同 IP 30 分钟内已提交过 */
export class FeedbackError extends Error {
  status: number;

  retryAfter: number;

  constructor(message: string, status: number, retryAfter = 0) {
    super(message);
    this.name = 'FeedbackError';
    this.status = status;
    this.retryAfter = retryAfter;
  }
}

/** 提交一条反馈，成功返回服务端 id，失败抛 FeedbackError */
export async function postFeedback(payload: FeedbackPayload): Promise<string> {
  if (!payload || typeof payload.text !== 'string' || payload.text.length > 2000 ||
      (payload.contact !== undefined && (typeof payload.contact !== 'string' || payload.contact.length > 120)) ||
      (payload.images !== undefined && (!Array.isArray(payload.images) || payload.images.length > 3 ||
        payload.images.some(image => typeof image !== 'string' || !/^data:image\/(jpeg|jpg|png|webp);base64,[A-Za-z0-9+/]*={0,2}$/.test(image)))))
    throw new FeedbackError('反馈文字或图片格式不正确', 400);
  if (new TextEncoder().encode(JSON.stringify(payload)).length > 4 * 1024 * 1024)
    throw new FeedbackError('图片过大，请减少图片后重试', 413);
  const headers: Record<string,string> = {'Content-Type':'application/json'};
  if (payload.requestId) {
    if (!/^[A-Za-z0-9_-]{8,128}$/.test(payload.requestId)) throw new FeedbackError('反馈标识不正确',400);
    headers['X-FXW-Request-ID'] = payload.requestId;
  }
  const res = await CapacitorHttp.request({
    url: FEEDBACK_URL,
    method: 'POST',
    headers,
    data: payload,
    connectTimeout: CONNECT_TIMEOUT,
    readTimeout: READ_TIMEOUT,
  });

  let body: PostResult | null = null;
  try {
    body = typeof res.data === 'string' ? (JSON.parse(res.data) as PostResult) : (res.data as PostResult);
  } catch {
    body = null;
  }

  if (res.status < 200 || res.status >= 300) {
    throw new FeedbackError(
      body && body.msg ? body.msg : `HTTP ${res.status}`,
      res.status,
      retrySeconds(res.headers, body?.retryAfter)
    );
  }

  if (!body || body.ok !== true || typeof body.id !== 'string') {
    throw new FeedbackError(body && body.msg ? body.msg : '提交失败', res.status);
  }
  return body.id;
}

/** 粗略的设备串，方便在后台看出问题机型 */
export function deviceLabel(): string {
  const ua = navigator.userAgent || '';
  const m = ua.match(/Android[^;)]*;\s*([^)]+)\)/);
  return m ? m[1].trim() : ua.slice(0, 80);
}
function retrySeconds(headers: Record<string, string> | undefined, body?: number): number {
  const raw = Object.entries(headers ?? {}).find(([key]) => key.toLowerCase() === 'retry-after')?.[1];
  const n = raw ? Number(raw) : NaN;
  const header = Number.isFinite(n) ? Math.max(0,n) : raw ? Math.max(0,Math.ceil((Date.parse(raw)-Date.now())/1000)) : 0;
  return Math.max(Number.isFinite(header) ? header : 0, Number.isFinite(body) ? Math.max(0,body!) : 0) || 1800;
}
