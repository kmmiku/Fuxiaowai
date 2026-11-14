import { Course } from './Course';

export function validateCourses(courses: Course[]): void {
  if (!Array.isArray(courses) || courses.length > 800) {
    throw new Error('课表格式或课程数量不正确');
  }
  courses.forEach((c: Course) => {
    if (c === null || c === undefined || typeof c.id !== 'string' || c.id.length === 0 || c.id.length > 4096 ||
      typeof c.name !== 'string' || c.name.trim().length === 0 || c.name.length > 500 ||
      typeof c.teacher !== 'string' || c.teacher.length > 500 || typeof c.room !== 'string' || c.room.length > 500 ||
      typeof c.campus !== 'string' || c.campus.length > 500 ||
      !Number.isInteger(c.weekday) || c.weekday < 1 || c.weekday > 7 ||
      !Number.isInteger(c.startPeriod) || c.startPeriod < 1 || c.startPeriod > 48 ||
      !Number.isInteger(c.endPeriod) || c.endPeriod < c.startPeriod || c.endPeriod > 48 ||
      !Array.isArray(c.weeks) || c.weeks.length === 0 || c.weeks.length > 60 ||
      !c.weeks.every((w: number) => Number.isInteger(w) && w >= 1 && w <= 60) ||
      !Number.isInteger(c.colorIndex) || c.colorIndex < 0 || c.colorIndex > 1024) {
      throw new Error('课程数据不完整或超出有效范围');
    }
  });
}

/** Opaque storage key scoped to a timetable; legacy IDs remain readable. */
export function scopedCourseId(id: string, tableId: string): string {
  let original: string = id;
  if (id.startsWith('fxw:')) {
    const split: number = id.indexOf(':', 4);
    if (split >= 0) {
      try { original = decodeURIComponent(id.substring(split + 1)); } catch (e) {}
    }
  }
  return 'fxw:' + encodeURIComponent(tableId) + ':' + encodeURIComponent(original);
}
