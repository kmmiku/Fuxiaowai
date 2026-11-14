import router from '@ohos.router';
import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import { LineIcon } from '../ui/components/LineIcon';

interface MoreRow {
  key: string;
  title: string;
  desc: string;
  icon: string;
}

@Entry
@Component
struct MorePage {
  @StorageLink('dark') dark: boolean = false;
  @State pressKey: string = '';

  private rows: MoreRow[] = [
    { key: 'collect', title: '个人信息收集清单', desc: '收集了什么、用在哪里', icon: 'grid' },
    { key: 'share', title: '第三方信息共享清单', desc: '与谁交换了数据', icon: 'wifi' },
    { key: 'export', title: '个人信息导出', desc: '把数据复制成 JSON', icon: 'info' },
    { key: 'permission', title: '权限中心', desc: '申请了哪些系统权限', icon: 'lock' },
    { key: 'revoke', title: '隐私协议撤回', desc: '清除本机全部个人数据', icon: 'trash' }
  ];

  private rowBg(key: string): ResourceColor {
    if (this.pressKey !== key) {
      return Color.Transparent;
    }
    return this.dark ? '#262B36' : '#F1F4FD';
  }

  @Builder
  headerBar() {
    Row() {
      Row() {
        Text('‹')
          .fontSize(26)
          .fontColor(TC(this.dark).text)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .onClick(() => {
        router.back();
      })

      Text('更多')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(TC(this.dark).text)
        .margin({ left: 4 })
    }
    .width('100%')
    .height(52)
    .padding({ left: 8, right: 12 })
  }

  build() {
    Column() {
      this.headerBar()

      Scroll() {
        Column() {
          Column() {
            ForEach(this.rows, (r: MoreRow, i: number) => {
              Row() {
                Row() {
                  LineIcon({ name: r.icon, iconSize: 17, tone: 'sub' })
                }
                .width(32)
                .height(32)
                .borderRadius(16)
                .backgroundColor(TC(this.dark).chip)
                .justifyContent(FlexAlign.Center)

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
                router.pushUrl({ url: 'pages/PrivacyDocPage', params: { kind: r.key } });
              })

              if (i < this.rows.length - 1) {
                Divider()
                  .color(TC(this.dark).line)
                  .margin({ left: 58 })
              }
            }, (r: MoreRow) => r.key)
          }
          .width('100%')
          .backgroundColor(TC(this.dark).card)
          .borderRadius(Metric.cardRadius)
          .clip(true)

          Text('这些内容只描述本机数据的处理方式，不涉及任何云端账号。')
            .fontSize(10)
            .fontColor(TC(this.dark).textHint)
            .lineHeight(16)
            .width('100%')
            .padding({ left: 4, right: 4, top: 14, bottom: 24 })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 12 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
  }
}