import { Font, Palette, TC } from '../../common/design/Tokens';

interface FuncItem {
  key: string;
  glyph: string;
  label: string;
}

/**
 * 功能宫格：4×2
 * 图标用单字 + 圆底，避免几何符号被系统字体渲染成彩色 emoji
 */
@Component
export struct FunctionGrid {
  @Prop dark: boolean = false;
  onItem: (key: string) => void = () => {
  };

  private items: FuncItem[] = [
    { key: 'period', glyph: '时', label: '上课时间' },
    { key: 'table', glyph: '表', label: '课表设置' },
    { key: 'remind', glyph: '铃', label: '上课提醒' },
    { key: 'widget', glyph: '件', label: '小组件' }
  ];

  build() {
    Grid() {
      ForEach(this.items, (it: FuncItem) => {
        GridItem() {
          Column() {
            Text(it.glyph)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Palette.primary)
              .textAlign(TextAlign.Center)
              .width(30)
              .height(30)
              .borderRadius(15)
              .backgroundColor(this.dark ? '#262A33' : '#EEF1FB')
            Text(it.label)
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textSub)
              .margin({ top: 6 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .borderRadius(14)
          .onClick(() => this.onItem(it.key))
        }
      }, (it: FuncItem) => it.key)
    }
    .columnsTemplate('1fr 1fr 1fr 1fr')
    .rowsTemplate('1fr')
    .width('100%')
    .height(84)
    .padding({ left: 6, right: 6, top: 10, bottom: 10 })
    .borderRadius(20)
    .backgroundColor(TC(this.dark).card)
  }
}