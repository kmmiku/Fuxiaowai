import { Font, Metric, Palette, TC } from '../../common/design/Tokens';
import { Course, DEFAULT_PERIODS, Period, isInWeek, displayedColorIndex } from '../../domain/model/Course';
import { CourseBlock } from './CourseBlock';
import display from '@ohos.display';
import { effectiveWidth } from '../../common/util/CellWidth';

/** Tab 页面被 replaceUrl 重建时沿用同进程、同布局的上次列宽。 */
const measuredColumnWidths: number[] = [0, 0];

interface DayCell {
  start: number;
  end: number;
  courses: Course[];
  /** 本周没有这门课，只作为占位提示（半透明 + 「非本周」） */
  ghost: boolean;
  /** 同一时间段重叠时的列序号（0 起） */
  col: number;
  /** 该重叠簇一共分几列 */
  cols: number;
}

/**
 * 课表网格：时间轴列 + 每个星期一个 Stack 列
 * Grid 的 rowStart/rowEnd 在真机/模拟器上不生效，改用 Stack + position 绝对定位
 */
@Component
export struct TimetableGrid {
  /** 该课表的全部课程（含其他周），本周没有的会渲染成半透明幽灵块 */
  @Prop courses: Course[] = [];
  @Prop week: number = 1;
  @Prop showWeekend: boolean = true;
  /** 是否显示「其他周有、本周不上」的课（幽灵块），默认关 */
  @Prop showGhost: boolean = false;
  @Prop periods: Period[] = DEFAULT_PERIODS;
  @Prop cellHeight: number = 52;
  @Prop dark: boolean = false;
  @Prop cellWidth: number = 0;
  @Prop cellWidthRatio: number = 0;
  onBaseBlockWidth: (width: number) => void = () => {};
  /** 点课程块回调：打开课程详情弹窗 */
  onCourseTap: (c: Course) => void = () => {};
  /** 每天那一列的实际宽度（vp），由 onAreaChange 量出来，用于重叠块横向分列 */
  @State colWidth: number = 0;

  /** 取列宽；首帧还没量到时按屏幕宽度估算 */
  private colW(): number {
    if (this.colWidth > 0) {
      return this.colWidth;
    }
    const sw: number = px2vp(display.getDefaultDisplaySync().width);
    const estimated: number = Math.max(14,
      (sw - Metric.pagePadding * 2 - 12 - Metric.timeColWidth) / this.days().length);
    const cached: number = measuredColumnWidths[this.showWeekend ? 1 : 0];
    return cached > 0 && Math.abs(cached - estimated) < estimated * 0.15 ? cached : estimated;
  }

  /** 在现有课程块宽度上等比调整，不改变时间轴和星期列。 */
  private blockW(cell: DayCell): number {
    const unit: number = this.colW() / cell.cols;
    const desired: number = effectiveWidth(this.colW(), this.cellWidthRatio, this.cellWidth);
    return Math.max(0, Math.min(unit, desired / cell.cols) - 2);
  }

  /** 保持课程在星期列中的起点。 */
  private blockX(cell: DayCell): number {
    const unit: number = this.colW() / cell.cols;
    return 1 + unit * cell.col + Math.max(0, unit - this.blockW(cell) - 2) / 2;
  }

  private days(): number[] {
    return this.showWeekend ? [1, 2, 3, 4, 5, 6, 7] : [1, 2, 3, 4, 5];
  }

  private isFirstCourse(course: Course): boolean {
    let first: number = course.startPeriod;
    this.courses.forEach((item: Course) => {
      if (item.weekday === course.weekday && item.startPeriod < first) {
        first = item.startPeriod;
      }
    });
    return course.startPeriod === first;
  }

  /** 节次 → 起止时间（块内展示用） */
  private timeOf(index: number, start: boolean): string {
    let t: string = '';
    this.periods.forEach((p: Period) => {
      if (p.index === index) {
        t = start ? p.start : p.end;
      }
    });
    return t;
  }

