import { reportLoginMetric } from '../../data/remote/UserMetrics';
import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import { CourseRepository, TimetableInfo } from '../../domain/repository/CourseRepository';
import { CourseRepositoryImpl } from '../../data/repository/CourseRepositoryImpl';
import { CourseDao } from '../../data/local/dao/CourseDao';
import { Db } from '../../data/local/Db';
import { TimetableSource, QrTicket, QrProgress } from '../../domain/service/TimetableSource';
import { FuwaiTimetableSource } from '../../data/remote/FuwaiTimetableSource';
import { SyncTimetable, SyncResult } from '../../domain/usecase/SyncTimetable';
import { ProfileStore, Profile } from '../../data/local/ProfileStore';
import { Credential, CredentialStore } from '../../data/local/CredentialStore';
import { SessionStore } from '../../data/local/SessionStore';
import { GradeSync, GradeSyncResult } from '../../data/remote/GradeSync';
import { GradeCacheStore, GradeSnapshot } from '../../data/local/GradeCacheStore';
import { StudentInfo } from '../../domain/service/TimetableSource';
import { AccountScope } from '../../common/util/AccountScope';
import { TimetableStateStore, clearOwnedReminders, resolveSchoolTerm, TermMetadata } from '../../data/local/TimetableStateStore';
import { clearOwnedCalendarEvents } from '../../common/util/CalendarExport';
import { AvatarStore } from '../../data/local/AvatarStore';
import { FeedbackStore } from '../../data/local/FeedbackStore';
import preferences from '@ohos.data.preferences';
import fs from '@ohos.file.fs';
import webview from '@ohos.web.webview';
import { WidgetRefresh } from '../../widget/WidgetRefresh';
import { PeriodStore } from '../../data/local/PeriodStore';
import { DEFAULT_PERIODS } from '../../domain/model/Course';

const DOMAIN: number = 0x0020;
const TAG: string = 'FuxiaowaiDI';

/**
 * 极简依赖注入（手写 30 行，不引第三方框架）。
 * 页面只认 Locator.repo() / Locator.sync()，换实现只改这里。
 */
export class Locator {
  private static repoImpl: CourseRepository | null = null;
  private static sourceImpl: TimetableSource | null = null;
  private static syncImpl: SyncTimetable | null = null;
  private static initializing: Promise<void> | null = null;
  private static loginPrevious: string = '';

  static repo(): CourseRepository {
    if (Locator.repoImpl === null) {
      Locator.repoImpl = new CourseRepositoryImpl();
    }
    return Locator.repoImpl;
  }

  static sync(): SyncTimetable {
    if (Locator.syncImpl === null) {
      Locator.syncImpl = new SyncTimetable(Locator.source(), Locator.repo());
    }
    return Locator.syncImpl;
  }

  private static source(): TimetableSource {
    if (Locator.sourceImpl === null) {
      Locator.sourceImpl = new FuwaiTimetableSource();
    }
    return Locator.sourceImpl;
  }

  /** 打开数据库（EntryAbility.onCreate 调一次即可，页面里再兜底一次） */
  static async init(context: common.UIAbilityContext): Promise<void> {
    if (Locator.initializing === null) {
      Locator.initializing = Locator.initStores(context).catch((e: Error) => {
        Locator.initializing = null;
        throw e;
      });
    }
    await Locator.initializing;
  }

  private static async initStores(context: common.UIAbilityContext): Promise<void> {
    await Db.open(context);
    Locator.ctx = context;
    SessionStore.use(context);
    GradeSync.use(context);
    await TimetableStateStore.init(context);
    const credential: Credential = await CredentialStore.load(context);
    await Db.claimLegacyAccount(credential.user);
    Db.selectAccount(credential.user);
    AccountScope.adopt(credential.user);
    await SessionStore.bindUser(credential.user);
  }

  private static ctx: common.UIAbilityContext | null = null;

  /**
   * 同步课表并顺手把学生信息落盘。
   * 教务的 xsxxwh 接口对本账号没有访问权限，姓名/专业只能从课表接口的 xsxx 取，
   * 所以这里统一在同步成功后写 ProfileStore，"我的"页直接读缓存。
   */
  static async syncAndSave(user: string, pwd: string, tableId: string): Promise<SyncResult> {
    const previous: string = Db.accountUser();
    Locator.loginPrevious = previous;
    AccountScope.begin(user);
    await SessionStore.bindUser(user);
    const token: number = AccountScope.token();
    const r: SyncResult = await Locator.sync().run(user, pwd, tableId);
    if (!AccountScope.valid(token)) { return Locator.cancelled(r); }
    if (!r.ok && r.captcha.byteLength === 0) {
      Db.selectAccount(previous);
      AccountScope.adopt(previous);
      await SessionStore.bindUser(previous);
    }
    return await Locator.persist(user, r, tableId);
  }

