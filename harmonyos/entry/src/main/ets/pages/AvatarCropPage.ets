import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import image from '@ohos.multimedia.image';
import display from '@ohos.display';
import hilog from '@ohos.hilog';
import { AvatarStore } from '../data/local/AvatarStore';

interface CropParams {
  path: string;
}

/**
 * 头像裁剪页：照安卓版 AvatarCropper 的做法
 * 全屏黑底 + 圆形取景框 + 底部缩放滑块，确认后裁 512 方图存进沙箱
 */
@Entry
@Component
struct AvatarCropPage {
  @State src: string = '';
  @State cropPm: image.PixelMap | undefined = undefined;
  @State zoom: number = 1;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State busy: boolean = false;
  @State viewSize: number = 294;
  private buf: ArrayBuffer = new ArrayBuffer(0);
  private imgW: number = 0;
  private imgH: number = 0;
  private panBaseX: number = 0;
  private panBaseY: number = 0;

  aboutToAppear(): void {
    const p: CropParams = router.getParams() as CropParams;
    if (p !== undefined && p.path !== undefined && p.path.length > 0) {
      this.open(p.path);
    }
  }

  private async open(path: string): Promise<void> {
    try {
      const f: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(f.fd);
      const data: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(f.fd, data);
      fs.closeSync(f);
      const source: image.ImageSource = image.createImageSource(data);
      const info: image.ImageInfo = await source.getImageInfo();
      this.imgW = info.size.width;
      this.imgH = info.size.height;
      const pm: image.PixelMap = await source.createPixelMap();
      source.release();
      this.buf = data;
      this.cropPm = pm;
      this.src = path;
      // 取景框边长：屏宽的 78%，夹在 240–340vp（与安卓一致）
      const screenW: number = this.winWidth();
      this.viewSize = Math.min(340, Math.max(240, Math.round(screenW * 0.78)));
      hilog.info(0x0022, 'FuxiaoCrop', 'open %{public}dx%{public}d view=%{public}d', this.imgW, this.imgH,
        this.viewSize);
    } catch (e) {
      const err: Error = e as Error;
      hilog.error(0x0022, 'FuxiaoCrop', 'open failed: %{public}s', err.message);
      this.cancel();
    }
  }

