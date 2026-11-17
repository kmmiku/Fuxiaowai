/** 只按实际结束时间判断；无效时间不能当作已上完。 */
export function hasCourseEnded(end: string, now: Date): boolean {
  const matched: RegExpMatchArray | null = end.trim().match(/^(\d{1,2}):(\d{2})$/);
  if (!matched) { return false; }
  const hour: number = Number(matched[1]);
  const minute: number = Number(matched[2]);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) { return false; }
  return now.getUTCHours() * 60 + now.getUTCMinutes() >= hour * 60 + minute;
}
