import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import picker from '@ohos.file.picker';
import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import { Feedback, FeedbackStore } from '../data/local/FeedbackStore';
import { FeedbackDelivery, encodeFeedbackImage, newFeedbackId, removeFeedbackImage } from '../data/remote/FeedbackDelivery';

const MAX_IMAGES: number = 3;

@Entry
@Component
struct FeedbackPage {
  @StorageLink('dark') dark: boolean = false;
  @State text: string = '';
  @State contact: string = '';
  @State images: string[] = [];
  @State busy: boolean = false;
  @State pending: number = 0;
  @State showDone: boolean = false;
  @State doneScale: number = 0.5;
  @State doneTick: number = 0;

  aboutToAppear(): void {
    this.refreshPending();
    this.flushPending();
  }

  private async refreshPending(): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.pending = await FeedbackStore.pendingCount(ctx);
  }

  private tip(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1600 });
  }

  private async pickImages(): Promise<void> {
    const remain: number = MAX_IMAGES - this.images.length;
    if (remain <= 0) {
      this.tip(`最多添加 ${MAX_IMAGES} 张图片`);
      return;
    }
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    // 优先走系统图库；只有图库不可用（抛异常）才回退到文件选择器。
    // 用户主动取消时返回空数组，不算不可用，避免又弹一个选择器。
    let uris: string[] = [];
    const gallery: string[] | null = await this.pickFromGallery(remain);
    if (gallery === null) {
      uris = await this.pickFromFiles(remain);
    } else {
      uris = gallery;
    }
    if (uris.length === 0) {
      return;
    }
    const added: string[] = [];
    for (let i = 0; i < uris.length; i++) {
      const dest: string = `${ctx.cacheDir}/${newFeedbackId()}_${i}.jpg`;
      try {
        const src: fs.File = fs.openSync(uris[i], fs.OpenMode.READ_ONLY);
        try { fs.copyFileSync(src.fd, dest); } finally { fs.closeSync(src); }
        added.push('file://' + dest);
      } catch (e) {
        removeFeedbackImage('file://' + dest);
        this.tip('这张图读取失败，已跳过');
      }
    }
    if (added.length > 0) {
      this.images = this.images.concat(added);
    }
  }

  private async pickFromGallery(remain: number): Promise<string[] | null> {
    try {
      const options: photoAccessHelper.PhotoSelectOptions = {
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: remain
      };
      const pv: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const res: photoAccessHelper.PhotoSelectResult = await pv.select(options);
      return res.photoUris;
    } catch (e) {
      return null;
    }
  }

  private async pickFromFiles(remain: number): Promise<string[]> {
    try {
      const opts: picker.DocumentSelectOptions = {
        maxSelectNumber: remain,
        fileSuffixFilters: ['.jpg', '.jpeg', '.png', '.webp']
      };
      const dp: picker.DocumentViewPicker = new picker.DocumentViewPicker(getContext(this));
      return await dp.select(opts);
    } catch (e) {
      this.tip('当前设备没有可用的图库或文件选择器');
      return [];
    }
  }

  private removeImage(i: number): void {
    if (i >= 0 && i < this.images.length) { removeFeedbackImage(this.images[i]); }
    const next: string[] = [];
    for (let k = 0; k < this.images.length; k++) {
      if (k !== i) {
        next.push(this.images[k]);
      }
    }
    this.images = next;
  }

  private async submit(): Promise<void> {
    if (this.busy) {
      return;
    }
    if (this.text.trim().length === 0) {
      this.tip('先说点什么吧');
      return;
    }
    if (this.contact.trim().length === 0) {
      this.tip('留个联系方式吧，方便我们回你');
      return;
    }
    this.busy = true;
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const f: Feedback = {
        id: newFeedbackId(),
        text: this.text.trim(),
        contact: this.contact.trim(),
        images: this.images,
        createdAt: Date.now(),
        sent: false
      };
      await FeedbackStore.push(ctx, f);
      await this.refreshPending();
      this.text = '';
      this.contact = '';
      this.images = [];

      // 立刻尝试上传；失败就留在本地队列，下次进页面自动补发
      const state: string = await this.sendOne(f);
      await this.refreshPending();
      if (state === 'ok') {
        this.playDone();
      } else if (state === 'limited') {
        this.tip('提交过于频繁，反馈已保存在本机，稍后重试');
      } else if (state === 'image') {
        this.tip('图片处理失败，反馈已保存在本机，请检查图片后重试');
      } else {
        this.tip('网络不通，已存本地，下次进入会重试');
      }
    } catch (e) {
      this.tip('保存失败，请重试');
    }
    this.busy = false;
  }

  /** 提交成功的打勾动画：圆从 0.5 弹到 1，2.2 秒后自动消失 */
  private playDone(): void {
    this.doneScale = 0.5;
    this.showDone = true;
    // 同一 tick 里改状态又 animateTo 会被合帧成一帧，必须错开
    setTimeout(() => {
      animateTo({ duration: 320, curve: Curve.FastOutSlowIn }, () => {
        this.doneScale = 1;
      });
    }, 16);
    setTimeout(() => {
      this.showDone = false;
    }, 2200);
  }

  @Builder
  doneOverlay() {
    Column() {
      Column() {
        Stack() {
          Circle()
            .width(78)
            .height(78)
            .fill('#2FA36B')
          Text('✓')
            .fontSize(46)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(78)
        .height(78)

        Text('反馈已提交')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .margin({ top: 16 })
        Text('谢谢你的反馈，我们会在后续版本里处理')
          .fontSize(Font.small)
          .fontColor('#D9FFFFFF')
          .margin({ top: 7 })
      }
      .padding({ left: 30, right: 30, top: 28, bottom: 26 })
      .backgroundColor('#E6101216')
      .borderRadius(20)
      .scale({ x: this.doneScale, y: this.doneScale })
      .opacity(this.doneScale < 1 ? 0.6 : 1)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
    })
  }

  private async toDataUrl(uri: string): Promise<string> {
    return encodeFeedbackImage(uri);
  }

  private async sendOne(f: Feedback): Promise<string> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return FeedbackDelivery.send(ctx, f);
  }

  private async flushPending(): Promise<void> {
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await FeedbackDelivery.flush(ctx);
      await this.refreshPending();
    } catch (error) {
      this.tip(error instanceof Error ? error.message : '本地反馈读取失败');
    }
  }

  @Builder
  headerBar() {
    Row() {
      Text('‹')
        .fontSize(26)
        .fontColor(TC(this.dark).text)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          router.back();
        })
      Text('反馈问题')
        .fontSize(Font.title)
        .fontWeight(FontWeight.Bold)
        .fontColor(TC(this.dark).text)
        .margin({ left: 4 })
      Blank()
      if (this.pending > 0) {
        Text(`${this.pending} 条待提交`)
          .fontSize(10)
          .fontColor(TC(this.dark).textHint)
      }
    }
    .width('100%')
    .padding({ left: 6, right: 14, top: 6, bottom: 6 })
  }

  @Builder
  imageGrid() {
    Row() {
      ForEach(this.images, (uri: string, i: number) => {
        Stack({ alignContent: Alignment.TopEnd }) {
          Image(uri)
            .width(84)
            .height(84)
            .borderRadius(10)
            .objectFit(ImageFit.Cover)
            .backgroundColor(TC(this.dark).chip)
          Text('×')
            .fontSize(12)
            .fontColor(Color.White)
            .width(20)
            .height(20)
            .textAlign(TextAlign.Center)
            .borderRadius(10)
            .backgroundColor('#99000000')
            .margin({ top: 3, right: 3 })
            .onClick(() => {
              this.removeImage(i);
            })
        }
        .margin({ right: 10 })
      }, (uri: string, i: number) => `${i}-${uri}`)

      if (this.images.length < MAX_IMAGES) {
        Column() {
          Text('+')
            .fontSize(24)
            .fontColor(TC(this.dark).textHint)
          Text('图片')
            .fontSize(9)
            .fontColor(TC(this.dark).textHint)
            .margin({ top: 2 })
        }
        .width(84)
        .height(84)
        .justifyContent(FlexAlign.Center)
        .borderRadius(10)
        .backgroundColor(TC(this.dark).chip)
        .onClick(() => {
          this.pickImages();
        })
      }
    }
    .width('100%')
    .margin({ top: 12 })
  }

  build() {
    Stack() {
    Column() {
      this.headerBar()

      Scroll() {
        Column() {
          // 文字区
          Column() {
            TextArea({ text: this.text })
              .placeholderColor(TC(this.dark).textHint)
              .fontColor(TC(this.dark).text)
              .fontSize(Font.body)
              .backgroundColor(Color.Transparent)
              .height(150)
              .width('100%')
              .onChange((v: string) => {
                this.text = v;
              })
            Text(`${this.text.length}/500`)
              .fontSize(9)
              .fontColor(TC(this.dark).textHint)
              .width('100%')
              .textAlign(TextAlign.End)
              .padding({ right: 6, bottom: 4 })
          }
          .width('100%')
          .padding(12)
          .backgroundColor(TC(this.dark).card)
          .borderRadius(Metric.cardRadius)

          // 图片区
          Column() {
            Row() {
              Text('图片')
                .fontSize(Font.body)
                .fontColor(TC(this.dark).text)
              Blank()
              Text(`${this.images.length}/${MAX_IMAGES}`)
                .fontSize(10)
                .fontColor(TC(this.dark).textHint)
            }
            .width('100%')
            this.imageGrid()
          }
          .width('100%')
          .padding(14)
          .backgroundColor(TC(this.dark).card)
          .borderRadius(Metric.cardRadius)
          .margin({ top: 12 })

          // 联系方式
          Column() {
            Row() {
              Text('联系方式')
                .fontSize(Font.body)
                .fontColor(TC(this.dark).text)
                .width(76)
              TextInput({ text: this.contact, placeholder: '必填，手机号 / 微信 / 邮箱' })
                .placeholderColor(TC(this.dark).textHint)
                .fontColor(TC(this.dark).text)
                .fontSize(Font.small)
                .backgroundColor(Color.Transparent)
                .layoutWeight(1)
                .onChange((v: string) => {
                  this.contact = v;
                })
              Text('*')
                .fontSize(13)
                .fontColor(Palette.danger)
                .margin({ left: 2 })
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: 14, right: 8, top: 6, bottom: 6 })
          .backgroundColor(TC(this.dark).card)
          .borderRadius(Metric.cardRadius)
          .margin({ top: 12 })

          // 提交
          Button(this.busy ? '提交中…' : '提交反馈')
            .fontSize(Font.body)
            .fontColor(Color.White)
            .width('100%')
            .height(46)
            .borderRadius(12)
            .backgroundColor(Palette.primary)
            .enabled(!this.busy)
            .margin({ top: 20 })
            .onClick(() => {
              this.submit();
            })

          Text('提交后直接发送到服务器；网络不通时先存本机，下次进来自动补发')
            .fontSize(10)
            .fontColor(TC(this.dark).textHint)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 12 })
            .padding({ left: 20, right: 20 })
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 30 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)

      if (this.showDone) {
        this.doneOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }
}