let dayStorage = new LocalStorage();

/** 取行里第 i 段（时间\t课名\t教室\t底色\t主色） */
function linePart(line: string, i: number): string {
  const parts: string[] = line.split('\t');
  return i < parts.length ? parts[i] : '';
}

function lineList(raw: string): string[] {
  if (raw.length === 0) {
    return [];
  }
  return raw.split('\n');
}

/** 副标题：时间 · 教室 */
function subOf(line: string): string {
  const time: string = linePart(line, 0);
  const room: string = linePart(line, 2);
  return room.length > 0 ? `${time} · ${room}` : time;
}

/**
 * 桌面卡片：今天一天的课表（2*4，可放大到 4*4）
 * 卡片沙箱不支持 List / Grid，只有 Column + ForEach，所以条数由宿主截断到 5 条。
 */
@Entry(dayStorage)
@Component
struct DayCard {
  @LocalStorageProp('ready') ready: string = '0';
  @LocalStorageProp('weekLabel') weekLabel: string = '';
  @LocalStorageProp('dateLabel') dateLabel: string = '今天';
  @LocalStorageProp('count') count: string = '0';
  @LocalStorageProp('empty') empty: string = '1';
  @LocalStorageProp('more') more: string = '';
  @LocalStorageProp('lines') lines: string = '';

  build() {
    Column() {
      Row() {
        Text(this.dateLabel)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
        Blank()
        Text(this.count === '0' ? this.weekLabel : `${this.count} 门`)
          .fontSize(9)
          .fontColor('#8A909C')
      }
      .width('100%')
      .height(18)
      .alignItems(VerticalAlign.Center)

      if (this.ready !== '1') {
        Column() {
          Text('正在读取…')
            .fontSize(10)
            .fontColor('#8A909C')
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.empty === '1') {
        Column() {
          Text('今天没有课')
            .fontSize(12)
            .fontColor('#6B7280')
          Text('好好休息')
            .fontSize(9)
            .fontColor('#A0A6B1')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          ForEach(lineList(this.lines), (line: string) => {
            Row() {
              Column()
                .width(3)
                .height(22)
                .backgroundColor(linePart(line, 4))
                .borderRadius(2)
                .margin({ right: 6 })
              Column() {
                Text(linePart(line, 1))
                  .fontSize(11)
                  .fontColor(linePart(line, 4))
                  .fontWeight(FontWeight.Medium)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .textAlign(TextAlign.Start)
                Text(subOf(line))
                  .fontSize(8)
                  .fontColor('#8A909C')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .textAlign(TextAlign.Start)
                  .margin({ top: 2 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .height(34)
            .alignItems(VerticalAlign.Center)
            .backgroundColor(linePart(line, 3))
            .borderRadius(8)
            .padding({ left: 5, right: 6 })
            .margin({ bottom: 6 })
          }, (line: string, index: number) => `${index}_${line}`)

          if (this.more.length > 0) {
            Text(`还有 ${this.more} 门`)
              .fontSize(9)
              .fontColor('#8A909C')
              .width('100%')
              .textAlign(TextAlign.Center)
          }
        }
        .layoutWeight(1)
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .height('100%')
    .padding(10)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { 'from': 'day_card' }
      });
    })
  }
}