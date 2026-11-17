import { COURSE_COLORS, Font, Metric, Palette, TC } from '../../common/design/Tokens';
import { Course, Period } from '../../domain/model/Course';
import { periodsLabel, weekdayLabel, weeksLabel } from '../../common/util/CourseFormat';

/**
 * 课程详情弹窗内容：点课表格子后自下而上升起
 * 只做信息展示 + 编辑/复制/删除入口，作用域可选「仅本周 / 所有周」
 */
@Component
export struct CourseDetailSheet {
  @Prop course: Course;
  @Prop periods: Period[] = [];
  @Prop dark: boolean = false;
  @Prop allWeeks: boolean = false;
  @Prop displayColorIndex: number = -1;
  /** sheet 内容不订阅父状态，作用域标记要在本地自己维护 */
  @State scopeAll: boolean = false;
  onScope: (all: boolean) => void = () => {};
  onEdit: () => void = () => {};
  onCopy: () => void = () => {};
  onDelete: () => void = () => {};

  aboutToAppear(): void {
    this.scopeAll = this.allWeeks;
  }

  private accent(): string {
    return COURSE_COLORS[this.displayColorIndex >= 0 ? this.displayColorIndex : this.course.colorIndex % 8][1];
  }

  /** 起止时间：08:25-09:10 */
  private timeText(): string {
    let start: string = '';
    let end: string = '';
    this.periods.forEach((p: Period) => {
      if (p.index === this.course.startPeriod) {
        start = p.start;
      }
      if (p.index === this.course.endPeriod) {
        end = p.end;
      }
    });
    if (start.length === 0 || end.length === 0) {
      return '';
    }
    return `${start}-${end}`;
  }

  private placeText(): string {
    const bits: string[] = [];
    if (this.course.room.length > 0) {
      bits.push(this.course.room);
    }
    if (this.course.campus.length > 0) {
      bits.push(this.course.campus);
    }
    return bits.length > 0 ? bits.join(' · ') : '未填写';
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(Font.small)
        .fontColor(TC(this.dark).textHint)
        .width(52)
      Text(value)
        .fontSize(Font.body)
        .fontColor(TC(this.dark).text)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 9, bottom: 9 })
  }

  @Builder
  scopeChip(text: string, active: boolean, action: () => void) {
    Text(text)
      .fontSize(Font.small)
      .fontColor(active ? Palette.primary : TC(this.dark).textSub)
      .fontWeight(active ? FontWeight.Medium : FontWeight.Normal)
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .backgroundColor(active
        ? (this.dark ? '#232A44' : '#E9EDFC')
        : Color.Transparent)
      .borderRadius(8)
      .onClick(action)
  }

  build() {
    Column() {
      // 顶部：色条 + 课名
      Row() {
        Column()
          .width(4)
          .height(22)
          .backgroundColor(this.accent())
          .borderRadius(2)
        Text(this.course.name)
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(TC(this.dark).text)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ left: 10 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ top: 4, bottom: 10 })

      Divider()
        .color(TC(this.dark).line)

      Column() {
        this.infoRow('周次', weeksLabel(this.course.weeks))
        this.infoRow('时间', `${weekdayLabel(this.course.weekday)} ${periodsLabel(this.course)}` +
          (this.timeText().length > 0 ? `  ${this.timeText()}` : ''))
        this.infoRow('地点', this.placeText())
        this.infoRow('教师', this.course.teacher.length > 0 ? this.course.teacher : '未填写')
      }
      .width('100%')

      Blank()

      // 作用域：仅本周 / 所有周
      Row() {
        Text('操作范围')
          .fontSize(Font.small)
          .fontColor(TC(this.dark).textHint)
          .layoutWeight(1)
        Row() {
          Text('仅本周')
            .fontSize(Font.small)
            .fontColor(!this.scopeAll ? Palette.primary : TC(this.dark).textSub)
            .fontWeight(!this.scopeAll ? FontWeight.Medium : FontWeight.Normal)
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .backgroundColor(!this.scopeAll
              ? (this.dark ? '#232A44' : '#E9EDFC')
              : Color.Transparent)
            .borderRadius(8)
            .onClick(() => {
              this.scopeAll = false;
              this.onScope(false);
            })
          Text('所有周')
            .fontSize(Font.small)
            .fontColor(this.scopeAll ? Palette.primary : TC(this.dark).textSub)
            .fontWeight(this.scopeAll ? FontWeight.Medium : FontWeight.Normal)
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .backgroundColor(this.scopeAll
              ? (this.dark ? '#232A44' : '#E9EDFC')
              : Color.Transparent)
            .borderRadius(8)
            .onClick(() => {
              this.scopeAll = true;
              this.onScope(true);
            })
        }
        .padding(2)
        .backgroundColor(TC(this.dark).chip)
        .borderRadius(10)
      }
      .width('100%')
      .padding({ bottom: 12 })

      // 操作按钮
      Row({ space: 8 }) {
        Text('编辑')
          .fontSize(Font.body)
          .fontColor(TC(this.dark).text)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(44)
          .borderRadius(12)
          .backgroundColor(TC(this.dark).chip)
          .onClick(() => this.onEdit())
        Text('复制')
          .fontSize(Font.body)
          .fontColor(TC(this.dark).text)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .width(84)
          .height(44)
          .borderRadius(12)
          .backgroundColor(TC(this.dark).chip)
          .onClick(() => this.onCopy())
        Text('删除')
          .fontSize(Font.body)
          .fontColor('#E8453C')
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .width(84)
          .height(44)
          .borderRadius(12)
          .backgroundColor(this.dark ? '#33222A' : '#FDECEA')
          .onClick(() => this.onDelete())
      }
      .width('100%')
      .padding({ bottom: 10 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: Metric.pagePadding + 4, right: Metric.pagePadding + 4 })
    .alignItems(HorizontalAlign.Start)
  }
}