  /** 验证码填完之后继续同一次同步（会话由数据源自己握着） */
  static async syncWithCaptcha(code: string, user: string, tableId: string): Promise<SyncResult> {
    const token: number = AccountScope.token();
    const r: SyncResult = await Locator.sync().resumeCaptcha(code, user, tableId);
    if (!AccountScope.valid(token)) { return Locator.cancelled(r); }
    if (!r.ok && r.captcha.byteLength === 0) { await Locator.restoreLoginAccount(); }
    return await Locator.persist(user, r, tableId);
  }

  /** 换一张验证码图（浮层里点图片时用） */
  static async refreshCaptcha(): Promise<ArrayBuffer> {
    return await Locator.sync().refreshCaptcha();
  }

  /** 企业微信扫码登录：取二维码 */
  static async qrStart(): Promise<QrTicket> {
    Locator.loginPrevious = Db.accountUser();
    AccountScope.begin('');
    return await Locator.sync().qrStart();
  }

  /** 企业微信扫码登录：轮询状态 */
  static async qrPoll(): Promise<QrProgress> {
    return await Locator.sync().qrPoll();
  }

  /** 企业微信扫码确认后：取课表 + 落库 + 写学生信息 + 记住登录过的学号 */
  static async syncWithQr(code: string, tableId: string): Promise<SyncResult> {
    const token: number = AccountScope.token();
    const r: SyncResult = await Locator.sync().qrLogin(code, tableId);
    if (!AccountScope.valid(token)) { return Locator.cancelled(r); }
    if (!r.ok && r.captcha.byteLength === 0) { await Locator.restoreLoginAccount(); }
    if (r.ok) {
      await Locator.rememberQrUser(r);
    }
    return await Locator.persist('', r, tableId);
  }

