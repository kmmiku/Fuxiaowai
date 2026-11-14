import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

const NAME: string = 'fxw_avatar';
const KEY: string = 'avatar_path';

/**
 * 头像本地存储：只存一张图的沙箱路径（图片本体在 filesDir 下）
 * 用独立 preferences，不污染 Profile（Profile 的结构跟着教务同步走）
 */
export class AvatarStore {
  private static pref: preferences.Preferences | null = null;

  private static async open(ctx: common.UIAbilityContext): Promise<preferences.Preferences> {
    if (AvatarStore.pref === null) {
      AvatarStore.pref = await preferences.getPreferences(ctx, NAME);
    }
    return AvatarStore.pref;
  }

  static async load(ctx: common.UIAbilityContext): Promise<string> {
    const p: preferences.Preferences = await AvatarStore.open(ctx);
    const v: preferences.ValueType = await p.get(KEY, '');
    return v as string;
  }

  static async save(ctx: common.UIAbilityContext, path: string): Promise<void> {
    const p: preferences.Preferences = await AvatarStore.open(ctx);
    await p.put(KEY, path);
    await p.flush();
  }

  static async clear(ctx: common.UIAbilityContext): Promise<void> {
    const p: preferences.Preferences = await AvatarStore.open(ctx);
    await p.delete(KEY);
    await p.flush();
  }
}