/**
 * 课程详情弹层（对应鸿蒙 CourseDetailSheet.ets）
 * 自下而上升起，只做信息展示 + 编辑/复制/删除入口，作用域可选「仅本周 / 所有周」
 */

import { periodsLabel, weekdayLabel, weeksLabel } from '../core/courseFormat';
import type { Course, Period } from '../core/types';
import { COURSE_COLORS } from './CourseBlock';

export interface CourseDetailSheetProps {
  course: Course;
  periods: Period[];
  /** true = 作用域「所有周」 */
  scopeAll: boolean;
  onScope: (all: boolean) => void;
  onEdit: () => void;
  onCopy: () => void;
  onDelete: () => void;
  onClose: () => void;
}

export default function CourseDetailSheet({
  course,
  periods,
  scopeAll,
  onScope,
  onEdit,
  onCopy,
  onDelete,
  onClose
}: CourseDetailSheetProps) {
  const accent = COURSE_COLORS[course.colorIndex % COURSE_COLORS.length][1];

  const timeText = (): string => {
    let start = '';
    let end = '';
    for (const p of periods) {
      if (p.index === course.startPeriod) start = p.start;
      if (p.index === course.endPeriod) end = p.end;
    }
    if (!start || !end) return '';
    return `${start}-${end}`;
  };

  const placeText = (): string => {
    const bits: string[] = [];
    if (course.room) bits.push(course.room);
    if (course.campus) bits.push(course.campus);
    return bits.length > 0 ? bits.join(' · ') : '未填写';
  };

  const t = timeText();
  const timeLine = `${weekdayLabel(course.weekday)} ${periodsLabel(course)}${t ? `  ${t}` : ''}`;

  return (
    <div className="cd-mask" onClick={onClose}>
      <div className="cd-sheet" onClick={(e) => e.stopPropagation()}>
        <div className="cd-grabber" />

        {/* 顶部：色条 + 课名 */}
        <div className="cd-head">
          <span className="cd-bar" style={{ background: accent }} />
          <span className="cd-name">{course.name}</span>
        </div>

        <div className="cd-divider" />

        <div className="cd-rows">
          <div className="cd-row">
            <span className="cd-label">周次</span>
            <span className="cd-value">{weeksLabel(course.weeks)}</span>
          </div>
          <div className="cd-row">
            <span className="cd-label">时间</span>
            <span className="cd-value">{timeLine}</span>
          </div>
          <div className="cd-row">
            <span className="cd-label">地点</span>
            <span className="cd-value">{placeText()}</span>
          </div>
          <div className="cd-row">
            <span className="cd-label">教师</span>
            <span className="cd-value">{course.teacher || '未填写'}</span>
          </div>
        </div>

        <div className="cd-spacer" />

        {/* 作用域 */}
        <div className="cd-scope">
          <span className="cd-scope-label">操作范围</span>
          <div className="cd-chips">
            <button
              className="cd-chip"
              data-on={!scopeAll}
              onClick={() => onScope(false)}
            >
              仅本周
            </button>
            <button
              className="cd-chip"
              data-on={scopeAll}
              onClick={() => onScope(true)}
            >
              所有周
            </button>
          </div>
        </div>

        {/* 操作按钮 */}
        <div className="cd-actions">
          <button className="cd-btn" onClick={onEdit}>
            编辑
          </button>
          <button className="cd-btn cd-btn-sm" onClick={onCopy}>
            复制
          </button>
          <button className="cd-btn cd-btn-sm cd-btn-danger" onClick={onDelete}>
            删除
          </button>
        </div>
      </div>
    </div>
  );
}