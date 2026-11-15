import { storedCourseColor } from '../core/courseAppearance';
/**
 * 周课表网格
 * - 同一天里时间区间重叠的课横向分列（贪心「簇」内找空列）
 * - 非本周的课用淡色幽灵块占位，与本周块重叠时只保留本周块
 * - 列宽用 ResizeObserver 实测，不靠魔法数字
 */

import { useLayoutEffect, useMemo, useRef, useState } from 'react';

import type { Course, Period } from '../core/types';
import CourseBlock from './CourseBlock';

interface DayCell {
  start: number;
  end: number;
  courses: Course[];
  ghost: boolean;
  col: number;
  cols: number;
}

export interface TimetableGridProps {
  /** 当前课表的全部课程（含非本周，用于幽灵块） */
  courses: Course[];
  week: number;
  periods: Period[];
  showWeekend: boolean;
  /** 是否显示「非本周」浅色幽灵块 */
  showGhost: boolean;
  /** 课程块占列宽的比例（0.65–1） */
  cellHeight: number;
  onCourseClick?: (c: Course) => void;
  onCellClick?: (day: number, period: number) => void;
}

function cellsOfDay(all: Course[], day: number, week: number, showGhost: boolean): DayCell[] {
  const real: DayCell[] = [];
  const ghost: DayCell[] = [];

  for (const c of all) {
    if (c.weekday !== day) continue;
    if (c.weeks.indexOf(week) >= 0) {
      const hit = real.find((x) => x.start === c.startPeriod && x.end === c.endPeriod);
      if (hit) hit.courses.push(c);
      else
        real.push({
          start: c.startPeriod,
          end: c.endPeriod,
          courses: [c],
          ghost: false,
          col: 0,
          cols: 1
        });
    }
  }

  if (showGhost) {
    // 非本周幽灵块：只显示「还没上完」的课，同一天同一节段只留距当前周最近的那门
    const best = new Map<string, { course: Course; next: number }>();
    for (const c of all) {
      if (c.weekday !== day) continue;
      if (c.weeks.indexOf(week) >= 0) continue;
      let next = 0;
      for (const w of c.weeks) {
        if (w >= week && (next === 0 || w < next)) next = w;
      }
      // next === 0 说明这门课整学期已经上完了，不该再占位
      if (next === 0) continue;
      const key = `${c.startPeriod}-${c.endPeriod}`;
      const prev = best.get(key);
      if (!prev || next < prev.next) best.set(key, { course: c, next });
    }
    for (const item of best.values()) {
      const c = item.course;
      // 被本周真实块覆盖的位置不画幽灵，否则会重影
      const covered = real.some((r) => !(c.endPeriod < r.start || c.startPeriod > r.end));
      const dup = ghost.some((g) => !(c.endPeriod < g.start || c.startPeriod > g.end));
      if (covered || dup) continue;
      ghost.push({
        start: c.startPeriod,
        end: c.endPeriod,
        courses: [c],
        ghost: true,
        col: 0,
        cols: 1
      });
    }
  }

  return layoutColumns([...real, ...ghost]);
}

/** 贪心分列：先按起始节次排序，再把互相重叠的切成一个簇，簇内依次找空列 */
function layoutColumns(cells: DayCell[]): DayCell[] {
  const ghosts = cells.filter((c) => c.ghost).map((c) => ({ ...c, col: 0, cols: 1 }));
  const sorted = cells
    .filter((c) => !c.ghost)
    .slice()
    .sort((a, b) => a.start - b.start || b.end - a.end);

  let i = 0;
  while (i < sorted.length) {
    const cluster: DayCell[] = [sorted[i]];
    let maxEnd = sorted[i].end;
    let j = i + 1;
    while (j < sorted.length && sorted[j].start <= maxEnd) {
      cluster.push(sorted[j]);
      maxEnd = Math.max(maxEnd, sorted[j].end);
      j++;
    }
    const colEnds: number[] = [];
    for (const c of cluster) {
      let placed = -1;
      for (let k = 0; k < colEnds.length; k++) {
        if (colEnds[k] < c.start) {
          placed = k;
          break;
        }
      }
      if (placed < 0) {
        placed = colEnds.length;
        colEnds.push(c.end);
      } else {
        colEnds[placed] = c.end;
      }
      c.col = placed;
    }
    for (const c of cluster) c.cols = colEnds.length;
    i = j;
  }

  return [...sorted, ...ghosts];
}

