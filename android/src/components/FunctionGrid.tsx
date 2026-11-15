/** 功能宫格：上课时间 / 课表设置 / 上课提醒 / 小组件 */

export interface FunctionItem {
  key: string;
  glyph: string;
  label: string;
}

const ITEMS: FunctionItem[] = [
  { key: 'period', glyph: '时', label: '上课时间' },
  { key: 'table', glyph: '表', label: '课表设置' },
  { key: 'remind', glyph: '铃', label: '上课提醒' },
  { key: 'widget', glyph: '件', label: '小组件' }
];

export default function FunctionGrid({ onTap }: { onTap: (key: string) => void }) {
  return (
    <div className="fgrid no-select">
      {ITEMS.map((it) => (
        <button key={it.key} className="fgrid-item" onClick={() => onTap(it.key)}>
          <span className="fgrid-glyph">{it.glyph}</span>
          <span className="fgrid-label">{it.label}</span>
        </button>
      ))}
    </div>
  );
}

export { ITEMS as FUNCTION_ITEMS };