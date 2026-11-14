import { COURSE_COLORS, Font, Metric, Palette, TC } from '../../common/design/Tokens';
import { Course, Period, isInWeek } from '../../domain/model/Course';

/** 当天的一节课（含同节次重叠的多门课，按开始节次排序） */
interface DayItem {
  course: Course;
  start: string;
  end: string;
}

/**
 * 日视图：竖向时间轴 + 卡片列表（参考超级课程表的当天视图）
 * 只显示「本周 + 今天」的课，空节次不占位
 */
@Component
export struct DayList {
  @Prop courses: Course[] = [];
  @Prop week: number = 1;
  @Prop periods: Period[] = [];
  @Prop dark: boolean = false;
  /** 指定星期几（1=周一 … 7=周日）；0 表示用系统今天 */
  @Prop dayOfWeek: number = 0;
  onCourseTap: (c: Course) => void = () => {};

  /** 1=周一 … 7=周日 */
  private today(): number {
    if (this.dayOfWeek > 0) {
      return this.dayOfWeek;
    }
    const d: number = new Date().getDay();
    return d === 0 ? 7 : d;
  }

  private timeOf(index: number, start: boolean): string {
    let t: string = '';
    this.periods.forEach((p: Period) => {
      if (p.index === index) {
        t = start ? p.start : p.end;
      }
    });
    return t;
  }

  private items(): DayItem[] {
    const day: number = this.today();
    const list: DayItem[] = [];
    this.courses.forEach((c: Course) => {
      if (c.weekday !== day) {
        return;
      }
      if (!isInWeek(c, this.week)) {
        return;
      }
      list.push({
        course: c,
        start: this.timeOf(c.startPeriod, true),
        end: this.timeOf(c.endPeriod, false)
      });
    });
    return list.sort((a: DayItem, b: DayItem) => a.course.startPeriod - b.course.startPeriod);
  }

  private dateLabel(): string {
    const now: Date = new Date();
    const names: string[] = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return `${now.getMonth() + 1}月${now.getDate()}日 ${names[this.today() - 1]}`;
  }

  build() {
    Column() {
      Row() {
        Text(this.dateLabel())
          .fontSize(Font.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(TC(this.dark).text)
        Blank()
        Text(`第${this.week}周`)
          .fontSize(Font.small)
          .fontColor(TC(this.dark).textHint)
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 4, bottom: 8 })

      if (this.items().length === 0) {
        Column() {
          Text('今天没有课')
            .fontSize(Font.body)
            .fontColor(TC(this.dark).textSub)
          Text('点右上角「周」翻回周课表')
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textHint)
            .margin({ top: 6 })
        }
        .width('100%')
        .height(220)
        .justifyContent(FlexAlign.Center)
      } else {
        ForEach(this.items(), (it: DayItem) => {
          Row() {
            // 左侧时间列
            Column() {
              Text(it.start)
                .fontSize(Font.small)
                .fontColor(TC(this.dark).textSub)
              Column()
                .width(1)
                .layoutWeight(1)
                .margin({ top: 4, bottom: 4 })
                .backgroundColor(TC(this.dark).line)
              Text(it.end)
                .fontSize(Font.small)
                .fontColor(TC(this.dark).textHint)
            }
            .width(46)
            .height(86)
            .alignItems(HorizontalAlign.Center)

            // 右侧课程卡片
            Row() {
              Column()
                .width(4)
                .height('100%')
                .backgroundColor(COURSE_COLORS[it.course.colorIndex % 8][1])
                .borderRadius({ topLeft: 10, bottomLeft: 10 })

              Column() {
                Row() {
                  Text(it.course.name)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(COURSE_COLORS[it.course.colorIndex % 8][1])
                    .layoutWeight(1)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(it.course.startPeriod === it.course.endPeriod
                    ? `第${it.course.startPeriod}节`
                    : `第${it.course.startPeriod}-${it.course.endPeriod}节`)
                    .fontSize(Font.tiny)
                    .fontColor(COURSE_COLORS[it.course.colorIndex % 8][1])
                    .opacity(0.8)
                    .margin({ left: 6 })
                }
                .width('100%')

                Row() {
                  Text(this.roomText(it.course))
                    .fontSize(Font.tiny)
                    .fontColor(TC(this.dark).textSub)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  if (it.course.teacher.length > 0) {
                    Text(it.course.teacher)
                      .fontSize(Font.tiny)
                      .fontColor(TC(this.dark).textSub)
                      .margin({ left: 6 })
                  }
                }
                .width('100%')
                .margin({ top: 6 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .justifyContent(FlexAlign.Center)
              .padding({ left: 10, right: 10, top: 10, bottom: 10 })
            }
            .layoutWeight(1)
              .height(86)
              .alignItems(VerticalAlign.Center)
              .backgroundColor(COURSE_COLORS[it.course.colorIndex % 8][0])
            .borderRadius(10)
            .onClick(() => this.onCourseTap(it.course))

            Blank()
              .width(6)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .margin({ bottom: 10 })
        }, (it: DayItem) => `${it.course.id}-${it.course.startPeriod}`)
      }
    }
    .width('100%')
    .padding({ left: 4, right: 4 })
  }

  private roomText(c: Course): string {
    const parts: string[] = [];
    if (c.campus.length > 0) {
      parts.push(c.campus);
    }
    if (c.room.length > 0) {
      parts.push(c.room);
    }
    return parts.length > 0 ? parts.join(' · ') : '教室未填写';
  }
}
