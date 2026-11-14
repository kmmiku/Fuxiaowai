import { COURSE_COLORS, Font, Metric, Palette, TC } from '../../common/design/Tokens';
import { Course } from '../../domain/model/Course';

/**
 * 课程块：浅底 + 同色深字 + 左侧 3vp 色条
 * 高度由外部（Grid 行跨度）决定；课名 / 教室 / 教师一律完整换行显示，不作省略号；
 * 不显示上课时间（左侧时间轴已经有了），把空间留给课名。
 */
@Component
export struct CourseBlock {
  @Prop course: Course;
  @Prop compact: boolean = false;
  /** 7 天模式：列更窄，字号收一档 */
  @Prop narrow: boolean = false;
  /** 一节课的高度，用来推算这个块能放几行字 */
  @Prop cellHeight: number = 52;
  @Prop startTime: string = '';
  @Prop endTime: string = '';
  /** 幽灵块：这门课本周不上（只做占位提示） */
  @Prop ghost: boolean = false;
  @Prop dark: boolean = false;
  /** 外部指定的块高（同格多课平分时用）；0 表示按节次跨度自己算 */
  @Prop blockHeight: number = 0;
  /** 这个块所在的重叠簇一共分了几列（1 表示独占） */
  @Prop cols: number = 1;

  private span(): number {
    return this.course.endPeriod - this.course.startPeriod + 1;
  }

  /** 这个块实际有多高（vp） */
  private h(): number {
    return this.blockHeight > 0 ? this.blockHeight : this.span() * this.cellHeight - 4;
  }

  /** 按高度能放几行字（课名行高 15、其它行 11，取中间值 13 估算） */
  private rows(): number {
    return Math.max(1, Math.floor((this.h() - 6) / 13));
  }

  /** 窄列（7 天模式）又被拆成多列时，一列只剩 40~50vp，只能保住课名 */
  private onlyName(): boolean {
    return this.narrow && this.cols > 1;
  }

  /** 教室：只要有就不省略地显示（不再按行数裁剪） */
  private showRoom(): boolean {
    return !this.ghost && !this.onlyName() && this.course.room.length > 0;
  }

  /** 教师：只要有就不省略地显示 */
  private showTeacher(): boolean {
    return !this.ghost && !this.onlyName() && this.course.teacher.length > 0;
  }

  /** 课名至少留一行，其余让给教室和教师 */
  private nameLines(): number {
    const rest: number = this.rows() - (this.showRoom() ? 1 : 0) - (this.showTeacher() ? 1 : 0);
    if (this.compact) {
      return Math.max(1, rest);
    }
    if (this.ghost) {
      return this.rows() >= 3 ? 2 : 1;
    }
    if (this.narrow) {
      return this.onlyName() ? Math.max(1, this.rows()) : Math.max(2, rest);
    }
    return Math.max(2, rest);
  }

  /** 教室行数：窄列长教室名要折行 */
  private roomLines(): number {
    return this.narrow ? 2 : 2;
  }

  build() {
    Row() {
      // 左侧色条
      Column()
        .width(3)
        .height('100%')
        .backgroundColor(this.ghost
          ? ('#6E' + COURSE_COLORS[this.course.colorIndex % 8][1].substring(1))
          : COURSE_COLORS[this.course.colorIndex % 8][1])
        .borderRadius({ topLeft: Metric.blockRadius, bottomLeft: Metric.blockRadius })

      Column() {
        // 课名：加粗 + 换行，溢出裁切而不是省略号
        Text(this.course.name)
          .fontSize(this.compact ? 9 : (this.narrow ? 8 : 12))
          .fontWeight(FontWeight.Bold)
          .fontColor(COURSE_COLORS[this.course.colorIndex % 8][1])
          .lineHeight(this.compact ? 11 : (this.narrow ? 10 : 15))
          .maxLines(this.nameLines())
          .textOverflow({ overflow: TextOverflow.Clip })
          .width('100%')

        if (this.showRoom()) {
          Text(this.course.room)
            .fontSize(this.narrow ? 8 : Font.tiny)
            .fontColor(COURSE_COLORS[this.course.colorIndex % 8][1])
            .opacity(0.9)
            .lineHeight(this.narrow ? 10 : 11)
            .maxLines(this.roomLines())
            .textOverflow({ overflow: TextOverflow.Clip })
            .width('100%')
        }

        if (this.showTeacher()) {
          Text(this.course.teacher)
            .fontSize(this.narrow ? 8 : Font.tiny)
            .fontColor(Palette.textSub)
            .lineHeight(this.narrow ? 10 : 11)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Clip })
            .width('100%')
        }

        // 非本周：块底压一个浅色小标签
        if (this.ghost) {
          Blank()
          Text('非本周')
            .fontSize(this.narrow ? 7 : Font.tiny)
            .fontColor(TC(this.dark).textHint)
            .lineHeight(this.narrow ? 9 : 11)
            .maxLines(1)
            .width('100%')
        }
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .opacity(this.ghost ? 0.78 : 1)
      .padding(this.narrow
        ? { left: 3, right: 2, top: 2, bottom: 1 }
        : { left: this.compact ? 3 : 5, right: this.compact ? 2 : 4, top: 4, bottom: 3 })
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Top)
    .backgroundColor(this.ghost
      ? ('#2E' + COURSE_COLORS[this.course.colorIndex % 8][0].substring(1))
      : COURSE_COLORS[this.course.colorIndex % 8][0])
    .borderRadius(Metric.blockRadius)
    .clip(true)
    .margin(1)
  }
}