/**
 * 极简线条图标（与安卓端 LineIcons.tsx 同一套图形）
 *
 * 为什么用 Canvas 而不是 Shape/Path：鸿蒙的 Path.commands 在多段路径 + viewPort 缩放下
 * 只渲染出第一个起笔点（实测一圈图标全变成小圆点），Canvas 的 2D 上下文则完全可控。
 * 坐标按 24×24 设计稿写，绘制时统一乘 scale。
 */

const PI = Math.PI;

@Component
export struct LineIcon {
  @Prop name: string = 'grid';
  @Prop iconSize: number = 20;
  /** 'pri' = 主区（主题蓝），'sub' = 次区（灰） */
  @Prop @Watch('onIconStyleChange') tone: string = 'sub';
  @Prop strokeW: number = 1.6;
  @StorageLink('dark') @Watch('onIconStyleChange') dark: boolean = false;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private canvasReady: boolean = false;

  private color(): string {
    if (this.tone === 'white') { return '#FFFFFF'; }
    if (this.tone === 'text') {
      return this.dark ? '#E8EAF0' : '#161821';
    }
    if (this.tone === 'text-strong') {
      return this.dark ? '#FFFFFF' : '#090B10';
    }
    if (this.tone === 'pri') {
      return this.dark ? '#8AA0FF' : '#3D5AFE';
    }
    return this.dark ? '#A9AEBD' : '#8A90A0';
  }

  build() {
    Canvas(this.ctx)
      .width(this.iconSize)
      .height(this.iconSize)
      .onReady(() => {
        this.canvasReady = true;
        this.draw();
      })
  }

  private onIconStyleChange(): void {
    if (this.canvasReady) {
      this.draw();
    }
  }

  private arcPath(c: CanvasRenderingContext2D, cx: number, cy: number, r: number,
    a0: number, a1: number): void {
    c.moveTo(cx + r * Math.cos(a0), cy + r * Math.sin(a0));
    c.arc(cx, cy, r, a0, a1);
  }

  private rrect(c: CanvasRenderingContext2D, x: number, y: number,
    w: number, h: number, r: number): void {
    c.moveTo(x + r, y);
    c.lineTo(x + w - r, y);
    c.quadraticCurveTo(x + w, y, x + w, y + r);
    c.lineTo(x + w, y + h - r);
    c.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    c.lineTo(x + r, y + h);
    c.quadraticCurveTo(x, y + h, x, y + h - r);
    c.lineTo(x, y + r);
    c.quadraticCurveTo(x, y, x + r, y);
  }

  private dot(c: CanvasRenderingContext2D, cx: number, cy: number, r: number): void {
    c.moveTo(cx + r, cy);
    c.arc(cx, cy, r, 0, PI * 2);
  }

