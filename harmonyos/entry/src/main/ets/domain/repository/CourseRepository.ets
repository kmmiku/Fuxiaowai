import { Course } from '../model/Course';

/** 课表（支持多课表：我的课表 / 考研复习…） */
export interface TimetableInfo {
  id: string;
  name: string;
}

/**
 * 课程仓储接口（domain 层，零 ArkUI / 零 ohos API）
 * 实现放在 data/repository，UI 只依赖本接口
 */
export interface CourseRepository {
  listByWeek(tableId: string, week: number): Promise<Course[]>;
  listAll(tableId: string): Promise<Course[]>;
  replaceAll(tableId: string, courses: Course[], clearGuest?: boolean, accountToken?: number,
    canCommit?: () => boolean): Promise<void>;
  add(course: Course, tableId: string): Promise<void>;
  update(course: Course, tableId: string): Promise<void>;
  remove(courseId: string): Promise<void>;
  tables(): Promise<TimetableInfo[]>;
  createTable(name: string): Promise<TimetableInfo>;
  /** 删除课表（连同其中的课程） */
  removeTable(id: string): Promise<void>;
  renameTable(id: string, name: string): Promise<void>;
  isEmpty(): Promise<boolean>;
}
