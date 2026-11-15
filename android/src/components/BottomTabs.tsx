import { useLayoutEffect, useRef, useState } from 'react';

import { navigate } from '../core/router';
import LineIcon, { type IconName } from '../ui/LineIcons';

const ITEMS: { icon: IconName; label: string; path: string }[] = [
  { icon: 'calendar', label: '校历', path: '/calendar' },
  { icon: 'book', label: '课程', path: '/home' },
  { icon: 'award', label: '我的成绩', path: '/grades' },
  { icon: 'user', label: '我的', path: '/profile' }
];

/**
 * 底部常驻 Tab —— 校历 / 课程 / 成绩 / 我 四个主页面共用。
 *
 * 与鸿蒙 BottomTabs.ets 对齐的动效：
 *   按下：90ms FastOutSlowIn → 缩到 0.96
 *   松开：260ms springMotion(0.4, 0.62) → 弹回 1
 *   选中：独立浅蓝滑块，250ms 平滑移动
 */
export default function BottomTabs({ current }: { current: number }) {
  const [pressed, setPressed] = useState(-1);
  const barRef = useRef<HTMLDivElement>(null);
  const pillRef = useRef<HTMLSpanElement>(null);
  const initialized = useRef(false);

  useLayoutEffect(() => {
    const bar = barRef.current;
    const pill = pillRef.current;
    if (!bar || !pill) return;
    const position = (snap: boolean) => {
      const tab = bar.querySelector<HTMLButtonElement>('.tab[data-active="true"]');
      if (!tab) return;
      if (snap) pill.style.transition = 'none';
      pill.style.transform = `translateX(${tab.offsetLeft}px)`;
      pill.style.width = `${tab.offsetWidth}px`;
      pill.style.top = `${tab.offsetTop}px`;
      pill.style.height = `${tab.offsetHeight}px`;
      if (snap) {
        void pill.offsetWidth;
        pill.style.removeProperty('transition');
      }
    };
    position(!initialized.current);
    initialized.current = true;
    const resize = () => position(true);
    // Ignore ResizeObserver's initial delivery so it cannot cancel a tab transition.
    let width = bar.offsetWidth;
    let height = bar.offsetHeight;
    const observer = new ResizeObserver(() => {
      if (width !== bar.offsetWidth || height !== bar.offsetHeight) {
        width = bar.offsetWidth;
        height = bar.offsetHeight;
        resize();
      }
    });
    observer.observe(bar);
    window.addEventListener('resize', resize);
    return () => { observer.disconnect(); window.removeEventListener('resize', resize); };
  }, [current]);

  const press = (i: number) => {
    setPressed(i);
  };

  const release = () => {
    setPressed(-1);
  };

  return (
    <div className="tabs no-select" ref={barRef} role="navigation" aria-label="主导航">
      <span className="tabs-pill" ref={pillRef} aria-hidden="true" />
      {ITEMS.map((t, i) => (
        <button
          key={t.label}
          className="tab"
          data-active={i === current}
          aria-current={i === current ? 'page' : undefined}
          style={{
            transform: `scale(${pressed === i ? 0.96 : 1})`,
            transition:
              (pressed === i
                ? 'transform 90ms cubic-bezier(.4,0,.2,1)'
                : 'transform 260ms cubic-bezier(.34,1.56,.64,1)') +
              ', background-color 260ms cubic-bezier(.34,1.56,.64,1)'
          }}
          onTouchStart={() => press(i)}
          onTouchEnd={release}
          onTouchCancel={release}
          onMouseDown={() => press(i)}
          onMouseUp={release}
          onMouseLeave={release}
          onClick={() => {
            if (i !== current) navigate(t.path);
          }}
        >
          <span className="tab-glyph">
            <LineIcon name={t.icon} size={22} />
          </span>
          <span className="tab-text">{t.label}</span>
        </button>
      ))}
    </div>
  );
}
