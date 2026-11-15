import { COURSE_PALETTE } from '../core/courseAppearance';
/** 纯色课程块：固定字形、白字、统一名称区域；教师保留于详情。 */

import { useLayoutEffect, useRef, useState } from 'react';
import type { Course } from '../core/types';

const COLOR_TINTS = ['#FDEBF0','#FCEBF0','#E6F8F5','#E9F0FF','#F1EBFE','#FFF1E2','#E8F4FE','#E8F1FD'];
export const COURSE_COLORS: [string,string][] = COURSE_PALETTE.map((color,i)=>[COLOR_TINTS[i],color]);


export interface CourseBlockProps {
  course: Course;
  backgroundColor?: string;
  alignFirst?: boolean;
  startTime: string;
  endTime: string;
  /** 块高度，决定能放几行 */
  height: number;
  /** 7 天模式窄列 */
  narrow: boolean;
  /** 7 天模式下只留课名、字号更小（对齐鸿蒙的 compact） */
  compact?: boolean;
  /** 同格并排的列数 */
  cols: number;
  /** 非本周的淡色占位块 */
  ghost: boolean;
  onClick?: () => void;
}

export default function CourseBlock({
  course,
  backgroundColor,
  alignFirst = false,
  startTime,
  endTime,
  height,
  narrow,
  compact = false,
  cols,
  ghost,
  onClick
}: CourseBlockProps) {
  const solidColors = COURSE_PALETTE;
  const solid = backgroundColor || solidColors[course.colorIndex % solidColors.length];

  const innerRef = useRef<HTMLDivElement>(null);
  const [layout, setLayout] = useState({ top: false, nameLines: 1000, roomLines: 1000, shortRoom: false });
  const codes = course.room.match(/(?:教|实|[A-Za-z])?\s*\d+(?:[-－—]\d+)*/g);
  const roomCode = codes?.find(c => /教|实/.test(c)) || codes?.[codes.length - 1] || course.room;
  const showRoom = !ghost && course.room.trim().length > 0;
  const roomText = (text: string) => text.split(/(\d+)/).map((part, i) =>
    /^\d+$/.test(part) ? <span className="cb-number" key={i}><span>{part}</span></span> : part
  );
  useLayoutEffect(() => {
    const el = innerRef.current;
    if (!el) return;
    const update = () => {

      const width = Math.max(1, el.clientWidth - 6);
      // Keep original glyph proportions. Only allow a numeric run to wrap when
      // even that run cannot fit the column; never scale its width.
      el.querySelectorAll<HTMLElement>('.cb-number').forEach(box => {
        const digits = box.firstElementChild as HTMLElement;
        box.style.whiteSpace = digits.scrollWidth > width ? 'normal' : 'nowrap';
      });
      const measured = (key: string) => (el.querySelector('[data-measure="' + key + '"]') as HTMLElement)?.offsetHeight || 0;
      const available = Math.max(16, el.clientHeight - 16);

      const nameHeight = measured('name'), roomHeight = showRoom ? measured('room') : 0;
      const codeHeight = showRoom ? measured('code') : 0;
      const top = nameHeight + roomHeight > available - 16;
      const reserved = showRoom ? Math.min(codeHeight, Math.max(16, available - 16)) : 0;
      const nameLines = top ? Math.max(1, Math.floor((available - reserved) / 16)) : 1000;
      const visibleName = Math.min(nameHeight, nameLines * 16);
      const roomLines = Math.max(1, Math.floor((available - visibleName) / 16));
      const shortRoom = top && roomHeight > roomLines * 16;
      setLayout(old => old.top === top && old.nameLines === nameLines && old.roomLines === roomLines && old.shortRoom === shortRoom ? old : { top, nameLines, roomLines, shortRoom });


    };
    update();
    const observer = new ResizeObserver(update);observer.observe(el);
    return () => observer.disconnect();
  }, [course.name, course.room, height, showRoom]);

  return (
    <div
      className="course-block no-select"
      onClick={onClick}
      style={{
        height,
        background: solid,
        borderLeft: 'none',
        borderRadius: 5,
        opacity: ghost ? 0.4 : 1
      }}
    >

      <div ref={innerRef} className="cb-inner cb-centered" style={{ justifyContent: layout.top || alignFirst ? 'flex-start' : 'center', paddingBottom: layout.top || alignFirst ? 0 : 16 }}>
        <div className="cb-name" style={{ color: '#fff', WebkitLineClamp: layout.nameLines, maxHeight: layout.nameLines * 16 }}>{course.name}</div>
        {showRoom && <div className="cb-line cb-room" style={{ color: '#fff', WebkitLineClamp: layout.roomLines, maxHeight: layout.roomLines * 16 }}>{layout.shortRoom ? roomText(roomCode) : roomText(course.room)}</div>}
        {ghost && <div className="cb-ghost-tag" style={{ color: '#fff' }}>非本周</div>}
        <div className="cb-measures" aria-hidden="true">
          <div data-measure="name" className="cb-name">{course.name}</div>
          <div data-measure="room" className="cb-room">{roomText(course.room)}</div>
          <div data-measure="code" className="cb-room">{roomText(roomCode)}</div>
        </div>
      </div>
    </div>
  );
}

