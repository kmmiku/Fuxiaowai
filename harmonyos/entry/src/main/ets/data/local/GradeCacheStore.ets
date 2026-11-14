import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import { AccountScope } from '../../common/util/AccountScope';
import { SerialQueue } from '../../common/util/SerialQueue';
import { SessionStore } from './SessionStore';
import { GradeRecord, GradeSummary, TermGrades } from '../../domain/model/Grade';

const PREFIX: string = 'grades_';

/** 一整份成绩快照：既是「离线可看」的数据，也是「什么时候拉的」凭证 */
export interface GradeSnapshot {
  /** 抓取成功的时间戳（ms） */
  at: number;
  /** 属于哪个学号，换账号不串味 */
  user: string;
  /** 'ok' 上次拉到；'expired' 上次被教务判会话过期 */
  status: string;
  terms: TermGrades[];
  items: GradeRecord[];
  summary: GradeSummary;
}

/**
 * 成绩离线缓存。
 *
 * 为什么落文件而不是 preferences：
 * 一学期几十门课、三年就是几百条，JSON 轻松几十 KB，
 * preferences 的 value 有长度上限，写大对象容易静默失败；文件没有这个顾虑。
 * 文件名按学号分开，退出登录时整批删掉（和课表一个处理方式）。
 */
export class GradeCacheStore {
  private static queue: SerialQueue = new SerialQueue();
  private static revision: number = 0;
  private static sequence: number = 0;
  private static dir(ctx: common.UIAbilityContext): string {
    return ctx.filesDir;
  }

  private static safe(user: string): string {
    const u: string = user.replace(/[^0-9A-Za-z]/g, '');
    return u.length > 0 ? u : 'anon';
  }

  private static pathOf(ctx: common.UIAbilityContext, user: string): string {
    return `${GradeCacheStore.dir(ctx)}/${PREFIX}${GradeCacheStore.safe(user)}.json`;
  }

  /** 最近一次成功缓存的学号：成绩页没登录时也能知道「上次是谁」 */
  private static pointerPath(ctx: common.UIAbilityContext): string {
    return `${GradeCacheStore.dir(ctx)}/${PREFIX}last.txt`;
  }

  private static atomicWrite(path: string, text: string, valid: () => boolean): void {
    const temp: string = path + '.tmp_' + Date.now() + '_' + (++GradeCacheStore.sequence);
    let file: fs.File | undefined = undefined;
    let published: boolean = false;
    try {
      const bytes: Uint8Array = new util.TextEncoder().encodeInto(text);
      file = fs.openSync(temp, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      if (fs.writeSync(file.fd, bytes.buffer as ArrayBuffer) !== bytes.length) { throw new Error('缓存写入不完整'); }
      fs.fsyncSync(file.fd);
      fs.closeSync(file);
      file = undefined;
      if (!valid()) { throw new Error('账号已切换，取消成绩缓存写入'); }
      // Same-directory rename publishes the fully flushed file without truncating the prior cache.
      fs.renameSync(temp, path);
      published = true;
    } finally {
      if (file !== undefined) { try { fs.closeSync(file); } catch (_) {} }
      if (!published) { try { fs.unlinkSync(temp); } catch (_) {} }
    }
  }

  static async save(ctx: common.UIAbilityContext, snap: GradeSnapshot): Promise<void> {
    const token: number = AccountScope.token();
    const generation: number = SessionStore.generation();
    const revision: number = GradeCacheStore.revision;
    const valid = (): boolean => snap.user.length > 0 && AccountScope.valid(token) &&
      AccountScope.user() === snap.user && SessionStore.isCurrent(snap.user, generation) &&
      revision === GradeCacheStore.revision;
    return GradeCacheStore.queue.run(async () => {
      if (!valid()) { throw new Error('账号已切换，取消成绩缓存写入'); }
      try {
        GradeCacheStore.atomicWrite(GradeCacheStore.pathOf(ctx, snap.user), JSON.stringify(snap), valid);
        GradeCacheStore.atomicWrite(GradeCacheStore.pointerPath(ctx), snap.user, valid);
      } catch (error) {
        const reason: string = error instanceof Error ? error.message : '文件操作失败';
        throw new Error('保存成绩缓存失败：' + reason);
      }
    });
  }

  /** 读缓存：user 传空时读「上次那个学号」的缓存 */
  static async load(ctx: common.UIAbilityContext, user: string): Promise<GradeSnapshot | null> {
    return GradeCacheStore.queue.run(async () => {
      const requested: string = user.length > 0 ? user : GradeCacheStore.lastUser(ctx);
      if (requested.length === 0) { return null; }
      try {
        const path: string = GradeCacheStore.pathOf(ctx, requested);
        if (!fs.accessSync(path)) { return null; }
        const snap: GradeSnapshot = JSON.parse(fs.readTextSync(path)) as GradeSnapshot;
        if (snap === null || typeof snap !== 'object' || snap.user !== requested ||
          !Array.isArray(snap.items) || !Array.isArray(snap.terms) || !Number.isFinite(snap.at) ||
          snap.at < 0 || snap.summary === null || typeof snap.summary !== 'object' ||
          (snap.status !== 'ok' && snap.status !== 'expired')) { return null; }
        return snap;
      } catch (_) { return null; }
    });
  }

  static lastUser(ctx: common.UIAbilityContext): string {
    try {
      const path: string = GradeCacheStore.pointerPath(ctx);
      if (!fs.accessSync(path)) {
        return '';
      }
      return fs.readTextSync(path).trim();
    } catch (e) {
      return '';
    }
  }

  /** 退出登录：所有学号的成绩缓存一起清掉 */
  static async clear(ctx: common.UIAbilityContext): Promise<void> {
    GradeCacheStore.revision++;
    return GradeCacheStore.queue.run(async () => {
      const dir: string = GradeCacheStore.dir(ctx);
      const names: string[] = fs.listFileSync(dir);
      let failed: boolean = false;
      names.forEach((name: string) => {
        if (name.startsWith(PREFIX)) {
          try { fs.unlinkSync(dir + '/' + name); } catch (_) { failed = true; }
        }
      });
      if (failed) { throw new Error('清除成绩缓存失败，请重试'); }
    });
  }

  /** "11-13 02:10" 这种短格式，页面上直接显示 */
  static shortTime(at: number): string {
    if (at <= 0) {
      return '—';
    }
    const d: Date = new Date(at);
    const mm: string = `${d.getMonth() + 1}`.padStart(2, '0');
    const dd: string = `${d.getDate()}`.padStart(2, '0');
    const hh: string = `${d.getHours()}`.padStart(2, '0');
    const mi: string = `${d.getMinutes()}`.padStart(2, '0');
    return `${mm}-${dd} ${hh}:${mi}`;
  }
}