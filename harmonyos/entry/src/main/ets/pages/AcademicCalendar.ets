import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import display from '@ohos.display';
import hilog from '@ohos.hilog';
import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import { BottomTabs } from '../ui/components/BottomTabs';
import {
  CAL_TERMS, CalEvent, CalMonth, CalTerm,
  eventOfDay, eventsOfMonth, isToday, kindColor, monthRows, termIndexOfToday, weekOfTerm
} from '../common/util/SchoolCalendar';

const WEEK_HEAD: string[] = ['日', '一', '二', '三', '四', '五', '六'];
/** 今日圈圈的颜色，红圈是用户点名要的 */
const TODAY_COLOR: string = '#E5484D';

/**
 * 校历页：自绘日历（不再加载教务处图片）。
 *
 * 数据来自 `common/util/SchoolCalendar.ets`（人工解析自 2026-2027 学年校历图），
 * 逐月渲染，今天用红色圆圈圈出来，放假/考试日下方有一个彩色圆点，卡片底部列出当月安排。
 */
@Entry
@Component
struct AcademicCalendar {
  @StorageLink('dark') dark: boolean = false;
  /** 0 = 第一学期，1 = 第二学期 */
  @State tab: number = 0;
  /** 学期切换器的实测宽度（px），用于算滑块位置 */
  @State segW: number = 0;

  /** 校历滚动：进页面后从顶部平滑滑到当前月份并居中 */
  private calScroller: Scroller = new Scroller();
  private monthH: Map<string, number> = new Map<string, number>();
  private autoScrolled: boolean = false;

  aboutToAppear(): void {
    const i: number = termIndexOfToday();
    this.tab = i >= 0 ? i : 0;
    // 等首帧布局完成、各月份卡片量出真实高度后再滑
    setTimeout(() => {
      this.scrollToCurrentMonth();
    }, 520);
  }

  /** 当前月卡片滑到可视区垂直居中；Curve.FastOutSlowIn 是先快后慢的减速曲线 */
  private scrollToCurrentMonth(): void {
    if (this.autoScrolled) {
      return;
    }
    const term: CalTerm = this.cur();
    const now: Date = new Date();
    let idx: number = -1;
    for (let i = 0; i < term.months.length; i++) {
      const m: CalMonth = term.months[i];
      if (m.year === now.getFullYear() && m.month === now.getMonth() + 1) {
        idx = i;
        break;
      }
    }
    if (idx < 0) {
      return;
    }
    let y: number = 0;
    for (let i = 0; i < idx; i++) {
      const m: CalMonth = term.months[i];
      y += (this.monthH.get(`${m.year}-${m.month}`) ?? 340) + Metric.gap;
    }
    const target: CalMonth = term.months[idx];
    const cardH: number = this.monthH.get(`${target.year}-${target.month}`) ?? 340;
    // 可视区高度：整屏减去头部、学期切换、周提示与底部 Tab
    const viewH: number = px2vp(display.getDefaultDisplaySync().height) - 300;
    const offset: number = Math.max(0, y + cardH / 2 - viewH / 2);
    this.autoScrolled = true;
    hilog.info(0x0022, 'FuxiaoCal', 'auto scroll to month y=%{public}s offset=%{public}s cardH=%{public}s',
      `${y}`, `${offset}`, `${cardH}`);
    this.calScroller.scrollTo({
      xOffset: 0,
      yOffset: offset,
      animation: { duration: 1500, curve: Curve.FastOutSlowIn }
    });
  }

  private cur(): CalTerm {
    return CAL_TERMS[this.tab];
  }

  /** 今天是本学期第几周，0 表示不在学期内 */
  private weekNow(): number {
    return weekOfTerm(this.cur(), new Date());
  }

  private openInBrowser(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    ctx.startAbility({
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: 'https://www.fzfu.com/jwc/info/1084/5556.htm'
    }).catch(() => {
      this.toast('没有可用的浏览器');
    });
  }