  private draw(): void {
    const c = this.ctx;
    const k = this.iconSize / 24;
    c.clearRect(0, 0, this.iconSize, this.iconSize);
    c.save();
    c.scale(k, k);
    c.strokeStyle = this.color();
    c.lineWidth = this.strokeW;
    c.lineCap = 'round';
    c.lineJoin = 'round';
    c.beginPath();

    if (this.name === 'check') {
      c.lineCap = 'butt';
      c.lineJoin = 'miter';
      c.moveTo(5, 12); c.lineTo(10, 17); c.lineTo(20, 6);
    } else if (this.name === 'clock') {
      this.arcPath(c, 12, 12, 8, 0, PI * 2);
      c.moveTo(12, 6.5); c.lineTo(12, 12); c.lineTo(8.5, 14);
    } else if (this.name === 'sliders') {
      c.moveTo(4, 6); c.lineTo(10, 6); c.moveTo(14, 6); c.lineTo(20, 6);
      c.moveTo(4, 12); c.lineTo(6, 12); c.moveTo(10, 12); c.lineTo(20, 12);
      c.moveTo(4, 18); c.lineTo(13, 18); c.moveTo(17, 18); c.lineTo(20, 18);
      this.arcPath(c, 12, 6, 2, 0, PI * 2);
      this.arcPath(c, 8, 12, 2, 0, PI * 2);
      this.arcPath(c, 15, 18, 2, 0, PI * 2);
    } else if (this.name === 'phone') {
      this.rrect(c, 6.5, 3, 11, 18, 2);
      c.moveTo(10, 6); c.lineTo(14, 6);
      c.moveTo(11, 18); c.lineTo(13, 18);
    } else if (this.name === 'mail') {
      this.rrect(c, 3, 5, 18, 14, 2);
      c.moveTo(4, 6); c.lineTo(12, 12.5); c.lineTo(20, 6);
    } else if (this.name === 'moon') {
      c.moveTo(18.8, 15.3);
      c.bezierCurveTo(9, 18, 6.5, 9.5, 9, 4);
      c.bezierCurveTo(1, 7, 3, 20, 12, 20);
      c.bezierCurveTo(15.5, 20, 18, 18, 18.8, 15.3);
    } else if (this.name === 'download') {
      c.moveTo(12, 3); c.lineTo(12, 14);
      c.moveTo(7.5, 10); c.lineTo(12, 14.5); c.lineTo(16.5, 10);
      c.moveTo(4, 13); c.lineTo(4, 20); c.lineTo(20, 20); c.lineTo(20, 13);
    } else if (this.name === 'plus') {
      c.moveTo(5, 12);
      c.lineTo(19, 12);
      c.moveTo(12, 5);
      c.lineTo(12, 19);
    } else if (this.name === 'import-file' || this.name === 'share-out') {
      c.moveTo(9, 4);
      c.lineTo(6, 4);
      c.quadraticCurveTo(4, 4, 4, 6);
      c.lineTo(4, 18);
      c.quadraticCurveTo(4, 20, 6, 20);
      c.lineTo(18, 20);
      c.quadraticCurveTo(20, 20, 20, 18);
      c.lineTo(20, this.name === 'import-file' ? 10 : 13);
      if (this.name === 'import-file') {
        c.moveTo(19, 4);
        c.quadraticCurveTo(12, 4, 12, 14);
        c.moveTo(8, 10);
        c.lineTo(12, 14);
        c.lineTo(16, 10);
      } else {
        c.moveTo(10, 14);
        c.lineTo(20, 4);
        c.moveTo(13, 4);
        c.lineTo(20, 4);
        c.lineTo(20, 11);
      }
    } else if (this.name === 'user') {
      this.arcPath(c, 12, 8, 3.6, 0, PI * 2);
      this.arcPath(c, 12, 13.8, 7.2, 0, PI);
    } else if (this.name === 'help') {
      this.arcPath(c, 12, 12, 8.4, 0, PI * 2);
      this.arcPath(c, 12, 9.6, 2.3, PI * 0.85, PI * 2.3);
      c.moveTo(11.9, 11.9);
      c.lineTo(11.9, 13.6);
      this.dot(c, 12, 16.8, 0.9);
    } else if (this.name === 'calendar') {
      this.rrect(c, 3.6, 5.4, 16.8, 15, 2.6);
      c.moveTo(3.6, 9.6);
      c.lineTo(20.4, 9.6);
      c.moveTo(8.2, 3.4);
      c.lineTo(8.2, 7);
      c.moveTo(15.8, 3.4);
      c.lineTo(15.8, 7);
      c.moveTo(7.6, 13);
      c.lineTo(9.2, 13);
      c.moveTo(11.2, 13);
      c.lineTo(12.8, 13);
      c.moveTo(14.8, 13);
      c.lineTo(16.4, 13);
      c.moveTo(7.6, 16.6);
      c.lineTo(9.2, 16.6);
      c.moveTo(11.2, 16.6);
      c.lineTo(12.8, 16.6);
    } else if (this.name === 'bell') {
      c.moveTo(6.6, 9.2);
      c.arc(12, 9.2, 5.4, PI, PI * 2);
      c.lineTo(17.4, 12.2);
      c.lineTo(18.9, 14.8);
      c.lineTo(5.1, 14.8);
      c.lineTo(6.6, 12.2);
      c.closePath();
      this.arcPath(c, 12, 17.6, 2.4, 0, PI);
    } else if (this.name === 'shirt') {
      c.moveTo(8.6, 4.2);
      c.lineTo(4.4, 6.6);
      c.lineTo(6.3, 10.2);
      c.lineTo(8, 9.3);
      c.lineTo(8, 19.2);
      c.lineTo(16, 19.2);
      c.lineTo(16, 9.3);
      c.lineTo(17.7, 10.2);
      c.lineTo(19.6, 6.6);
      c.lineTo(15.4, 4.2);
      this.arcPath(c, 12, 4.2, 3.2, 0, PI);
    } else if (this.name === 'lock') {
      this.rrect(c, 4.8, 10.4, 14.4, 9.4, 2.4);
      this.arcPath(c, 12, 7.9, 3.6, PI, PI * 2);
      c.moveTo(8.4, 7.9);
      c.lineTo(8.4, 10.4);
      c.moveTo(15.6, 7.9);
      c.lineTo(15.6, 10.4);
      this.dot(c, 12, 15, 1.1);
    } else if (this.name === 'info') {
      this.arcPath(c, 12, 12, 8.4, 0, PI * 2);
      c.moveTo(12, 10.8);
      c.lineTo(12, 16.2);
      this.dot(c, 12, 8.2, 0.9);
    } else if (this.name === 'trash') {
      c.moveTo(4.8, 7.2);
      c.lineTo(19.2, 7.2);
      c.moveTo(9.4, 7.2);
      c.lineTo(9.4, 5.4);
      c.lineTo(14.6, 5.4);
      c.lineTo(14.6, 7.2);
      c.moveTo(6.6, 7.2);
      c.lineTo(7.5, 18.4);
      c.quadraticCurveTo(7.6, 20, 9.3, 20);
      c.lineTo(14.7, 20);
      c.quadraticCurveTo(16.4, 20, 16.5, 18.4);
      c.lineTo(17.4, 7.2);
      c.moveTo(10.4, 10.8);
      c.lineTo(10.4, 16.4);
      c.moveTo(13.6, 10.8);
      c.lineTo(13.6, 16.4);
    } else if (this.name === 'book') {
      // 摊开的书：外框 + 中缝 + 两侧页线
      c.moveTo(4.6, 5.6);
      c.lineTo(4.6, 18.8);
      c.lineTo(12, 17.2);
      c.lineTo(19.4, 18.8);
      c.lineTo(19.4, 5.6);
      c.quadraticCurveTo(15.7, 4.2, 12, 5.6);
      c.quadraticCurveTo(8.3, 4.2, 4.6, 5.6);
      c.moveTo(12, 5.6);
      c.lineTo(12, 17.2);
      c.moveTo(7.6, 8.6);
      c.lineTo(7.6, 12.4);
      c.moveTo(16.4, 8.6);
      c.lineTo(16.4, 12.4);
    } else if (this.name === 'award') {
      // 奖章：圆环 + 两条缎带
      this.arcPath(c, 12, 9.4, 5.6, 0, PI * 2);
      c.moveTo(9.1, 13.6);
      c.lineTo(8.1, 20.6);
      c.lineTo(12, 18.8);
      c.lineTo(15.9, 20.6);
      c.lineTo(14.9, 13.6);
    } else if (this.name === 'send') {
      // 纸飞机：轮廓及折叠线共同位于格窗中央，避免尖角造成视觉偏移
      c.moveTo(4.2, 11.8);
      c.lineTo(19.8, 5.2);
      c.lineTo(15, 19);
      c.lineTo(11.8, 13.2);
      c.lineTo(4.2, 11.8);
      c.moveTo(11.8, 13.2);
      c.lineTo(19.8, 5.2);
    } else if (this.name === 'key') {
      // 钥匙：整体轮廓约 14×14，视觉中心落在 12×12
      this.arcPath(c, 8.3, 8.3, 3.7, 0, PI * 2);
      c.moveTo(10.9, 10.9);
      c.lineTo(18.8, 18.8);
      c.moveTo(14.8, 14.8);
      c.lineTo(16.8, 12.8);
      c.moveTo(16.8, 16.8);
      c.lineTo(18.8, 14.8);
    } else if (this.name === 'wifi') {
      this.arcPath(c, 12, 19, 13.4, PI * 1.22, PI * 1.78);
      this.arcPath(c, 12, 19, 8.6, PI * 1.2, PI * 1.8);
      this.arcPath(c, 12, 19, 4, PI * 1.15, PI * 1.85);
      this.dot(c, 12, 19, 0.9);
    } else {
      this.rrect(c, 4, 4, 6.4, 6.4, 1.6);
      this.rrect(c, 13.6, 4, 6.4, 6.4, 1.6);
      this.rrect(c, 4, 13.6, 6.4, 6.4, 1.6);
      this.rrect(c, 13.6, 13.6, 6.4, 6.4, 1.6);
    }

    c.stroke();
    c.restore();
  }
}
