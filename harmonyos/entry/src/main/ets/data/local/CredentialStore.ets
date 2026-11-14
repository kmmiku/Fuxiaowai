import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { SecretStore } from './SecretStore';
import { SerialQueue } from '../../common/util/SerialQueue';
import { AccountScope } from '../../common/util/AccountScope';

/** 本机保存的教务凭据 */
export interface Credential {
  user: string;
  pwd: string;
  remember: boolean;
  /** 每天首次打开 App 时自动同步一次课表 */
  autoUpdate: boolean;
}

const FILE: string = 'fxw_auth';
const K_USER: string = 'user';
const K_PWD: string = 'pwd';
const K_SECRET: string = 'pwd_enc_v1';
const K_REMEMBER: string = 'remember';
const K_AUTO_UPDATE: string = 'auto_update';
const K_AUTO_DAY: string = 'auto_day';
const K_LAST_SYNC: string = 'last_sync_at';

/**
 * 凭据存储。
 * 密码由 HUKS AES-GCM 加密。旧记录经回读校验后才删除明文。
 */
export class CredentialStore {
  private static queue: SerialQueue = new SerialQueue();

  static async load(ctx: common.UIAbilityContext): Promise<Credential> {
    return CredentialStore.queue.run(() => CredentialStore.read(ctx));
  }

  private static async read(ctx: common.UIAbilityContext): Promise<Credential> {
    try {
      const p: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
      const user: string = await p.get(K_USER, '') as string;
      const remember: boolean = await p.get(K_REMEMBER, true) as boolean;
      const autoUpdate: boolean = await p.get(K_AUTO_UPDATE, true) as boolean;
      let pwd: string = '';
      const secret: string = await p.get(K_SECRET, '') as string;
      if (remember && secret.length > 0) {
        try { pwd = await SecretStore.open(secret, 'credential:' + user); }
        catch (e) { pwd = ''; }
      } else if (remember) {
        const legacy: string = await p.get(K_PWD, '') as string;
        if (legacy.length > 0) {
          try {
            const sealed: string = await SecretStore.seal(legacy, 'credential:' + user);
            if (await SecretStore.open(sealed, 'credential:' + user) !== legacy) {
              throw new Error('凭据迁移校验失败');
            }
            await p.put(K_SECRET, sealed);
            await p.flush();
            await p.delete(K_PWD);
            await p.flush();
            pwd = legacy;
          } catch (e) {
            // Keep the legacy value for a later migration, but never write a new plaintext copy.
            pwd = '';
          }
        }
      }
      return { user: user, pwd: pwd, remember: remember, autoUpdate: autoUpdate };
    } catch (e) {
      return { user: '', pwd: '', remember: true, autoUpdate: true };
    }
  }

  static async save(ctx: common.UIAbilityContext, c: Credential): Promise<void> {
    const token: number = AccountScope.token();
    return CredentialStore.queue.run(() => CredentialStore.write(ctx, c, token));
  }

  private static async write(ctx: common.UIAbilityContext, c: Credential, token: number): Promise<void> {
    if (!AccountScope.valid(token)) { return; }
    const secret: string = c.remember ? await SecretStore.seal(c.pwd, 'credential:' + c.user) : '';
    const p: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
    if (!AccountScope.valid(token)) { return; }
    await p.put(K_USER, c.user);
    await p.put(K_REMEMBER, c.remember);
    await p.put(K_AUTO_UPDATE, c.autoUpdate);
    await p.put(K_SECRET, secret);
    await p.flush();
    await p.delete(K_PWD);
    await p.flush();
  }

  static async clear(ctx: common.UIAbilityContext): Promise<void> {
    return CredentialStore.queue.run(async () => {
      const p: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
      await p.clear();
      await p.flush();
    });
  }

  /** 上次成功同步课表的时间戳（毫秒），0 表示从未同步 */
  static async lastSyncAt(ctx: common.UIAbilityContext): Promise<number> {
    try {
      const p: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
      return await p.get(K_LAST_SYNC, 0) as number;
    } catch (e) {
      return 0;
    }
  }

  static async markSyncAt(ctx: common.UIAbilityContext, ts: number): Promise<void> {
    const p: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
    await p.put(K_LAST_SYNC, ts);
    await p.flush();
  }

  /** 上次自动更新课表的自然日（yyyy-MM-dd），空串表示从未自动更新 */
  static async autoUpdateDay(ctx: common.UIAbilityContext): Promise<string> {
    try {
      const p: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
      return await p.get(K_AUTO_DAY, '') as string;
    } catch (e) {
      return '';
    }
  }

  static async markAutoUpdateDay(ctx: common.UIAbilityContext, day: string): Promise<void> {
    const p: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
    await p.put(K_AUTO_DAY, day);
    await p.flush();
  }

  /** 本地自然日字符串，用于「每天只更新一次」的判重 */
  static today(): string {
    const d: Date = new Date();
    const mm: string = d.getMonth() + 1 < 10 ? `0${d.getMonth() + 1}` : `${d.getMonth() + 1}`;
    const dd: string = d.getDate() < 10 ? `0${d.getDate()}` : `${d.getDate()}`;
    return `${d.getFullYear()}-${mm}-${dd}`;
  }
}
