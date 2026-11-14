/**
 * 课表分享口令的本地存档。
 *
 * 口令本身只是一串 32 位十六进制，真正能被"一比一复用"的是它指向的课表快照：
 * 所以这里把 code 和整份课表一起存进 preferences，等服务器就绪时按 `uploaded` 标记补传。
 *
 * 为什么单独一个 preferences 文件：口令会越来越多，塞进 SettingsStore 会把
 * 每次读设置都拖上一大坨 JSON。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Course, Period } from '../../domain/model/Course';

const STORE: string = 'fxw_share';
const KEY_TICKETS: string = 'tickets';
/** 口令有效期（天）—— 仅用于本地清理与文案，服务器侧还要再校验一次 */
export const TICKET_DAYS: number = 30;

export interface ShareCodeResult {
  code: string;
  error: string;
}

/** 可粘贴完整分享文案；不从更长的字母数字串里截取，不猜测多个不同口令。 */
export function extractShareCode(value: string): ShareCodeResult {
  const parts: string[] = value.toLowerCase().split(/[^a-z0-9]+/);
  const codes: string[] = [];
  for (let i = 0; i < parts.length; i++) {
    if (/^[a-f0-9]{32}$/.test(parts[i]) && codes.indexOf(parts[i]) < 0) { codes.push(parts[i]); }
  }
  if (codes.length === 1) { return { code: codes[0], error: '' }; }
  return { code: '', error: codes.length > 1 ? '识别到多个口令，请只保留一个' : '未找到有效的32位口令，请粘贴完整分享文案或口令' };
}

export interface ShareTicket {
  /** 32 位十六进制口令 */
  code: string;
  createdAt: number;
  /** 分享时所在的周次，只作记录 */
  week: number;
  term: string;
  courses: Course[];
  periods: Period[];
  /** 是否已上传到服务器；服务器就绪前恒为 false */
  uploaded: boolean;
}

function randomHex(bytes: number): string {
  let s: string = '';
  for (let i = 0; i < bytes; i++) {
    const v: number = Math.floor(Math.random() * 256);
    s += v.toString(16).padStart(2, '0');
  }
  return s;
}

function safeParse(raw: string): ShareTicket[] {
  try {
    const list: ShareTicket[] = JSON.parse(raw) as ShareTicket[];
    return Array.isArray(list) ? list : [];
  } catch (e) {
    return [];
  }
}

async function open(ctx: common.UIAbilityContext): Promise<preferences.Preferences> {
  return await preferences.getPreferences(ctx, STORE);
}

/** 读出全部口令（新的在前） */
export async function listTickets(ctx: common.UIAbilityContext): Promise<ShareTicket[]> {
  const p: preferences.Preferences = await open(ctx);
  const raw: string = await p.get(KEY_TICKETS, '[]') as string;
  const list: ShareTicket[] = safeParse(raw);
  list.sort((a: ShareTicket, b: ShareTicket) => b.createdAt - a.createdAt);
  return list;
}

/** 按口令查快照；查不到返回 null */
export async function findByCode(ctx: common.UIAbilityContext, code: string): Promise<ShareTicket | null> {
  const key: string = code.trim().toLowerCase();
  const list: ShareTicket[] = await listTickets(ctx);
  const hit: ShareTicket | undefined = list.find((t: ShareTicket) => t.code.toLowerCase() === key);
  return hit ?? null;
}

/** 生成一个口令并把整份课表存下来 */
export async function createTicket(
  ctx: common.UIAbilityContext,
  courses: Course[],
  periods: Period[],
  term: string,
  week: number
): Promise<ShareTicket> {
  const p: preferences.Preferences = await open(ctx);
  const raw: string = await p.get(KEY_TICKETS, '[]') as string;
  const list: ShareTicket[] = safeParse(raw);

  // 顺手清掉过期的，省得越攒越大
  const deadline: number = Date.now() - TICKET_DAYS * 86400000;
  const kept: ShareTicket[] = list.filter((t: ShareTicket) => t.createdAt >= deadline);

  let code: string = randomHex(16);
  // 极端情况下撞号，重摇一次
  while (kept.some((t: ShareTicket) => t.code === code)) {
    code = randomHex(16);
  }

  const ticket: ShareTicket = {
    code: code,
    createdAt: Date.now(),
    week: week,
    term: term,
    courses: courses,
    periods: periods,
    uploaded: false
  };
  kept.push(ticket);
  await p.put(KEY_TICKETS, JSON.stringify(kept));
  await p.flush();
  return ticket;
}

/** 还没传上去的口令（服务器上线后由同步任务消费） */
export async function pendingUpload(ctx: common.UIAbilityContext): Promise<ShareTicket[]> {
  const list: ShareTicket[] = await listTickets(ctx);
  return list.filter((t: ShareTicket) => !t.uploaded);
}

/** 标记某个口令已上传 */
export async function markUploaded(ctx: common.UIAbilityContext, code: string, onlineCode: string = ''): Promise<void> {
  const p: preferences.Preferences = await open(ctx);
  const raw: string = await p.get(KEY_TICKETS, '[]') as string;
  const list: ShareTicket[] = safeParse(raw);
  list.forEach((t: ShareTicket) => {
    if (t.code === code) {
      t.uploaded = true;
      if (onlineCode.length > 0) { t.code = onlineCode; }
    }
  });
  await p.put(KEY_TICKETS, JSON.stringify(list));
  await p.flush();
}

/** 分享用的整段话术，直接进剪贴板 */
export function ticketMessage(ticket: ShareTicket, totalWeeks: number): string {
  const weeks: number = ticket.courses.length;
  return `这是来自「福小外」的课表分享，口令 ${TICKET_DAYS} 天内有效。\n` +
    `复制这条消息后打开福小外，点首页右上角「↗」→「从分享口令导入」，即可一比一复用这份课表（${weeks} 门课 · 共 ${totalWeeks} 周）。\n` +
    `分享口令：${ticket.code}`;
}
