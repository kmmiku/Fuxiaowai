@Component
export struct UpdateAnnouncement {
  version: string = '';
  content: string = '';
  canIgnore: boolean = false;
  preview: boolean = false;
  @State ignored: boolean = false;
  onDismiss: (ignore: boolean) => void = () => {};
  onUpdate: () => void = () => {};
  build() {
    Column({ space: 18 }) {
      Text(this.preview ? '更新公告 · 预览' : '更新公告').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#20232B')
      Text(this.version.length > 0 ? `发现新版本 ${this.version}` : '发现新版本').fontSize(14).fontColor('#777D8E')
      Column({ space: 12 }) {
        Text('更新内容').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#4058FF').width('100%')
        Scroll() {
          Text(this.content).fontSize(15).fontColor('#343946').lineHeight(25).width('100%')
        }.constraintSize({ maxHeight: 240 }).width('100%')
      }.padding(18).width('100%').backgroundColor('#F3F5FC').borderRadius(18).alignItems(HorizontalAlign.Start)
      if (this.canIgnore) {
        Row({ space: 8 }) {
          Checkbox({ name: 'ignore-update' }).select(this.ignored).selectedColor('#4058FF')
            .onChange((value: boolean) => { this.ignored = value; })
          Text('不再提示此版本').fontSize(14).fontColor('#686E7D')
        }.width('100%')
      }
      Row({ space: 12 }) {
        Button('暂不更新').layoutWeight(1).height(46).backgroundColor('#F0F2F8').fontColor('#555C6D')
          .onClick(() => { this.onDismiss(this.ignored); })
        Button('立即更新').layoutWeight(1).height(46).backgroundColor('#4058FF').fontColor(Color.White)
          .onClick(() => { this.onUpdate(); })
      }.width('100%')
      Text(this.preview ? '仅预览样式，不代表市场已发布新版' : '下载安装将在华为应用市场完成')
        .fontSize(11).fontColor('#949AAA').textAlign(TextAlign.Center)
    }.padding(24).width('90%').backgroundColor(Color.White).borderRadius(26)
  }
}

export interface UpdateDialogParams {
  version: string;
  content: string;
  canIgnore: boolean;
  preview: boolean;
  onDismiss: (ignore: boolean) => void;
  onUpdate: () => void;
}
@Builder
export function updateDialogBuilder(params: UpdateDialogParams) {
  UpdateAnnouncement({ version: params.version, content: params.content,
    canIgnore: params.canIgnore, preview: params.preview,
    onDismiss: params.onDismiss, onUpdate: params.onUpdate })
}
