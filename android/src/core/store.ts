import { freezeCourseColors } from './courseAppearance';
import { loadTerm, saveTerm, validateTermMetadata } from './termStore';
import { atomic, getRaw, setRaw, removeRaw } from './persistence';
import { validateCourses, validatePeriods } from './validation';
import { accountKey, invalidateAccount } from './accountScope';
import { readSecretRecord, writeSecretRecord } from './secrets';
/**
 * 本地持久化层：localStorage
 * 键名沿用鸿蒙版 preferences 的语义，方便对照排查
 *
 * 说明：Android WebView 的 localStorage 会随 WebView 数据存活，
 * 卸载 App 一起清空，和原来的 preferences 行为一致。
 */

import {
  DEFAULT_PERIODS,
  type AppSettings,
  type Course,
  type Credential,
  type FeedbackItem,
  type Period,
  type Profile,
  type TableOption,
  colorIndexOf
} from './types';

/** 老版本的三档行高，只用于把 density 迁移成 cellHeight */
const DENSITY_HEIGHT = [44, 52, 64];
export const CELL_MIN = 40;
export const CELL_MAX = 80;
/** 块宽：0 = 半列宽，50 = 正好一列（默认，滑块居中），100 = 1.5 列 */

/**
 * 账号隔离：课表、课表列表、个人资料、头像都挂在「当前登录学号」下面，
 * 换一个账号登录只会看到自己的数据，不会串到上一个账号。
 * 设备级设置（外观 / 上课时间 / 提醒）保持全局，换账号不用重设。
 */
const K = {
  settings: 'fxw_settings',
  periods: 'fxw_periods',
  credential: 'fxw_credential',
  feedback: 'fxw_feedback',
  seeded: 'fxw_seeded',
  cleanDemo: 'fxw_clean_demo',
  ratioV2: 'fxw_ratio_v4',
  scopeMigrated: 'fxw_scope_v1'
} as const;

/** 当前登录学号（只留字母数字），未登录用 anon */
function scope(): string {
  return accountKey(loadCredential()?.user ?? '');
}

function scopedKey(suffix: string): string {
  return `fxw_a_${scope()}_${suffix}`;
}

function coursesKey(tableId: string): string {
  return scopedKey(`courses_${tableId}`);
}