  private toast(msg: string): void {
    try {
      promptAction.showToast({ message: msg, duration: 2000 });
    } catch (e) {
      console.info(`Fuxiaowai: calendar toast ${msg}`);
    }
  }

  /** 日期文字颜色：今天红、周末浅、其余正常 */
  private dayColor(y: number, m: number, d: number): string {
    if (isToday(y, m, d)) {
      return TODAY_COLOR;
    }
    const wd: number = new Date(y, m - 1, d).getDay();
    return wd === 0 || wd === 6 ? TC(this.dark).textHint : TC(this.dark).text;
  }

  /** 这一天的圆点颜色，空串表示没有安排 */
  private dotColor(m: number, d: number): string {
    const e: CalEvent | null = eventOfDay(this.cur(), m, d);
    return e === null ? '' : kindColor(e.kind);
  }

  @Builder
  header() {
    Row() {
      Text('校历')
        .fontSize(Font.title)
        .fontWeight(FontWeight.Bold)
        .fontColor(TC(this.dark).text)
        .layoutWeight(1)

      Text('原文')
        .fontSize(Font.small)
        .fontColor(Palette.primary)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .onClick(() => this.openInBrowser())
    }
    .width('100%')
    .height(56)
    .padding({ left: Metric.pagePadding, right: Metric.pagePadding })
  }

