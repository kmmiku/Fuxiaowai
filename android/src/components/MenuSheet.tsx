import type { ReactNode } from 'react';
import LineIcon from '../ui/LineIcons';
/** 三点菜单：周次、课表切换及八项图标入口。 */

export interface MenuSheetProps {
  offset: number;
  tables: ReactNode;
  dark: boolean;
  week: number;
  totalWeeks: number;
  weekRange: string;
  onWeekChange: (w: number) => void;
  onShare: () => void;
  onItem: (key: string) => void;
}

export default function MenuSheet({
  offset,
  tables,
  dark,
  week,
  totalWeeks,
  weekRange,
  onWeekChange,
  onShare,
  onItem
}: MenuSheetProps) {
  const grid = [
    ['period', '上课时间', 'clock'], ['table', '课表设置', 'sliders'],
    ['remind', '上课提醒', 'bell'], ['widget', '小组件', 'phone'],
    ['contact', '联系我们', 'mail'], ['appearance', '主题设置', 'shirt'],
    ['dark', '夜间模式', 'moon'], ['update', '检查更新', 'download']
  ] as const;
  return (
    <div className="sheet menu-sheet integrated-menu" style={{ transform: `translateY(${offset}px)` }}>
      <div className="week-panel">
        <div className="wp-head">
          <span className="wp-title">周数</span>
          <span className="wp-pill">第{week}周</span>
        </div>
        <input
          className="wp-slider"
          type="range"
          min={1}
          max={totalWeeks}
          step={1}
          value={week}
          onChange={(e) => onWeekChange(Number(e.target.value))}
        />
        <div className="wp-foot">
          <span className="wp-range">{weekRange}</span>
          <button className="wp-share" onClick={onShare}>
            分享当前课表
          </button>
        </div>
      </div>

      {tables}
      <div className="integrated-grid">
        {grid.map(([key, title, icon]) => <button key={key} aria-pressed={key === 'dark' ? dark : undefined} onClick={() => onItem(key)}><span className="integrated-icon"><LineIcon name={icon} size={21} /></span><span>{title}</span></button>)}
      </div>
    </div>
  );
}