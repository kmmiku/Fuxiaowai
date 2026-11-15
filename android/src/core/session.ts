import { invalidateAccount } from './accountScope';
/**
 * 账号会话边界
 *
 * 一个手机可能先后登过好几个学号。只要换了账号，旧会话的 Cookie、
 * 旧账号的课表缓存都不能再被复用，否则会出现「登别人的号，看到的还是自己的课表」。
 */

import { CapacitorCookies } from '@capacitor/core';

import { clearSessionCookies, clearNativeCookies } from './zhengfang';

/** 清掉一切会话痕迹：内存 jar、原生 Cookie 存储、登录态标记 */
export async function resetSession(): Promise<void> {
  invalidateAccount();
  clearSessionCookies();
  try {
    await clearNativeCookies();
  } catch {
    throw new Error('WebView 会话清理未完成，请重试');
  }
}