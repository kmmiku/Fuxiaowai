import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import { ZhengfangAuth, LoginResult } from './auth/ZhengfangAuth';
import { currentSemester, Semester } from './auth/RsaPublicKey';
import { GradeAdapter } from './parser/GradeAdapter';
import { GradeRecord, summarize, termLabelOf, TermGrades } from '../../domain/model/Grade';
import { GradeCacheStore, GradeSnapshot } from '../local/GradeCacheStore';
import { SessionStore } from '../local/SessionStore';
import { ProfileStore } from '../local/ProfileStore';
import { AccountScope } from '../../common/util/AccountScope';
import { SchoolTraffic } from '../../common/util/SchoolTraffic';

export interface GradeSyncResult {
  ok: boolean;
  expired: boolean;
  message: string;
  snapshot: GradeSnapshot | null;
}
interface GradeTask {
  user: string;
  token: number;
  generation: number;
  ctx: common.UIAbilityContext | null;
}

/** A completed snapshot is committed only after every requested term succeeds. */
export class GradeSync {
  private static readonly TERM_CODES: number[] = [3, 12];
  private static inflight: Map<string, Promise<GradeSyncResult>> = new Map<string, Promise<GradeSyncResult>>();
  private static ctx: common.UIAbilityContext | null = null;

  static use(ctx: common.UIAbilityContext): void { GradeSync.ctx = ctx; }
  static async quiet(user: string, pwd: string): Promise<GradeSyncResult> {
    try { return await GradeSync.run(user, pwd); }
    catch (e) {
      hilog.warn(0x0032, 'FuxiaowaiGradeSync', 'quiet sync failed %{public}s', JSON.stringify(e));
      return { ok: false, expired: false, message: '成绩暂时没拉到，已保留原有缓存', snapshot: null };
    }
  }

  static run(user: string, pwd: string): Promise<GradeSyncResult> {
    if (user.length === 0) {
      const missing: GradeSyncResult = { ok: false, expired: false, message: '还没有保存教务账号', snapshot: null };
      return Promise.resolve(missing);
    }
    const task: GradeTask = { user: user, token: AccountScope.token(), generation: SessionStore.generation(), ctx: GradeSync.ctx };
    const key: string = `${user}:${task.token}:${task.generation}`;
    const joined: Promise<GradeSyncResult> | undefined = GradeSync.inflight.get(key);
    if (joined) { return joined; }
    const pending: Promise<GradeSyncResult> = SchoolTraffic.run(() => GradeSync.doRun(task, pwd));
    GradeSync.inflight.set(key, pending);
    pending.then(() => { GradeSync.inflight.delete(key); }).catch(() => { GradeSync.inflight.delete(key); });
    return pending;
  }

  private static valid(task: GradeTask): boolean {
    return AccountScope.valid(task.token) && AccountScope.user() === task.user && SessionStore.isCurrent(task.user, task.generation);
  }
  private static cancelled(): GradeSyncResult {
    return { ok: false, expired: false, message: '账号已切换，本次成绩同步已取消', snapshot: null };
  }
  private static async doRun(task: GradeTask, pwd: string): Promise<GradeSyncResult> {
    if (!GradeSync.valid(task)) { return GradeSync.cancelled(); }
    const saved: string = await SessionStore.loadJw();
    if (!GradeSync.valid(task)) { return GradeSync.cancelled(); }
    if (saved.length > 0) {
      const result: GradeSyncResult = await GradeSync.collect(task, saved);
      if (result.ok || !result.expired) { return result; }
      if (!GradeSync.valid(task)) { return GradeSync.cancelled(); }
    }
    if (pwd.length === 0) { return GradeSync.expiredResult(task); }
    const auth: ZhengfangAuth = new ZhengfangAuth();
    if (!GradeSync.valid(task)) { return GradeSync.cancelled(); }
    const login: LoginResult = await auth.login(task.user, pwd);
    if (!GradeSync.valid(task)) { return GradeSync.cancelled(); }
    if (!login.ok) { return { ok: false, expired: false, message: login.message, snapshot: null }; }
    const cookie: string = auth.cookieHeader();
    await SessionStore.saveJw(cookie);
    if (!GradeSync.valid(task)) { return GradeSync.cancelled(); }
    const result: GradeSyncResult = await GradeSync.collect(task, cookie);
    return result.expired ? GradeSync.expiredResult(task) : result;
  }

  private static async collect(task: GradeTask, cookie: string): Promise<GradeSyncResult> {
    const auth: ZhengfangAuth = new ZhengfangAuth();
    auth.attachSession(cookie);
    const current: Semester = currentSemester(new Date());
    const inferred: number = Number(ProfileStore.gradeOf(task.user));
    // Unknown IDs still search a bounded eight academic years. Valid older cohorts retain their full history.
    const firstYear: number = Number.isInteger(inferred) && inferred >= 1970 && inferred <= current.xnm ? inferred : current.xnm - 7;
    const terms: TermGrades[] = [];
    const all: GradeRecord[] = [];
    for (let year = current.xnm; year >= firstYear; year--) {
      for (let index = 0; index < GradeSync.TERM_CODES.length; index++) {
        const code: number = GradeSync.TERM_CODES[index];
        if (year === current.xnm && code > current.xqm) { continue; }
        if (!GradeSync.valid(task)) { return GradeSync.cancelled(); }
        let items: GradeRecord[];
        try {
          const body: string = await auth.fetchGrades(year, code);
          if (!GradeSync.valid(task)) { return GradeSync.cancelled(); }
          items = GradeAdapter.parse(body);
        } catch (e) {
          if (!GradeSync.valid(task)) { return GradeSync.cancelled(); }
          const message: string = (e as Error).message || JSON.stringify(e);
          return {
            ok: false, expired: message.indexOf('过期') >= 0,
            message: `${termLabelOf(year, code)} 获取失败，已保留原有完整缓存：${message}`, snapshot: null
          };
        }
        if (items.length > 0) {
          terms.push({ xnm: year, xqm: code, label: termLabelOf(year, code), items: items });
          for (let i = 0; i < items.length; i++) { all.push(items[i]); }
        }
      }
    }
    if (!GradeSync.valid(task)) { return GradeSync.cancelled(); }
    const snapshot: GradeSnapshot = { at: Date.now(), user: task.user, status: 'ok', terms: terms, items: all, summary: summarize(all) };
    if (task.ctx !== null) {
      await GradeCacheStore.save(task.ctx, snapshot);
      if (!GradeSync.valid(task)) { return GradeSync.cancelled(); }
    }
    return { ok: true, expired: false, message: all.length === 0 ? '还没有已出分成绩' : '', snapshot: snapshot };
  }

  private static async expiredResult(task: GradeTask): Promise<GradeSyncResult> {
    if (!GradeSync.valid(task)) { return GradeSync.cancelled(); }
    if (task.ctx !== null) {
      const old: GradeSnapshot | null = await GradeCacheStore.load(task.ctx, task.user);
      if (!GradeSync.valid(task)) { return GradeSync.cancelled(); }
      if (old !== null && old.user === task.user) {
        const flagged: GradeSnapshot = { at: old.at, user: old.user, status: 'expired', terms: old.terms, items: old.items, summary: old.summary };
        await GradeCacheStore.save(task.ctx, flagged);
      }
    }
    return { ok: false, expired: true, message: '身份验证已过期，请点击右上角重新验证；原有成绩已保留', snapshot: null };
  }
}
