import relationalStore from '@ohos.data.relationalStore';
import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import { SerialQueue } from '../../common/util/SerialQueue';

const DOMAIN: number = 0x0010;
const TAG: string = 'FuxiaowaiDb';
const DB_NAME: string = 'fuxiaowai.db';
const ACCOUNT_BACKUP: string = 'fuxiaowai_pre_account_v1.db';

const CONFIG: relationalStore.StoreConfig = {
  name: DB_NAME,
  securityLevel: relationalStore.SecurityLevel.S1
};

const SQL_COURSE: string = `CREATE TABLE IF NOT EXISTS course (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL DEFAULT '',
  table_id TEXT NOT NULL,
  name TEXT NOT NULL,
  teacher TEXT,
  room TEXT,
  campus TEXT,
  weekday INTEGER NOT NULL,
  start_period INTEGER NOT NULL,
  end_period INTEGER NOT NULL,
  weeks TEXT NOT NULL,
  color_index INTEGER NOT NULL,
  color_override INTEGER NOT NULL DEFAULT 0
)`;

const SQL_TIMETABLE: string = `CREATE TABLE IF NOT EXISTS timetable (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  account_id TEXT NOT NULL DEFAULT '',
  is_active INTEGER DEFAULT 0
)`;

const SQL_PERIOD: string = `CREATE TABLE IF NOT EXISTS period (
  idx INTEGER PRIMARY KEY,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL
)`;

const SQL_META: string = `CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT
)`;

/**
 * 数据库单例。
 * 关键点：open() 用一个共享 Promise 收敛并发调用，
 * 避免"页面 aboutToAppear 抢跑、DB 还没 open 完"的经典竞态。
 */
export class Db {
  private static rdb: relationalStore.RdbStore | null = null;
  private static opening: Promise<void> | null = null;
  private static writes: SerialQueue = new SerialQueue();
  private static account: string = '';
  static accountUser(): string { return Db.account; }
  static selectAccount(user: string): void { Db.account = user; }

  private static async hasColumn(store: relationalStore.RdbStore, table: string, column: string): Promise<boolean> {
    const rs: relationalStore.ResultSet = await store.querySql('PRAGMA table_info(' + table + ')');
    try {
      while (rs.goToNextRow()) { if (rs.getString(rs.getColumnIndex('name')) === column) { return true; } }
      return false;
    } finally { rs.close(); }
  }

  private static async migrateAccounts(store: relationalStore.RdbStore): Promise<void> {
    const course: boolean = await Db.hasColumn(store, 'course', 'account_id');
    const timetable: boolean = await Db.hasColumn(store, 'timetable', 'account_id');
    if (course && timetable) { return; }
    await store.backup(ACCOUNT_BACKUP);
    store.beginTransaction();
    try {
      if (!course) { await store.executeSql("ALTER TABLE course ADD COLUMN account_id TEXT NOT NULL DEFAULT ''"); }
      if (!timetable) { await store.executeSql("ALTER TABLE timetable ADD COLUMN account_id TEXT NOT NULL DEFAULT ''"); }
      await store.executeSql("INSERT OR REPLACE INTO meta (key,value) VALUES ('account_schema','1')");
      store.commit();
    } catch (error) { store.rollBack(); throw new Error((error as Error).message || '账号数据迁移失败'); }
  }

  private static async migrateCourseColors(store: relationalStore.RdbStore): Promise<void> {
    if (await Db.hasColumn(store, 'course', 'color_override')) { return; }
    store.beginTransaction();
    try {
      await store.executeSql('ALTER TABLE course ADD COLUMN color_override INTEGER NOT NULL DEFAULT 0');
      store.commit();
    } catch (error) { store.rollBack(); throw new Error((error as Error).message || '课程颜色字段迁移失败'); }
  }

  static async claimLegacyAccount(user: string): Promise<void> {
    return Db.transaction(async () => {
      const store: relationalStore.RdbStore = Db.store();
      const rs: relationalStore.ResultSet = await store.querySql("SELECT value FROM meta WHERE key='legacy_account_claimed'");
      let claimed: boolean = false;
      try { claimed = rs.goToNextRow(); } finally { rs.close(); }
      if (claimed) { return; }
      await store.executeSql("UPDATE course SET account_id=? WHERE account_id=''", [user]);
      await store.executeSql("UPDATE timetable SET account_id=? WHERE account_id='' AND id<>'t1'", [user]);
      await store.executeSql("INSERT INTO meta (key,value) VALUES ('legacy_account_claimed',?)", [user]);
    });
  }

  static async clearMigrationBackup(context: common.Context): Promise<void> {
    return Db.write(() => relationalStore.deleteRdbStore(context, ACCOUNT_BACKUP));
  }

  static async eraseAllAccountData(): Promise<void> {
    return Db.transaction(async () => {
      const store: relationalStore.RdbStore = Db.store();
      await store.executeSql('DELETE FROM course');
      await store.executeSql("DELETE FROM timetable WHERE id<>'t1'");
      await store.executeSql("UPDATE timetable SET account_id='' WHERE id='t1'");
    });
  }

  static write<T>(work: () => Promise<T>): Promise<T> {
    return Db.writes.run(work);
  }

  static transaction<T>(work: () => Promise<T>): Promise<T> {
    return Db.write(async () => {
      const store: relationalStore.RdbStore = Db.store();
      store.beginTransaction();
      try {
        const value: T = await work();
        store.commit();
        return value;
      } catch (e) {
        store.rollBack();
        throw new Error((e as Error).message || '数据库写入失败');
      }
    });
  }

  static open(context: common.Context): Promise<void> {
    if (Db.rdb !== null) {
      return Promise.resolve();
    }
    if (Db.opening === null) {
      Db.opening = Db.doOpen(context).catch((e: Error) => {
        Db.opening = null;
        throw e;
      });
    }
    return Db.opening;
  }

  private static async doOpen(context: common.Context): Promise<void> {
    const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, CONFIG);
    await store.executeSql(SQL_COURSE);
    await store.executeSql(SQL_TIMETABLE);
    await store.executeSql(SQL_PERIOD);
    await store.executeSql(SQL_META);
    await Db.migrateAccounts(store);
    await Db.migrateCourseColors(store);
    Db.rdb = store;
    hilog.info(DOMAIN, TAG, '%{public}s', 'db opened, version ready');
  }

  static store(): relationalStore.RdbStore {
    if (Db.rdb === null) {
      throw new Error('Db not opened');
    }
    return Db.rdb;
  }

  static isReady(): boolean {
    return Db.rdb !== null;
  }
}
