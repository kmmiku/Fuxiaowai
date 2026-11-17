import { COURSE_COLORS, Metric } from '../../common/design/Tokens';
import { Course } from '../../domain/model/Course';
import measure from '@ohos.measure';
import { wrappedLineCount, courseNameLines, fixedRoomCode } from '../../common/util/CourseTextLayout';

const glyphWidths: Map<string, number> = new Map<string, number>();

/** 与安卓课表一致的实心白字课程块。教师保留在课程详情中。 */
@Component
export struct CourseBlock {
  @Prop course: Course;
  @Prop compact: boolean = false;
  @Prop narrow: boolean = false;
  @Prop cellHeight: number = 52;
  @Prop startTime: string = '';
  @Prop endTime: string = '';
  @Prop ghost: boolean = false;
  @Prop dark: boolean = false;
  @Prop blockHeight: number = 0;
  @Prop cols: number = 1;
  @Prop alignFirst: boolean = false;
  @Prop displayColorIndex: number = -1;

  @State measuredWidth: number = 38;

  private heightVp(): number {
    return this.blockHeight > 0 ? this.blockHeight :
      (this.course.endPeriod - this.course.startPeriod + 1) * this.cellHeight - 4;
  }

  private roomCode(): string {
    const room: string = this.course.room.trim();
    const matched: RegExpMatchArray | null = room.match(/(?:教|实|[A-Za-z])?\s*\d+(?:[-－—]\d+)*/g);
    if (!matched || matched.length === 0) {
      return room;
    }
    for (let i: number = 0; i < matched.length; i++) {
      if (matched[i].indexOf('教') >= 0 || matched[i].indexOf('实') >= 0) {
        return matched[i].trim();
      }
    }
    return matched[matched.length - 1].trim();
  }

  private linesOf(text: string): number {
    const widths: number[] = [];
    for (let i: number = 0; i < text.length; i++) {
      const glyph: string = text.charAt(i);
      if (glyph === '\n') { widths.push(-1); continue; }
      let width: number | undefined = glyphWidths.get(glyph);
      if (width === undefined) {
        width = px2vp(measure.measureText({ textContent: glyph, fontSize: '15fp', fontWeight: '700' }));
        glyphWidths.set(glyph, width);
      }
      widths.push(width);
    }
    return wrappedLineCount(widths, Math.max(1, this.measuredWidth - 6));
  }

  private roomText(): string {
    const room: string = this.course.room.trim();
    const fixed: string = fixedRoomCode(this.roomCode());
    if (fixed.indexOf('\n') >= 0) { return fixed; }
    return this.cols > 1 || this.linesOf(room) > 2 ? this.roomCode() : room;
  }

  private roomLines(): number {
    return this.ghost || !this.course.room.trim() ? 0 : this.linesOf(this.roomText());
  }

  private maxNameLines(): number {
    return courseNameLines(this.heightVp(), this.roomLines());
  }

  private maxRoomLines(): number {
    const name: number = Math.min(this.linesOf(this.course.name), this.maxNameLines());
    return Math.max(1, Math.floor((this.heightVp() - 16 - name * 16) / 16));
  }

  private topAligned(): boolean {
    return this.alignFirst || (this.linesOf(this.course.name) + this.roomLines()) * 16 > this.heightVp() - 32;
  }

  build() {
    Column() {
      Text(this.course.name)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .lineHeight(16)
        .wordBreak(WordBreak.BREAK_ALL)
        .maxLines(this.maxNameLines())
        .textOverflow({ overflow: TextOverflow.Clip })
        .textAlign(TextAlign.Center)
        .width('100%')

      if (!this.ghost && this.course.room.trim().length > 0) {
        Text(this.roomText())
          .fontSize(15)
          .fontWeight(600)
          .fontColor('#FFFFFF')
          .lineHeight(16)
          .wordBreak(WordBreak.BREAK_ALL)
          .maxLines(this.maxRoomLines())
          .textOverflow({ overflow: TextOverflow.Clip })
          .textAlign(TextAlign.Center)
          .width('100%')
      }

      if (this.ghost) {
        Text('非本周')
          .fontSize(9)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textAlign(TextAlign.Center)
          .width('100%')
      }
    }
    .width('100%')
    .onAreaChange((_old: Area, area: Area) => {
      const width: number = Number(area.width);
      if (width > 0 && Math.abs(width - this.measuredWidth) > 0.1) { this.measuredWidth = width; }
    })
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(this.topAligned() ? FlexAlign.Start : FlexAlign.Center)
    .padding({ left: 3, right: 3, top: 16, bottom: this.topAligned() ? 0 : 16 })
    .backgroundColor(COURSE_COLORS[((this.displayColorIndex >= 0 ? this.displayColorIndex : this.course.colorIndex) % 8 + 8) % 8][1])
    .opacity(this.ghost ? 0.4 : 1)
    .borderRadius(Metric.blockRadius)
    .clip(true)
    .margin(1)
  }
}
