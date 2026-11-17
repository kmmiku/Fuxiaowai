/**
 * 课表口令服务客户端
 * 服务端源码：本工程 server/server.js。
 * - POST /api/share        上传课表快照，返回 32 位口令
 * - GET  /api/share/<code> 凭口令取回快照
 */
import http from '@ohos.net.http';
import util from '@ohos.util';
import { Course, Period, colorIndexOf } from '../../domain/model/Course';

/** 备案期间分享直连 IP；反馈维持原 HTTPS 地址。 */
export const SHARE_BASE: string = 'http://113.45.242.182';
export const FEEDBACK_BASE: string = 'https://fuxiaowai.xyz';

const CONNECT_TIMEOUT: number = 8000;
const READ_TIMEOUT: number = 15000;

/** 服务器返回的一份课表快照 */
export interface ShareSnapshot {
  code: string;
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

interface UploadRequest {
  term: string;
  week: number;
  courses: Course[];
  periods: Period[];
}

/** 上传课表，返回服务器生成的口令 */
export async function uploadShare(courses: Course[], periods: Period[], term: string,
  week: number): Promise<string> {
  const req: http.HttpRequest = http.createHttp();
  try {
    const payload: UploadRequest = {
      term: term,
      week: week,
      courses: courses,
      periods: periods
    };
    const body: string = JSON.stringify(payload);
    const res: http.HttpResponse = await req.request(SHARE_BASE + '/api/share', {
      method: http.RequestMethod.POST,
      header: { 'Content-Type': 'application/json' },
      extraData: body,
      connectTimeout: CONNECT_TIMEOUT,
      readTimeout: READ_TIMEOUT,
      expectDataType: http.HttpDataType.STRING
    });
    if (res.responseCode !== 200) {
      throw new Error('HTTP ' + res.responseCode);
    }
    const data: UploadResponse = JSON.parse(res.result as string) as UploadResponse;
    if (!data.ok || typeof data.code !== 'string' || !/^[a-f0-9]{32}$/i.test(data.code)) {
      throw new Error(data.msg !== undefined ? data.msg : '服务器返回异常');
    }
    return data.code.toLowerCase();
  } finally {
    req.destroy();
  }
}

/** 凭口令取回课表；口令不存在或过期返回 null */
export async function fetchShare(code: string): Promise<ShareSnapshot | null> {
  const req: http.HttpRequest = http.createHttp();
  try {
    const res: http.HttpResponse = await req.request(SHARE_BASE + '/api/share/' + encodeURIComponent(code), {
      method: http.RequestMethod.GET,
      connectTimeout: CONNECT_TIMEOUT,
      readTimeout: READ_TIMEOUT,
      expectDataType: http.HttpDataType.STRING
    });
    if (res.responseCode === 404) {
      return null;
    }
    if (res.responseCode !== 200) {
      throw new Error('HTTP ' + res.responseCode);
    }
    const snap: ShareSnapshot = JSON.parse(res.result as string) as ShareSnapshot;
    if (!validateSnapshot(snap)) { throw new Error('课表数据格式无效'); }
    return snap;
  } finally {
    req.destroy();
  }
}

/** 把远端课表转成本地课表（重新发 id，避免与现有课程撞号） */
export function toLocalCourses(list: Course[]): Course[] {
  const stamp: number = Date.now();
  const out: Course[] = [];
  for (let i = 0; i < list.length; i++) {
    const c: Course = list[i];
    const item: Course = {
      id: 'imp_' + stamp + '_' + i,
      name: c.name,
      teacher: c.teacher,
      room: c.room,
      campus: c.campus,
      weekday: c.weekday,
      startPeriod: c.startPeriod,
      endPeriod: c.endPeriod,
      weeks: c.weeks,
      colorIndex: c.colorIndex,
      colorOverride: c.colorOverride
    };
    out.push(item);
  }
  return out;
}

/** 反馈上报的请求体 */
export interface FeedbackRequest {
  text: string;
  contact: string;
  images: string[];
  app: string;
  version: string;
  device: string;
  requestId?: string;
}

interface FeedbackResponse {
  ok: boolean;
  id?: string;
  msg?: string;
  retryAfter?: number;
}

/**
 * 提交一条反馈到后台。成功返回服务端 id，失败抛错。
 * 图片是 dataURL（data:image/jpeg;base64,...），服务端限制最多 3 张、单张 1.5MB。
 */
export async function uploadFeedback(payload: FeedbackRequest): Promise<string> {
  const req: http.HttpRequest = http.createHttp();
  try {
    const body: string = JSON.stringify(payload);
    if (new util.TextEncoder().encodeInto(body).length >= 4 * 1024 * 1024) { throw new Error('反馈内容过大'); }
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (payload.requestId !== undefined) { headers['X-FXW-Request-ID'] = payload.requestId; }
    const res: http.HttpResponse = await req.request(FEEDBACK_BASE + '/api/feedback', {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: body,
      connectTimeout: CONNECT_TIMEOUT,
      readTimeout: 20000,
      expectDataType: http.HttpDataType.STRING
    });
    if (res.responseCode === 429) {
      let seconds: number = 1800;
      try {
        const limited: FeedbackResponse = JSON.parse(res.result as string) as FeedbackResponse;
        if (typeof limited.retryAfter === 'number' && Number.isFinite(limited.retryAfter) && limited.retryAfter > 0) {
          seconds = Math.ceil(limited.retryAfter);
        }
      } catch (_) {}
      const header: Record<string, string> = res.header as Record<string, string>;
      if (header !== undefined) {
        Object.keys(header).forEach((key: string) => {
          if (key.toLowerCase() === 'retry-after') {
            const value: string = header[key];
            const delay: number = /^\d+$/.test(value) ? Number(value) : Math.ceil((Date.parse(value) - Date.now()) / 1000);
            if (Number.isFinite(delay) && delay > 0) { seconds = delay; }
          }
        });
      }
      throw new Error('TOO_FREQUENT:' + seconds);
    }
    if (res.responseCode !== 200) {
      throw new Error('HTTP ' + res.responseCode);
    }
    const data: FeedbackResponse = JSON.parse(res.result as string) as FeedbackResponse;
    if (data.ok !== true || typeof data.id !== 'string' || data.id.length === 0) {
      throw new Error(data.msg !== undefined ? data.msg : '提交失败');
    }
    return data.id;
  } finally {
    req.destroy();
  }
}
function integer(value: number, min: number, max: number): boolean {
  return Number.isInteger(value) && value >= min && value <= max;
}
function text(value: string, max: number): boolean { return typeof value === 'string' && value.length <= max; }
/** Validate untrusted snapshots before import can replace the local timetable. */
export function validateSnapshot(snap: ShareSnapshot): boolean {
  if (snap === null || typeof snap !== 'object' || !text(snap.code, 64) || !text(snap.term, 200) ||
    !Number.isFinite(snap.createdAt) || snap.createdAt < 0 || !integer(snap.week, 0, 60) ||
    !Array.isArray(snap.courses) || snap.courses.length === 0 || snap.courses.length > 800 ||
    !Array.isArray(snap.periods) || snap.periods.length > 48) { return false; }
  const courseIds: Set<string> = new Set<string>();
  for (let i = 0; i < snap.courses.length; i++) {
    const course: Course = snap.courses[i];
    if (course === null || typeof course !== 'object' || !text(course.id, 300) ||
      courseIds.has(course.id) || !text(course.name, 300) || course.name.trim().length === 0 || !text(course.room, 300) ||
      !integer(course.weekday, 1, 7) || !integer(course.startPeriod, 1, 48) ||
      !integer(course.endPeriod, course.startPeriod, 48) || !Array.isArray(course.weeks) ||
      course.weeks.length === 0 || course.weeks.length > 60 ||
      !course.weeks.every((week: number) => integer(week, 1, 60))) { return false; }
    if (course.teacher === undefined) { course.teacher = ''; }
    if (course.campus === undefined) { course.campus = ''; }
    if (course.colorIndex === undefined) { course.colorIndex = colorIndexOf(course.name); }
    if (!text(course.teacher, 300) || !text(course.campus, 300) || !integer(course.colorIndex, 0, 255) ||
      (course.colorOverride !== undefined && typeof course.colorOverride !== 'boolean')) { return false; }
    courseIds.add(course.id);
  }
  const indices: Set<number> = new Set<number>();
  for (let i = 0; i < snap.periods.length; i++) {
    const period: Period = snap.periods[i];
    if (period === null || typeof period !== 'object' || !integer(period.index, 1, 48) || indices.has(period.index) ||
      typeof period.start !== 'string' || typeof period.end !== 'string' ||
      !/^([01]\d|2[0-3]):[0-5]\d$/.test(period.start) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(period.end) ||
      period.end <= period.start) { return false; }
    indices.add(period.index);
  }
  return true;
}
