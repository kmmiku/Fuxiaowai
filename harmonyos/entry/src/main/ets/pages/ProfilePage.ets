import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import http from '@ohos.net.http';
import hilog from '@ohos.hilog';
import promptAction from '@ohos.promptAction';
import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import { BottomTabs } from '../ui/components/BottomTabs';
import { LineIcon } from '../ui/components/LineIcon';
import { Profile, ProfileStore } from '../data/local/ProfileStore';
import { AvatarStore } from '../data/local/AvatarStore';
import { checkForUpdate, previewUpdate } from '../common/util/UpdateCheck';

interface MenuRow {
  key: string;
  title: string;
  desc: string;
  icon: string;
}

@Entry
@Component
struct ProfilePage {
  @StorageLink('dark') dark: boolean = false;
  @State profile: Profile = {
    name: '', studentId: '', clazz: '', major: '', grade: '', updatedAt: 0
  };
  @State loggedIn: boolean = false;
  @State avatarPath: string = '';
  /** 正在按下的条目 key，按下时底色淡入，抬手后淡出 */
  @State pressKey: string = '';

  private rows: MenuRow[] = [
    { key: 'info', title: '个人资料', desc: '学号、专业、班级', icon: 'user' },
    { key: 'feedback', title: '反馈问题', desc: '说说哪里不好用', icon: 'help' },
    { key: 'timetable', title: '课表设置', desc: '周末、行高、上课时间', icon: 'calendar' },
    { key: 'remind', title: '上课提醒', desc: '提前几分钟提醒', icon: 'bell' },
    { key: 'appearance', title: '外观', desc: '深色 / 主题', icon: 'shirt' },
    { key: 'account', title: '账号与安全', desc: '凭据、清除数据', icon: 'lock' }
  ];

  private subRows: MenuRow[] = [
    { key: 'faq', title: '常见问题', desc: '登录、课表、提醒的答案', icon: 'help' },
    { key: 'about', title: '关于福小外', desc: '版本、开发者与反馈邮箱', icon: 'info' },
    { key: 'cache', title: '清除缓存', desc: '清掉临时文件，不动课表', icon: 'trash' },
    { key: 'network', title: '网络检测', desc: '看看教务和后台通不通', icon: 'wifi' },
    { key: 'update', title: '检查更新', desc: '查看当前版本与更新信息', icon: 'download' },
    { key: 'more', title: '更多', desc: '隐私与个人信息相关的入口', icon: 'grid' }
  ];

  aboutToAppear(): void {
    this.load();
  }

  onPageShow(): void {
    this.pressKey = '';
    this.load();
  }

  /** 按下底色的淡入淡出：亮色 #F1F4FD、深色 #262B36，比卡片底稍深一档 */
  private rowBg(key: string): ResourceColor {
    if (this.pressKey !== key) {
      return Color.Transparent;
    }
    return this.dark ? '#262B36' : '#F1F4FD';
  }

  private toast(text: string): void {
    promptAction.showToast({ message: text, duration: 2000 });
  }

