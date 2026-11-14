import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import { Credential, CredentialStore } from '../data/local/CredentialStore';
import { ProfileStore } from '../data/local/ProfileStore';
import { SessionStore } from '../data/local/SessionStore';
import { Locator } from '../app/di/ServiceLocator';
import common from '@ohos.app.ability.common';
import router from '@ohos.router';

/** 账号与安全：查看绑定的教务账号、上次同步时间、清除本地数据 */
@Entry
@Component
struct AccountPage {
  @StorageLink('dark') dark: boolean = false;
  @State user: string = '';
  @State masked: string = '';
  @State remember: boolean = true;
  @State lastSync: string = '从未同步';
  @State busy: boolean = false;

  aboutToAppear(): void {
    this.refresh();
  }

  private async refresh(): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const c: Credential = await CredentialStore.load(ctx);
    this.user = c.user;
    this.masked = this.maskUser(c.user);
    this.remember = c.remember;
    const ts: number = await CredentialStore.lastSyncAt(ctx);
    this.lastSync = ts > 0 ? this.formatTime(ts) : '从未同步';
  }

  private maskUser(u: string): string {
    if (u.length <= 4) {
      return u;
    }
    let s: string = u.substring(0, 4);
    for (let i = 4; i < u.length; i++) {
      s += '*';
    }
    return s;
  }

  private formatTime(ts: number): string {
    const d: Date = new Date(ts);
    const mm: string = (d.getMonth() + 1).toString().padStart(2, '0');
    const dd: string = d.getDate().toString().padStart(2, '0');
    const hh: string = d.getHours().toString().padStart(2, '0');
    const mi: string = d.getMinutes().toString().padStart(2, '0');
    return `${d.getFullYear()}-${mm}-${dd} ${hh}:${mi}`;
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(26)
          .fontColor(TC(this.dark).text)
          .width(40)
          .onClick(() => router.back())
        Text('账号与安全')
          .fontSize(Font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(TC(this.dark).text)
        Blank()
      }
      .width('100%')
      .height(60)
      .padding({ left: 8, right: Metric.pagePadding })

      Column() {
        Row() {
          Column() {
            Text(this.user.length > 0 ? '已绑定教务账号' : '未绑定教务账号')
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textHint)
            Text(this.user.length > 0 ? this.masked : '—')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(TC(this.dark).text)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('更新密码')
            .fontSize(Font.body)
            .fontColor(Palette.primary)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor(TC(this.dark).chip)
            .borderRadius(10)
            .onClick(() => {
              router.pushUrl({ url: 'pages/LoginPage' });
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      }
      .backgroundColor(TC(this.dark).card)
      .borderRadius(16)
      .margin({ left: Metric.pagePadding, right: Metric.pagePadding })

      Column() {
        this.infoRow('上次同步', this.lastSync)
        Divider().color(TC(this.dark).line).strokeWidth(0.5).margin({ left: 16 })
        this.infoRow('记住密码', this.remember ? '已开启（自动刷新用）' : '已关闭')
        Divider().color(TC(this.dark).line).strokeWidth(0.5).margin({ left: 16 })
        this.infoRow('数据位置', '本机保存，主动分享或反馈时上传')
      }
      .backgroundColor(TC(this.dark).card)
      .borderRadius(16)
      .margin({ left: Metric.pagePadding, right: Metric.pagePadding, top: 12 })

      Column() {
        Text('登录凭据经 HUKS 加密后保存在本机；分享与反馈仅在主动使用时发送。')
          .fontSize(Font.small)
          .fontColor(TC(this.dark).textHint)
          .lineHeight(18)
      }
      .width('100%')
      .padding({ left: 4, right: 4, top: 10, bottom: 10 })

      Blank()

      Column({ space: 10 }) {
        Button(this.busy ? '处理中…' : '清除本地课表')
          .width('100%')
          .height(46)
          .fontSize(Font.body)
          .fontColor(Palette.danger)
          .backgroundColor(TC(this.dark).card)
          .enabled(!this.busy)
          .onClick(() => this.clearCourses())

        Button('退出登录并清除账号')
          .width('100%')
          .height(46)
          .fontSize(Font.body)
          .fontColor(Color.White)
          .backgroundColor(Palette.danger)
          .enabled(!this.busy)
          .onClick(() => this.clearAll())
      }
      .width('100%')
      .padding({ left: Metric.pagePadding, right: Metric.pagePadding, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(TC(this.dark).text)
      Blank()
      Text(value)
        .fontSize(Font.body)
        .fontColor(TC(this.dark).textSub)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 13, bottom: 13 })
  }

  private async clearCourses(): Promise<void> {
    this.busy = true;
    try {
      await Locator.init(getContext(this) as common.UIAbilityContext);
      const all = await Locator.repo().tables();
      for (const t of all) {
        await Locator.repo().replaceAll(t.id, []);
      }
      this.toast('本地课表已清空');
    } catch (e) {
      this.toast('清除失败');
    }
    this.busy = false;
  }

  private async clearAll(): Promise<void> {
    this.busy = true;
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await Locator.init(ctx);
      await Locator.clearPersonalData();
      this.toast('已退出登录');
      this.user = '';
      this.masked = '';
      this.lastSync = '从未同步';
      setTimeout(() => {
        router.back();
      }, 800);
    } catch (e) {
      this.toast('操作失败');
    }
    this.busy = false;
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1600 });
  }
}
