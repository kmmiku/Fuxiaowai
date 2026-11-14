import { Font, Metric, Palette, TC } from '../../common/design/Tokens';

/** 星期条：11月 / 一~日 / 日号，今天高亮 */
@Component
export struct WeekBar {
  @Prop dates: string[] = [];      // 日号，如 '10'
  @Prop todayIndex: number = 0;    // 0-based（周一=0）
  @Prop showWeekend: boolean = true;
  @Prop month: string = '11月';
  @Prop dark: boolean = false;

  private dayNames: string[] = ['一', '二', '三', '四', '五', '六', '日'];

  build() {
    Row() {
      Text(this.month)
        .fontSize(Font.small)
        .fontColor(TC(this.dark).textHint)
        .width(Metric.timeColWidth)
        .textAlign(TextAlign.Center)

      ForEach(this.dayNames.slice(0, this.showWeekend ? 7 : 5), (d: string, i: number) => {
        Column() {
          Text(d)
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textSub)

          Text(this.dates[i] ?? '')
            .fontSize(Font.body)
            .fontWeight(i === this.todayIndex ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(i === this.todayIndex ? Color.White : TC(this.dark).text)
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .width(30)
            .height(30)
            .borderRadius(10)
            .backgroundColor(i === this.todayIndex ? (this.dark ? Palette.primary : Palette.todayMark) : Color.Transparent)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }, (d: string, i: number) => d + i)
    }
    .width('100%')
    .height(64)
    .padding({ left: Metric.pagePadding, right: Metric.pagePadding })
  }
}