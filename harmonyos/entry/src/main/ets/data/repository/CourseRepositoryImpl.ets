import { Course } from '../../domain/model/Course';
import { CourseRepository, TimetableInfo } from '../../domain/repository/CourseRepository';
import { CourseDao } from '../local/dao/CourseDao';
import { Db } from '../local/Db';
import { validateCourses } from '../../domain/model/CourseValidation';
import { AccountScope } from '../../common/util/AccountScope';

/** CourseRepository 的实现：目前直连本地 RDB，M3 起由教务同步写入 */
export class CourseRepositoryImpl implements CourseRepository {
  private static tableSequence: number = 0;
  private checkAccount(account: string, token?: number, canCommit?: () => boolean): void {
    if (Db.accountUser() !== account || (token !== undefined && !AccountScope.valid(token)) ||
      (canCommit !== undefined && !canCommit())) {
      throw new Error('账号已切换，取消课表写入');
    }
  }
  async listByWeek(tableId: string, week: number): Promise<Course[]> {
    return CourseDao.queryByWeek(tableId, week);
  }

  async listAll(tableId: string): Promise<Course[]> {
    return CourseDao.queryAll(tableId);
  }

  async replaceAll(tableId: string, courses: Course[], clearGuest: boolean = false, accountToken?: number,
    canCommit?: () => boolean): Promise<void> {
    validateCourses(courses);
    const account: string = Db.accountUser();
    await Db.transaction(async () => {
      this.checkAccount(account, accountToken, canCommit);
      await CourseDao.clear(tableId, account);
      await CourseDao.insertAll(tableId, courses, account);
      if (clearGuest && account.length > 0) {
        await Db.store().executeSql("DELETE FROM course WHERE account_id='' ");
        await Db.store().executeSql("DELETE FROM timetable WHERE account_id='' AND id<>'t1'");
      }
      this.checkAccount(account, accountToken, canCommit);
    });
  }

  async add(course: Course, tableId: string): Promise<void> {
    validateCourses([course]);
    const account: string = Db.accountUser();
    await Db.transaction(async () => { this.checkAccount(account); await CourseDao.insertOne(tableId, course, account); this.checkAccount(account); });
  }

  async remove(courseId: string): Promise<void> {
    const account: string = Db.accountUser();
    await Db.transaction(async () => { this.checkAccount(account); await CourseDao.remove(courseId, account); this.checkAccount(account); });
  }

  async tables(): Promise<TimetableInfo[]> {
    return CourseDao.tables();
  }

  async createTable(name: string): Promise<TimetableInfo> {
    const id: string = `t${Date.now()}_${++CourseRepositoryImpl.tableSequence}`;
    const account: string = Db.accountUser();
    await Db.transaction(async () => { this.checkAccount(account); await CourseDao.createTable(id, name, account); this.checkAccount(account); });
    return { id: id, name: name };
  }

  async isEmpty(): Promise<boolean> {
    const n: number = await CourseDao.count();
    return n === 0;
  }

  async removeTable(id: string): Promise<void> {
    const account: string = Db.accountUser();
    await Db.transaction(async () => { this.checkAccount(account); await CourseDao.removeTable(id, account); this.checkAccount(account); });
  }

  async renameTable(id: string, name: string): Promise<void> {
    const account: string = Db.accountUser();
    await Db.transaction(async () => { this.checkAccount(account); await CourseDao.renameTable(id, name, account); this.checkAccount(account); });
  }
}
