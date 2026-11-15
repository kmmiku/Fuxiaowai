import { retryExternalCleanup } from './cleanup';
import { toast } from '../ui/toast';
import { atomic, recoverStorage } from './persistence';
import { accountToken, isCurrent, invalidateAccount, schoolTask } from './accountScope';
import { initializeTerm, loadTerm, saveTerm } from './termStore';
import { refreshTerm } from './semester';
/**
 * 全局状态：一份 Data 快照 + 一组会落盘的写操作。
 * 所有写操作都遵守「先写 localStorage，再 setData」，这样切页/重进不会丢。
 */
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import type { ReactNode } from 'react';

import type { AppSettings, Course, Credential, FeedbackItem, Period, Profile, TableOption } from './types';
import { DEFAULT_PERIODS } from './types';
import * as DB from './store';
import { TOTAL_WEEKS, currentWeek } from './semester';
import { buildWidgetSnapshot, syncWidget } from './widget';
import { clearGradesCache } from './gradeStore';
import { currentSemester, ensureJwSession, fetchTimetable, login, persistJwSession } from './zhengfang';
import { silentPortalLogin } from './portal';

export interface Data {
  settings: AppSettings;
  periods: Period[];
  tables: TableOption[];
  activeTableId: string;
  courses: Course[];
  profile: Profile;
  credential: Credential | null;
  feedback: FeedbackItem[];
  avatar: string;
}

export interface AppCtx extends Data {
  /** 当前查看的教学周（1..20） */
  week: number;
  setWeek: (w: number) => void;

  updateSettings: (patch: Partial<AppSettings>) => void;
  setPeriods: (list: Period[]) => void;
  resetPeriods: () => void;

  switchTable: (id: string) => void;
  createTable: (name: string) => string;
  renameTable: (id: string, name: string) => void;
  deleteTable: (id: string) => void;

  replaceCourses: (list: Course[]) => void;
  addCourse: (c: Omit<Course, 'id'>) => void;
  updateCourse: (c: Course) => void;
  deleteCourse: (id: string) => void;

  saveProfile: (p: Profile) => void;
  setCredential: (c: Credential | null) => void;
  /** 换账号登录：凭据 + 资料 + 课表一次写完，避免中间态串号 */
  signIn: (c: Credential, p: Profile, courses: Course[]) => void;
  /** 退出登录：清凭据与名下课表/成绩缓存，回到未登录空态 */
  signOut: () => void;

  addFeedback: (item: FeedbackItem) => void;
  markFeedbackSent: (id: string) => void;
  setAvatar: (dataUrl: string) => void;

  /** 清空全部本地数据（隐私撤回） */
  wipe: () => void;
  reload: () => void;
}

const Ctx = createContext<AppCtx | null>(null);

/** App 启动时「每天自动更新课表」只跑一次，StrictMode 双执行也只跑一次 */
let autoSyncStarted = false;

function initData(): Data {
  recoverStorage();
  DB.ensureSeeded();
  DB.migrateCleanDemo();
  // 老版本的课表/头像存在全局键上，按学号搬一次，避免换账号看到别人的东西
  DB.migrateAccountScope();
  const tables = DB.loadTables();
  const selected = DB.loadActiveTable();
  const activeTableId = tables.some(t=>t.id===selected) ? selected : tables[0]?.id || 't1';
  DB.saveActiveTable(activeTableId);
  initializeTerm(activeTableId);
  refreshTerm();
  return {
    settings: DB.loadSettings(),
    periods: DB.loadPeriods(),
    tables,
    activeTableId,
    courses: DB.loadCourses(activeTableId),
    profile: DB.loadProfile(),
    credential: DB.loadCredential(),
    feedback: DB.loadFeedback(),
    avatar: DB.loadAvatar()
  };
}

function newTableId(): string {
  return `t${Date.now().toString(36)}`;
}

