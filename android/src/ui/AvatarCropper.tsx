import { useCallback, useEffect, useRef, useState } from 'react';
import type { PointerEvent as ReactPointerEvent } from 'react';

/**
 * 头像框选裁剪 —— 选好相册图片后，先把要用的那块框出来，再确认。
 * 选框固定为正方形（显示成圆形），图片可拖动、可缩放。
 */

const OUTPUT = 512;          // 输出边长（px）
const FRAME_MIN = 240;       // 选框最小边长
const FRAME_MAX = 340;       // 选框最大边长
const MIN_ZOOM = 1;
const MAX_ZOOM = 3;

interface Props {
  src: string;
  onCancel: () => void;
  onDone: (dataUrl: string) => void;
}

interface Box {
  w: number;
  h: number;
}

export default function AvatarCropper({ src, onCancel, onDone }: Props) {
  const imgRef = useRef<HTMLImageElement | null>(null);
  const frameRef = useRef<HTMLDivElement | null>(null);
  const drag = useRef<{ id: number; x: number; y: number; tx: number; ty: number } | null>(null);

  const [frame, setFrame] = useState<Box>({ w: 0, h: 0 });
  const [natural, setNatural] = useState<Box>({ w: 0, h: 0 });
  const [zoom, setZoom] = useState(1);
  const [pos, setPos] = useState({ x: 0, y: 0 });

  /** 让图片刚好铺满选框的缩放比 */
  const coverScale = useCallback(() => {
    if (!natural.w || !natural.h || !frame.w || !frame.h) return 1;
    return Math.max(frame.w / natural.w, frame.h / natural.h);
  }, [natural, frame]);

  /** 把图片限制在选框内，不许露出底色 */
  const clamp = useCallback(
    (next: { x: number; y: number }, z: number) => {
      const s = coverScale() * z;
      const dw = natural.w * s;
      const dh = natural.h * s;
      const minX = frame.w - dw;
      const minY = frame.h - dh;
      return {
        x: Math.min(0, Math.max(minX, next.x)),
        y: Math.min(0, Math.max(minY, next.y)),
      };
    },
    [coverScale, natural, frame],
  );

  const center = useCallback(
    (z: number) => {
      const s = coverScale() * z;
      return {
        x: (frame.w - natural.w * s) / 2,
        y: (frame.h - natural.h * s) / 2,
      };
    },
    [coverScale, natural, frame],
  );

  // 选框尺寸：取视口宽度的 78%，夹在 240–340 之间
  useEffect(() => {
    const size = Math.round(Math.min(FRAME_MAX, Math.max(FRAME_MIN, window.innerWidth * 0.78)));
    setFrame({ w: size, h: size });
  }, []);

  // 图片原始尺寸拿到后先居中
  useEffect(() => {
    if (!natural.w || !frame.w) return;
    setPos(center(zoom));
    // 只在尺寸就绪时居中一次
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [natural.w, natural.h, frame.w, frame.h]);

  function onImgLoad() {
    const el = imgRef.current;
    if (!el) return;
    setNatural({ w: el.naturalWidth, h: el.naturalHeight });
  }

  function onPointerDown(e: ReactPointerEvent<HTMLDivElement>) {
    const el = e.currentTarget;
    el.setPointerCapture(e.pointerId);
    drag.current = { id: e.pointerId, x: e.clientX, y: e.clientY, tx: pos.x, ty: pos.y };
  }

  function onPointerMove(e: ReactPointerEvent<HTMLDivElement>) {
    const d = drag.current;
    if (!d || d.id !== e.pointerId) return;
    const next = { x: d.tx + (e.clientX - d.x), y: d.ty + (e.clientY - d.y) };
    setPos(clamp(next, zoom));
  }

  function onPointerUp(e: ReactPointerEvent<HTMLDivElement>) {
    const d = drag.current;
    if (!d || d.id !== e.pointerId) return;
    drag.current = null;
    try {
      e.currentTarget.releasePointerCapture(e.pointerId);
    } catch {
      /* 已经释放过就忽略 */
    }
  }

  function onZoom(next: number) {
    const z = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, next));
    setZoom(z);
    setPos((prev) => {
      // 以选框中心为锚点缩放
      const cx = frame.w / 2;
      const cy = frame.h / 2;
      const ratio = z / zoom;
      return clamp({ x: cx - (cx - prev.x) * ratio, y: cy - (cy - prev.y) * ratio }, z);
    });
  }

  function confirm() {
    const img = imgRef.current;
    if (!img || !natural.w || !frame.w) {
      onCancel();
      return;
    }
    const s = coverScale() * zoom;
    const dw = natural.w * s;
    const dh = natural.h * s;
    // 选框左上角在图片坐标系里的位置
    const srcX = (-pos.x / dw) * natural.w;
    const srcY = (-pos.y / dh) * natural.h;
    const srcW = (frame.w / dw) * natural.w;
    const srcH = (frame.h / dh) * natural.h;

    const canvas = document.createElement('canvas');
    canvas.width = OUTPUT;
    canvas.height = OUTPUT;
    const ctx = canvas.getContext('2d');
    if (!ctx) {
      onCancel();
      return;
    }
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(img, srcX, srcY, srcW, srcH, 0, 0, OUTPUT, OUTPUT);
    onDone(canvas.toDataURL('image/jpeg', 0.9));
  }

  const s = coverScale() * zoom;
  const dw = natural.w * s;
  const dh = natural.h * s;

  return (
    <div className="avc-wrap">
      <div className="avc-head">
        <button className="avc-cancel" onClick={onCancel}>
          取消
        </button>
        <div className="avc-title">调整头像</div>
        <button className="avc-done" onClick={confirm}>
          使用
        </button>
      </div>

      <div className="avc-stage">
        <div
          className="avc-frame"
          ref={frameRef}
          style={{ width: frame.w || FRAME_MIN, height: frame.h || FRAME_MIN }}
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerCancel={onPointerUp}
        >
          <img
            ref={imgRef}
            src={src}
            alt=""
            draggable={false}
            onLoad={onImgLoad}
            style={{
              width: dw > 0 ? dw : 'auto',
              height: dh > 0 ? dh : 'auto',
              transform: `translate3d(${pos.x}px, ${pos.y}px, 0)`,
            }}
          />
          <div className="avc-ring" />
        </div>
      </div>

      <div className="avc-zoom">
        <span className="avc-zoom-label">缩放</span>
        <input
          className="avc-zoom-range"
          type="range"
          min={MIN_ZOOM}
          max={MAX_ZOOM}
          step={0.01}
          value={zoom}
          onChange={(e) => onZoom(Number(e.target.value))}
        />
      </div>

      <div className="avc-tip">拖动图片调整位置，滑块缩放；圆环内的部分就是头像</div>
    </div>
  );
}