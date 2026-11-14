import { Font, TC } from '../../common/design/Tokens';
import { LineIcon } from './LineIcon';

interface MenuItem {
  key: string;
  title: string;
  icon: string;
}

/** 三点菜单下卡片：四列两行，导航与状态操作由 Index 承担。 */
@Component
export struct MenuSheet {
  @Prop dark: boolean = false;
  onSelect: (key: string) => void = () => {};
  @State pressedKey: string = '';

  private items: MenuItem[] = [
    { key: 'period', title: '上课时间', icon: 'clock' },
    { key: 'table', title: '课表设置', icon: 'sliders' },
    { key: 'remind', title: '上课提醒', icon: 'bell' },
    { key: 'widget', title: '小组件', icon: 'phone' },
    { key: 'contact', title: '联系我们', icon: 'mail' },
    { key: 'theme', title: '主题设置', icon: 'shirt' },
    { key: 'dark', title: '夜间模式', icon: 'moon' },
    { key: 'update', title: '检查更新', icon: 'download' }
  ];

  build() {
    Grid() {
      ForEach(this.items, (it: MenuItem) => {
        GridItem() {
          Column({ space: 8 }) {
            Stack({ alignContent: Alignment.Center }) {
              LineIcon({ name: it.icon, iconSize: 21, tone: 'text', strokeW: 1.6 })
            }
            .width(36)
            .height(36)
            .borderRadius(18)
            .backgroundColor(TC(this.dark).chip)
            Text(it.title)
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textSub)
              .maxLines(1)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .borderRadius(16)
          .scale({ x: this.pressedKey === it.key ? 0.92 : 1, y: this.pressedKey === it.key ? 0.92 : 1 })
          .animation({ duration: 180, curve: Curve.EaseOut })
          .onTouch((e: TouchEvent) => {
            if (e.type === TouchType.Down) { this.pressedKey = it.key; }
            if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressedKey = ''; }
          })
          .onClick(() => this.onSelect(it.key))
          .accessibilityText(it.title)
        }
      }, (it: MenuItem) => it.key)
    }
    .columnsTemplate('1fr 1fr 1fr 1fr')
    .rowsTemplate('1fr 1fr')
    .width('100%')
    .height(164)
    .padding({ left: 8, right: 8, top: 8, bottom: 8 })
    .linearGradient({ angle: 110, colors: [
      [this.dark ? TC(true).card : '#F9FCF9', 0],
      [this.dark ? TC(true).card : '#FFF7F8', 0.5],
      [this.dark ? TC(true).card : '#F1F1FF', 1]
    ] })
    .borderRadius(24)
    .clip(true)
  }
}