  /**
   * 扫码登录只拿到身份、没有密码，但首页靠「有没有登录过的账号」决定要不要显示课表，
   * 所以这里必须把学号补写进 CredentialStore，否则课上来了、首页依旧空白。
   * 密码只在同一账号时沿用；换了账号就清空并关掉自动同步，免得拿旧密码去连别人。
   */
  private static async rememberQrUser(r: SyncResult): Promise<void> {
    const token: number = AccountScope.token();
    const ctx: common.UIAbilityContext | null = Locator.ctx;
    if (ctx === null) {
      return;
    }
    const sid: string = r.student.studentId;
    if (sid.length === 0) {
      hilog.warn(DOMAIN, TAG, 'qr login ok but student id is empty, skip credential write');
      return;
    }
    try {
      const old: Credential = await CredentialStore.load(ctx);
      if (!AccountScope.valid(token)) { return; }
      const same: boolean = old.user === sid;
      const c: Credential = {
        user: sid,
        pwd: same ? old.pwd : '',
        remember: same ? old.remember : false,
        autoUpdate: same ? old.autoUpdate : false
      };
      await CredentialStore.save(ctx, c);
      hilog.info(DOMAIN, TAG, 'qr credential user=%{public}s same=%{public}s', sid, same ? '1' : '0');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'qr credential save failed %{public}s', JSON.stringify(e));
    }
  }

  /**
   * 登录成功后的第一件事：趁会话还热，把成绩全量抓一遍存到本地。
   * 扫码登录只拿到一小段校验权限，晚一步就可能已经过期；
   * 这里刻意不 await —— 成绩拉多久都不能拖住「导入课表」的返回。
   */
  private static gradesInBackground(user: string): void {
    const ctx: common.UIAbilityContext | null = Locator.ctx;
    if (ctx === null || user.length === 0) {
      return;
    }
    CredentialStore.load(ctx).then((cred: Credential) => {
      const pwd: string = cred.user === user ? cred.pwd : '';
      return GradeSync.quiet(user, pwd);
    }).then((r: GradeSyncResult) => {
      hilog.info(DOMAIN, TAG, 'background grades ok=%{public}s msg=%{public}s',
        r.ok ? '1' : '0', r.message);
    }).catch((e: Error) => {
      hilog.warn(DOMAIN, TAG, 'background grades failed %{public}s', JSON.stringify(e));
    });
  }

  /** 成绩页手动/自动刷新时调用（返回完整结果，页面自己决定怎么显示） */
  static async syncGrades(user: string): Promise<GradeSyncResult> {
    const ctx: common.UIAbilityContext | null = Locator.ctx;
    let pwd: string = '';
    let uid: string = user;
    if (ctx !== null) {
      const cred: Credential = await CredentialStore.load(ctx);
      uid = user.length > 0 ? user : cred.user;
      pwd = cred.user === uid ? cred.pwd : '';
    }
    return await GradeSync.quiet(uid, pwd);
  }

  /** 读离线缓存（没网也能看） */
  static async loadGradeCache(user: string): Promise<GradeSnapshot | null> {
    const ctx: common.UIAbilityContext | null = Locator.ctx;
    if (ctx === null) {
      return null;
    }
    const credential: Credential = await CredentialStore.load(ctx);
    const uid: string = user.length > 0 ? user : credential.user;
    if (uid.length === 0 || uid !== credential.user) { return null; }
    return await GradeCacheStore.load(ctx, uid);
  }

  /** 退出登录 / 清数据：成绩缓存和课表一起清 */
  static async clearGradeCache(): Promise<void> {
    const ctx: common.UIAbilityContext | null = Locator.ctx;
    if (ctx === null) {
      return;
    }
    await GradeCacheStore.clear(ctx);
  }

  private static cancelled(r: SyncResult): SyncResult {
    return { ok: false, message: '账号状态已变更，请重新操作', count: 0,
      student: r.student, semesterLabel: '', captcha: new ArrayBuffer(0) };
  }

  /** One cleanup path for every logout and privacy withdrawal entry. */
  static async clearPersonalData(): Promise<void> {
    const ctx: common.UIAbilityContext | null = Locator.ctx;
    if (ctx === null) { throw new Error('应用尚未初始化'); }
    AccountScope.invalidate();
    SessionStore.invalidate();
    Locator.sourceImpl = null;
    Locator.syncImpl = null;
    await Db.eraseAllAccountData();
    await Db.clearMigrationBackup(ctx);
    Db.selectAccount('');
    await CredentialStore.clear(ctx);
    await ProfileStore.clear(ctx);
    await SessionStore.clear();
    await GradeCacheStore.clear(ctx);
    await AvatarStore.clear(ctx);
    await FeedbackStore.clear(ctx);
    const shares: preferences.Preferences = await preferences.getPreferences(ctx, 'fxw_share');
    await shares.clear(); await shares.flush();
    const favorites: preferences.Preferences = await preferences.getPreferences(ctx, 'fxw_workbench');
    await favorites.clear(); await favorites.flush();
    const examCache: preferences.Preferences = await preferences.getPreferences(ctx, 'fxw_exam_cache');
    await examCache.clear(); await examCache.flush();
    try { webview.WebCookieManager.clearAllCookiesSync(); } catch (e) {}
    await clearOwnedReminders(ctx);
    // Calendar read/write may be denied; do not silently claim all data was removed.
    await clearOwnedCalendarEvents(ctx);
    await TimetableStateStore.clear();
    await WidgetRefresh.update(ctx, [], []);
    for (const dir of [ctx.filesDir, ctx.cacheDir]) {
      for (const name of fs.listFileSync(dir)) {
        if (/^(avatar_|crop_src_|fb_|grades_)/.test(name)) {
          try { fs.unlinkSync(dir + '/' + name); } catch (e) {}
        }
      }
    }
  }

  private static async persist(user: string, r: SyncResult, tableId: string): Promise<SyncResult> {
    const token: number = AccountScope.token();
    if (r.ok) {
      if (Locator.ctx !== null) { await TimetableStateStore.init(Locator.ctx); }
      if (!AccountScope.valid(token)) { return Locator.cancelled(r); }
      await TimetableStateStore.discardGuest();
      if (!AccountScope.valid(token)) { return Locator.cancelled(r); }
      if (Locator.loginPrevious.length === 0 && Locator.ctx !== null) {
        PeriodStore.init(Locator.ctx);
        if (!await PeriodStore.save(DEFAULT_PERIODS, token)) {
          if (!AccountScope.valid(token)) { return Locator.cancelled(r); }
          throw new Error('教务课表已导入，上课时间重置失败，请重试');
        }
      }
      const metadata: TermMetadata | null = resolveSchoolTerm(r.semesterLabel);
      if (metadata !== null) { await TimetableStateStore.saveTerm(tableId, metadata, token); }
      await TimetableStateStore.select(tableId);
      if (!AccountScope.valid(token)) { return Locator.cancelled(r); }
    }
    if (r.ok && Locator.ctx !== null) {
      const p: Profile = {
        name: r.student.name,
        studentId: r.student.studentId.length > 0 ? r.student.studentId : user,
        clazz: r.student.clazz,
        major: r.student.major,
        grade: ProfileStore.gradeOf(r.student.studentId.length > 0 ? r.student.studentId : user),
        updatedAt: Date.now()
      };
      await ProfileStore.save(Locator.ctx, p);
    }
    if (r.ok && AccountScope.valid(token)) {
      const sid: string = r.student.studentId.length > 0 ? r.student.studentId : user;
      Locator.gradesInBackground(sid);
      reportLoginMetric(sid).catch(() => {});
    }
    return r;
  }

  private static async restoreLoginAccount(): Promise<void> {
    Db.selectAccount(Locator.loginPrevious);
    AccountScope.adopt(Locator.loginPrevious);
    await SessionStore.bindUser(Locator.loginPrevious);
  }

  /**
   * 首次启动只建默认课表，不写任何演示数据。
   * 游客可通过口令导入或手动添加；成功登录后由教务课表覆盖，退出清空。
   */
  static async ensureSeed(): Promise<void> {
    const r: CourseRepository = Locator.repo();
    const tables: TimetableInfo[] = await r.tables();
    if (tables.length === 0) {
      await Db.write(() => CourseDao.createTable('t1', '我的课表'));
      hilog.info(DOMAIN, TAG, 'created default timetable t1');
    }
    if (await r.isEmpty()) {
      hilog.info(DOMAIN, TAG, 'timetable is empty, waiting for login');
    }
  }
}