  /** 某一天的课按"起止节次"分组（同一格可能有两门不同周次的课）
   *  分两层：本周的课优先占格；某格本周没课、但别的周有，则放一个幽灵块
   */
  private cellsOfDay(day: number): DayCell[] {
    const real: Map<string, DayCell> = new Map<string, DayCell>();
    // 幽灵候选：同一格多门非本周课时，只留「离当前周最近」的那一门
    const ghostBest: Map<string, DayCell> = new Map<string, DayCell>();
    const ghostNext: Map<string, number> = new Map<string, number>();
    this.courses.forEach((c: Course) => {
      if (c.weekday !== day) {
        return;
      }
      const key: string = `${c.startPeriod}-${c.endPeriod}`;
      if (isInWeek(c, this.week)) {
        const exist: DayCell | undefined = real.get(key);
        if (exist) {
          exist.courses.push(c);
        } else {
          real.set(key, { start: c.startPeriod, end: c.endPeriod, courses: [c], ghost: false, col: 0, cols: 1 });
        }
        return;
      }
      if (!this.showGhost) {
        return;
      }
      // 只认「本周及以后还有课」的周次；整门课都上完了就不再占位
      let next: number = 0;
      for (let i = 0; i < c.weeks.length; i++) {
        const w: number = c.weeks[i];
        if (w >= this.week && (next === 0 || w < next)) {
          next = w;
        }
      }
      if (next === 0) {
        return;
      }
      const cur: number | undefined = ghostNext.get(key);
      if (cur === undefined || next < cur) {
        ghostNext.set(key, next);
        ghostBest.set(key, { start: c.startPeriod, end: c.endPeriod, courses: [c], ghost: true, col: 0, cols: 1 });
      }
    });
    // 本周有课的格子不显示幽灵，避免重复
    // 注意必须按「区间相交」判断：本周课占 1-8 节时，别的周占 1-2 节的幽灵块会压在上面形成重影
    ghostBest.forEach((v: DayCell, k: string) => {
      if (real.has(k)) {
        return;
      }
      let hit: boolean = false;
      real.forEach((r: DayCell) => {
        if (!(v.end < r.start || v.start > r.end)) {
          hit = true;
        }
      });
      if (!hit) {
        real.set(k, v);
      }
    });
    const arr: DayCell[] = [];
    real.forEach((v: DayCell) => arr.push(v));
    return this.layoutColumns(arr);
  }

  /**
   * 同一天里时间区间互相重叠的课块，要横向分列，否则长块会盖住短块
   * （周五 1-8 节的 HarmonyOS 与 1-2 节的课同时存在时就靠这个拆开）
   */
  private layoutColumns(cells: DayCell[]): DayCell[] {
    // 幽灵块（非本周占位）不参与分列：它没有真实课要避让，独占整列更清楚
    const ghosts: DayCell[] = cells.filter((c: DayCell) => c.ghost);
    const sorted: DayCell[] = cells.filter((c: DayCell) => !c.ghost)
      .sort((a: DayCell, b: DayCell) => (a.start - b.start) || (b.end - a.end));
    let i: number = 0;
    while (i < sorted.length) {
      // 找出一段「时间上连在一起」的簇
      let maxEnd: number = sorted[i].end;
      let j: number = i + 1;
      while (j < sorted.length && sorted[j].start <= maxEnd) {
        maxEnd = Math.max(maxEnd, sorted[j].end);
        j++;
      }
      // 簇内贪心分配列：放到第一个已经空出来的列
      const colEnds: number[] = [];
      for (let k = i; k < j; k++) {
        let placed: number = -1;
        for (let c = 0; c < colEnds.length; c++) {
          if (colEnds[c] < sorted[k].start) {
            placed = c;
            break;
          }
        }
        if (placed < 0) {
          colEnds.push(sorted[k].end);
          placed = colEnds.length - 1;
        } else {
          colEnds[placed] = sorted[k].end;
        }
        sorted[k].col = placed;
      }
      for (let k = i; k < j; k++) {
        sorted[k].cols = colEnds.length;
      }
      i = j;
    }
    // 幽灵块各自独占一列
    ghosts.forEach((g: DayCell) => {
      g.col = 0;
      g.cols = 1;
      sorted.push(g);
    });
    return sorted;
  }

