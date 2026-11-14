import relationalStore from '@ohos.data.relationalStore';
import { Course } from '../../../domain/model/Course';
import { Db } from '../Db';
import { TimetableInfo } from '../../../domain/repository/CourseRepository';
import { scopedCourseId } from '../../../domain/model/CourseValidation';

const COLS: string[] = [
  'id', 'table_id', 'name', 'teacher', 'room', 'campus',
  'weekday', 'start_period', 'end_period', 'weeks', 'color_index'
];

function toBucket(c: Course, tableId: string, account: string): relationalStore.ValuesBucket {
  const bucket: relationalStore.ValuesBucket = {
    'id': accountCourseId(c.id, tableId, account),
    'account_id': account,
    'table_id': tableId,
    'name': c.name,
    'teacher': c.teacher,
    'room': c.room,
    'campus': c.campus,
    'weekday': c.weekday,
    'start_period': c.startPeriod,
    'end_period': c.endPeriod,
    'weeks': c.weeks.join(','),
    'color_index': c.colorIndex
  };
  return bucket;
}

function toCourse(rs: relationalStore.ResultSet): Course {
  const weeksText: string = rs.getString(rs.getColumnIndex('weeks'));
  const weeks: number[] = weeksText.length === 0
    ? []
    : weeksText.split(',').map((s: string) => parseInt(s, 10));
  const course: Course = {
    id: rs.getString(rs.getColumnIndex('id')),
    name: rs.getString(rs.getColumnIndex('name')),
    teacher: rs.getString(rs.getColumnIndex('teacher')),
    room: rs.getString(rs.getColumnIndex('room')),
    campus: rs.getString(rs.getColumnIndex('campus')),
    weekday: rs.getLong(rs.getColumnIndex('weekday')),
    startPeriod: rs.getLong(rs.getColumnIndex('start_period')),
    endPeriod: rs.getLong(rs.getColumnIndex('end_period')),
    weeks: weeks,
    colorIndex: rs.getLong(rs.getColumnIndex('color_index'))
  };
  return course;
}

function accountCourseId(id: string, tableId: string, account: string): string {
  let original: string = id;
  if (id.startsWith('fxwa:')) {
    const pieces: string[] = id.split(':');
    if (pieces.length === 4) { try { original = decodeURIComponent(pieces[3]); } catch (_) {} }
  } else {
    const legacy: string = scopedCourseId(id, tableId);
    const split: number = legacy.indexOf(':', 4);
    try { original = decodeURIComponent(legacy.substring(split + 1)); } catch (_) {}
  }
  return 'fxwa:' + encodeURIComponent(account) + ':' + encodeURIComponent(tableId) + ':' + encodeURIComponent(original);
}

/** 课程表 DAO：所有 SQL 都收敛在这里 */
export class CourseDao {
  static async queryByWeek(tableId: string, week: number, account: string = Db.accountUser()): Promise<Course[]> {
    const store: relationalStore.RdbStore = Db.store();
    const p: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('course');
    p.equalTo('account_id', account).equalTo('table_id', tableId).orderByAsc('weekday').orderByAsc('start_period');
    const rs: relationalStore.ResultSet = await store.query(p, COLS);
    const list: Course[] = [];
    while (rs.goToNextRow()) {
      const c: Course = toCourse(rs);
      if (c.weeks.indexOf(week) >= 0) {
        list.push(c);
      }
    }
    rs.close();
    if (Db.accountUser() !== account) { return []; }
    return list;
  }

  static async queryAll(tableId: string, account: string = Db.accountUser()): Promise<Course[]> {
    const store: relationalStore.RdbStore = Db.store();
    const p: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('course');
    p.equalTo('account_id', account).equalTo('table_id', tableId);
    const rs: relationalStore.ResultSet = await store.query(p, COLS);
    const list: Course[] = [];
    while (rs.goToNextRow()) {
      list.push(toCourse(rs));
    }
    rs.close();
    return list;
  }

  static async clear(tableId: string, account: string = Db.accountUser()): Promise<void> {
    const store: relationalStore.RdbStore = Db.store();
    const p: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('course');
    p.equalTo('account_id', account).equalTo('table_id', tableId);
    await store.delete(p);
  }

  static async insertAll(tableId: string, courses: Course[], account: string = Db.accountUser()): Promise<void> {
    const store: relationalStore.RdbStore = Db.store();
    const buckets: relationalStore.ValuesBucket[] = courses.map((c: Course) => toBucket(c, tableId, account));
    if (buckets.length > 0) {
      await store.batchInsert('course', buckets);
    }
  }

  static async insertOne(tableId: string, course: Course, account: string = Db.accountUser()): Promise<void> {
    const store: relationalStore.RdbStore = Db.store();
    await store.insert('course', toBucket(course, tableId, account));
  }

  static async remove(courseId: string, account: string = Db.accountUser()): Promise<void> {
    const store: relationalStore.RdbStore = Db.store();
    const p: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('course');
    p.equalTo('account_id', account).equalTo('id', courseId);
    await store.delete(p);
  }

  static async count(account: string = Db.accountUser()): Promise<number> {
    const store: relationalStore.RdbStore = Db.store();
    const p: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('course');
    p.equalTo('account_id', account);
    const rs: relationalStore.ResultSet = await store.query(p, ['id']);
    const n: number = rs.rowCount;
    rs.close();
    return n < 0 ? 0 : n;
  }

  // ---------- 课表（多套） ----------
  static async tables(account: string = Db.accountUser()): Promise<TimetableInfo[]> {
    const store: relationalStore.RdbStore = Db.store();
    const p: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('timetable');
    p.orderByAsc('id');
    const rs: relationalStore.ResultSet = await store.querySql("SELECT id,name FROM timetable WHERE (id='t1' AND account_id='') OR account_id=? ORDER BY id", [account]);
    const list: TimetableInfo[] = [];
    while (rs.goToNextRow()) {
      list.push({
        id: rs.getString(rs.getColumnIndex('id')),
        name: rs.getString(rs.getColumnIndex('name'))
      });
    }
    rs.close();
    return list;
  }

  static async createTable(id: string, name: string, account: string = Db.accountUser()): Promise<void> {
    const store: relationalStore.RdbStore = Db.store();
    const bucket: relationalStore.ValuesBucket = { 'id': id, 'name': name, 'is_active': 0, 'account_id': id === 't1' ? '' : account };
    await store.insert('timetable', bucket);
  }

  /** 删除课表：连同这张表下的全部课程一起删 */
  static async removeTable(id: string, account: string = Db.accountUser()): Promise<void> {
    const store: relationalStore.RdbStore = Db.store();
    const cp: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('course');
    cp.equalTo('account_id', account).equalTo('table_id', id);
    await store.delete(cp);
    const tp: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('timetable');
    tp.equalTo('account_id', account).equalTo('id', id);
    await store.delete(tp);
  }

  static async renameTable(id: string, name: string, account: string = Db.accountUser()): Promise<void> {
    const store: relationalStore.RdbStore = Db.store();
    const p: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('timetable');
    p.equalTo('account_id', id === 't1' ? '' : account).equalTo('id', id);
    const bucket: relationalStore.ValuesBucket = { 'name': name };
    await store.update(bucket, p);
  }
}
