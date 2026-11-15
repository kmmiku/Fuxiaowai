import { useEffect, useRef } from 'react';

interface Props {
  items: string[];
  /** 当前选中下标 */
  index: number;
  onPick: (i: number) => void;
  /** 每行高度，默认 44 */
  itemH?: number;
  /** 可见行数，默认 5（奇数，中间那行是选中项） */
  visible?: number;
}

/**
 * 滚轮选择器：上下滚动，停下后自动吸附到最近一项。
 * 用原生 scroll-snap 实现，惯性由浏览器给，比自己算速度更顺。
 */
export default function WheelPicker({ items, index, onPick, itemH = 44, visible = 5 }: Props) {
  const ref = useRef<HTMLDivElement | null>(null);
  const timer = useRef<number>(0);
  const pad = ((visible - 1) / 2) * itemH;

  // 外部改 index（或首次进来）时把滚轮滚到对应位置
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const want = index * itemH;
    if (Math.abs(el.scrollTop - want) > 2) el.scrollTop = want;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [index, items.length]);

  function onScroll(): void {
    const el = ref.current;
    if (!el) return;
    window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => {
      const i = Math.max(0, Math.min(items.length - 1, Math.round(el.scrollTop / itemH)));
      if (i !== index) onPick(i);
    }, 110);
  }

  return (
    <div className="wheel-wrap" style={{ height: itemH * visible }}>
      <div className="wheel-band" style={{ top: pad, height: itemH }} />
      <div className="wheel-scroll" ref={ref} onScroll={onScroll} style={{ paddingTop: pad, paddingBottom: pad }}>
        {items.map((t, i) => (
          <div
            key={`${t}-${i}`}
            className="wheel-item"
            data-on={i === index}
            style={{ height: itemH, lineHeight: `${itemH}px` }}
            onClick={() => {
              onPick(i);
              const el = ref.current;
              if (el) el.scrollTo({ top: i * itemH, behavior: 'smooth' });
            }}
          >
            {t}
          </div>
        ))}
      </div>
    </div>
  );
}