  build() {
    Row() {
      // ---------- 左侧时间轴 ----------
      Column() {
        ForEach(this.periods, (p: Period) => {
          Column({ space: 1 }) {
            Text(`${p.index}`)
              .fontSize(12)
              .lineHeight(12)
              .height(12)
              .fontWeight(FontWeight.Normal)
              .fontColor(TC(this.dark).textHint)
            Text(p.start)
              .fontSize(12)
              .lineHeight(12)
              .height(12)
              .fontColor(TC(this.dark).textHint)
              .opacity(0.75)
            Text(p.end)
              .fontSize(12)
              .lineHeight(12)
              .height(12)
              .fontColor(TC(this.dark).textHint)
              .opacity(0.75)
          }
          .width('100%')
          .height(this.cellHeight)
          .justifyContent(FlexAlign.Center)
        }, (p: Period) => `t${p.index}-${p.start}-${p.end}`)
      }
      .width(Metric.timeColWidth)

      // ---------- 每天一列 ----------
      ForEach(this.days(), (d: number) => {
        Stack({ alignContent: Alignment.TopStart }) {
          // 底：每节一条横线
          Column() {
            ForEach(this.periods, (p: Period) => {
              Row()
                .width('100%')
                .height(this.cellHeight)
                .border({ width: { bottom: 0.5 }, color: TC(this.dark).gridLine })
            }, (p: Period) => `line${d}-${p.index}`)
          }
          .width('100%')

          // 上：课程块（按节次绝对定位）
          ForEach(this.cellsOfDay(d), (cell: DayCell) => {
            Column() {
              if (cell.courses.length > 1) {
                // 同一格多门课：纵向平分这块高度（显式算高度，layoutWeight 在 Stack 里不稳）
                ForEach(cell.courses, (c: Course) => {
                  CourseBlock({
                    course: c,
                    compact: this.days().length >= 7,
                    narrow: this.showWeekend,
                    cellHeight: this.cellHeight,
                    startTime: this.timeOf(c.startPeriod, true),
                    endTime: this.timeOf(c.endPeriod, false),
                    ghost: cell.ghost,
                    dark: this.dark,
                    alignFirst: this.isFirstCourse(c) && c.endPeriod - c.startPeriod + 1 < 6,
                    displayColorIndex: displayedColorIndex(c, this.isFirstCourse(c)),
                    cols: cell.cols,
                    blockHeight: ((cell.end - cell.start + 1) * this.cellHeight - 4) / cell.courses.length - 3
                  })
                    .height(((cell.end - cell.start + 1) * this.cellHeight - 4) / cell.courses.length - 3)
                    .onClick(() => this.onCourseTap(c))
                }, (c: Course) => c.id)
              } else {
                CourseBlock({
                  course: cell.courses[0],
                  compact: this.days().length >= 7,
                  narrow: this.showWeekend,
                  cellHeight: this.cellHeight,
                  startTime: this.timeOf(cell.start, true),
                  endTime: this.timeOf(cell.end, false),
                  ghost: cell.ghost,
                  dark: this.dark,
                  alignFirst: this.isFirstCourse(cell.courses[0]) && cell.end - cell.start + 1 < 6,
                  displayColorIndex: displayedColorIndex(cell.courses[0], this.isFirstCourse(cell.courses[0])),
                  cols: cell.cols,
                  blockHeight: (cell.end - cell.start + 1) * this.cellHeight - 4
                })
              }
            }
            .width(this.blockW(cell))
            .height((cell.end - cell.start + 1) * this.cellHeight - 4)
            .position({ x: this.blockX(cell), y: (cell.start - 1) * this.cellHeight + 3 })
            .onClick(() => this.onCourseTap(cell.courses[0]))
          }, (cell: DayCell) => `${d}-${cell.start}-${cell.end}-${cell.ghost ? 'g' : 'r'}-${cell.col}-${cell.cols}-${cell.courses.map((c: Course) => c.id).join('_')}`)
        }
        .layoutWeight(1)
        .height(this.periods.length * this.cellHeight)
        .onAreaChange((_o: Area, n: Area) => {
          const w: number = Number(n.width);
          if (w > 0 && Math.abs(w - this.colWidth) > 0.5) {
            this.colWidth = w;
            this.onBaseBlockWidth(w);
            measuredColumnWidths[this.showWeekend ? 1 : 0] = w;
          }
        })
      }, (d: number) => `day${d}`)
    }
    .width('100%')
    .height(this.periods.length * this.cellHeight)
    .alignItems(VerticalAlign.Top)
  }
}