  private winWidth(): number {
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      if (d.width > 0 && d.densityDPI > 0) {
        return d.width * 160 / d.densityDPI;
      }
    } catch (e) {
      hilog.warn(0x0022, 'FuxiaoCrop', 'display unavailable');
    }
    return 406;
  }

  /** 图片铺满取景框的基础倍率（Cover）× 用户缩放 */
  private displayScale(): number {
    const iw: number = this.imgW > 0 ? this.imgW : 1;
    const ih: number = this.imgH > 0 ? this.imgH : 1;
    return Math.max(this.viewSize / iw, this.viewSize / ih) * this.zoom;
  }

  private imageW(): number {
    const iw: number = this.imgW > 0 ? this.imgW : 1;
    return iw * this.displayScale();
  }

  private imageH(): number {
    const ih: number = this.imgH > 0 ? this.imgH : 1;
    return ih * this.displayScale();
  }

  private imageLeft(): number {
    return (this.viewSize - this.imageW()) / 2 + this.offsetX;
  }

  private imageTop(): number {
    return (this.viewSize - this.imageH()) / 2 + this.offsetY;
  }

  private clampOffsets(nx: number, ny: number): void {
    const iw: number = this.imgW > 0 ? this.imgW : 1;
    const ih: number = this.imgH > 0 ? this.imgH : 1;
    const z: number = Math.max(this.viewSize / iw, this.viewSize / ih) * this.zoom;
    const maxX: number = Math.max(0, (iw * z - this.viewSize) / 2);
    const maxY: number = Math.max(0, (ih * z - this.viewSize) / 2);
    this.offsetX = Math.max(-maxX, Math.min(maxX, nx));
    this.offsetY = Math.max(-maxY, Math.min(maxY, ny));
  }

  /** 视口 + 缩放 + 拖动 → 原图上的裁剪矩形 */
  private cropRegion(): image.Region {
    const vp: number = this.viewSize;
    const iw: number = this.imgW > 0 ? this.imgW : 1;
    const ih: number = this.imgH > 0 ? this.imgH : 1;
    const z: number = Math.max(vp / iw, vp / ih) * this.zoom;
    const dw: number = iw * z;
    const dh: number = ih * z;
    const left: number = (dw - vp) / 2 - this.offsetX;
    const top: number = (dh - vp) / 2 - this.offsetY;
    const side: number = vp / z;
    let x: number = left / z;
    let y: number = top / z;
    x = Math.max(0, Math.min(iw - side, x));
    y = Math.max(0, Math.min(ih - side, y));
    return {
      x: Math.round(x),
      y: Math.round(y),
      size: { width: Math.round(side), height: Math.round(side) }
    };
  }

  private async cropTo(side: number): Promise<image.PixelMap> {
    const src: image.ImageSource = image.createImageSource(this.buf);
    const opt: image.DecodingOptions = {
      desiredRegion: this.cropRegion(),
      desiredSize: { width: side, height: side }
    };
    const pm: image.PixelMap = await src.createPixelMap(opt);
    src.release();
    return pm;
  }

  private async use(): Promise<void> {
    if (this.busy || this.cropPm === undefined) {
      return;
    }
    this.busy = true;
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const pm: image.PixelMap = await this.cropTo(512);
      const packer: image.ImagePacker = image.createImagePacker();
      const opt: image.PackingOption = { format: 'image/jpeg', quality: 90 };
      const data: ArrayBuffer = await packer.packing(pm, opt);
      packer.release();
      const dest: string = `${ctx.filesDir}/avatar_${Date.now()}.jpg`;
      const f: fs.File = fs.openSync(dest, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      fs.writeSync(f.fd, data);
      fs.closeSync(f);
      const old: string = await AvatarStore.load(ctx);
      await AvatarStore.save(ctx, dest);
      if (old.length > 0 && old !== dest) {
        try {
          fs.unlinkSync(old);
        } catch (e) {
        }
      }
      hilog.info(0x0022, 'FuxiaoCrop', 'saved avatar bytes=%{public}d', data.byteLength);
      this.getUIContext().getPromptAction().showToast({ message: '头像已更新', duration: 1500 });
      this.cleanSrc();
      router.back();
    } catch (e) {
      const err: Error = e as Error;
      hilog.error(0x0022, 'FuxiaoCrop', 'save failed: %{public}s', err.message);
      this.getUIContext().getPromptAction().showToast({ message: '保存失败，请重试', duration: 1500 });
    }
    this.busy = false;
  }

  private cleanSrc(): void {
    if (this.cropPm !== undefined) {
      this.cropPm.release();
      this.cropPm = undefined;
    }
    if (this.src.length > 0) {
      try {
        fs.unlinkSync(this.src);
      } catch (e) {
      }
    }
  }

  private cancel(): void {
    this.cleanSrc();
    router.back();
  }

  build() {
    Column() {
      Row() {
        Button('取消', { type: ButtonType.Normal })
          .fontSize(14)
          .fontColor('#AEF2F3F7')
          .backgroundColor(Color.Transparent)
          .padding({ left: 10, right: 10 })
          .height(36)
          .onTouch((e: TouchEvent) => {
            if (e.type === TouchType.Up) {
              this.cancel();
            }
          })
          .onClick(() => this.cancel())
        Blank()
        Text('调整头像')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F2F3F7')
        Blank()
        Button(this.busy ? '处理中' : '使用', { type: ButtonType.Normal })
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#6E8BFF')
          .backgroundColor(Color.Transparent)
          .padding({ left: 10, right: 10 })
          .height(36)
          .onTouch((e: TouchEvent) => {
            if (e.type === TouchType.Up) {
              this.use();
            }
          })
          .onClick(() => this.use())
      }
      .width('100%')
      .height(52)
      .padding({ left: 8, right: 8 })

      Stack() {
        Stack() {
          if (this.cropPm !== undefined) {
            Image(this.cropPm)
              .width(this.imageW())
              .height(this.imageH())
              .objectFit(ImageFit.Fill)
              .position({ x: this.imageLeft(), y: this.imageTop() })
              .draggable(false)
          } else {
            LoadingProgress()
              .width(32)
              .height(32)
              .color('#6E8BFF')
          }
        }
        .width(this.viewSize)
        .height(this.viewSize)
        .clipShape(new Circle({ width: this.viewSize, height: this.viewSize }))
        .backgroundColor('#14161C')
        .gesture(
          PanGesture()
            .onActionStart(() => {
              this.panBaseX = this.offsetX;
              this.panBaseY = this.offsetY;
            })
            .onActionUpdate((e: GestureEvent) => {
              this.clampOffsets(this.panBaseX + e.offsetX, this.panBaseY + e.offsetY);
            })
        )

        Circle()
          .width(this.viewSize)
          .height(this.viewSize)
          .fillOpacity(0)
          .stroke('#FFFFFF')
          .strokeWidth(2)
          .opacity(0.9)
          .hitTestBehavior(HitTestMode.None)
      }
      .width(this.viewSize)
      .height(this.viewSize)
      .layoutWeight(1)

      Row() {
        Text('缩放')
          .fontSize(12)
          .fontColor('#99F2F3F7')
          .width(28)
        Slider({
          value: this.zoom,
          min: 1,
          max: 3,
          step: 0.02,
          style: SliderStyle.OutSet
        })
          .selectedColor('#FFFFFF')
          .trackColor('#3DFFFFFF')
          .blockColor('#FFFFFF')
          .layoutWeight(1)
          .onChange((v: number) => {
            this.zoom = v;
            this.clampOffsets(this.offsetX, this.offsetY);
          })
      }
      .width('100%')
      .padding({ left: 28, right: 28, top: 10, bottom: 4 })

      Text('拖动图片调整位置，滑块缩放；圆环内的部分就是头像')
        .fontSize(11)
        .fontColor('#73F2F3F7')
        .textAlign(TextAlign.Center)
        .lineHeight(18)
        .padding({ left: 24, right: 24, top: 8, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 36 })
    .backgroundColor('#0B0D12')
    .alignItems(HorizontalAlign.Center)
  }
}