export function AppProvider({ children }: { children: ReactNode }) {
  const [data, setData] = useState<Data>(initData);
  useEffect(()=>{void retryExternalCleanup().then(done=>{if(done)setData(initData());}).catch(e=>toast(e instanceof Error?e.message:'清理未完成，请重试'));},[]);
  const [week, setWeekState] = useState<number>(() => currentWeek());

  /* ---------------- 主题：深色写进 html[data-dark] ---------------- */
  useEffect(() => {
    document.documentElement.dataset.dark = String(data.settings.dark);
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', data.settings.dark ? '#0E1116' : '#F6F7FB');
  }, [data.settings.dark]);

  /* ---------------- 桌面小组件：课表变了就推一次快照 ---------------- */
  useEffect(() => {
    void syncWidget(buildWidgetSnapshot(data.courses, data.periods, currentWeek()));
  }, [data.courses, data.periods, week]);

  /* ---------------- 每天首次打开自动更新课表（失败静默） ---------------- */
  const dataRef = useRef(data);
  dataRef.current = data;
  const publish = (next: Data) => { dataRef.current=next; setData(next); };
  const commit = useCallback((change: (current: Data) => Data) => {
    const next=atomic(()=>change(dataRef.current));
    dataRef.current=next; setData(next);
  }, []);
  useEffect(() => {
    if (autoSyncStarted) return;
    autoSyncStarted = true;
    const cred = dataRef.current.credential;
    if (!cred || !cred.user || !cred.autoUpdate) return;
    if (cred.autoDay === DB.todayKey()) return;

    const token=accountToken();
    const target=DB.loadActiveTable();
    void schoolTask(token, async () => {
      try {
        let ok = ensureJwSession(cred.user);
        if (!ok && cred.pwd) {
          const res = await login(cred.user, cred.pwd);
          ok = res.ok;
          if (!ok) ok = (await silentPortalLogin(cred.user, cred.pwd)).ok;
        }
        if (!ok) return;
        if (!isCurrent(token,cred.user)) return;
        persistJwSession(cred.user);

        const tt = await fetchTimetable(cred.user, currentSemester());
        // 只认这次登录的学号，教务回了别人的课表就整单丢掉
        const xh = (tt.student.XH ?? '').trim();
        if (!tt.courses.length || (xh && xh !== cred.user)) return;

        if (!isCurrent(token,cred.user) || DB.loadActiveTable()!==target) return;
        const active = target;
        const nextCred: Credential = { ...cred, lastSyncAt: Date.now(), autoDay: DB.todayKey() };
        commit((d) => {
          if (!isCurrent(token,cred.user) || d.activeTableId!==target) return d;
          DB.saveCourses(active,tt.courses); DB.saveCredential(nextCred);
          saveTerm(active,{...loadTerm(active),syncedAt:Date.now()});
          return {...d,courses:DB.loadCourses(active),credential:nextCred};
        });
      } catch {
        /* 自动更新失败不打扰用户，手动刷新会有提示 */
      }
    }).catch(() => undefined);
  }, []);

  const updateSettings = useCallback((patch: Partial<AppSettings>) => {
    commit((d) => {
      const settings = { ...d.settings, ...patch };
      DB.saveSettings(settings);
      return { ...d, settings };
    });
  }, []);

  const setPeriods = useCallback((list: Period[]) => {
    DB.savePeriods(list);
    commit((d) => ({ ...d, periods: list }));
  }, []);

  const resetPeriods = useCallback(() => {
    const list = DEFAULT_PERIODS.map((p) => ({ ...p }));
    DB.savePeriods(list);
    commit((d) => ({ ...d, periods: list }));
  }, []);

  const switchTable = useCallback((id: string) => {
    commit((d) => {
      if (!d.tables.some(t=>t.id===id)) return d;
      DB.saveActiveTable(id); initializeTerm(id); refreshTerm();
      return {...d,activeTableId:id,courses:DB.loadCourses(id)};
    });
  }, []);

  const createTable = useCallback((name: string) => {
    const id = newTableId();
    commit((d) => {
      const tables = [...d.tables, { id, name }];
      DB.saveTables(tables);
      DB.saveActiveTable(id);
      DB.saveCourses(id, []); initializeTerm(id); refreshTerm();
      return { ...d, tables, activeTableId: id, courses: [] };
    });
    return id;
  }, []);

  const renameTable = useCallback((id: string, name: string) => {
    commit((d) => {
      const tables = d.tables.map((t) => (t.id === id ? { ...t, name } : t));
      DB.saveTables(tables);
      return { ...d, tables };
    });
  }, []);

  const deleteTable = useCallback((id: string) => {
    commit((d) => {
      const tables = d.tables.filter((t) => t.id !== id);
      const safeTables = tables.length > 0 ? tables : [{ id: 't1', name: '我的课表' }];
      const activeTableId = d.activeTableId === id ? safeTables[0].id : d.activeTableId;
      DB.saveTables(safeTables);
      DB.saveActiveTable(activeTableId);
      DB.removeCourses(id); refreshTerm();
      return { ...d, tables: safeTables, activeTableId, courses: DB.loadCourses(activeTableId) };
    });
  }, []);

  const replaceCourses = useCallback((list: Course[]) => {
    commit((d) => {
      DB.saveCourses(d.activeTableId, list);
      return { ...d, courses: DB.loadCourses(d.activeTableId) };
    });
  }, []);

  const addCourse = useCallback((c: Omit<Course, 'id'>) => {
    commit((d) => {
      const course: Course = { ...c, id: `c_${Date.now()}_${Math.floor(Math.random() * 1000)}` };
      const courses = [...d.courses, course];
      DB.saveCourses(d.activeTableId, courses);
      return { ...d, courses: DB.loadCourses(d.activeTableId) };
    });
  }, []);

  const updateCourse = useCallback((c: Course) => {
    commit((d) => {
      const courses = d.courses.map((x) => (x.id === c.id ? c : x));
      DB.saveCourses(d.activeTableId, courses);
      return { ...d, courses: DB.loadCourses(d.activeTableId) };
    });
  }, []);

  const deleteCourse = useCallback((id: string) => {
    commit((d) => {
      const courses = d.courses.filter((c) => c.id !== id);
      DB.saveCourses(d.activeTableId, courses);
      return { ...d, courses: DB.loadCourses(d.activeTableId) };
    });
  }, []);

  const saveProfile = useCallback((p: Profile) => {
    DB.saveProfile(p);
    commit((d) => ({ ...d, profile: p }));
  }, []);

  const setCredential = useCallback((c: Credential | null) => {
    if (!c) {
      DB.clearCredential();
      publish(initData());
      return;
    }
    DB.saveCredential(c);
    commit((d) => ({ ...d, credential: c }));
  }, []);

  const signIn = useCallback((c: Credential, p: Profile, courses: Course[]) => {
    const next=atomic(() => {
      DB.saveCredential(c); DB.saveProfile(p);
      const tables=DB.loadTables();
      let active=DB.loadActiveTable() || tables[0].id;
      if(!tables.some(t=>t.id===active))active=tables[0].id;
      DB.saveActiveTable(active); DB.saveCourses(active,courses);
      initializeTerm(active); saveTerm(active,{...loadTerm(active),syncedAt:Date.now()});
      // initData normally recovers an interrupted transaction; do not recover our in-flight staged write.
      return {...dataRef.current, credential:DB.loadCredential(),profile:p,tables,activeTableId:active,courses:DB.loadCourses(active),
        avatar:DB.loadAvatar(),feedback:DB.loadFeedback()};
    });
    refreshTerm(); publish(next);
  }, []);

  const signOut = useCallback(() => {
    invalidateAccount();
    const who=DB.loadCredential()?.user ?? '';
    atomic(() => { if(who)DB.clearAccountData(who); DB.saveFeedback([]); DB.clearCredential(); });
    if(who)clearGradesCache(who);
    autoSyncStarted=false;
    publish(initData());
  }, []);

  const addFeedback = useCallback((item: FeedbackItem) => {
    commit((d) => {
      const feedback = [item, ...DB.loadFeedback().filter(f=>f.id!==item.id)];
      DB.saveFeedback(feedback);
      return { ...d, feedback:DB.loadFeedback() };
    });
  }, []);

  const markFeedbackSent = useCallback((id: string) => {
    commit((d) => {
      const feedback = DB.loadFeedback().map((f) => (f.id === id ? { ...f, sent: true, images:[],retryAt:undefined } : f));
      DB.saveFeedback(feedback);
      return { ...d, feedback:DB.loadFeedback() };
    });
  }, []);

  const setAvatar = useCallback((dataUrl: string) => {
    DB.saveAvatar(dataUrl);
    commit((d) => ({ ...d, avatar: dataUrl }));
  }, []);

  const wipe = useCallback(() => {
    const who = DB.loadCredential()?.user ?? '';
    invalidateAccount();
    DB.wipeAll();
    autoSyncStarted=false;
    if (who) clearGradesCache(who);
    publish(initData());
  }, []);

  const reload = useCallback(() => {
    publish(initData());
  }, []);

  const setWeek = useCallback((w: number) => {
    setWeekState(Math.max(1, Math.min(TOTAL_WEEKS, w)));
  }, []);

  const value = useMemo<AppCtx>(
    () => ({
      ...data,
      week,
      setWeek,
      updateSettings,
      setPeriods,
      resetPeriods,
      switchTable,
      createTable,
      renameTable,
      deleteTable,
      replaceCourses,
      addCourse,
      updateCourse,
      deleteCourse,
      saveProfile,
      setCredential,
      signIn,
      signOut,
      addFeedback,
      markFeedbackSent,
      setAvatar,
      wipe,
      reload
    }),
    [
      data,
      week,
      setWeek,
      updateSettings,
      setPeriods,
      resetPeriods,
      switchTable,
      createTable,
      renameTable,
      deleteTable,
      replaceCourses,
      addCourse,
      updateCourse,
      deleteCourse,
      saveProfile,
      setCredential,
      signIn,
      signOut,
      addFeedback,
      markFeedbackSent,
      setAvatar,
      wipe,
      reload
    ]
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useApp(): AppCtx {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error('useApp 必须在 AppProvider 内使用');
  return ctx;
}