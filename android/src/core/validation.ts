import type { Course, Period } from './types';
const integer = (v: unknown, min: number, max: number): v is number =>
  typeof v === 'number' && Number.isInteger(v) && v >= min && v <= max;
const text = (v: unknown, max: number, optional = false): string => {
  if (optional && v === undefined) return '';
  if (typeof v !== 'string' || v.length > max) throw new Error('课程文字字段不完整或过长');
  return v;
};
export function validateCourses(value: unknown): Course[] {
  if (!Array.isArray(value) || value.length > 800) throw new Error('课程列表格式或数量不正确');
  const ids = new Set<string>();
  return value.map(c => {
    if (!c || typeof c !== 'object') throw new Error('课程数据不完整');
    const id = text(c.id, 300);
    const name = text(c.name, 300);
    if (!id || ids.has(id) || !name.trim()) throw new Error('课程编号重复或名称为空');
    ids.add(id);
    if (!integer(c.weekday, 1, 7) || !integer(c.startPeriod, 1, 48) ||
      !integer(c.endPeriod, c.startPeriod, 48) || !Array.isArray(c.weeks) ||
      !c.weeks.length || c.weeks.length > 60 || c.weeks.some((w: unknown) => !integer(w, 1, 60)))
      throw new Error('课程星期、节次或周次不正确');
    const colorIndex = c.colorIndex ?? 0;
    if (!integer(colorIndex, 0, 255)) throw new Error('课程颜色不正确');
    if(c.autoColorIndex!==undefined&&!integer(c.autoColorIndex,0,7))throw new Error('自动课程颜色不正确');
    if(c.colorOverride!==undefined&&typeof c.colorOverride!=='boolean')throw new Error('课程选色标记不正确');
    if(c.colorOverride===true&&colorIndex>7)throw new Error('手动颜色不在课表调色板内');
    return { id, name, teacher: text(c.teacher, 300, true), room: text(c.room, 300, true),
      campus: text(c.campus, 300, true), weekday: c.weekday, startPeriod: c.startPeriod,
      endPeriod: c.endPeriod, weeks: [...new Set<number>(c.weeks)], colorIndex, ...(c.colorOverride===true?{colorOverride:true}:{}), ...(c.autoColorIndex!==undefined?{autoColorIndex:c.autoColorIndex}:{}) };
  });
}
export function validatePeriods(value: unknown): Period[] {
  if (!Array.isArray(value) || value.length > 48) throw new Error('节次数据不正确');
  const ids = new Set<number>();
  return value.map(p => {
    if (!p || !integer(p.index, 1, 48) || ids.has(p.index) ||
      typeof p.start !== 'string' || typeof p.end !== 'string' ||
      !/^([01]\d|2[0-3]):[0-5]\d$/.test(p.start) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(p.end) ||
      p.end <= p.start) throw new Error('节次时间或编号不正确');
    ids.add(p.index); return {index:p.index,start:p.start,end:p.end};
  });
}