export default function TimetableGrid({
  courses,
  week,
  periods,
  showWeekend,
  showGhost,
  cellHeight,
  onCourseClick,
  onCellClick
}: TimetableGridProps) {
  const dayCount = showWeekend ? 7 : 5;
  const rowH = Math.max(cellHeight, 68);
  const gridH = periods.length * rowH;
  const colRef = useRef<HTMLDivElement>(null);
  // 初值按视口宽度估算，避免从别的页面切回来时首帧列宽为 0 再跳一次（闪烁）
  const [colW, setColW] = useState(() => {
    const vw = typeof window === 'undefined' ? 390 : window.innerWidth;
    return Math.max(28, (vw - 38 - 24) / 7);
  });

  useLayoutEffect(() => {
    const el = colRef.current;
    if (!el) return;
    // 用布局宽度（offsetWidth / contentRect）而不是 getBoundingClientRect：
    // 日/周翻面时父容器带 rotateY transform，getBoundingClientRect 会返回投影宽度，
    // 转到 90° 附近量到接近 0，列宽被写坏后整张课表就缩成一团。
    const apply = (raw: number): void => {
      if (!raw || raw < 60) return;
      const w = raw / dayCount;
      setColW((prev) => (Math.abs(prev - w) > 0.5 ? w : prev));
    };
    const measure = (): void => apply(el.offsetWidth);
    measure();
    const ro = new ResizeObserver((entries) => {
      const cw = entries[0]?.contentRect.width ?? 0;
      apply(cw > 0 ? cw : el.offsetWidth);
    });
    ro.observe(el);
    // 翻面动画结束后再量一次，防止动效期间量到过渡尺寸
    const t1 = window.setTimeout(measure, 60);
    const t2 = window.setTimeout(measure, 260);
    return () => {
      window.clearTimeout(t1);
      window.clearTimeout(t2);
      ro.disconnect();
    };
  }, [dayCount]);

  const perDay = useMemo(() => {
    const out: DayCell[][] = [];
    for (let d = 1; d <= dayCount; d++) out.push(cellsOfDay(courses, d, week, showGhost));
    return out;
  }, [courses, week, dayCount, showGhost]);


  const appearance = useMemo(() => {
    const all = perDay.flatMap((cells, day) => cells.map(cell => ({ cell, day:day+1, start:cell.start, end:cell.end, col:cell.col, cols:cell.cols })));
    const first = perDay.map(cells => Math.min(...cells.filter(c=>!c.ghost).map(c=>c.start)));
    const colors = all.map(node=>storedCourseColor(node.cell.courses[0]));
    return new Map(all.map((node,i)=>[node.cell,{ color:colors[i], aligned:!node.cell.ghost && node.start===first[node.day-1] && node.end-node.start+1<6 }]));
  }, [perDay]);

  const timeOf = (period: number, isStart: boolean): string => {
    const p = periods[period - 1];
    if (!p) return '';
    return isStart ? p.start : p.end;
  };

  const w = colW;

  return (
    <div className="tt-grid" style={{ height: gridH }}>
      {/* 左侧时间轴 */}
      <div className="tt-timecol" style={{ width: 'var(--time-col)' }}>
        {periods.map((p) => (
          <div key={p.index} className="tt-timeslot" style={{ height: rowH }}>
            <span className="tt-period">{p.index}</span>
            <span className="tt-clock">{p.start}</span>
          </div>
        ))}
      </div>

      {/* 天列 */}
      <div className="tt-cols" ref={colRef}>
        {perDay.map((cells, idx) => {
          const day = idx + 1;
          return (
            <div key={day} className="tt-day" style={{ width: w }}>
              {/* 行线 */}
              {periods.map((p) => (
                <div
                  key={`l${p.index}`}
                  className="tt-rowline"
                  style={{ top: (p.index - 1) * rowH, height: rowH }}
                  onClick={() => onCellClick?.(day, p.index)}
                />
              ))}
              {/* 课程块 */}
              {cells.map((cell) => {
                const c = cell.courses[0];
                // 等比标尺：0.7 = 正好一列（默认宽度），1 = 约 1.43 列
                const unit = w / cell.cols;
                const startX = unit * cell.col;
                // 块宽固定为一列（不做宽度调节）
                const wantW = Math.max(unit, 14);
                // 最右列加宽会顶出表格右边界，把起点左移同样多的量，保证不出屏
                const tableW = w * perDay.length;
                const leftX = startX + 1;
                const blockH = (cell.end - cell.start + 1) * rowH - 4;
                return (
                  <div
                    key={`${cell.ghost ? 'g' : 'r'}-${cell.start}-${cell.end}-${cell.col}-${cell.courses
                      .map((x) => x.id)
                      .join('_')}`}
                    style={{
                      position: 'absolute',
                      top: (cell.start - 1) * rowH + 2,
                      left: leftX,
                      width: Math.max(18, wantW - 2),
                      zIndex: cell.ghost ? 1 : 2
                    }}
                  >
                    <CourseBlock
                      course={c}
                      backgroundColor={appearance.get(cell)?.color}
                      alignFirst={appearance.get(cell)?.aligned}
                      startTime={timeOf(c.startPeriod, true)}
                      endTime={timeOf(c.endPeriod, false)}
                      height={blockH}
                      narrow={showWeekend}
                      compact={dayCount >= 7}
                      cols={cell.cols}
                      ghost={cell.ghost}
                      onClick={() => onCourseClick?.(c)}
                    />
                  </div>
                );
              })}
            </div>
          );
        })}
      </div>
    </div>
  );
}