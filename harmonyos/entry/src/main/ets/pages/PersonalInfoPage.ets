import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import hilog from '@ohos.hilog';
import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import { Profile, ProfileStore } from '../data/local/ProfileStore';
import { CredentialStore } from '../data/local/CredentialStore';
import { AvatarStore } from '../data/local/AvatarStore';
import { SessionStore } from '../data/local/SessionStore';
import { Locator } from '../app/di/ServiceLocator';

interface InfoRow {
  label: string;
  value: string;
}

interface CropParams {
  path: string;
}

@Entry
@Component
struct PersonalInfoPage {
  @StorageLink('dark') dark: boolean = false;
  @State profile: Profile = {
    name: '', studentId: '', clazz: '', major: '', grade: '', updatedAt: 0
  };
  @State rows: InfoRow[] = [];
  @State confirmClear: boolean = false;
  /** 自定义头像的沙箱路径；空串表示用姓名首字圆形头像 */
  @State avatarPath: string = '';
  @State picking: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  /** 从裁剪页回来时刷新头像 */
  onPageShow(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const p: Profile = await ProfileStore.load(ctx);
    this.profile = p;
    const list: InfoRow[] = [
      { label: '姓名', value: p.name.length > 0 ? p.name : '—' },
      { label: '学号', value: p.studentId.length > 0 ? p.studentId : '—' },
      { label: '专业', value: p.major.length > 0 ? p.major : '—' },
      { label: '班级', value: p.clazz.length > 0 ? p.clazz : '—' },
      { label: '年级', value: p.grade.length > 0 ? `${p.grade}级` : '—' }
    ];
    this.rows = list;
    this.avatarPath = await AvatarStore.load(ctx);
  }

  private initial(): string {
    if (this.profile.name.length === 0) {
      return '—';
    }
    return this.profile.name.substring(this.profile.name.length - 1);
  }

