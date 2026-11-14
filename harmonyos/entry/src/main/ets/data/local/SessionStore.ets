import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import { SecretStore } from './SecretStore';
import { SerialQueue } from '../../common/util/SerialQueue';

const FILE: string = 'fxw_session';
const K_JW: string = 'jw_cookie';
const K_AT: string = 'jw_at';
const K_SECRET: string = 'jw_secret_v1';
const K_USER: string = 'jw_user';
const DOMAIN: number = 0x0025;
const TAG: string = 'FuxiaowaiSession';

/**
 * 教务（jw.fzfu.edu.cn）会话 Cookie 的本地缓存。
 *
 * 为什么需要：扫码登录只拿到身份、拿不到密码，成绩/考试页没办法「用账号密码重新登录」。
 * 登录成功时把 jw 的 JSESSIONID 存一份，进成绩页直接带着这条 Cookie 调接口即可。
 * 教务的会话有存活时间（一般半小时），过期后接口会 302 弹回统一身份认证，
 * 这时提示「登录状态已过期，请重新导入课表」，而不是让用户以为没登录过。
 */
export class SessionStore {
  private static ctx: common.UIAbilityContext | null = null;
  private static owner: string = '';
  private static revision: number = 0;
  private static queue: SerialQueue = new SerialQueue();

  static generation(): number { return SessionStore.revision; }
  static currentUser(): string { return SessionStore.owner; }
  static isCurrent(user: string, generation: number): boolean {
    return SessionStore.owner === user && SessionStore.revision === generation;
  }

  /** Bind before authentication. Older in-flight requests can no longer save. */
  static async bindUser(user: string): Promise<void> {
    if (SessionStore.owner === user) { return; }
    const previous: string = SessionStore.owner;
    SessionStore.revision++;
    SessionStore.owner = user;
    await SessionStore.queue.run(async () => {
      if (SessionStore.ctx === null) { return; }
      const p: preferences.Preferences = await preferences.getPreferences(SessionStore.ctx, FILE);
      const savedUser: string = await p.get(K_USER, '') as string;
      if ((savedUser.length > 0 && savedUser !== user) || (previous.length > 0 && previous !== user)) {
        await p.clear();
        await p.flush();
      }
    });
  }

  static invalidate(): void {
    SessionStore.revision++;
    SessionStore.owner = '';
  }

  /** 由 Locator.init 注入一次上下文 */
  static use(context: common.UIAbilityContext): void {
    SessionStore.ctx = context;
  }

  static async saveJw(cookie: string): Promise<void> {
    const user: string = SessionStore.owner;
    const revision: number = SessionStore.revision;
    return SessionStore.queue.run(() => SessionStore.write(cookie, user, revision));
  }

  private static async write(cookie: string, user: string, revision: number): Promise<void> {
    const ctx: common.UIAbilityContext | null = SessionStore.ctx;
    if (ctx === null || cookie.length === 0) {
      return;
    }
    try {
      const p: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
      const sealed: string = await SecretStore.seal(cookie, 'session:' + user);
      if (!SessionStore.isCurrent(user, revision)) { return; }
      await p.put(K_SECRET, sealed);
      await p.put(K_USER, user);
      await p.put(K_AT, Date.now());
      await p.flush();
      await p.delete(K_JW);
      await p.flush();
      hilog.info(DOMAIN, TAG, 'saved jw session len=%{public}d', cookie.length);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'save jw session failed %{public}s', JSON.stringify(e));
    }
  }

  /** 上次登录留下的 Cookie 请求头原串（没有就空串） */
  static async loadJw(): Promise<string> {
    return SessionStore.queue.run(() => SessionStore.read());
  }

  private static async read(): Promise<string> {
    const ctx: common.UIAbilityContext | null = SessionStore.ctx;
    if (ctx === null) {
      return '';
    }
    try {
      const p: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
      const user: string = await p.get(K_USER, '') as string;
      if (user.length > 0 && user !== SessionStore.owner) { return ''; }
      const secret: string = await p.get(K_SECRET, '') as string;
      if (secret.length > 0) {
        return await SecretStore.open(secret, 'session:' + user);
      }
      const legacy: string = await p.get(K_JW, '') as string;
      if (legacy.length === 0 || SessionStore.owner.length === 0) { return ''; }
      const sealed: string = await SecretStore.seal(legacy, 'session:' + SessionStore.owner);
      if (await SecretStore.open(sealed, 'session:' + SessionStore.owner) !== legacy) { return ''; }
      await p.put(K_SECRET, sealed);
      await p.put(K_USER, SessionStore.owner);
      await p.flush();
      await p.delete(K_JW);
      await p.flush();
      return legacy;
    } catch (e) {
      return '';
    }
  }

  /** 上次成功登录的时间戳（毫秒），0 表示没有会话 */
  static async savedAt(): Promise<number> {
    const ctx: common.UIAbilityContext | null = SessionStore.ctx;
    if (ctx === null) {
      return 0;
    }
    try {
      const p: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
      return await p.get(K_AT, 0) as number;
    } catch (e) {
      return 0;
    }
  }

  static async clear(): Promise<void> {
    SessionStore.invalidate();
    return SessionStore.queue.run(() => SessionStore.erase());
  }

  private static async erase(): Promise<void> {
    const ctx: common.UIAbilityContext | null = SessionStore.ctx;
    if (ctx === null) {
      return;
    }
    try {
      const p: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
      await p.clear();
      await p.flush();
      hilog.info(DOMAIN, TAG, 'jw session cleared');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'clear jw session failed %{public}s', JSON.stringify(e));
    }
  }
}
