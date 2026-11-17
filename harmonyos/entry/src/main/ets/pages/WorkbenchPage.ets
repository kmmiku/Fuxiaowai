import router from '@ohos.router';
import { BottomTabs } from '../ui/components/BottomTabs';
import { LineIcon } from '../ui/components/LineIcon';
import { TC } from '../common/design/Tokens';
import { SessionStore } from '../data/local/SessionStore';

interface WorkService { name: string; desc: string; icon: string; light: string; color: string; url: string; }
const SERVICES: WorkService[] = [
  { name: '我的成绩', desc: '查看个人成绩信息', icon: 'calendar', light: '#F4D58D', color: '#DCA747', url: '' },
  { name: '考试安排', desc: '查看考试时间安排', icon: 'book', light: '#B4EFE1', color: '#74CBBF', url: '' },
  { name: '自主选课', desc: '选课操作与管理', icon: 'book', light: '#C1A4F7', color: '#8D63DF', url: 'http://jw.fzfu.edu.cn/jwglxt/xsxk/zzxkyzb_cxZzxkYzbIndex.html?gnmkdm=N253512&layout=default' },
  { name: '英语四六级报名', desc: '报名四六级考试', icon: 'award', light: '#A7CCFF', color: '#6D9BE5', url: 'https://passport.neea.edu.cn/CETLogin?ReturnUrl=https://cet-bm.neea.edu.cn/Home/VerifyPassport/?LoginType=0&Safe=1' },
  { name: '英语四六级成绩查询', desc: '查询四六级考试成绩', icon: 'calendar', light: '#F4D58D', color: '#DCA747', url: 'https://iam.neea.edu.cn/login.html?client_id=prod_query_web&response_type=code&redirect_uri=https%3A%2F%2Fcjcx.neea.edu.cn%2Fhtml1%2Ffolder%2F21033%2F653-1.htm&scope=basic' }
];

@Entry
@Component
struct WorkbenchPage {
  @StorageLink('dark') dark: boolean = false;
  private opening: boolean = false;

  private async openService(id: number): Promise<void> {
    if (this.opening) { return; }
    this.opening = true;
    try {
      if (id === 0 || id === 1) { await router.pushUrl({ url: id === 0 ? 'pages/GradePage' : 'pages/ExamPage' }); return; }
      const service: WorkService = SERVICES[id];
      if (id === 2 && (await SessionStore.loadJw()).length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: '请先登录教务系统' });
        await router.pushUrl({ url: 'pages/LoginPage' }); return;
      }
      await router.pushUrl({ url: 'pages/ServiceWebPage', params: { url: service.url, title: service.name } });
    } catch (_) { this.getUIContext().getPromptAction().showToast({ message: '暂时无法打开服务页面' }); }
    finally { this.opening = false; }
  }
  @Builder
  serviceIcon(id: number) {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Stack() { LineIcon({ name: SERVICES[id].icon, iconSize: 42, tone: 'white', strokeW: 1.7 }) }
        .width(58).height(50).borderRadius(10)
        .linearGradient({ angle: 135, colors: [[SERVICES[id].light, 0], [SERVICES[id].color, 1]] })
      Text(id === 2 ? '选' : (id === 4 ? '四级' : '+'))
        .fontSize(id === 4 ? 9 : 17).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .width(30).height(30).textAlign(TextAlign.Center).borderRadius(id === 2 || id === 4 ? 7 : 15)
        .backgroundColor(SERVICES[id].color).border({ width: 1.5, color: '#FFFFFF' })
        .translate({ x: 8, y: 8 })
    }.width(67).height(62)
  }
  @Builder
  serviceCopy(id: number, wide: boolean) {
    Column({ space: 3 }) {
      Text(SERVICES[id].name).fontSize(wide ? 17 : (id === 3 ? 16 : 18))
        .fontWeight(FontWeight.Bold).fontColor(TC(this.dark).text).maxLines(1)
        .width('100%').textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 6 }) {
        Text(SERVICES[id].desc).fontSize(12).fontColor(TC(this.dark).textSub).layoutWeight(1)
        Text('›').fontSize(20).fontColor(TC(this.dark).textSub).width(23).height(23)
          .textAlign(TextAlign.Center).backgroundColor(TC(this.dark).chip).borderRadius(12)
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  serviceCard(id: number) {
    Column() {
      Row() { this.serviceIcon(id) }.width('100%').padding({ left: 9 })
      Blank().height(11)
      this.serviceCopy(id, false)
    }.width('100%').height(156).padding({ left: 17, right: 17, top: 19, bottom: 15 })
      .borderRadius(19).border({ width: 1, color: this.dark ? TC(true).line : '#FFFFFF' })
      .linearGradient({ angle: 135, colors: [[this.dark ? TC(true).card : (id === 0 ? '#FFF8F0' : id === 1 ? '#F3FCFE' : id === 2 ? '#F7F4FF' : '#F3F8FF'), 0], [TC(this.dark).card, 0.62]] })
      .onClick(() => this.openService(id))
  }
  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Scroll() {
          Column() {
            Stack({ alignContent: Alignment.TopStart }) {
              Image($r('app.media.workbench_header')).width('100%').height(126).objectFit(ImageFit.Cover).opacity(this.dark ? 0.55 : 1)
              Column({ space: 5 }) {
                Text('工作台').fontSize(34).fontWeight(FontWeight.Bold).fontColor(TC(this.dark).text)
                Text('欢迎使用福小外').fontSize(13).fontColor(TC(this.dark).textSub)
              }.alignItems(HorizontalAlign.Start).margin({ left: 26, top: 25 })
            }.width('100%').height(126).onClick(() => { router.pushUrl({ url: 'pages/ServiceWebPage', params: { url: 'https://www.fzfu.com/', title: '学校官网', temporary: true } }); })
            Column({ space: 14 }) {
              Row({ space: 12 }) { Column() { this.serviceCard(0) }.layoutWeight(1); Column() { this.serviceCard(1) }.layoutWeight(1) }.width('100%')
              Row({ space: 12 }) { Column() { this.serviceCard(2) }.layoutWeight(1); Column() { this.serviceCard(3) }.layoutWeight(1) }.width('100%')
              Row({ space: 22 }) {
                this.serviceIcon(4)
                Column() { this.serviceCopy(4, true) }.layoutWeight(1)
              }.width('100%').height(100).padding({ left: 26, right: 26, top: 15, bottom: 15 })
                .backgroundColor(TC(this.dark).card).borderRadius(19)
                .onClick(() => this.openService(4))
            }.padding({ left: 18, right: 18, bottom: 24 }).width('100%')
          }.width('100%')
        }.layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Off)
        BottomTabs({ current: 2, dark: this.dark })
      }.width('100%').height('100%').backgroundColor(this.dark ? TC(true).bg : '#F1F5FF')
    }.width('100%').height('100%')
  }
}
