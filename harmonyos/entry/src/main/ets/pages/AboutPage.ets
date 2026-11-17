import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import router from '@ohos.router';

/** 关于与反馈 */
@Entry
@Component
struct AboutPage {
  @StorageLink('dark') dark: boolean = false;
  private rows: string[][] = [
    ['版本', 'v0.1.1'],
    ['服务院校', '福州外语外贸学院'],
    ['数据来源', '正方教务系统 jwglxt'],
    ['课表范围', '2026—2027 学年 第 1 学期'],
    ['网络', '仅在校验账号时访问教务系统'],
    ['收集信息', '本机保存；分享、反馈及登录统计按声明处理']
  ];

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(26)
          .fontColor(TC(this.dark).text)
          .width(40)
          .onClick(() => router.back())
        Text('关于与反馈')
          .fontSize(Font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(TC(this.dark).text)
        Blank()
      }
      .width('100%')
      .height(60)
      .padding({ left: 8, right: Metric.pagePadding })

      Column({ space: 6 }) {
        Text('福小外')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(TC(this.dark).text)
        Text('看得清的课表，记得住的一周')
          .fontSize(Font.body)
          .fontColor(TC(this.dark).textSub)
      }
      .width('100%')
      .padding({ left: 20, top: 8, bottom: 20 })
      .alignItems(HorizontalAlign.Start)

      Column() {
        ForEach(this.rows, (r: string[], i: number) => {
          Row() {
            Text(r[0])
              .fontSize(15)
              .fontColor(TC(this.dark).text)
            Blank()
            Text(r[1])
              .fontSize(Font.body)
              .fontColor(TC(this.dark).textSub)
              .layoutWeight(1)
              .textAlign(TextAlign.End)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 13, bottom: 13 })
          if (i < this.rows.length - 1) {
            Divider().color(TC(this.dark).line).strokeWidth(0.5).margin({ left: 16 })
          }
        }, (r: string[]) => r[0])
      }
      .backgroundColor(TC(this.dark).card)
      .borderRadius(16)
      .margin({ left: Metric.pagePadding, right: Metric.pagePadding })

      Column({ space: 10 }) {
        Text('反馈')
          .fontSize(Font.body)
          .fontColor(TC(this.dark).text)
        Text('遇到课表不对、导入失败，或想加功能，用应用内「意见反馈」提交，写明「学号 + 现象 + 截图」，会在两个工作日内回复。')
          .fontSize(Font.small)
          .fontColor(TC(this.dark).textSub)
          .lineHeight(19)
        Text('fuxiaowai.xyz')
          .fontSize(Font.body)
          .fontColor(Palette.primary)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(16)
      .backgroundColor(TC(this.dark).card)
      .borderRadius(16)
      .margin({ left: Metric.pagePadding, right: Metric.pagePadding, top: 12 })

      Blank()

      Text('本应用与学校官方无关，课表数据来自你自己登录后的教务系统。')
        .fontSize(Font.tiny)
        .fontColor(TC(this.dark).textHint)
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ left: 24, right: 24, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
  }
}
