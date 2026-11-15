import { accountToken, isCurrent } from './accountScope';
import { atomic } from './persistence';
import { loadActiveTable, saveCourses, saveCredential } from './store';
import { loadTerm, saveTerm } from './termStore';
import type { Course, Credential } from './types';
export function commitTimetable(courses: Course[], credential: Credential, tableId: string, token=accountToken()): void {
  if (!isCurrent(token,credential.user) || loadActiveTable()!==tableId) throw new Error('账号或课表已改变，已停止更新');
  if (!courses.length) throw new Error('未读取到完整课表，原课表已保留');
  atomic(() => {
    saveCourses(tableId,courses);
    saveTerm(tableId,{...loadTerm(tableId),syncedAt:Date.now()});
    saveCredential(credential);
  });
}