function read<T>(key: string, fallback: T): T {
  try {
    const raw = getRaw(key);
    if (raw === null || raw === '') return fallback;
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

function write(key: string, value: unknown): void {
  try {
    setRaw(key, JSON.stringify(value));
  } catch {
    throw new Error('本地存储写入失败，请检查可用空间');
  }
}

/* ---------------- 设置 ---------------- */

export const DEFAULT_SETTINGS: AppSettings = {
  showWeekend: true,
  showGhost: false,
  density: 1,
  cellHeight: 60,
  dark: false,
  theme: 'default',
  remindBefore: 0,
  calendarRemind: true
};

export function loadSettings(): AppSettings {
  const s = read<Partial<AppSettings>>(K.settings, {});
  // 块宽语义改过一次：以前 100% = 占满一列，现在 50% = 占满一列。
  // 老值直接作废、统一回到默认 50%，避免升级后突然变两倍宽。
  const ratioMigrated = read<boolean>(K.ratioV2, false);
  if (!ratioMigrated) write(K.ratioV2, true);
  const density = typeof s.density === 'number' ? s.density : DEFAULT_SETTINGS.density;
  const legacyHeight = DENSITY_HEIGHT[density] ?? 52;
  return {
    showWeekend: typeof s.showWeekend === 'boolean' ? s.showWeekend : DEFAULT_SETTINGS.showWeekend,
    showGhost: s.showGhost === true,
    density,
    cellHeight:
      typeof s.cellHeight === 'number'
        ? Math.min(CELL_MAX, Math.max(CELL_MIN, s.cellHeight))
        : legacyHeight,
    dark: typeof s.dark === 'boolean' ? s.dark : DEFAULT_SETTINGS.dark,
    theme: typeof s.theme === 'string' && s.theme.length > 0 ? s.theme : DEFAULT_SETTINGS.theme,
    remindBefore:
      typeof s.remindBefore === 'number' ? s.remindBefore : DEFAULT_SETTINGS.remindBefore,
    calendarRemind:
      typeof s.calendarRemind === 'boolean' ? s.calendarRemind : DEFAULT_SETTINGS.calendarRemind
  };
}

export function saveSettings(s: AppSettings): void {
  write(K.settings, s);
}

/* ---------------- 节次 ---------------- */

export function loadPeriods(): Period[] {
  const list = read<Period[]>(K.periods, []);
  if (!Array.isArray(list) || list.length === 0) return DEFAULT_PERIODS.map((p) => ({ ...p }));
  const valid = list.filter(
    (p) =>
      p &&
      typeof p.index === 'number' &&
      typeof p.start === 'string' &&
      typeof p.end === 'string' &&
      p.start.length > 0 &&
      p.end.length > 0
  );
  return valid.length > 0 ? valid : DEFAULT_PERIODS.map((p) => ({ ...p }));
}

export function savePeriods(list: Period[]): void {
  write(K.periods, validatePeriods(list));
}

/* ---------------- 课表（表） ---------------- */

export function loadTables(): TableOption[] {
  const list = read<TableOption[]>(scopedKey('tables'), []);
  if (Array.isArray(list) && list.length > 0) return list;
  const seed: TableOption[] = [{ id: 't1', name: '我的课表' }];
  write(scopedKey('tables'), seed);
  return seed;
}

export function saveTables(list: TableOption[]): void {
  write(scopedKey('tables'), list);
}

export function loadActiveTable(): string {
  return read<string>(scopedKey('active_table'), 't1');
}

export function saveActiveTable(id: string): void {
  write(scopedKey('active_table'), id);
}

/* ---------------- 课程 ---------------- */

export function loadCourses(tableId: string): Course[] {
  // coursesKey already isolates guests (anon) from every signed-in account.
  // Guest imports and manually added courses must remain readable after reload.
  const list = read<Course[]>(coursesKey(tableId), []);
  if(!Array.isArray(list))return [];
  const frozen=freezeCourseColors(list);
  if(frozen!==list)atomic(()=>write(coursesKey(tableId),frozen));
  return frozen;
}

export function saveCourses(tableId: string, courses: Course[]): Course[] {
  const valid = validateCourses(courses);
  let saved = valid;
  const key = coursesKey(tableId);
  atomic(() => {
    const old = getRaw(key);
    if (old !== null) setRaw(`${key}_snapshot_v1`, JSON.stringify({schema:1,courses:JSON.parse(old),term:loadTerm(tableId),periods:loadPeriods()}));
    const previous:Course[]=old?JSON.parse(old):[];
    const assigned=new Map(previous.map(c=>[c.id,c]));
    saved=freezeCourseColors(valid.map(c=>{const prior=assigned.get(c.id);return c.autoColorIndex===undefined&&prior?.autoColorIndex!==undefined&&prior.name===c.name&&prior.weekday===c.weekday&&prior.startPeriod===c.startPeriod&&prior.endPeriod===c.endPeriod?{...c,autoColorIndex:prior.autoColorIndex}:c;}));
    write(key, saved);
  });
  return saved;
}

export function removeCourses(tableId: string): void {
  removeRaw(coursesKey(tableId));
}

/* ---------------- 身份 ---------------- */

export function loadProfile(): Profile {
  const p = read<Partial<Profile>>(scopedKey('profile'), {});
  return {
    name: p.name ?? '',
    studentId: p.studentId ?? '',
    clazz: p.clazz ?? '',
    major: p.major ?? '',
    grade: p.grade ?? ''
  };
}

export function saveProfile(p: Profile): void {
  write(scopedKey('profile'), p);
}

export function clearProfile(): void {
  removeRaw(scopedKey('profile'));
}

/* ---------------- 教务凭据 ---------------- */

export function loadCredential(): Credential | null {
  const c = readSecretRecord(K.credential, 'pwd') as unknown as Credential | null;
  if (!c || typeof c.user !== 'string' || typeof c.pwd !== 'string') return null;
  return {
    user: c.user,
    pwd: c.pwd,
    remember: typeof c.remember === 'boolean' ? c.remember : true,
    lastSyncAt: typeof c.lastSyncAt === 'number' ? c.lastSyncAt : 0,
    autoUpdate: typeof c.autoUpdate === 'boolean' ? c.autoUpdate : true,
    autoDay: typeof c.autoDay === 'string' ? c.autoDay : ''
  };
}

export function saveCredential(c: Credential): void {
  if ((loadCredential()?.user ?? '') !== c.user) invalidateAccount();
  writeSecretRecord(K.credential, 'pwd', { ...c, pwd: c.remember ? c.pwd : '' });
}

export function clearCredential(): void {
  invalidateAccount();
  removeRaw(`${K.credential}_migration_v1`);
  removeRaw(K.credential);
}

/* ---------------- 反馈 ---------------- */

export function loadFeedback(): FeedbackItem[] {
  const list = read<FeedbackItem[]>(K.feedback, []);
  return Array.isArray(list) ? list : [];
}

export function saveFeedback(list: FeedbackItem[]): void {
  const pending = list.filter(f => !f.sent);
  if (pending.length > 100) throw new Error('待发送反馈已满，请先发送已有反馈');
  const sent = list.filter(f => f.sent).slice(0,30).map(f => ({...f,images:[]}));
  write(K.feedback, [...pending,...sent]);
}

/* ---------------- 头像（dataURL） ---------------- */

export function loadAvatar(): string {
  return read<string>(scopedKey('avatar'), '');
}

export function saveAvatar(dataUrl: string): void {
  write(scopedKey('avatar'), dataUrl);
}

export function clearAvatar(): void {
  removeRaw(scopedKey('avatar'));
}

/* ---------------- 老数据搬家（只做一次） ---------------- */

/**
 * 改造前所有账号共用一套 fxw_* 键，换账号会看到上一个人的课表。
 * 升级时把这些数据归到「当时登录的那个学号」名下，之后各账号互不可见。
 */
export function migrateAccountScope(): void {
  if (read<boolean>(K.scopeMigrated, false)) return;
  const user = loadCredential()?.user ?? '';
  if (!user) return;
  atomic(() => {
    const prefix = `fxw_a_${accountKey(user)}_`;
    const legacy: Array<[string, string]> = [
      ['fxw_tables', `${prefix}tables`], ['fxw_active_table', `${prefix}active_table`],
      ['fxw_profile', `${prefix}profile`], ['fxw_avatar', `${prefix}avatar`]
    ];
    const tables = read<TableOption[]>('fxw_tables', []);
    for (const t of Array.isArray(tables) ? tables : []) legacy.push([`fxw_courses_${t.id}`, `${prefix}courses_${t.id}`]);
    for (const [from, to] of legacy) {
      const raw = getRaw(from);
      if (raw !== null && getRaw(to) === null) setRaw(to, raw);
      if (raw !== null && getRaw(to) !== null) removeRaw(from);
    }
    write(K.scopeMigrated, true);
  });
}

/* ---------------- 示例课表种子 ---------------- */

type Seed = [
  weekday: number,
  start: number,
  end: number,
  name: string,
  room: string,
  teacher: string,
  weeks?: number[]
];

const SEED: Seed[] = [
  [1, 1, 2, 'Hadoop开发技术', '实3603', '张国煊'],
  [1, 3, 4, '机器学习', '实3303', '张紫铃'],
  [1, 5, 6, '大学英语（三）', '教4102', '陈晓'],
  [1, 9, 10, '创新创业基础', '教3202', '许清女'],
  [2, 1, 2, '高级数据库', '教4203', '梁艳'],
  [2, 3, 4, '数据结构', '实3201', '林伟'],
  [2, 5, 6, '概率论与数理统计', '教3305', '王芳'],
  [3, 1, 2, '操作系统', '实3105', '陈明'],
  [3, 3, 4, '大学体育（三）', '田径场', '李强'],
  [3, 5, 6, 'Python程序设计', '实3402', '黄敏'],
  [4, 1, 2, '计算机网络', '教4108', '吴磊'],
  [4, 3, 4, '机器学习', '实3303', '张紫铃'],
  [4, 5, 6, '高级数据库', '教4203', '梁艳'],
  [5, 1, 2, '形势与政策', '教3201', '郑华'],
  [5, 3, 4, '大学英语（三）', '教4102', '陈晓'],
  [5, 5, 6, 'Python程序设计', '实3402', '黄敏']
];

function range(a: number, b: number): number[] {
  const out: number[] = [];
  for (let i = a; i <= b; i++) out.push(i);
  return out;
}

export function seedCourses(): Course[] {
  return SEED.map(([weekday, start, end, name, room, teacher], i) => ({
    id: `seed_${i + 1}`,
    name,
    teacher,
    room,
    campus: '长乐校区',
    weekday,
    startPeriod: start,
    endPeriod: end,
    weeks: range(1, 17),
    colorIndex: colorIndexOf(name)
  }));
}

/** 首次启动只建默认课表，不写演示数据：未登录用户看到的课表必须是空的 */
export function ensureSeeded(): void {
  if (read<boolean>(K.seeded, false)) return;
  loadTables();
  write(K.seeded, true);
}

/**
 * 一次性迁移：旧版本首次启动会灌 16 门示例课表。
 * 现在要求未登录用户看到空课表，所以升级后清一次。
 * 只清「没有保存教务账号」的情况：已登录用户的课表是真实的，不能动。
 */
export function migrateCleanDemo(): void {
  if (read<boolean>(K.cleanDemo, false)) return;
  const cred = loadCredential();
  if (!cred || !cred.user) {
    loadTables().forEach((t) => {
      if (loadCourses(t.id).some((c) => c.id.startsWith('seed_'))) saveCourses(t.id, []);
    });
  }
  write(K.cleanDemo, true);
}

/** 本地自然日（yyyy-MM-dd），用于「每天只更新一次」的判重 */
export function todayKey(): string {
  const d = new Date();
  const pad = (n: number) => (n < 10 ? `0${n}` : String(n));
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export function isSeeded(): boolean {
  return read<boolean>(K.seeded, false);
}

/** 时间戳 → "11月10日 12:07"；0 返回「从未」 */
export function fmtTime(ts: number): string {
  if (!ts) return '从未';
  const d = new Date(ts);
  const pad = (n: number) => (n < 10 ? `0${n}` : String(n));
  return `${d.getMonth() + 1}月${d.getDate()}日 ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/** 清空全部本地数据（隐私协议撤回用） */
export function wipeAll(): void {
  invalidateAccount();
  const keys=Array.from({length:localStorage.length},(_,i)=>localStorage.key(i)).filter((k):k is string=>!!k&&k.startsWith('fxw_')&&k!=='fxw_cleanup_pending_v1'&&k!=='fxw_storage_transaction_v1');
  atomic(()=>{for(const key of keys)removeRaw(key);});
}
export function clearAccountData(user: string): void {
  const prefix = `fxw_a_${accountKey(user)}_`;
  const keys = Array.from({length: localStorage.length}, (_, i) => localStorage.key(i)).filter((k): k is string => !!k && k.startsWith(prefix));
  atomic(() => { for (const key of keys) removeRaw(key); });
}
export function clearTemporaryCache(): {count: number; bytes: number} {
  const keys = Array.from({length: localStorage.length}, (_, i) => localStorage.key(i)).filter((k): k is string => !!k && k.startsWith('fxw_tmp_'));
  let bytes = 0;
  for (const key of keys) { bytes += key.length + (getRaw(key)?.length ?? 0); removeRaw(key); }
  return {count: keys.length, bytes};
}

/** Internal recovery entry; the page's Course.id and overwrite semantics are unchanged. */
export function restoreLastTimetable(tableId:string):void {
  const key=coursesKey(tableId),raw=getRaw(`${key}_snapshot_v1`);
  if(!raw)throw new Error('没有可恢复的课表快照');
  const snapshot=JSON.parse(raw);
  const courses=validateCourses(snapshot.courses),periods=validatePeriods(snapshot.periods),term=validateTermMetadata(snapshot.term);
  atomic(()=>{write(key,courses);savePeriods(periods);saveTerm(tableId,term);});
}

export function clearTimetables(user:string):void {
  const prefix=`fxw_a_${accountKey(user)}_courses_`;
  const keys=Array.from({length:localStorage.length},(_,i)=>localStorage.key(i)).filter((k):k is string=>!!k&&k.startsWith(prefix));
  atomic(()=>{for(const key of keys)removeRaw(key);});
}