  private async load(): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const p: Profile = await ProfileStore.load(ctx);
    this.profile = p;
    this.loggedIn = p.name.length > 0;
    this.avatarPath = await AvatarStore.load(ctx);
  }

  /** 清缓存：只删 cacheDir 下的文件，不碰 preferences 与数据库 */
  private clearCache(): void {
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const dir: string = ctx.cacheDir;
      const names: string[] = fs.listFileSync(dir);
      let count: number = 0;
      names.forEach((name: string) => {
        const full: string = `${dir}/${name}`;
        try {
          if (fs.statSync(full).isDirectory()) {
            fs.rmdirSync(full);
          } else {
            fs.unlinkSync(full);
          }
          count++;
        } catch (e) {
          // 单个文件删不掉不影响其它
        }
      });
      this.toast(count > 0 ? `已清理 ${count} 项临时文件` : '缓存已经是干净的');
    } catch (e) {
      this.toast('清理失败，请稍后再试');
    }
  }

  /** 网络检测：并发探教务与后台，结果用对话框列出 */
  private async probe(url: string): Promise<boolean> {
    const client: http.HttpRequest = http.createHttp();
    try {
      const res: http.HttpResponse = await client.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 6000,
        readTimeout: 6000,
        expectDataType: http.HttpDataType.STRING
      });
      return res.responseCode > 0;
    } catch (e) {
      hilog.error(0x0000, 'FxwProbe', 'probe fail %{public}s -> %{public}s', url, JSON.stringify(e));
      return false;
    } finally {
      client.destroy();
    }
  }

  private async checkNetwork(): Promise<void> {
    this.toast('正在检测…');
    const jw: boolean = await this.probe('http://jw.fzfu.edu.cn/jwglxt/xtgl/login_slogin.html');
    const server: boolean = await this.probe('https://fuxiaowai.xyz/healthz');
    const lines: string[] = [
      `教务系统  ${jw ? '可访问' : '连不上'}`,
      `福小外后台  ${server ? '可访问' : '连不上'}`,
      '',
      jw ? '教务正常。' : '教务只对校内网开放，校外请先连学校 VPN。',
      server ? '后台正常。' : '后台连不上时，分享口令与反馈会先存本机，联网后自动补传。'
    ];
    promptAction.showDialog({
      title: '网络检测',
      message: lines.join('\n'),
      buttons: [{ text: '知道了', color: Palette.primary }]
    });
  }

  private open(key: string): void {
    if (key === 'update') {
      checkForUpdate(getContext(this) as common.UIAbilityContext, this.getUIContext());
      return;
    }
    if (key === 'info') {
      router.pushUrl({ url: 'pages/PersonalInfoPage' });
      return;
    }
    if (key === 'feedback') {
      router.pushUrl({ url: 'pages/FeedbackPage' });
      return;
    }
    if (key === 'timetable') {
      router.pushUrl({ url: 'pages/TimetableSettings' });
      return;
    }
    if (key === 'remind') {
      router.pushUrl({ url: 'pages/RemindPage' });
      return;
    }
    if (key === 'appearance') {
      router.pushUrl({ url: 'pages/AppearancePage' });
      return;
    }
    if (key === 'account') {
      router.pushUrl({ url: 'pages/AccountPage' });
      return;
    }
    if (key === 'faq') {
      router.pushUrl({ url: 'pages/FaqPage' });
      return;
    }
    if (key === 'about') {
      router.pushUrl({ url: 'pages/AboutPage' });
      return;
    }
    if (key === 'more') {
      router.pushUrl({ url: 'pages/MorePage' });
      return;
    }
    if (key === 'cache') {
      this.clearCache();
      return;
    }
    if (key === 'network') {
      this.checkNetwork();
    }
  }

  private initial(): string {
    if (this.profile.name.length === 0) {
      return '';
    }
    return this.profile.name.substring(this.profile.name.length - 1);
  }

  @Builder
  headerBar() {
    Row() {
      Text('我的')
        .fontSize(Font.title)
        .fontWeight(FontWeight.Bold)
        .fontColor(TC(this.dark).text)
        .margin({ left: 4 })
    }
    .width('100%')
    .padding({ left: 12, right: 10, top: 6, bottom: 6 })
  }

  @Builder
  accountCard() {
    Row() {
      if (this.loggedIn) {
        Stack() {
          if (this.avatarPath.length > 0) {
            Image('file://' + this.avatarPath)
              .width(72)
              .height(72)
              .borderRadius(36)
              .objectFit(ImageFit.Cover)
          } else {
            Text(this.initial())
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .width(72)
              .height(72)
              .textAlign(TextAlign.Center)
              .borderRadius(36)
              .linearGradient({
                angle: 135,
                colors: [['#3A56C8', 0.0], ['#5B6FE8', 1.0]]
              })
          }
        }
        .width(72)
        .height(72)
      } else {
        Column() {
          LineIcon({ name: 'user', iconSize: 30, tone: 'sub', strokeW: 1.4 })
        }
        .width(72)
        .height(72)
        .justifyContent(FlexAlign.Center)
        .borderRadius(36)
        .backgroundColor(TC(this.dark).chip)
      }

      Column() {
        Text(this.loggedIn ? this.profile.name : '立即登录')
          .fontSize(this.loggedIn ? 22 : 20)
          .fontWeight(FontWeight.Bold)
          .fontColor(TC(this.dark).text)
        Text(this.loggedIn
          ? (ProfileStore.subtitle(this.profile).length > 0
            ? ProfileStore.subtitle(this.profile)
            : this.profile.clazz)
          : '选择学校 / 年级 ›')
          .fontSize(Font.small)
          .fontColor(TC(this.dark).textSub)
          .margin({ top: 6 })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 16 })

      if (!this.loggedIn) {
        Text('›')
          .fontSize(20)
          .fontColor(TC(this.dark).textHint)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 18, bottom: 18 })
    .backgroundColor(TC(this.dark).card)
    .borderRadius(Metric.cardRadius)
    .onClick(() => {
      if (!this.loggedIn) {
        router.pushUrl({ url: 'pages/LoginPage' });
      } else {
        router.pushUrl({ url: 'pages/PersonalInfoPage' });
      }
    })
  }

  @Builder
  rowItem(r: MenuRow, quiet: boolean) {
    Row() {
      Row() {
        LineIcon({
          name: r.icon,
          iconSize: quiet ? 17 : 19,
          tone: quiet ? 'sub' : 'pri',
          strokeW: 1.6
        })
      }
      .width(32)
      .height(32)
      .borderRadius(16)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(quiet ? TC(this.dark).chip : (this.dark ? '#232A44' : '#EEF1FB'))

      Column() {
        Text(r.title)
          .fontSize(Font.body)
          .fontColor(TC(this.dark).text)
        Text(r.desc)
          .fontSize(Font.tiny)
          .fontColor(TC(this.dark).textHint)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      Text('›')
        .fontSize(16)
        .fontColor(TC(this.dark).textHint)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(this.rowBg(r.key))
    .animation({ duration: 150, curve: Curve.EaseOut })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressKey = r.key;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressKey = '';
      }
    })
    .onClick(() => {
      this.open(r.key);
    })
    .gesture(LongPressGesture({ repeat: false }).onAction(() => {
      if (r.key === 'update') { previewUpdate(this.getUIContext()); }
    }))
  }

  @Builder
  menuCard() {
    Column() {
      ForEach(this.rows, (r: MenuRow, i: number) => {
        this.rowItem(r, false)
        if (i < this.rows.length - 1) {
          Divider()
            .color(TC(this.dark).line)
            .margin({ left: 58 })
        }
      }, (r: MenuRow) => r.key)
    }
    .width('100%')
    .backgroundColor(TC(this.dark).card)
    .borderRadius(Metric.cardRadius)
    .margin({ top: 12 })
    .clip(true)
  }

  @Builder
  subCard() {
    Column() {
      ForEach(this.subRows, (r: MenuRow, i: number) => {
        this.rowItem(r, true)
        if (i < this.subRows.length - 1) {
          Divider()
            .color(TC(this.dark).line)
            .margin({ left: 58 })
        }
      }, (r: MenuRow) => r.key)
    }
    .width('100%')
    .backgroundColor(TC(this.dark).card)
    .borderRadius(Metric.cardRadius)
    .clip(true)
    // 与主区之间留出分组间距，次区整体往下挪一点
    .margin({ top: 22 })
  }

  build() {
    Column() {
      this.headerBar()

      Scroll() {
        Column() {
          this.accountCard()
          this.menuCard()

          this.subCard()

          Text('福小外 v0.1.1 · 福州外语外贸学院')
            .fontSize(10)
            .fontColor(TC(this.dark).textHint)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 20, bottom: 24 })
        }
        .width('100%')
        .padding({ left: 14, right: 14 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      BottomTabs({ current: 3, dark: this.dark })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
  }
}
