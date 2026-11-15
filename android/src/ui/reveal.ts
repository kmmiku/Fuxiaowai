/**
 * 从按钮「紧凑态」展开到下一页的圆形扩散转场（Material container transform 的轻量版）。
 *
 * 做法：在按钮中心放一个与按钮等大的圆，先放大到覆盖全屏，再切路由，
 * 新页面渲染完成后再把圆淡出。整个过程不碰 React 状态，纯 DOM，掉帧风险低。
 */

import { navigate, type RouteParams } from '../core/router';

const REVEAL_MS = 320;
const FADE_MS = 180;

/** 目标页的背景色：与 tokens.css 的 --bg 保持一致，展开时不会露出色差 */
function pageBg(): string {
  const dark = document.documentElement.dataset.dark === 'true';
  return dark ? '#101114' : '#f6f7fb';
}

function prefersReduced(): boolean {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

/**
 * 带扩散动画地进入某个页面。
 * @param origin 触发按钮（取它的中心与尺寸作为动画起点）
 * @param path   目标路由
 */
export function navigateFrom(origin: HTMLElement | null, path: string, params?: RouteParams): void {
  if (!origin || prefersReduced()) {
    navigate(path, params);
    return;
  }

  const r = origin.getBoundingClientRect();
  const cx = r.left + r.width / 2;
  const cy = r.top + r.height / 2;
  // 从按钮中心到屏幕四角的最远距离，保证圆能盖住整屏
  const far = Math.max(
    Math.hypot(cx, cy),
    Math.hypot(window.innerWidth - cx, cy),
    Math.hypot(cx, window.innerHeight - cy),
    Math.hypot(window.innerWidth - cx, window.innerHeight - cy)
  );
  const size = Math.max(r.width, r.height) || 44;

  const dot = document.createElement('div');
  dot.style.cssText = [
    'position:fixed',
    `left:${cx - size / 2}px`,
    `top:${cy - size / 2}px`,
    `width:${size}px`,
    `height:${size}px`,
    'border-radius:50%',
    `background:${pageBg()}`,
    'pointer-events:none',
    'z-index:9000',
    'transform:scale(1)',
    'will-change:transform,opacity',
    'transition:none'
  ].join(';');
  document.body.appendChild(dot);

  const grow = (far * 2) / size;
  // 下一帧再改，确保浏览器先画出初始的那一小块
  requestAnimationFrame(() => {
    dot.style.transition = `transform ${REVEAL_MS}ms cubic-bezier(.32,.72,0,1)`;
    dot.style.transform = `scale(${grow})`;

    window.setTimeout(() => {
      navigate(path, params);
      // 等新页面交出首帧再收圆，避免露出白底
      window.setTimeout(() => {
        dot.style.transition = `opacity ${FADE_MS}ms ease-out`;
        dot.style.opacity = '0';
        window.setTimeout(() => dot.remove(), FADE_MS + 40);
      }, 60);
    }, REVEAL_MS);
  });
}