/** 周次条：月份 + 周一~周日 + 今天的日号高亮 */

import { weekdayText } from '../core/semester';

export interface WeekBarProps {
  dates: string[];
  month: string;
  todayIndex: number;
  showWeekend: boolean;
}

export default function WeekBar({ dates, month, todayIndex, showWeekend }: WeekBarProps) {
  const n = showWeekend ? 7 : 5;
  return (
    <div className="weekbar no-select">
      <div className="weekbar-month">{month}</div>
      <div className="weekbar-days">
        {dates.slice(0, n).map((d, i) => {
          const isToday = i === todayIndex;
          return (
            <div key={i} className="weekbar-day" data-today={isToday}>
              <span className="weekbar-wd">{weekdayText(i + 1).replace('周', '')}</span>
              <span className="weekbar-date">{d}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}