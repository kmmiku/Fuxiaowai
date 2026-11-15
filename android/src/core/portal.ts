import { accountToken, isCurrent } from './accountScope';
import { Capacitor, registerPlugin } from '@capacitor/core';

import {
  completePortalLogin,
  importWebviewCookies,
  persistJwSession,
  portalLoginEntryUrl
} from './zhengfang';

/** 原生侧的门户网页登录窗口（PortalLoginPlugin） */
interface FxwPortalPlugin {
  login(options: { url: string; user: string; pwd: string; silent: boolean }): Promise<{
    jw: string;
    portal: string;
  }>;
}

const Portal = registerPlugin<FxwPortalPlugin>('FxwPortal');

export interface PortalLoginOutcome {
  ok: boolean;
  message: string;
}

/**
 * 用「教学综合平台入口」的方式登录：走应用内 WebView（静默）过统一身份认证，
 * 再把 Cookie 交回 HTTP 通道。纯 HTTP 复刻会被门户的动态防护脚本拦掉，
 * 所以成绩页 / 考试页 / 首页刷新都复用这一条链路。
 */
export async function silentPortalLogin(user: string, pwd: string): Promise<PortalLoginOutcome> {
  if (!Capacitor.isNativePlatform()) return { ok: false, message: '当前环境不支持网页登录' };
  if (!user || !pwd) return { ok: false, message: '需要先保存密码才能自动登录' };
  const token=accountToken();
  let cookies: { jw: string; portal: string };
  try {
    cookies = await Portal.login({ url: portalLoginEntryUrl(), user, pwd, silent: true });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { ok: false, message: msg.indexOf('取消') >= 0 ? '已取消登录' : msg };
  }
  if (!isCurrent(token)) return {ok:false,message:'账号状态已改变'};
  if (!importWebviewCookies({ jw: cookies.jw, portal: cookies.portal })) {
    return { ok: false, message: '登录窗口没有拿到教务会话，请重试' };
  }
  const done = await completePortalLogin();
  if (!done.ok) return { ok: false, message: done.message };
  if (!isCurrent(token)) return {ok:false,message:'账号状态已改变'};
  persistJwSession(user);
  return { ok: true, message: done.message };
}