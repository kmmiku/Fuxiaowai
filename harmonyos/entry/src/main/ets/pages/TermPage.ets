import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import { currentWeek, TERM_LABEL, TOTAL_WEEKS, weekRangeLabel } from '../common/util/TermCalendar';
import { Locator } from '../app/di/ServiceLocator';
import { Credential, CredentialStore } from '../data/local/CredentialStore';
import { SyncResult } from '../domain/usecase/SyncTimetable';
import common from '@ohos.app.ability.common';
import router from '@ohos.router';

/** 学期管理：查看当前学期与周次，重新同步本学期课表 */
@Entry
@Component
struct TermPage {
  @StorageLink('dark') dark: boolean = false;
  @State syncLabel: string = '';
  @State busy: boolean = false;

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(26)
          .fontColor(TC(this.dark).text)
          .width(40)
          .onClick(() => router.back())
        Text('切换学期')
          .fontSize(Font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(TC(this.dark).text)
        Blank()
      }
      .width('100%')
      .height(60)
      .padding({ left: 8, right: Metric.pagePadding })

      Row() {
        Column() {
          Text('当前学期')
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textHint)
          Text(TERM_LABEL)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(TC(this.dark).text)
            .margin({ top: 4 })
          Text(`第${currentWeek(TOTAL_WEEKS)}周 · 共${TOTAL_WEEKS}周 · 本周 ${weekRangeLabel(currentWeek(TOTAL_WEEKS))}`)
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textSub)
            .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text('使用中')
          .fontSize(Font.small)
          .fontColor(Palette.primary)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(Palette.todayBg)
          .borderRadius(8)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(TC(this.dark).card)
      .borderRadius(16)
      .margin({ left: Metric.pagePadding, right: Metric.pagePadding })

      Column() {
        Row() {
          Column() {
            Text('重新同步本学期')
              .fontSize(15)
              .fontColor(TC(this.dark).text)
            Text('用已保存的账号再拉一次课表，课程变动时用')
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textHint)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Button(this.busy ? '同步中…' : '同步')
            .width(72)
            .height(36)
            .fontSize(Font.body)
            .fontColor(Color.White)
            .backgroundColor(Palette.primary)
            .enabled(!this.busy)
            .onClick(() => this.sync())
        }
        .width('100%')
        .padding(16)
      }
      .backgroundColor(TC(this.dark).card)
      .borderRadius(16)
      .margin({ left: Metric.pagePadding, right: Metric.pagePadding, top: 12 })

      if (this.syncLabel.length > 0) {
        Text(this.syncLabel)
          .fontSize(Font.small)
          .fontColor(TC(this.dark).textSub)
          .width('100%')
          .padding({ left: 20, right: 20, top: 10 })
      }

      Text('教务系统一学期只开放当前学期的课表，历史学期需在教务端查询；下一学期开放后这里会自动出现。')
        .fontSize(Font.small)
        .fontColor(TC(this.dark).textHint)
        .lineHeight(19)
        .padding({ left: 20, right: 20, top: 16 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
  }

  private async sync(): Promise<void> {
    this.busy = true;
    this.syncLabel = '';
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const cred: Credential = await CredentialStore.load(ctx);
      if (cred.user.length === 0 || cred.pwd.length === 0) {
        this.syncLabel = '还没有保存的账号，先去登录一次';
        this.busy = false;
        return;
      }
      await Locator.init(ctx);
      const r: SyncResult = await Locator.syncAndSave(cred.user, cred.pwd, 't1');
      if (r.ok) {
        await CredentialStore.markSyncAt(ctx, Date.now());
      }
      if (r.captcha.byteLength > 0) {
        this.syncLabel = '教务要求验证码，请到「导入课表」页完成验证';
      } else {
        this.syncLabel = r.ok ? `同步完成：${r.message}` : `同步失败：${r.message}`;
      }
    } catch (e) {
      this.syncLabel = '同步异常：' + (e instanceof Error ? e.message : JSON.stringify(e));
    }
    this.busy = false;
  }
}