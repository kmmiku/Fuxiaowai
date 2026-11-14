import { Font, Metric, Palette, TC } from '../../common/design/Tokens';

/**
 * 卡片A 上半：周数滑块 + "分享当前课表"
 * 对应截图黄圈区域的上半部分
 */
@Component
export struct WeekSlider {
  @Link week: number;
  @Prop totalWeeks: number = 20;
  @Prop dark: boolean = false;
  onShare: () => void = () => {
  };

  build() {
    Column() {
      Row() {
        Text('周数')
          .fontSize(Font.section)
          .fontWeight(FontWeight.Medium)
          .fontColor(TC(this.dark).text)
        Blank()
        Text('分享当前课表')
          .fontSize(Font.body)
          .fontColor(Palette.primary)
          .onClick(() => this.onShare())
      }
      .width('100%')

      Row() {
        Slider({
          value: this.week,
          min: 1,
          max: this.totalWeeks,
          step: 1,
          style: SliderStyle.OutSet
        })
          .layoutWeight(1)
          .selectedColor(Palette.primary)
          .trackColor(this.dark ? '#33363E' : '#E8EBF2')
          .trackThickness(6)
          .onChange((value: number) => {
            this.week = Math.round(value);
          })

        Text(`第${this.week}周`)
          .fontSize(Font.body)
          .fontColor(TC(this.dark).text)
          .width(56)
          .textAlign(TextAlign.Center)
          .backgroundColor(TC(this.dark).chip)
          .borderRadius(10)
          .padding({ top: 4, bottom: 4 })
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(16)
    .borderRadius(Metric.cardRadius)
    .backgroundColor(TC(this.dark).card)
  }
}