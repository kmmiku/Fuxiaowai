import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import { COURSE_COLORS, Font, Metric, Palette, TC } from '../common/design/Tokens';
import { Course, DEFAULT_PERIODS, Period } from '../domain/model/Course';
import { Locator } from '../app/di/ServiceLocator';
import { Db } from '../data/local/Db';
import { PeriodStore } from '../data/local/PeriodStore';

interface RouteParams {
  tableId?: string;
  tableName?: string;
  week?: number;
}

const PARITY_ALL: number = 0;
const PARITY_ODD: number = 1;
const PARITY_EVEN: number = 2;

/** 带标题的输入行 */
@Component
struct LabeledField {
  @Prop dark: boolean = false;
  @Prop label: string = '';
  @Prop placeholder: string = '';
  @Prop value: string = '';
  @Prop numeric: boolean = false;
  onValue: (v: string) => void = () => {
  };

  build() {
    Column() {
      Text(this.label)
        .fontSize(Font.small)
        .fontColor(TC(this.dark).textSub)
        .width('100%')
      TextInput({ text: this.value, placeholder: this.placeholder })
        .type(this.numeric ? InputType.Number : InputType.Normal)
        .height(44)
        .fontSize(15)
        .fontColor(TC(this.dark).text)
        .placeholderColor(TC(this.dark).textHint)
        .backgroundColor(TC(this.dark).chip)
        .borderRadius(12)
        .padding({ left: 12, right: 12 })
        .margin({ top: 6 })
        .onChange((v: string) => this.onValue(v))
    }
    .width('100%')
    .margin({ bottom: 12 })
  }
}

/** 数字加减器 */
@Component
struct StepSpin {
  @Prop dark: boolean = false;
  @Prop value: number = 1;
  @Prop minValue: number = 1;
  @Prop maxValue: number = 12;
  onChange: (v: number) => void = () => {
  };

  build() {
    Row() {
      Text('−')
        .fontSize(20)
        .width(34)
        .height(34)
        .textAlign(TextAlign.Center)
        .fontColor(this.value > this.minValue ? TC(this.dark).text : TC(this.dark).textHint)
        .backgroundColor(TC(this.dark).chip)
        .borderRadius(10)
        .onClick(() => {
          if (this.value > this.minValue) {
            this.onChange(this.value - 1);
          }
        })
      Text(`${this.value}`)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(TC(this.dark).text)
        .width(46)
        .textAlign(TextAlign.Center)
      Text('＋')
        .fontSize(18)
        .width(34)
        .height(34)
        .textAlign(TextAlign.Center)
        .fontColor(this.value < this.maxValue ? TC(this.dark).text : TC(this.dark).textHint)
        .backgroundColor(TC(this.dark).chip)
        .borderRadius(10)
        .onClick(() => {
          if (this.value < this.maxValue) {
            this.onChange(this.value + 1);
          }
        })
    }
  }
}

/** 圆形/胶囊选择项 */
@Component
struct PickChip {
  @Prop dark: boolean = false;
  @Prop text: string = '';
  @Prop active: boolean = false;
  onTap: () => void = () => {
  };

  build() {
    Text(this.text)
      .fontSize(Font.small)
      .fontColor(this.active ? Color.White : TC(this.dark).textSub)
      .backgroundColor(this.active ? Palette.primary : TC(this.dark).chip)
      .borderRadius(9)
      .padding({ left: 6, right: 6, top: 6, bottom: 6 })
      .textAlign(TextAlign.Center)
      .onClick(() => this.onTap())
  }
}

/**
 * 手动添加课程。
 * 教务导入是"整表替换"，手加的课挂在当前课表里会被下次同步覆盖，页面底部有提示。
 */
@Entry
@Component
struct AddCoursePage {
  @StorageLink('dark') dark: boolean = false;

  @State name: string = '';
  @State teacher: string = '';
  @State room: string = '';
  @State campus: string = '长乐校区';
  @State showCampusPicker: boolean = false;
  @State weekday: number = 1;
  @State startPeriod: number = 1;
  @State endPeriod: number = 2;
  @State weekStart: number = 1;
  @State weekEnd: number = 16;
  @State parity: number = PARITY_ALL;
  @State colorIndex: number = 0;
  @State tableId: string = 't1';
  @State periods: Period[] = DEFAULT_PERIODS;
  @State busy: boolean = false;
  @State errMsg: string = '';

  private weekdays: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  private campuses: string[] = ['长乐校区', '滨海校区'];
  private totalWeeks: number = 20;

