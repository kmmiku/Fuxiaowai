import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import {
  AppSettings, CELL_MAX, CELL_MIN, DEFAULT_SETTINGS, SettingsStore
} from '../data/local/SettingsStore';
import { Course, Period } from '../domain/model/Course';
import { PeriodStore } from '../data/local/PeriodStore';
import { Locator } from '../app/di/ServiceLocator';
import { currentWeek, TOTAL_WEEKS } from '../common/util/TermCalendar';
import { TimetableGrid } from '../ui/components/TimetableGrid';
import common from '@ohos.app.ability.common';
import router from '@ohos.router';

/**
 * 课表设置：格子高度与块宽度都用无极滑块调，拖动时面板变透、背后课表实时跟着变，
 * 松手（或点击轨道）立刻落盘。
 */
@Entry
@Component
struct TimetableSettings {
  @StorageLink('dark') dark: boolean = false;
  @State s: AppSettings = DEFAULT_SETTINGS;
  /** 预览用的真实课表数据 */
  @State courses: Course[] = [];
  @State periods: Period[] = [];
  @State week: number = 1;
  /** 是否正在拖动滑块（拖动时背景课表变清晰、面板变半透明） */
  @State dragging: boolean = false;
  /** 拖动过程中的临时值，松手才写进设置 */
  @State liveCell: number = 52;
  private ctx: common.UIAbilityContext | null = null;

  aboutToAppear(): void {
    this.ctx = getContext(this) as common.UIAbilityContext;
    this.week = currentWeek(TOTAL_WEEKS);
    PeriodStore.init(this.ctx);
    SettingsStore.load(this.ctx).then((v: AppSettings) => {
      this.s = v;
      this.liveCell = v.cellHeight;
    });
    this.loadCourses();
  }

  private async loadCourses(): Promise<void> {
    try {
      const tables = await Locator.repo().tables();
      if (tables.length > 0) {
        this.courses = await Locator.repo().listAll(tables[0].id);
      }
      this.periods = await PeriodStore.load();
    } catch (e) {
      this.courses = [];
    }
  }

  private persist(): void {
    if (this.ctx) {
      SettingsStore.save(this.ctx, this.s);
    }
  }

  private snap(v: number): number {
    return Math.round(v);
  }

  /** 拖动中 / 松手共用的处理 */
  private onCellChange(v: number, mode: SliderChangeMode): void {
    this.liveCell = this.snap(v);
    if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
      this.s.cellHeight = this.liveCell;
      this.dragging = false;
      this.persist();
    } else {
      this.dragging = true;
    }
  }


  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // ── 底层：真实课表，拖动时变清晰，松手回到淡淡一层 ──
      Column() {
        if (this.periods.length > 0) {
          TimetableGrid({
            courses: this.courses,
            week: this.week,
            showWeekend: true,
            periods: this.periods,
            cellHeight: this.liveCell,
            dark: this.dark,
            onCourseTap: (c: Course) => {}
          })
        }
      }
      .width('100%')
      .height(this.liveCell * 12 + 16)
      .padding({ left: 6, right: 6 })
      .margin({ top: 56 })
      .opacity(this.dragging ? 1 : 0.5)
      .animation({ duration: 160, curve: Curve.EaseOut })

      // ── 上层：设置面板，拖动时半透明 ──
      Column() {
        Row() {
          Text('‹')
            .fontSize(26)
            .fontColor(TC(this.dark).text)
            .width(40)
            .onClick(() => router.back())
          Text('课表设置')
            .fontSize(Font.title)
            .fontWeight(FontWeight.Bold)
            .fontColor(TC(this.dark).text)
          Blank()
          if (this.dragging) {
            Text('实时预览')
              .fontSize(Font.small)
              .fontColor(Palette.primary)
          }
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: Metric.pagePadding })

        Column() {
          this.switchRow('显示非本周课表', '其他周有课、本周不上，浅色显示', this.s.showGhost, (v: boolean) => {
            this.s.showGhost = v;
            this.persist();
          })
        }
        .backgroundColor(TC(this.dark).card)
        .borderRadius(16)
        .margin({ left: Metric.pagePadding, right: Metric.pagePadding })

        Column() {
          // 格子高度
          Row() {
            Text('课表格子高度')
              .fontSize(15)
              .fontColor(TC(this.dark).text)
            Blank()
            Text(`${this.liveCell} vp`)
              .fontSize(Font.body)
              .fontWeight(FontWeight.Medium)
              .fontColor(Palette.primary)
          }
          .width('100%')

          Slider({
            value: this.liveCell,
            min: CELL_MIN,
            max: CELL_MAX,
            step: 1,
            style: SliderStyle.OutSet
          })
            .width('100%')
            .blockColor(Color.White)
            .trackColor(TC(this.dark).chip)
            .selectedColor(Palette.primary)
            .margin({ top: 6 })
            .onChange((v: number, mode: SliderChangeMode) => this.onCellChange(v, mode))

          Row() {
            Text(`${CELL_MIN}`)
              .fontSize(Font.tiny)
              .fontColor(TC(this.dark).textHint)
            Blank()
            Text('一行能看到的课更少 / 更多')
              .fontSize(Font.tiny)
              .fontColor(TC(this.dark).textHint)
            Blank()
            Text(`${CELL_MAX}`)
              .fontSize(Font.tiny)
              .fontColor(TC(this.dark).textHint)
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 16 })
        .backgroundColor(TC(this.dark).card)
        .borderRadius(16)
        .margin({ left: Metric.pagePadding, right: Metric.pagePadding, top: 12 })

        Blank()

        Text('拖动滑块时，背后的课表会实时变化；松手自动保存')
          .fontSize(Font.small)
          .fontColor(TC(this.dark).textHint)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ bottom: 18 })
      }
      .width('100%')
      .height('100%')
      .opacity(this.dragging ? 0.45 : 0.94)
      .animation({ duration: 160, curve: Curve.EaseOut })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
  }

  @Builder
  switchRow(title: string, desc: string, value: boolean, onChange: (v: boolean) => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor(TC(this.dark).text)
        Text(desc)
          .fontSize(Font.small)
          .fontColor(TC(this.dark).textHint)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor(Palette.primary)
        .onChange((v: boolean) => onChange(v))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }
}