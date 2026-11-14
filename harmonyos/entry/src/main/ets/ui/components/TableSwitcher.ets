import { Font, Palette, TC } from '../../common/design/Tokens';
import { LineIcon } from './LineIcon';

export interface TableOption {
  id: string;
  name: string;
}

/**
 * "切换课表"横向卡片：我的课表 / 新建 / 管理
 * 交互：
 *  - 点方块切换，选中方块深色填充 + 轻微放大（240ms 过渡）
 *  - 点「管理课表」进入管理态，可删方块；再点「完成」退出
 *  - 长按方块重命名
 */
@Component
export struct TableSwitcher {
  @Prop tables: TableOption[] = [];
  @Prop dark: boolean = false;
  @Link activeId: string;
  onSwitch: (id: string) => void = () => {
  };
  onCreate: () => void = () => {
  };
  onDelete: (t: TableOption) => void = () => {
  };
  onRename: (t: TableOption) => void = () => {
  };

  @State managing: boolean = false;

  private isSel(id: string): boolean {
    return id === this.activeId;
  }

  private cardBg(id: string): ResourceColor {
    if (this.isSel(id)) {
      return this.dark ? '#3A3F49' : '#2B2F36';
    }
    return TC(this.dark).chip;
  }

  @Builder
  card(t: TableOption) {
    Stack() {
      Column() {
        if (this.isSel(t.id)) {
          LineIcon({ name: 'check', iconSize: 27, tone: 'white', strokeW: 2.2 })
            .margin({ bottom: 6 })
        }
        Text(t.name)
          .fontSize(Font.small)
          .fontColor(this.isSel(t.id) ? Color.White : TC(this.dark).textSub)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .padding({ left: 6, right: 6 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .borderRadius(16)
      .backgroundColor(this.cardBg(t.id))
      .scale({ x: this.isSel(t.id) ? 1 : 0.95, y: this.isSel(t.id) ? 1 : 0.95 })
      .animation({ duration: 240, curve: Curve.FastOutSlowIn })
      .onClick(() => {
        this.activeId = t.id;
        this.onSwitch(t.id);
      })
      .gesture(
        LongPressGesture({ repeat: false, duration: 420 })
          .onAction(() => {
            this.onRename(t);
          })
      )

      if (this.managing && this.tables.length > 1) {
        Text('×')
          .fontSize(13)
          .fontColor(Color.White)
          .width(22)
          .height(22)
          .textAlign(TextAlign.Center)
          .backgroundColor('#E5484D')
          .borderRadius(11)
          .position({ x: 47, y: 1 })
          .onClick(() => {
            this.onDelete(t);
          })
      }
    }
    .width(66)
    .height(84)
    .margin({ right: 10 })
  }

  build() {
    Column() {
      Row() {
        Text('切换课表')
          .fontSize(Font.body)
          .fontColor(TC(this.dark).textSub)
        Blank()
        Text('新建课表')
          .fontSize(Font.body)
          .fontColor(Palette.primary)
          .margin({ right: 16 })
          .onClick(() => this.onCreate())
        Text(this.managing ? '完成' : '管理课表')
          .fontSize(Font.body)
          .fontColor(Palette.primary)
          .onClick(() => {
            this.managing = !this.managing;
          })
      }
      .width('100%')
      .margin({ bottom: 10 })

      Scroll() {
        Row() {
          ForEach(this.tables, (t: TableOption) => {
            this.card(t)
          }, (t: TableOption) => `${t.id}-${t.name}`)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .align(Alignment.Start)
      .width('100%')

      if (this.managing) {
        Text('点方块右上角 × 删除，长按方块可重命名')
          .fontSize(10)
          .fontColor(TC(this.dark).textHint)
          .margin({ top: 10 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 18, right: 18, top: 10, bottom: 16 })
  }
}
