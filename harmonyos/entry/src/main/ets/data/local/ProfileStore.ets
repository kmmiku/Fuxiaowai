import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { SerialQueue } from '../../common/util/SerialQueue';
import { AccountScope } from '../../common/util/AccountScope';

/** 登录后从教务取到的学生信息 */
export interface Profile {
  name: string;
  studentId: string;
  clazz: string;
  major: string;
  grade: string;   // 年级，从学号前两位推：24xxxxxxx → 2024
  updatedAt: number;
}

const FILE: string = 'fxw_profile';
const KEY: string = 'profile';

const EMPTY: Profile = {
  name: '', studentId: '', clazz: '', major: '', grade: '', updatedAt: 0
};

/**
 * 学生信息缓存。
 * 教务的 xsxxwh 接口对本账号返回"没有访问权限"，
 * 所以姓名/专业/班级只能从课表接口的 xsxx 顺带取，登录同步时写进来。
 */
export class ProfileStore {
  private static queue: SerialQueue = new SerialQueue();
  static async load(ctx: common.UIAbilityContext): Promise<Profile> {
    try {
      const p: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
      const raw: string = await p.get(KEY, '') as string;
      if (raw.length === 0) {
        return EMPTY;
      }
      const v: Profile = JSON.parse(raw) as Profile;
      return {
        name: v.name ?? '',
        studentId: v.studentId ?? '',
        clazz: v.clazz ?? '',
        major: v.major ?? '',
        grade: v.grade ?? '',
        updatedAt: v.updatedAt ?? 0
      };
    } catch (e) {
      return EMPTY;
    }
  }

  static async save(ctx: common.UIAbilityContext, p: Profile): Promise<void> {
    const token: number = AccountScope.token();
    return ProfileStore.queue.run(async () => {
      const prefs: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
      if (!AccountScope.valid(token)) { return; }
      await prefs.put(KEY, JSON.stringify(p));
      await prefs.flush();
    });
  }

  static async clear(ctx: common.UIAbilityContext): Promise<void> {
    return ProfileStore.queue.run(async () => {
      const prefs: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
      await prefs.clear();
      await prefs.flush();
    });
  }

  /** 从学号推年级：24xxxxxxxxx → "2024" */
  static gradeOf(studentId: string): string {
    if (studentId.length < 2) {
      return '';
    }
    const yy: number = Number(studentId.substring(0, 2));
    if (isNaN(yy)) {
      return '';
    }
    return (yy >= 50 ? 1900 + yy : 2000 + yy).toString();
  }

  /** 一句话摘要：数据科学与大数据技术 · 2024级 */
  static subtitle(p: Profile): string {
    const parts: string[] = [];
    if (p.major.length > 0) {
      parts.push(p.major);
    }
    if (p.grade.length > 0) {
      parts.push(`${p.grade}级`);
    }
    return parts.join(' · ');
  }
}
