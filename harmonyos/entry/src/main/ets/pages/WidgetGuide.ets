import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import router from '@ohos.router';

/** 桌面小组件说明（FormKit 实现排在下一阶段） */
@Entry
@Component
struct WidgetGuide {
  @StorageLink('dark') dark: boolean = false;
  private steps: string[][] = [
    ['①', '长按桌面空白处', '进入桌面编辑态'],
    ['②', '点左上角「服务卡片」', '或长按应用图标选卡片'],
    ['③', '找到「福小外」', '选 2×4 今日课程卡片'],
    ['④', '拖到桌面', '自动显示今天的课']
  ];

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(26)
          .fontColor(TC(this.dark).text)
          .width(40)
          .onClick(() => router.back())
        Text('桌面小组件')
          .fontSize(Font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(TC(this.dark).text)
        Blank()
      }
      .width('100%')
      .height(60)
      .padding({ left: 8, right: Metric.pagePadding })

      // 卡片预览
      Column() {
        Row() {
          Text('今天 · 周一')
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textSub)
          Blank()
          Text('第11周')
            .fontSize(Font.tiny)
            .fontColor(TC(this.dark).textHint)
        }
        .width('100%')

        Row({ space: 8 }) {
          Column() {
            Text('08:25')
              .fontSize(Font.tiny)
              .fontColor(TC(this.dark).textHint)
          }
          .width(40)
          .alignItems(HorizontalAlign.Start)

          Column() {
            Text('高级数据库技术')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(TC(this.dark).text)
            Text('教4203 · 梁艳')
              .fontSize(Font.tiny)
              .fontColor(TC(this.dark).textSub)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .padding({ left: 8, top: 6, bottom: 6 })
          .backgroundColor('#EDEBFD')
          .borderRadius(8)
        }
        .width('100%')
        .margin({ top: 8 })

        Row({ space: 8 }) {
          Text('10:15')
            .fontSize(Font.tiny)
            .fontColor(TC(this.dark).textHint)
            .width(40)
          Text('高性能系统架构')
            .fontSize(13)
            .fontColor(TC(this.dark).text)
            .layoutWeight(1)
            .padding({ left: 8, top: 6, bottom: 6 })
            .backgroundColor('#FDF0E3')
            .borderRadius(8)
        }
        .width('100%')
        .margin({ top: 6 })
      }
      .width('100%')
      .padding(14)
      .backgroundColor(TC(this.dark).card)
      .borderRadius(18)
      .margin({ left: Metric.pagePadding, right: Metric.pagePadding })

      Text('卡片效果预览')
        .fontSize(Font.tiny)
        .fontColor(TC(this.dark).textHint)
        .width('100%')
        .padding({ left: 20, top: 8 })

      Column() {
        ForEach(this.steps, (s: string[], i: number) => {
          Row() {
            Text(s[0])
              .fontSize(15)
              .fontColor(Palette.primary)
              .width(28)
            Column() {
              Text(s[1])
                .fontSize(15)
                .fontColor(TC(this.dark).text)
              Text(s[2])
                .fontSize(Font.small)
                .fontColor(TC(this.dark).textHint)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          if (i < this.steps.length - 1) {
            Divider().color(TC(this.dark).line).strokeWidth(0.5).margin({ left: 44 })
          }
        }, (s: string[]) => s[0])
      }
      .backgroundColor(TC(this.dark).card)
      .borderRadius(16)
      .margin({ left: Metric.pagePadding, right: Metric.pagePadding, top: 12 })

      Text('卡片数据来自本机课表，每 30 分钟自动刷新一次，每天 06:10 另外更新一次；当天没有课时会显示「今天没有课」。')
        .fontSize(Font.small)
        .fontColor(TC(this.dark).textHint)
        .lineHeight(19)
        .padding({ left: 20, right: 20, top: 14 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
  }
}