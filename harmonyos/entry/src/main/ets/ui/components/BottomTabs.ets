import router from '@ohos.router';
import curves from '@ohos.curves';
import { Palette, TC } from '../../common/design/Tokens';
import { LineIcon } from './LineIcon';

/**
 * 底部常驻 Tab
 * 校历 / 课程 / 我的成绩 / 我的 —— 四个主页面共用同一个组件，
 * 选中项用整格浅蓝底 + 主色字做提示，切换用 replaceUrl 避免页面栈越叠越深。
 * 按下时整格缩到 0.96，松手用弹簧曲线回到 1（回弹一次）。
 */
@Component
export struct BottomTabs {
  /** 当前选中项：0 校历、1 课程、2 成绩、3 我的 */
  @Prop current: number = 1;
  @Prop dark: boolean = false;

  /** 正在按下的格子，-1 表示没有 */
  @State pressedIdx: number = -1;
  @State selected: number = 1;
  @State barWidth: number = 0;
  private moving: boolean = false;
  private destination: number = 1;
  private alive: boolean = false;

  aboutToAppear(): void {
    this.alive = true;
    this.selected = this.current;
    this.destination = this.current;
  }

  aboutToDisappear(): void {
    this.alive = false;
  }

  private items: string[] = ['校历', '课程', '我的成绩', '我的'];
  private icons: string[] = ['calendar', 'book', 'award', 'user'];

  private press(i: number): void {
    animateTo({ duration: 90, curve: Curve.FastOutSlowIn }, () => {
      this.pressedIdx = i;
    });
  }

  private release(): void {
    if (this.pressedIdx < 0) {
      return;
    }
    animateTo({ duration: 260, curve: curves.springMotion(0.4, 0.62) }, () => {
      this.pressedIdx = -1;
    });
  }

  private go(i: number): void {
    this.destination = i;
    if (this.moving) { return; }
    if (i === this.current) {
      return;
    }
    this.moving = true;
    this.slide();
  }

  private slide(): void {
    const target: number = this.destination;
    animateTo({ duration: 250, curve: curves.cubicBezierCurve(0.22, 1, 0.36, 1),
      onFinish: () => {
        if (!this.alive) { return; }
        if (this.destination !== target) { this.slide(); return; }
        if (target === this.current) { this.moving = false; return; }
        this.navigate(target);
      }
    }, () => { this.selected = target; });
  }

  private navigate(i: number): void {
    const pages: string[] = ['pages/AcademicCalendar', 'pages/Index', 'pages/GradePage', 'pages/ProfilePage'];
    router.replaceUrl({ url: pages[i] }).catch(() => {
      if (!this.alive) { return; }
      this.selected = this.current;
      this.moving = false;
    });
  }

  private selBg(): ResourceColor {
    return this.dark ? '#2B3350' : '#E4E9FA';
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row()
        .width(Math.max(0, this.barWidth / 4 - 8))
        .height(46)
        .borderRadius(14)
        .backgroundColor(this.selBg())
        .translate({ x: 4 + this.selected * this.barWidth / 4 })
        .hitTestBehavior(HitTestMode.None)
    Row() {
      ForEach(this.items, (name: string, i: number) => {
        Column() {
          LineIcon({
            name: this.icons[i],
            iconSize: 22,
            tone: i === this.selected ? 'pri' : 'sub',
            strokeW: i === this.selected ? 1.9 : 1.6
          })
          Text(name)
            .fontSize(10)
            .fontColor(i === this.selected ? Palette.primary : TC(this.dark).textHint)
            .fontWeight(i === this.selected ? FontWeight.Medium : FontWeight.Normal)
            .margin({ top: 1 })
        }
        .layoutWeight(1)
        .height(46)
        .margin({ left: 4, right: 4 })
        .borderRadius(14)
        .justifyContent(FlexAlign.Center)
        .scale({ x: this.pressedIdx === i ? 0.96 : 1, y: this.pressedIdx === i ? 0.96 : 1 })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.press(i);
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.release();
          }
        })
        .onClick(() => this.go(i))
      }, (name: string, i: number) => name + i)
    }
    .width('100%')
    .onAreaChange((_old: Area, area: Area) => { this.barWidth = Number(area.width); })
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 6, bottom: 8 })
    .backgroundColor(TC(this.dark).card)
    .borderRadius({ topLeft: 20, topRight: 20 })
  }
}