  private tip(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1600 });
  }

  /**
   * 从相册选一张图，交给裁剪页自己调范围
   * 图库 uri 是临时授权，先拷到沙箱，裁剪页直接用文件路径读
   */
  private async pickAvatar(): Promise<void> {
    if (this.picking) {
      return;
    }
    this.picking = true;
    try {
      const options: photoAccessHelper.PhotoSelectOptions = {
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      };
      const pv: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const res: photoAccessHelper.PhotoSelectResult = await pv.select(options);
      if (res.photoUris.length === 0) {
        this.picking = false;
        return;
      }
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      this.purgeCropSrc(ctx.filesDir);
      const dest: string = `${ctx.filesDir}/crop_src_${Date.now()}.jpg`;
      const src: fs.File = fs.openSync(res.photoUris[0], fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(src.fd);
      const buf: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(src.fd, buf);
      fs.closeSync(src);
      const out: fs.File = fs.openSync(dest, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      fs.writeSync(out.fd, buf);
      fs.closeSync(out);
      const params: CropParams = { path: dest };
      router.pushUrl({ url: 'pages/AvatarCropPage', params: params });
    } catch (e) {
      const err: Error = e as Error;
      hilog.error(0x0022, 'FuxiaoInfo', 'pick avatar failed: %{public}s', err.message);
      this.tip('当前设备没有可用图库，真机上可正常选图');
    }
    this.picking = false;
  }

  /** 清掉上一轮没走完的裁剪临时图，避免沙箱里堆垃圾 */
  private purgeCropSrc(dir: string): void {
    try {
      const names: string[] = fs.listFileSync(dir);
      for (let i = 0; i < names.length; i++) {
        if (names[i].indexOf('crop_src_') === 0) {
          try {
            fs.unlinkSync(`${dir}/${names[i]}`);
          } catch (e) {
          }
        }
      }
    } catch (e) {
      hilog.warn(0x0022, 'FuxiaoInfo', 'purge crop src failed');
    }
  }

  private async logout(): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    await Locator.init(ctx);
    await Locator.clearPersonalData();
    if (this.avatarPath.length > 0) {
      try {
        fs.unlinkSync(this.avatarPath);
      } catch (e) {
      }
    }
    this.getUIContext().getPromptAction().showToast({ message: '已退出登录', duration: 1500 });
    setTimeout(() => {
      router.back();
    }, 600);
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
      Text('个人资料')
        .fontSize(Font.title)
        .fontWeight(FontWeight.Bold)
        .fontColor(TC(this.dark).text)
        .margin({ left: 4 })
    }
    .width('100%')
    .padding({ left: 6, right: 10, top: 6, bottom: 6 })
  }

  build() {
    Column() {
      this.headerBar()

      Scroll() {
        Column() {
          // 头像区
          Column() {
            Stack() {
              if (this.avatarPath.length > 0) {
                Image('file://' + this.avatarPath)
                  .width(80)
                  .height(80)
                  .borderRadius(40)
                  .objectFit(ImageFit.Cover)
              } else {
                Text(this.initial())
                  .fontSize(30)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .width(80)
                  .height(80)
                  .textAlign(TextAlign.Center)
                  .borderRadius(40)
                  .linearGradient({
                    angle: 135,
                    colors: [['#3A56C8', 0.0], ['#5B6FE8', 1.0]]
                  })
              }

              // 右下角「换头像」徽标：灰色圆底 + 图片图标
              Column() {
                Image($r('app.media.ic_avatar_edit'))
                  .width(15)
                  .height(15)
                  .objectFit(ImageFit.Contain)
              }
              .width(28)
              .height(28)
              .justifyContent(FlexAlign.Center)
              .backgroundColor('#B3A8A8AD')
              .borderRadius(14)
              .border({ width: 2, color: TC(this.dark).bg })
              .position({ x: 54, y: 54 })
            }
            .width(80)
            .height(80)
            .onClick(() => {
              this.pickAvatar();
            })
            Text(this.profile.name.length > 0 ? this.profile.name : '未登录')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(TC(this.dark).text)
              .margin({ top: 12 })
            Text(this.profile.clazz.length > 0 ? this.profile.clazz : '登录教务后自动同步')
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textSub)
              .margin({ top: 4 })
          }
          .width('100%')
          .padding({ top: 24, bottom: 20 })

          Text(this.avatarPath.length > 0 ? '点击头像可重新选择并调整范围' : '点击头像从相册选择')
            .fontSize(10)
            .fontColor(TC(this.dark).textHint)
            .margin({ bottom: 16 })

          // 信息表
          Column() {
            ForEach(this.rows, (r: InfoRow, i: number) => {
              Row() {
                Text(r.label)
                  .fontSize(Font.body)
                  .fontColor(TC(this.dark).textSub)
                  .width(76)
                Text(r.value)
                  .fontSize(Font.body)
                  .fontColor(TC(this.dark).text)
                  .layoutWeight(1)
                  .textAlign(TextAlign.End)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })

              if (i < this.rows.length - 1) {
                Divider()
                  .color(TC(this.dark).line)
                  .margin({ left: 16 })
              }
            }, (r: InfoRow) => r.label)
          }
          .width('100%')
          .backgroundColor(TC(this.dark).card)
          .borderRadius(Metric.cardRadius)

          Text('资料来自教务系统，在首页点 ⇩ 重新同步课表时会一并更新')
            .fontSize(10)
            .fontColor(TC(this.dark).textHint)
            .width('100%')
            .margin({ top: 10, left: 4 })

          // 退出
          Text('退出登录')
            .fontSize(Font.body)
            .fontColor('#D64545')
            .width('100%')
            .height(48)
            .textAlign(TextAlign.Center)
            .backgroundColor(TC(this.dark).card)
            .borderRadius(Metric.cardRadius)
            .margin({ top: 24 })
            .onClick(() => {
              this.confirmClear = true;
            })
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
    .bindSheet($$this.confirmClear, this.confirmView(), {
      height: 240,
      dragBar: false,
      backgroundColor: TC(this.dark).card
    })
  }

  @Builder
  confirmView() {
    Column() {
      Text('退出登录？')
        .fontSize(Font.body)
        .fontWeight(FontWeight.Bold)
        .fontColor(TC(this.dark).text)
        .margin({ top: 24 })
      Text('会清除本机保存的学号密码、课表和成绩缓存，重新登录后自动恢复')
        .fontSize(Font.small)
        .fontColor(TC(this.dark).textSub)
        .margin({ top: 10 })
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 })

      Row() {
        Text('取消')
          .fontSize(Font.body)
          .fontColor(TC(this.dark).text)
          .layoutWeight(1)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor(TC(this.dark).chip)
          .borderRadius(10)
          .onClick(() => {
            this.confirmClear = false;
          })
        Text('退出')
          .fontSize(Font.body)
          .fontColor(Color.White)
          .layoutWeight(1)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor('#D64545')
          .borderRadius(10)
          .margin({ left: 12 })
          .onClick(() => {
            this.confirmClear = false;
            this.logout();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 26 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 6, right: 6 })
  }
}