  aboutToAppear(): void {
    const p: RouteParams = router.getParams() as RouteParams;
    if (p) {
      if (p.tableId) {
        this.tableId = p.tableId;
      }
      if (p.week && p.week >= 1 && p.week <= this.totalWeeks) {
        this.weekStart = p.week;
        this.weekEnd = Math.min(p.week + 15, this.totalWeeks);
      }
    }
    this.loadPeriods();
  }

  private async loadPeriods(): Promise<void> {
    try {
      PeriodStore.init(getContext(this) as common.UIAbilityContext);
      const list: Period[] = await PeriodStore.load();
      if (list.length > 0) {
        this.periods = list;
      }
    } catch (e) {
      this.periods = DEFAULT_PERIODS;
    }
  }

  private campusIndex(): number {
    const index: number = this.campuses.indexOf(this.campus);
    return index >= 0 ? index : 0;
  }

  @Builder
  campusField() {
    Column() {
      Text('校区')
        .fontSize(Font.small)
        .fontColor(TC(this.dark).textSub)
        .width('100%')
      Row() {
        Text(this.campus)
          .fontSize(15)
          .fontColor(TC(this.dark).text)
          .margin({ left: 12 })
          .layoutWeight(1)
        Text('▾')
          .fontSize(18)
          .fontColor(TC(this.dark).textHint)
          .width(38)
          .height(44)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height(44)
      .margin({ top: 6 })
      .borderRadius(12)
      .backgroundColor(TC(this.dark).chip)
      .onClick(() => {
        this.showCampusPicker = true;
      })
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  campusSheet() {
    Column() {
      Row() {
        Text('选择校区')
          .fontSize(Font.section)
          .fontWeight(FontWeight.Medium)
          .fontColor(TC(this.dark).text)
        Blank()
        Text('完成')
          .fontSize(Font.body)
          .fontColor(Palette.primary)
          .onClick(() => {
            this.showCampusPicker = false;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 4, bottom: 4 })

      TextPicker({ range: this.campuses, selected: this.campusIndex() })
        .width('100%')
        .height(180)
        .canLoop(false)
        .selectedTextStyle({ color: Palette.primary, font: { size: 17, weight: FontWeight.Medium } })
        .textStyle({ color: TC(this.dark).textSub, font: { size: 15 } })
        .onChange((value: string | string[], index: number | number[]) => {
          const i: number = typeof index === 'number' ? index : index[0];
          if (i >= 0 && i < this.campuses.length) {
            this.campus = this.campuses[i];
          }
        })
    }
    .width('100%')
    .height('100%')
  }

  private buildWeeks(): number[] {
    const out: number[] = [];
    for (let w = this.weekStart; w <= this.weekEnd; w++) {
      if (this.parity === PARITY_ODD && w % 2 === 0) {
        continue;
      }
      if (this.parity === PARITY_EVEN && w % 2 === 1) {
        continue;
      }
      out.push(w);
    }
    return out;
  }

  private weeksHint(): string {
    const list: number[] = this.buildWeeks();
    if (list.length === 0) {
      return '没有符合条件的周次';
    }
    if (list.length === 1) {
      return `第 ${list[0]} 周`;
    }
    const parityText: string = this.parity === PARITY_ODD ? '（单周）'
      : (this.parity === PARITY_EVEN ? '（双周）' : '');
    return `${this.weekStart}–${this.weekEnd} 周${parityText} · 共 ${list.length} 周`;
  }

  private periodTimeLabel(): string {
    if (this.periods.length === 0) {
      return '';
    }
    const s: number = Math.min(this.startPeriod, this.periods.length) - 1;
    const e: number = Math.min(this.endPeriod, this.periods.length) - 1;
    return `${this.periods[s].start} – ${this.periods[e].end}`;
  }

  private async save(): Promise<void> {
    hilog.info(0x0022, 'FuxiaoAdd', 'save clicked, name=[%{public}s] weekday=%{public}d p=%{public}d-%{public}d w=%{public}d-%{public}d t=%{public}s',
      this.name, this.weekday, this.startPeriod, this.endPeriod, this.weekStart, this.weekEnd, this.tableId);
    const nm: string = this.name.trim();
    if (nm.length === 0) {
      this.errMsg = '课程名不能为空';
      return;
    }
    if (this.startPeriod > this.endPeriod) {
      this.errMsg = '结束节次不能早于开始节次';
      return;
    }
    if (this.weekStart > this.weekEnd) {
      this.errMsg = '结束周不能早于开始周';
      return;
    }
    const weeks: number[] = this.buildWeeks();
    if (weeks.length === 0) {
      this.errMsg = '周次为空，检查一下单双周设置';
      return;
    }

    this.busy = true;
    this.errMsg = '';
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      if (!Db.isReady()) {
        await Locator.init(ctx);
      }
      const c: Course = {
        id: `c_${Date.now()}`,
        name: nm,
        teacher: this.teacher.trim(),
        room: this.room.trim(),
        campus: this.campus.trim(),
        weekday: this.weekday,
        startPeriod: this.startPeriod,
        endPeriod: this.endPeriod,
        weeks: weeks,
        colorIndex: this.colorIndex
      };
      await Locator.repo().add(c, this.tableId);
      hilog.info(0x0022, 'FuxiaoAdd', 'insert ok, id=%{public}s', c.id);
      this.getUIContext().getPromptAction().showToast({ message: '已添加', duration: 1400 });
      router.back();
    } catch (e) {
      hilog.error(0x0022, 'FuxiaoAdd', 'insert failed: %{public}s',
        e instanceof Error ? e.message : JSON.stringify(e));
      this.errMsg = '保存失败：' + (e instanceof Error ? e.message : JSON.stringify(e));
    } finally {
      this.busy = false;
    }
  }

  @Builder
  sectionTitle(text: string, hint: string) {
    Row() {
      Text(text)
        .fontSize(Font.section)
        .fontWeight(FontWeight.Medium)
        .fontColor(TC(this.dark).text)
      Blank()
      if (hint.length > 0) {
        Text(hint)
          .fontSize(Font.small)
          .fontColor(TC(this.dark).textHint)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .margin({ bottom: 10 })
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(26)
          .fontColor(TC(this.dark).text)
          .width(40)
          .onClick(() => router.back())
        Text('添加课程')
          .fontSize(Font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(TC(this.dark).text)
          .layoutWeight(1)
        Text(this.busy ? '保存中' : '保存')
          .fontSize(Font.body)
          .fontColor(this.busy ? TC(this.dark).textHint : Color.White)
          .fontWeight(FontWeight.Medium)
          .padding({ left: 16, right: 16, top: 7, bottom: 7 })
          .borderRadius(17)
          .backgroundColor(this.busy ? TC(this.dark).chip : Palette.primary)
          .onClick(() => {
            if (!this.busy) {
              this.save();
            }
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 8, right: Metric.pagePadding })

      Scroll() {
        Column() {
          if (this.errMsg.length > 0) {
            Text(this.errMsg)
              .fontSize(Font.body)
              .fontColor('#B3261E')
              .width('100%')
              .padding({ left: 12, right: 12, top: 9, bottom: 9 })
              .borderRadius(8)
              .backgroundColor(this.dark ? '#331C1C' : '#FBE3E2')
              .margin({ top: 10 })
          }
          Column() {
            LabeledField({
              dark: this.dark,
              label: '课程名 *',
              placeholder: '',
              value: this.name,
              onValue: (v: string) => {
                this.name = v;
              }
            })
            LabeledField({
              dark: this.dark,
              label: '教师',
              placeholder: '',
              value: this.teacher,
              onValue: (v: string) => {
                this.teacher = v;
              }
            })
            Row({ space: 10 }) {
              Column() {
                LabeledField({
                  dark: this.dark,
                  label: '教室',
                  placeholder: '',
                  value: this.room,
                  onValue: (v: string) => {
                    this.room = v;
                  }
                })
              }
              .layoutWeight(1)
              Column() {
                this.campusField()
              }
              .layoutWeight(1)
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(Metric.cardRadius)
          .backgroundColor(TC(this.dark).card)

          // 星期
          Column() {
            this.sectionTitle('星期', '')
            Row({ space: 5 }) {
              ForEach(this.weekdays, (d: string, i: number) => {
                PickChip({
                  dark: this.dark,
                  text: d,
                  active: this.weekday === i + 1,
                  onTap: () => {
                    this.weekday = i + 1;
                  }
                })
                  .layoutWeight(1)
              }, (d: string, i: number) => d + i)
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(Metric.cardRadius)
          .backgroundColor(TC(this.dark).card)
          .margin({ top: Metric.gap })

          // 节次
          Column() {
            this.sectionTitle('节次', `共 ${this.periods.length} 节`)
            Row() {
              Text('开始')
                .fontSize(Font.body)
                .fontColor(TC(this.dark).textSub)
                .width(40)
              StepSpin({
                dark: this.dark,
                value: this.startPeriod,
                minValue: 1,
                maxValue: this.periods.length,
                onChange: (v: number) => {
                  this.startPeriod = v;
                  if (this.endPeriod < v) {
                    this.endPeriod = v;
                  }
                }
              })
              Blank()
              Text('结束')
                .fontSize(Font.body)
                .fontColor(TC(this.dark).textSub)
                .width(40)
              StepSpin({
                dark: this.dark,
                value: this.endPeriod,
                minValue: this.startPeriod,
                maxValue: this.periods.length,
                onChange: (v: number) => {
                  this.endPeriod = v;
                }
              })
            }
            .width('100%')

            Text(this.periodTimeLabel())
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textHint)
              .width('100%')
              .margin({ top: 8 })
          }
          .width('100%')
          .padding(14)
          .borderRadius(Metric.cardRadius)
          .backgroundColor(TC(this.dark).card)
          .margin({ top: Metric.gap })

          // 周次
          Column() {
            this.sectionTitle('周次', this.weeksHint())
            Row() {
              Text('从')
                .fontSize(Font.body)
                .fontColor(TC(this.dark).textSub)
                .width(28)
              StepSpin({
                dark: this.dark,
                value: this.weekStart,
                minValue: 1,
                maxValue: this.weekEnd,
                onChange: (v: number) => {
                  this.weekStart = v;
                }
              })
              Blank()
              Text('到')
                .fontSize(Font.body)
                .fontColor(TC(this.dark).textSub)
                .width(28)
              StepSpin({
                dark: this.dark,
                value: this.weekEnd,
                minValue: this.weekStart,
                maxValue: this.totalWeeks,
                onChange: (v: number) => {
                  this.weekEnd = v;
                }
              })
            }
            .width('100%')

            Row({ space: 6 }) {
              PickChip({
                dark: this.dark, text: '全部周', active: this.parity === PARITY_ALL,
                onTap: () => {
                  this.parity = PARITY_ALL;
                }
              })
              PickChip({
                dark: this.dark, text: '单周', active: this.parity === PARITY_ODD,
                onTap: () => {
                  this.parity = PARITY_ODD;
                }
              })
              PickChip({
                dark: this.dark, text: '双周', active: this.parity === PARITY_EVEN,
                onTap: () => {
                  this.parity = PARITY_EVEN;
                }
              })
              Blank()
              PickChip({
                dark: this.dark, text: '整学期', active: this.weekStart === 1 && this.weekEnd === this.totalWeeks,
                onTap: () => {
                  this.weekStart = 1;
                  this.weekEnd = this.totalWeeks;
                  this.parity = PARITY_ALL;
                }
              })
            }
            .width('100%')
            .margin({ top: 10 })
          }
          .width('100%')
          .padding(14)
          .borderRadius(Metric.cardRadius)
          .backgroundColor(TC(this.dark).card)
          .margin({ top: Metric.gap })

          // 颜色
          Column() {
            this.sectionTitle('颜色', '')
            Row({ space: 12 }) {
              ForEach(COURSE_COLORS, (pair: string[], i: number) => {
                Stack() {
                  if (this.colorIndex === i) {
                    Circle()
                      .width(38)
                      .height(38)
                      .fill(Color.Transparent)
                      .stroke(pair[1])
                      .strokeWidth(2)
                  }
                  Circle()
                    .width(30)
                    .height(30)
                    .fill(pair[0])
                    .stroke(pair[1])
                    .strokeWidth(3)
                }
                .width(38)
                .height(38)
                .onClick(() => {
                  this.colorIndex = i;
                })
              }, (pair: string[], i: number) => `${i}`)
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(Metric.cardRadius)
          .backgroundColor(TC(this.dark).card)
          .margin({ top: Metric.gap })

          if (this.errMsg.length > 0) {
            Text(this.errMsg)
              .fontSize(Font.body)
              .fontColor('#E8453C')
              .width('100%')
              .padding({ left: 4, top: 10 })
          }

          Text('手动添加的课程保存在本课表；从教务重新同步会整表替换，手加课会被覆盖')
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textHint)
            .width('100%')
            .padding({ left: 4, right: 4, top: 12, bottom: 20 })
        }
        .width('100%')
        .padding({ left: Metric.pagePadding, right: Metric.pagePadding, top: 4 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
    .bindSheet($$this.showCampusPicker, this.campusSheet(), {
      height: 268,
      dragBar: true,
      showClose: false,
      backgroundColor: TC(this.dark).card
    })
  }
}
