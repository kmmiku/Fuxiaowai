/**
 * 日视图：左侧时间轴 + 右侧课程卡（对齐鸿蒙 DayList.ets）
 * 只显示「本周 + 今天」的课，空节次不占位
 */

import { useMemo } from 'react';

import type { Course, Period } from '../core/types';
import { todayWeekday } from '../core/semester';
import { COURSE_COLORS } from './CourseBlock';

export interface DayListProps {
  courses: Course[];
  week: number;
  periods: Period[];
  onCourseClick?: (c: Course) => void;
}

const DAY_NAMES = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

export default function DayList({ courses, week, periods, onCourseClick }: DayListProps) {
  const weekday = todayWeekday();
  const now = new Date();
  const dateLabel = `${now.getMonth() + 1}月${now.getDate()}日 ${DAY_NAMES[weekday]}`;

  const items = useMemo(
    () =>
      courses
        .filter((c) => c.weekday === weekday && c.weeks.indexOf(week) >= 0)
        .sort((a, b) => a.startPeriod - b.startPeriod),
    [courses, week, weekday]
  );

  const clockOf = (index: number, start: boolean): string => {
    for (const p of periods) {
      if (p.index === index) return start ? p.start : p.end;
    }
    return '';
  };

  const roomText = (c: Course): string => {
    const parts: string[] = [];
    if (c.campus) parts.push(c.campus);
    if (c.room) parts.push(c.room);
    return parts.length > 0 ? parts.join(' · ') : '教室未填写';
  };

  return (
    <div className="daylist no-select">
      <div className="daylist-head">
        <span className="daylist-date">{dateLabel}</span>
        <span className="daylist-week">第{week}周</span>
      </div>

      {items.length === 0 ? (
        <div className="daylist-empty">
          <span className="de-title">今天没有课</span>
          <span className="de-sub">点右上角「周」翻回周课表</span>
        </div>
      ) : (
        items.map((c) => {
          const [bg, fg] = COURSE_COLORS[c.colorIndex % COURSE_COLORS.length];
          const spanText =
            c.startPeriod === c.endPeriod
              ? `第${c.startPeriod}节`
              : `第${c.startPeriod}-${c.endPeriod}节`;
          return (
            <div key={`${c.id}-${c.startPeriod}`} className="daylist-row">
              <div className="dl-time">
                <span className="dl-start">{clockOf(c.startPeriod, true)}</span>
                <span className="dl-line" />
                <span className="dl-end">{clockOf(c.endPeriod, false)}</span>
              </div>

              <div
                className="dl-card"
                style={{ background: bg }}
                onClick={() => onCourseClick?.(c)}
              >
                <span className="dl-bar" style={{ background: fg }} />
                <div className="dl-body">
                  <div className="dl-top">
                    <span className="dl-name" style={{ color: fg }}>
                      {c.name}
                    </span>
                    <span className="dl-span" style={{ color: fg }}>
                      {spanText}
                    </span>
                  </div>
                  <div className="dl-bottom">
                    <span className="dl-room">{roomText(c)}</span>
                    {c.teacher && <span className="dl-teacher">{c.teacher}</span>}
                  </div>
                </div>
              </div>

              <span className="dl-gap" />
            </div>
          );
        })
      )}
    </div>
  );
}