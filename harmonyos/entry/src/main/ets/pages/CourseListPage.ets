import { COURSE_COLORS, Font, Metric, Palette, TC } from '../common/design/Tokens';
import { Course } from '../domain/model/Course';
import { Locator } from '../app/di/ServiceLocator';
import { courseBrief, weeksLabel } from '../common/util/CourseFormat';
import router from '@ohos.router';

interface RouteParams {
  tableId?: string;
  tableName?: string;
}

/** 已添加课程：把当前课表的全部课程列出来，可按课名/教师/教室搜索 */
@Entry
@Component
struct CourseListPage {
  @StorageLink('dark') dark: boolean = false;
  @State courses: Course[] = [];
  @State keyword: string = '';
  @State tableId: string = 't1';
  @State tableName: string = '我的课表';

  aboutToAppear(): void {
    const p: RouteParams = router.getParams() as RouteParams;
    if (p && p.tableId) {
      this.tableId = p.tableId;
    }
    if (p && p.tableName) {
      this.tableName = p.tableName;
    }
    this.load();
  }

  private async load(): Promise<void> {
    try {
      const all: Course[] = await Locator.repo().listAll(this.tableId);
      this.courses = all.sort((a: Course, b: Course) => {
        if (a.weekday !== b.weekday) {
          return a.weekday - b.weekday;
        }
        return a.startPeriod - b.startPeriod;
      });
    } catch (e) {
      this.courses = [];
    }
  }

  private filtered(): Course[] {
    const k: string = this.keyword.trim();
    if (k.length === 0) {
      return this.courses;
    }
    return this.courses.filter((c: Course) =>
      c.name.indexOf(k) >= 0 || c.teacher.indexOf(k) >= 0 || c.room.indexOf(k) >= 0);
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(26)
          .fontColor(TC(this.dark).text)
          .width(40)
          .onClick(() => router.back())
        Column() {
          Text('已添加课程')
            .fontSize(Font.title)
            .fontWeight(FontWeight.Bold)
            .fontColor(TC(this.dark).text)
          Text(`${this.tableName} · 共 ${this.courses.length} 门`)
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textHint)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
      }
      .width('100%')
      .height(60)
      .padding({ left: 8, right: Metric.pagePadding })

      Row() {
        Text('⌕')
          .fontSize(16)
          .fontColor(TC(this.dark).textHint)
          .margin({ right: 6 })
        TextInput({ text: this.keyword })
          .layoutWeight(1)
          .height(38)
          .fontSize(Font.body)
          .backgroundColor(Color.Transparent)
          .onChange((v: string) => {
            this.keyword = v;
          })
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })
      .margin({ left: Metric.pagePadding, right: Metric.pagePadding })
      .backgroundColor(TC(this.dark).chip)
      .borderRadius(12)

      if (this.filtered().length === 0) {
        Column() {
          Text(this.courses.length === 0 ? '还没有课程' : '没有匹配的课程')
            .fontSize(Font.body)
            .fontColor(TC(this.dark).textHint)
          Text(this.courses.length === 0 ? '点首页 ⇩ 用教务账号导入' : '换个关键词试试')
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textHint)
            .margin({ top: 6 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.filtered(), (c: Course) => {
            ListItem() {
              this.courseItem(c)
            }
          }, (c: Course) => c.id)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .padding({ left: Metric.pagePadding, right: Metric.pagePadding, top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
  }

  @Builder
  courseItem(c: Course) {
    Row() {
      Row()
        .width(4)
        .height(44)
        .backgroundColor(COURSE_COLORS[c.colorIndex % COURSE_COLORS.length][1])
        .borderRadius(2)

      Column() {
        Text(c.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(TC(this.dark).text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(courseBrief(c))
          .fontSize(Font.small)
          .fontColor(TC(this.dark).textSub)
          .margin({ top: 4 })
        Text(weeksLabel(c.weeks))
          .fontSize(Font.tiny)
          .fontColor(TC(this.dark).textHint)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })
    }
    .width('100%')
    .padding({ left: 10, right: 12, top: 10, bottom: 10 })
    .backgroundColor(TC(this.dark).card)
    .borderRadius(14)
  }
}