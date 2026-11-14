import { DEFAULT_PERIODS, Period } from '../domain/model/Course';
import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import { PeriodStore } from '../data/local/PeriodStore';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

/**
 * 上课时间设置：滚轮式 TimePicker 改每节起止时间，支持增删节次（自定义节数）。
 * 保存后写 PeriodStore，课表网格按 periods.length 重新排版。
 */
@Entry
@Component
struct PeriodSettings {
  @StorageLink('dark') dark: boolean = false;
  @State periods: Period[] = [];
  @State sheetOn: boolean = false;
  @State editingIndex: number = 1;
  @State pickStart: Date = new Date(2026, 0, 1, 8, 25);
  @State pickEnd: Date = new Date(2026, 0, 1, 9, 10);
  @State dirty: boolean = false;
  private ctx: common.UIAbilityContext | null = null;
  private pos: number = -1;

  aboutToAppear(): void {
    this.ctx = getContext(this) as common.UIAbilityContext;
    PeriodStore.init(this.ctx);
    PeriodStore.load().then((list: Period[]) => {
      this.periods = list;
    });
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(26)
          .fontColor(TC(this.dark).text)
          .width(40)
          .onClick(() => this.goBack())
        Text('上课时间')
          .fontSize(Font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(TC(this.dark).text)
        Blank()
        Text('＋ 添加')
          .fontSize(Font.body)
          .fontColor(Palette.primary)
          .padding(8)
          .onClick(() => this.addPeriod())
      }
      .width('100%')
      .height(60)
      .padding({ left: 8, right: Metric.pagePadding })

      Text(`共 ${this.periods.length} 节 · 点任意一节用滚轮改时间`)
        .fontSize(Font.small)
        .fontColor(TC(this.dark).textHint)
        .width('100%')
        .padding({ left: 20, bottom: 8 })

      List({ space: 8 }) {
        ForEach(this.periods, (p: Period, i: number) => {
          ListItem() {
            Row() {
              Text(`${p.index}`)
                .fontSize(Font.body)
                .fontWeight(FontWeight.Medium)
                .fontColor(Palette.primary)
                .width(34)
                .textAlign(TextAlign.Center)
              Column() {
                Text(`第 ${p.index} 节`)
                  .fontSize(Font.body)
                  .fontColor(TC(this.dark).text)
                Text(`${p.start} – ${p.end}`)
                  .fontSize(Font.small)
                  .fontColor(TC(this.dark).textSub)
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text('›')
                .fontSize(20)
                .fontColor(TC(this.dark).textHint)
            }
            .width('100%')
            .height(58)
            .padding({ left: 8, right: 14 })
            .backgroundColor(TC(this.dark).card)
            .borderRadius(14)
            .onClick(() => this.openEditor(i))
          }
        }, (p: Period) => `p${p.index}-${p.start}-${p.end}`)
      }
      .layoutWeight(1)
      .padding({ left: Metric.pagePadding, right: Metric.pagePadding })
      .scrollBar(BarState.Off)

      Row({ space: 12 }) {
        Button('恢复默认')
          .layoutWeight(1)
          .height(46)
          .fontSize(Font.body)
          .fontColor(TC(this.dark).textSub)
          .backgroundColor(TC(this.dark).chip)
          .onClick(() => {
            this.periods = DEFAULT_PERIODS.map((p: Period) => {
              const n: Period = { index: p.index, start: p.start, end: p.end };
              return n;
            });
            this.dirty = true;
            this.toast('已恢复默认，记得保存');
          })
        Button('保存')
          .layoutWeight(2)
          .height(46)
          .fontSize(Font.body)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .onClick(() => this.saveAll())
      }
      .width('100%')
      .padding({ left: Metric.pagePadding, right: Metric.pagePadding, top: 10, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
    .bindSheet($$this.sheetOn, this.editorSheet(), {
      height: 430,
      dragBar: false,
      backgroundColor: TC(this.dark).card,
      title: { title: `第 ${this.editingIndex} 节` }
    })
  }

  @Builder
  editorSheet() {
    Column() {
      Row() {
        Column() {
          Text('开始')
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textHint)
          TimePicker({ selected: this.pickStart })
            .useMilitaryTime(true)
            .onChange((v: TimePickerResult) => {
              this.pickStart = new Date(2026, 0, 1, v.hour, v.minute);
              // 结束早于开始就顺延 45 分钟
              if (this.minutes(this.pickEnd) <= this.minutes(this.pickStart)) {
                this.pickEnd = new Date(2026, 0, 1, v.hour, v.minute + 45);
              }
            })
            .width('100%')
            .height(160)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text('结束')
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textHint)
          TimePicker({ selected: this.pickEnd })
            .useMilitaryTime(true)
            .onChange((v: TimePickerResult) => {
              this.pickEnd = new Date(2026, 0, 1, v.hour, v.minute);
            })
            .width('100%')
            .height(160)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')

      if (this.minutes(this.pickEnd) <= this.minutes(this.pickStart)) {
        Text('结束时间要晚于开始时间')
          .fontSize(Font.small)
          .fontColor('#C0392B')
          .width('100%')
          .textAlign(TextAlign.Center)
      }

      Row({ space: 12 }) {
        Button('删除本节')
          .layoutWeight(1)
          .height(44)
          .fontSize(Font.body)
          .fontColor('#C0392B')
          .backgroundColor(TC(this.dark).chip)
          .enabled(this.periods.length > 1)
          .onClick(() => this.removeCurrent())
        Button('完成')
          .layoutWeight(2)
          .height(44)
          .fontSize(Font.body)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .onClick(() => this.applyCurrent())
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 20 })
  }

  private toast(msg: string): void {
    try {
      promptAction.showToast({ message: msg, duration: 1500 });
    } catch (e) {
      console.error('toast failed');
    }
  }

  private minutes(d: Date): number {
    return d.getHours() * 60 + d.getMinutes();
  }

  private fmt(d: Date): string {
    const h: string = d.getHours() < 10 ? '0' + d.getHours() : `${d.getHours()}`;
    const m: string = d.getMinutes() < 10 ? '0' + d.getMinutes() : `${d.getMinutes()}`;
    return `${h}:${m}`;
  }

  private openEditor(pos: number): void {
    this.pos = pos;
    const p: Period = this.periods[pos];
    this.editingIndex = p.index;
    this.pickStart = this.parse(p.start, 8, 25);
    this.pickEnd = this.parse(p.end, 9, 10);
    this.sheetOn = true;
  }

  private parse(s: string, dh: number, dm: number): Date {
    const parts: string[] = s.split(':');
    const h: number = parts.length === 2 ? parseInt(parts[0], 10) : dh;
    const m: number = parts.length === 2 ? parseInt(parts[1], 10) : dm;
    return new Date(2026, 0, 1, h, m);
  }

  private applyCurrent(): void {
    if (this.minutes(this.pickEnd) <= this.minutes(this.pickStart)) {
      this.toast('结束时间要晚于开始时间');
      return;
    }
    if (this.pos < 0) {
      return;
    }
    const np: Period = {
      index: this.periods[this.pos].index,
      start: this.fmt(this.pickStart),
      end: this.fmt(this.pickEnd)
    };
    const next: Period[] = this.periods.slice();
    next[this.pos] = np;
    this.periods = next;
    this.dirty = true;
    this.sheetOn = false;
  }

  private removeCurrent(): void {
    if (this.pos < 0 || this.periods.length <= 1) {
      return;
    }
    const next: Period[] = [];
    for (let i = 0; i < this.periods.length; i++) {
      if (i !== this.pos) {
        next.push(this.periods[i]);
      }
    }
    // 重新编号 1..n
    const renum: Period[] = next.map((p: Period, i: number) => {
      const n: Period = { index: i + 1, start: p.start, end: p.end };
      return n;
    });
    this.periods = renum;
    this.dirty = true;
    this.sheetOn = false;
    this.toast('已删除，记得保存');
  }

  private addPeriod(): void {
    const last: Period | null = this.periods.length > 0 ? this.periods[this.periods.length - 1] : null;
    let sh: number = 18;
    let sm: number = 30;
    if (last) {
      const e: Date = this.parse(last.end, 17, 15);
      const t: number = e.getHours() * 60 + e.getMinutes() + 10;
      sh = Math.floor(t / 60) % 24;
      sm = t % 60;
    }
    const np: Period = {
      index: this.periods.length + 1,
      start: this.fmt(new Date(2026, 0, 1, sh, sm)),
      end: this.fmt(new Date(2026, 0, 1, sh, sm + 45))
    };
    const next: Period[] = this.periods.slice();
    next.push(np);
    this.periods = next;
    this.dirty = true;
    this.pos = next.length - 1;
    this.editingIndex = np.index;
    this.pickStart = this.parse(np.start, sh, sm);
    this.pickEnd = this.parse(np.end, sh, sm + 45);
    this.sheetOn = true;
  }

  private async saveAll(): Promise<void> {
    const ok: boolean = await PeriodStore.save(this.periods);
    if (ok) {
      this.dirty = false;
      this.toast('已保存，课表同步更新');
      setTimeout(() => router.back(), 500);
    } else {
      this.toast('保存失败');
    }
  }

  private goBack(): void {
    if (this.dirty) {
      this.toast('有未保存的修改，点『保存』后生效');
    }
    router.back();
  }
}