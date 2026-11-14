import { TimetableStateStore, refreshOwnedReminders } from '../data/local/TimetableStateStore';
import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import { AppSettings, DEFAULT_SETTINGS, SettingsStore } from '../data/local/SettingsStore';
import { Course, Period } from '../domain/model/Course';
import { Locator } from '../app/di/ServiceLocator';
import { PeriodStore } from '../data/local/PeriodStore';
import { currentWeek, TOTAL_WEEKS } from '../common/util/TermCalendar';
import reminderAgentManager from '@ohos.reminderAgentManager';
import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import router from '@ohos.router';

const BUNDLE: string = 'com.fuxiaowai.timetable';
const DAY_MS: number = 86400000;

/** 上课提醒：按本周课程排后台提醒 */
@Entry
@Component
struct RemindPage {
  @StorageLink('dark') dark: boolean = false;
  @State s: AppSettings = DEFAULT_SETTINGS;
  @State status: string = '';
  @State busy: boolean = false;
  private ctx: common.UIAbilityContext | null = null;
  private options: number[] = [5, 10, 15, 30];

  aboutToAppear(): void {
    this.ctx = getContext(this) as common.UIAbilityContext;
    SettingsStore.load(this.ctx).then((v: AppSettings) => {
      this.s = v;
    });
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(26)
          .fontColor(TC(this.dark).text)
          .width(40)
          .onClick(() => router.back())
        Text('上课提醒')
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
            Text('开启上课提醒')
              .fontSize(15)
              .fontColor(TC(this.dark).text)
            Text('每节课开始前提醒一次')
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textHint)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.s.remindBefore > 0 })
            .selectedColor(Palette.primary)
            .onChange((v: boolean) => {
              this.s.remindBefore = v ? 15 : 0;
              this.persist();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        Divider().color(TC(this.dark).line).strokeWidth(0.5).margin({ left: 16 })

        Row() {
          Text('提前')
            .fontSize(15)
            .fontColor(TC(this.dark).text)
          Blank()
          Row({ space: 8 }) {
            ForEach(this.options, (m: number) => {
              Text(`${m} 分钟`)
                .fontSize(Font.body)
                .fontColor(this.s.remindBefore === m ? Color.White : TC(this.dark).textSub)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .backgroundColor(this.s.remindBefore === m ? Palette.primary : TC(this.dark).chip)
                .borderRadius(9)
                .onClick(() => {
                  this.s.remindBefore = m;
                  this.persist();
                })
            }, (m: number) => `m${m}`)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .opacity(this.s.remindBefore > 0 ? 1 : 0.4)
      }
      .backgroundColor(TC(this.dark).card)
      .borderRadius(16)
      .margin({ left: Metric.pagePadding, right: Metric.pagePadding })

      // 日程提醒：导出到系统日历的日程是否也带提前提醒
      Row() {
        Column() {
          Text('日程提醒')
            .fontSize(15)
            .fontColor(TC(this.dark).text)
          Text('导出到系统日历时，也带上提前提醒')
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textHint)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.s.calendarRemind })
          .selectedColor(Palette.primary)
          .onChange((v: boolean) => {
            this.s.calendarRemind = v;
            this.persist();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(TC(this.dark).card)
      .borderRadius(16)
      .margin({ left: Metric.pagePadding, right: Metric.pagePadding, top: 12 })

      Button(this.busy ? '正在排提醒…' : '按本周课表生成提醒')
        .width('100%')
        .height(46)
        .fontSize(Font.body)
        .fontColor(Color.White)
        .backgroundColor(Palette.primary)
        .enabled(!this.busy)
        .margin({ left: Metric.pagePadding, right: Metric.pagePadding, top: 16 })
        .onClick(() => {
          hilog.info(0x0000, 'Fuxiaowai', 'remind: click, before=%{public}d', this.s.remindBefore);
          this.scheduleWeek();
        })

      if (this.status.length > 0) {
        Text(this.status)
          .fontSize(Font.small)
          .fontColor(TC(this.dark).textSub)
          .width('100%')
          .padding({ left: 20, right: 20, top: 10 })
      }

      Text('提醒由系统代理发布，应用退到后台也能触发；换周或改上课时间后建议重新生成一次。')
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

  private persist(): void {
    if (this.ctx) {
      const ctx: common.UIAbilityContext = this.ctx;
      SettingsStore.save(ctx, this.s).then(async () => {
        await Locator.init(ctx);
        await TimetableStateStore.init(ctx);
        const courses: Course[] = await Locator.repo().listByWeek(TimetableStateStore.activeTableId(), currentWeek(TimetableStateStore.term().totalWeeks));
        await refreshOwnedReminders(ctx, courses, await PeriodStore.load(), this.s.remindBefore);
      }).catch((e: Error) => { this.status = e.message; });
    }
  }

  private async scheduleWeek(): Promise<void> {
    this.busy = true;
    this.status = '';
    if (this.s.remindBefore <= 0) {
      this.s.remindBefore = 15;
      this.persist();
    }
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await Locator.init(ctx);
      await TimetableStateStore.init(ctx);
      const week: number = currentWeek(TimetableStateStore.term().totalWeeks);
      const courses: Course[] = await Locator.repo().listByWeek(TimetableStateStore.activeTableId(), week);
      const periods: Period[] = await PeriodStore.load();
      this.status = await refreshOwnedReminders(ctx, courses, periods, this.s.remindBefore, true);
    } catch (e) {
      const msg: string = e instanceof Error ? e.message : JSON.stringify(e);
      if (msg.indexOf('1700002') >= 0 || msg.indexOf('exceeds the limit') >= 0) {
        this.status = '系统提醒服务返回配额限制：' + msg;
      } else {
        this.status = '生成失败：' + msg;
      }
    }
    this.busy = false;
  }

}