  @Builder
  termTabs() {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width(this.segW > 0 ? this.segW / 2 - 8 : '50%')
        .height(34)
        .borderRadius(10)
        .backgroundColor(Palette.primary)
        .translate({ x: this.segW > 0 ? this.tab * (this.segW / 2) + 4 : 0, y: 0 })
        .animation({ duration: 220, curve: Curve.FastOutSlowIn })

      Row() {
        ForEach(CAL_TERMS, (t: CalTerm, i: number) => {
          Text(t.label)
            .fontSize(16)
            .fontWeight(this.tab === i ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.tab === i ? Color.White : TC(this.dark).textSub)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(42)
            .onClick(() => {
              this.tab = i;
            })
        }, (t: CalTerm) => t.key)
      }
      .width('100%')
    }
    .width('100%')
    .height(42)
    .backgroundColor(TC(this.dark).chip)
    .borderRadius(14)
    .margin({ left: Metric.pagePadding, right: Metric.pagePadding })
    .onAreaChange((_o: Area, n: Area) => {
      this.segW = Number(n.width);
    })
  }

  @Builder
  weekHint() {
    Row({ space: 6 }) {
      Text(this.weekNow() > 0 ? `第 ${this.weekNow()} 周` : '不在学期内')
        .fontSize(Font.small)
        .fontWeight(FontWeight.Medium)
        .fontColor(Palette.primary)
      Text(`· 共 ${this.cur().weeks} 周`)
        .fontSize(Font.small)
        .fontColor(TC(this.dark).textHint)
      Blank()
      Text('红圈 = 今天')
        .fontSize(Font.tiny)
        .fontColor(TC(this.dark).textHint)
    }
    .width('100%')
    .padding({ left: Metric.pagePadding + 4, right: Metric.pagePadding + 4, top: 10, bottom: 2 })
  }

  @Builder
  dayCell(y: number, m: number, d: number) {
    Stack({ alignContent: Alignment.Center }) {
      if (d > 0) {
        Text(d > 0 ? `${d}` : '')
          .fontSize(16)
          .fontWeight(isToday(y, m, d) ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.dayColor(y, m, d))
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .borderRadius(14)
          .borderWidth(isToday(y, m, d) ? 2 : 0)
          .borderColor(TODAY_COLOR)

        Row()
          .width(4)
          .height(4)
          .borderRadius(2)
          .backgroundColor(this.dotColor(m, d).length > 0 ? this.dotColor(m, d) : Color.Transparent)
          .translate({ y: 17 })
      }
    }
    .layoutWeight(1)
    .height(46)
  }

  @Builder
  monthCard(cm: CalMonth) {
    Column() {
      Row() {
        Text(`${cm.year} 年 ${cm.month} 月`)
          .fontSize(Font.section)
          .fontWeight(FontWeight.Medium)
          .fontColor(TC(this.dark).text)
          .layoutWeight(1)
      }
      .width('100%')
      .margin({ bottom: 6 })

      Row() {
        ForEach(WEEK_HEAD, (w: string, i: number) => {
          Text(w)
            .fontSize(12)
            .fontColor(i === 0 || i === 6 ? TC(this.dark).textHint : TC(this.dark).textSub)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(42)
        }, (w: string) => w)
      }
      .width('100%')

      Divider()
        .color(this.dark ? '#414654' : '#DDE1EB')
        .strokeWidth(0.5)

      ForEach(monthRows(cm.year, cm.month), (row: number[], ri: number) => {
        if (ri > 0) {
          Divider()
            .color(this.dark ? '#414654' : '#DDE1EB')
            .strokeWidth(0.5)
        }
        Row() {
          ForEach(row, (d: number, ci: number) => {
            this.dayCell(cm.year, cm.month, d)
          }, (d: number, ci: number) => `${cm.month}-${ri}-${ci}-${d}`)
        }
        .width('100%')
      }, (row: number[], ri: number) => `${cm.year}-${cm.month}-${ri}`)

      if (eventsOfMonth(this.cur(), cm.year, cm.month).length > 0) {
        Divider()
          .color(TC(this.dark).line)
          .strokeWidth(0.5)
          .margin({ top: 6, bottom: 6 })

        Column({ space: 5 }) {
          ForEach(eventsOfMonth(this.cur(), cm.year, cm.month), (e: CalEvent) => {
            Row({ space: 7 }) {
              Row()
                .width(6)
                .height(6)
                .borderRadius(3)
                .backgroundColor(kindColor(e.kind))
              Text(`${e.month} 月 ${e.day} 日`)
                .fontSize(Font.tiny)
                .fontColor(TC(this.dark).textSub)
                .width(64)
              Text(e.title)
                .fontSize(Font.small)
                .fontColor(TC(this.dark).text)
                .layoutWeight(1)
            }
            .width('100%')
          }, (e: CalEvent) => `${e.month}-${e.day}-${e.title}`)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(12)
    .margin({ left: Metric.pagePadding, right: Metric.pagePadding, top: 12 })
    .backgroundColor(TC(this.dark).card)
    .borderRadius(Metric.cardRadius)
    .alignItems(HorizontalAlign.Start)
    .onAreaChange((oldA: Area, newA: Area) => {
      // 记下每个月的真实高度，进页面后据此算出「当前月居中」的滚动位置
      this.monthH.set(`${cm.year}-${cm.month}`, Number(newA.height));
    })
  }

  @Builder
  summaryCard() {
    Column({ space: 6 }) {
      Text('学期安排')
        .fontSize(Font.section)
        .fontWeight(FontWeight.Medium)
        .fontColor(TC(this.dark).text)
        .width('100%')
        .margin({ bottom: 2 })

      ForEach(this.cur().summary, (line: string) => {
        Text(line)
          .fontSize(Font.small)
          .fontColor(TC(this.dark).textSub)
          .lineHeight(20)
          .width('100%')
      }, (line: string) => line)
    }
    .width('100%')
    .padding(14)
    .margin({ left: Metric.pagePadding, right: Metric.pagePadding, top: 12, bottom: 8 })
    .backgroundColor(TC(this.dark).card)
    .borderRadius(Metric.cardRadius)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      this.header()
      this.termTabs()
      this.weekHint()

      Scroll(this.calScroller) {
        Column() {
          ForEach(this.cur().months, (cm: CalMonth) => {
            this.monthCard(cm)
          }, (cm: CalMonth) => `${cm.year}-${cm.month}`)

          this.summaryCard()
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      Text('来源：福州外语外贸学院教务处 · 2026-2027 学年校历')
        .fontSize(Font.tiny)
        .fontColor(TC(this.dark).textHint)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ left: Metric.pagePadding, right: Metric.pagePadding, top: 6, bottom: 14 })

      BottomTabs({ current: 0, dark: this.dark })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
  }
}

