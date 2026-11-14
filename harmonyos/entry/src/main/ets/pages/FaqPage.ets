import router from '@ohos.router';
import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import { LineIcon } from '../ui/components/LineIcon';

interface QA {
  q: string;
  a: string;
}

@Entry
@Component
struct FaqPage {
  @StorageLink('dark') dark: boolean = false;
  @State open: number = -1;

  private list: QA[] = [
    {
      q: '登录时提示「学号或密码不正确」怎么办？',
      a: '教务系统和教学综合平台是两套密码，可能不一样。在登录页下方切换圆形单选框，分别试一次：走教务入口用教务密码，走教学综合平台入口用统一身份认证密码。'
    },
    {
      q: '导入课表后一直是空的？',
      a: '多半是学期还没开始、课表没发布，或者当前学期选错了。到「我的 → 课表设置」确认学期，再重新导入一次。'
    },
    {
      q: '在校外连不上教务？',
      a: '教务只对校内网开放。校外请先连学校 VPN，或用「我的 → 网络检测」确认教务是否可达。'
    },
    {
      q: '为什么同一时间有两门课？',
      a: '课表会把时间重叠的课横向分成两列并排显示，不会互相遮挡。点开任意一块可以看周次、地点、教师，也可以只从本周移除。'
    },
    {
      q: '提醒是弹窗还是系统通知？',
      a: '「上课提醒」里可以选：软件内提醒（App 开着时在顶部弹条）或系统通知（App 没开也能收到）。导出到系统日历的日程，提醒由系统日历负责。'
    },
    {
      q: '分享口令发给别人，对方导入不了？',
      a: '口令需要先上传到福小外后台才能被他人使用。生成口令时如果显示「离线口令」，说明当时没连上服务器，换个网络重新生成即可。'
    },
    {
      q: '卸载重装会丢数据吗？',
      a: '会。课表、账号、头像、反馈都存在本机，卸载即清除。重要课表可以先「分享课表」生成口令留档。'
    }
  ];

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

      Text('常见问题')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(TC(this.dark).text)
        .margin({ left: 4 })
    }
    .width('100%')
    .height(52)
    .padding({ left: 8, right: 12 })
  }

  @Builder
  row(item: QA, i: number) {
    Column() {
      Row() {
        Text(item.q)
          .fontSize(14)
          .fontColor(TC(this.dark).text)
          .layoutWeight(1)
          .lineHeight(20)
        Text(this.open === i ? '−' : '+')
          .fontSize(16)
          .fontColor(this.open === i ? Palette.primary : TC(this.dark).textHint)
          .width(20)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .onClick(() => {
        this.open = this.open === i ? -1 : i;
      })

      if (this.open === i) {
        Text(item.a)
          .fontSize(Font.small)
          .fontColor(TC(this.dark).textSub)
          .lineHeight(20)
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 14 })
      }
    }
    .width('100%')
  }

  build() {
    Column() {
      this.headerBar()

      Scroll() {
        Column() {
          Column() {
            ForEach(this.list, (item: QA, i: number) => {
              this.row(item, i)
              if (i < this.list.length - 1) {
                Divider()
                  .color(TC(this.dark).line)
                  .margin({ left: 16, right: 16 })
              }
            }, (item: QA) => item.q)
          }
          .width('100%')
          .backgroundColor(TC(this.dark).card)
          .borderRadius(Metric.cardRadius)
          .clip(true)

          Row() {
            LineIcon({ name: 'help', iconSize: 15, tone: 'sub' })
            Text('没找到答案？到「我的 → 反馈问题」写给我们，也可以附截图。')
              .fontSize(10)
              .fontColor(TC(this.dark).textHint)
              .lineHeight(16)
              .layoutWeight(1)
              .margin({ left: 6 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .padding({ left: 4, right: 4, top: 14, bottom: 24 })
        }
        .width('100%')
        .padding({ left: 14, right: 14 })
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