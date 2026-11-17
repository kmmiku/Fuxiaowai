import { AccountScope } from '../common/util/AccountScope';
import router from '@ohos.router';
import { LineIcon } from '../ui/components/LineIcon';
import common from '@ohos.app.ability.common';
import curves from '@ohos.curves';
import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import { BottomTabs } from '../ui/components/BottomTabs';
import { Credential, CredentialStore } from '../data/local/CredentialStore';
import { SessionStore } from '../data/local/SessionStore';
import { ZhengfangAuth, LoginResult } from '../data/remote/auth/ZhengfangAuth';
import { currentSemester, Semester } from '../data/remote/auth/RsaPublicKey';
import { GradeAdapter } from '../data/remote/parser/GradeAdapter';
import { GradeSyncResult } from '../data/remote/GradeSync';
import { GradeCacheStore, GradeSnapshot } from '../data/local/GradeCacheStore';
import { Locator } from '../app/di/ServiceLocator';
import {
  GradeRecord, GradeSummary, scoreLevel, summarize, termLabelOf, TermGrades
} from '../domain/model/Grade';

/** 成绩等级 → 文字色 / 底色 */
const LEVEL_FG: string[] = ['#1E7A52', '#2A5BC7', '#9A5B12', '#A2411C', '#B3261E', '#5B6273'];
const LEVEL_BG: string[] = ['#E4F5EC', '#E7EEFC', '#FCF0DC', '#FBE7DE', '#FBE3E2', '#EDEFF3'];
const LEVEL_DARK_BG: string[] = ['#1B3329', '#1B2740', '#33280F', '#33211A', '#331C1C', '#24262D'];

@Entry
@Component
struct GradePage {
  @StorageLink('dark') dark: boolean = false;
  @State search: string = '';
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State needLogin: boolean = false;
  @State errMsg: string = '';
  @State terms: TermGrades[] = [];
  @State allItems: GradeRecord[] = [];
  @State activeTerm: number = -1;   // -1 = 全部
  @State showTermPicker: boolean = false;
  @State draftTerm: number = 0;
  /** 有没有离线缓存可看（有缓存时即便刷新失败也不白屏） */
  @State hasCache: boolean = false;
  /** 缓存时间戳：页面上显示「成绩更新于 …」 */
  @State cachedAt: number = 0;
  /** 'ok' 或 'expired'：右上角状态点用 */
  @State cacheStatus: string = '';
  /** 身份验证按钮按下态：按下 90% 压缩，松手回弹 */
  @State verifyPressed: boolean = false;
  @State summary: GradeSummary = {
    count: 0, credits: 0, weightedScore: 0, weightedGpa: 0, failed: 0, best: 0
  };

  private displayedUser: string = '';
  private revision: number = 0;

  aboutToAppear(): void {
    this.boot();
  }

  /** 从登录页回来（重新验证身份）要再刷一次，否则看到的是旧状态 */
  onPageShow(): void {
    this.boot();
  }

  /**
   * 先读缓存秒开（离线也能看），再后台刷新。
   * 缓存是登录/上次刷新时静默存下的，扫码那种「短暂权限」掉的会话也能靠它显示。
   */
  private async boot(): Promise<void> {
    const revision: number = ++this.revision;
    const token: number = AccountScope.token();
    this.loading = true;
    this.refreshing = false;
    this.needLogin = false;
    this.errMsg = '';
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const cred: Credential = await CredentialStore.load(ctx);
      if (revision !== this.revision || !AccountScope.valid(token)) { return; }
      if (this.displayedUser !== cred.user) {
        this.displayedUser = cred.user;
        this.terms = [];
        this.allItems = [];
        this.summary = summarize([]);
        this.activeTerm = -1;
        this.hasCache = false;
        this.cachedAt = 0;
        this.cacheStatus = '';
      }
      if (cred.user.length === 0) {
        this.loading = false;
        this.needLogin = true;
        return;
      }
      const cached: GradeSnapshot | null = await Locator.loadGradeCache(cred.user);
      if (!this.validView(revision, token, cred.user)) { return; }
      if (cached !== null && cached.user === cred.user) {
        this.applySnapshot(cached);
        this.loading = false;
      }
      await this.refresh(cached !== null);
    } catch (e) {
      if (revision !== this.revision || !AccountScope.valid(token)) { return; }
      this.errMsg = '读取成绩失败，请稍后重试';
      this.loading = false;
    }
  }

  private validView(revision: number, token: number, user: string): boolean {
    return revision === this.revision && AccountScope.valid(token) && AccountScope.user() === user && this.displayedUser === user;
  }

  private applySnapshot(snap: GradeSnapshot): void {
    if (snap.user !== this.displayedUser) { return; }
    this.terms = snap.terms;
    this.allItems = snap.items;
    this.summary = snap.summary;
    this.cachedAt = snap.at;
    this.cacheStatus = snap.status;
    this.hasCache = true;
  }

  /** silent=true 时不闪 loading，只在顶部转小圈 */
  private async refresh(silent: boolean): Promise<void> {
    if (this.refreshing) { return; }
    const revision: number = this.revision;
    const token: number = AccountScope.token();
    const user: string = this.displayedUser;
    if (user.length === 0 || !this.validView(revision, token, user)) { return; }
    this.refreshing = true;
    if (!silent) { this.loading = true; }
    try {
      const r: GradeSyncResult = await Locator.syncGrades(user);
      if (!this.validView(revision, token, user)) { return; }
      if (r.ok && r.snapshot !== null && r.snapshot.user === user) {
        this.applySnapshot(r.snapshot);
        this.errMsg = r.message;
      } else {
        this.errMsg = r.message;
        if (r.expired) { this.cacheStatus = 'expired'; }
      }
    } catch (e) {
      if (!this.validView(revision, token, user)) { return; }
      this.errMsg = '无法连接教务系统，已保留离线成绩';
    }
    this.loading = false;
    this.refreshing = false;
  }

  /** 身份验证刷新：回登录页走一遍（扫码或账号密码都行），成功后 onPageShow 自动再拉 */
  private goVerify(): void {
    router.pushUrl({ url: 'pages/LoginPage', params: { refresh: 'grade' } });
  }

  /** 页面上的时间/状态文案 */
  private statusText(): string {
    if (this.cachedAt <= 0) {
      return '';
    }
    const when: string = GradeCacheStore.shortTime(this.cachedAt);
    return `成绩更新于 ${when} · 本地已缓存`;
  }

  private shown(): GradeRecord[] {
    const list: GradeRecord[] = this.activeTerm < 0 || this.activeTerm >= this.terms.length ? this.allItems : this.terms[this.activeTerm].items;
    return list.filter((g: GradeRecord) => g.courseName.includes(this.search.trim()) || g.courseNo.includes(this.search.trim()));
  }

  private termLabels(): string[] {
    const out: string[] = ['全部学期'];
    this.terms.forEach((t: TermGrades) => out.push(t.label));
    return out;
  }

  private termIndex(): number {
    return this.activeTerm + 1;
  }

  private termTitle(): string {
    if (this.activeTerm < 0) {
      return '全部学期';
    }
    return this.activeTerm < this.terms.length ? this.terms[this.activeTerm].label : '全部学期';
  }

  /** 考试安排：内置页面，可视化列表 + 可切换网页原文 */
  private openExam(): void {
    router.pushUrl({ url: 'pages/ExamPage' });
  }

  @Builder
  headerBar() {
    Row() {
      Row() { LineIcon({ name: 'query-back', iconSize: 24, tone: 'query-blue', strokeW: 2 }) }
        .width(44).height(44).justifyContent(FlexAlign.Center).onClick(() => router.back())
      Text('成绩查询').fontSize(20).fontWeight(FontWeight.Bold).fontColor(TC(this.dark).text).layoutWeight(1).textAlign(TextAlign.Center)
      Row() { LineIcon({ name: 'query-refresh', iconSize: 22, tone: 'query-blue', strokeW: 1.8 }) }
        .width(44).height(44).justifyContent(FlexAlign.Center)
        .opacity(this.refreshing ? 0.5 : 1).onClick(() => { if (!this.refreshing) { this.refresh(false); } })
    }.width('100%').height(56)
  }

  @Builder
  summaryCard() {
    Column() {
      Row() {
        Column() {
          Text('平均绩点')
            .fontSize(Font.small)
            .fontColor('#DDE3FF')
          Text(this.summary.weightedGpa.toFixed(2))
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 考试安排：跳教务系统成绩查询页（系统浏览器打开，需自己在浏览器里登录）
        Column() {
          Text('考试安排')
            .fontSize(Font.small)
            .fontColor(Color.White)
          Text('教务系统 ›')
            .fontSize(Font.tiny)
            .fontColor('#DDE3FF')
            .margin({ top: 3 })
        }
        .width(96)
        .height(58)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(12)
        .backgroundColor('#26FFFFFF')
        .border({ width: 1, color: '#59FFFFFF' })
        .onClick(() => this.openExam())
      }
      .width('100%')

      Row() {
        Text(`已修 ${this.summary.credits} 学分`)
          .fontSize(Font.small)
          .fontColor('#DDE3FF')
        Text('·')
          .fontSize(Font.small)
          .fontColor('#9FAEFF')
          .margin({ left: 6, right: 6 })
        Text(`${this.summary.count} 门课`)
          .fontSize(Font.small)
          .fontColor('#DDE3FF')
        if (this.summary.failed > 0) {
          Text('·')
            .fontSize(Font.small)
            .fontColor('#9FAEFF')
            .margin({ left: 6, right: 6 })
          Text(`${this.summary.failed} 门不及格`)
            .fontSize(Font.small)
            .fontColor('#FFD9D6')
        }
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .width('100%')
    .padding(18)
    .borderRadius(Metric.cardRadius)
    .linearGradient({
      angle: 135,
      colors: [['#3A56C8', 0.0], ['#5B6FE8', 1.0]]
    })
  }

  /** 学期滚轮：点开底部选择器，滚到哪就切到哪 */
  private displayTerm(t: TermGrades): string {
    return `${t.xnm}-${t.xnm + 1} 学年 · ${t.xqm === 3 ? '第一学期' : t.xqm === 12 ? '第二学期' : '第三学期'}`;
  }

  @Builder
  termBar() {
    Row() {
      Column({ space: 5 }) {
        Text('学年学期').fontSize(12).fontColor(TC(this.dark).textHint)
        Text(this.activeTerm >= 0 && this.activeTerm < this.terms.length ? this.displayTerm(this.terms[this.activeTerm]) : '全部学期')
          .fontSize(15).fontColor(TC(this.dark).text).maxLines(2)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      LineIcon({ name: 'query-down', iconSize: 18, tone: 'sub', strokeW: 2 })
    }.width('100%').height(60).padding({ left: 12, right: 12 })
      .border({ width: 1, color: TC(this.dark).line }).borderRadius(10).backgroundColor(TC(this.dark).card)
      .onClick(() => { this.draftTerm = this.activeTerm + 1; this.showTermPicker = true; })
  }

  @Builder
  termSheet() {
    Column() {
      Row() {
        Text('选择学年学期').fontSize(17).fontWeight(FontWeight.Medium).fontColor(TC(this.dark).text)
        Blank()
        Text('完成').fontSize(15).fontColor(Palette.primary).padding(10)
          .onClick(() => { this.activeTerm = this.draftTerm - 1; this.showTermPicker = false; })
      }.width('100%').padding({ left: 20, right: 10 })
      TextPicker({ range: ['全部学期'].concat(this.terms.map((t: TermGrades) => this.displayTerm(t))), selected: this.draftTerm })
        .width('100%').height(180).canLoop(false)
        .selectedTextStyle({ color: Palette.primary, font: { size: 17 } })
        .textStyle({ color: TC(this.dark).textSub, font: { size: 15 } })
        .onChange((_v: string | string[], index: number | number[]) => { this.draftTerm = typeof index === 'number' ? index : index[0]; })
    }.width('100%').height('100%')
  }

  @Builder
  gradeRow(g: GradeRecord) {
    Row({ space: 14 }) {
      Column({ space: 1 }) {
        Text(g.courseName).fontSize(18).lineHeight(25).fontColor(TC(this.dark).text).width('100%')
        Text(g.courseNo || '课程代码未提供').fontSize(13).lineHeight(20).fontColor(TC(this.dark).textSub).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text(g.scoreText || `${g.score}`).fontSize(23).lineHeight(30).fontWeight(FontWeight.Bold)
        .fontColor(this.dark ? '#6CAAFF' : '#1675C8').constraintSize({ maxWidth: '36%' }).textAlign(TextAlign.End)
    }.width('100%').constraintSize({ minHeight: 62 }).padding({ top: 11, bottom: 9 })
      .border({ width: { bottom: 1 }, color: TC(this.dark).line })
  }

  @Builder
  centerHint(title: string, desc: string, actionText: string, action: () => void) {
    Column() {
      Text(title)
        .fontSize(Font.body)
        .fontColor(TC(this.dark).text)
      Text(desc)
        .fontSize(Font.small)
        .fontColor(TC(this.dark).textSub)
        .margin({ top: 8 })
        .textAlign(TextAlign.Center)
      if (actionText.length > 0) {
        Text(actionText)
          .fontSize(Font.body)
          .fontColor(Color.White)
          .padding({ left: 24, right: 24, top: 10, bottom: 10 })
          .backgroundColor(Palette.primary)
          .borderRadius(10)
          .margin({ top: 20 })
          .onClick(action)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(32)
  }

  build() {
    Column() {
      this.headerBar()
      Column() {
        this.termBar()
        Row({ space: 12 }) {
          LineIcon({ name: 'search', iconSize: 22, tone: 'sub' })
          TextInput({ text: this.search, placeholder: '搜索科目名称' })
            .layoutWeight(1).height(40).fontSize(15).placeholderColor(TC(this.dark).textHint).padding(0).backgroundColor(Color.Transparent)
            .onChange((value: string) => { this.search = value; })
        }.height(40).width('100%').padding({ left: 16, right: 16 })
          .backgroundColor(this.dark ? TC(true).chip : '#E4E7F3').borderRadius(24).margin({ top: 14 })
        Text(`共 ${this.shown().length} 门课程`).fontSize(14).fontColor(TC(this.dark).textSub)
          .width('100%').padding({ left: 3, top: 21, bottom: 11 })
      }.padding({ left: 14, right: 14 }).width('100%')
      if (this.needLogin) {
        this.centerHint('请先登录教务系统', '', '去登录', () => this.goVerify())
      } else if (this.loading && !this.hasCache) {
        this.centerHint('正在读取成绩…', '', '', () => {})
      } else if (!this.hasCache) {
        this.centerHint(this.errMsg || '暂无成绩数据', '', '重新查询', () => this.refresh(false))
      } else {
        List() {
          ForEach(this.shown(), (g: GradeRecord) => {
            ListItem() { this.gradeRow(g) }
          }, (g: GradeRecord, i: number) => `${g.courseNo}-${g.xnm}-${g.xqm}-${i}`)
          if (this.shown().length === 0) {
            ListItem() { Text(this.search ? '没有找到相关课程' : '该学期暂无成绩').fontSize(14).fontColor(TC(this.dark).textSub).width('100%').textAlign(TextAlign.Center).padding(30) }
          }
          ListItem() {
            Text(this.errMsg ? `更新未成功，当前显示缓存：${this.errMsg}` : `数据来源：教务成绩查询 · ${this.statusText()}`)
              .fontSize(11).fontColor(TC(this.dark).textHint).width('100%').textAlign(TextAlign.Center).padding({ top: 20, bottom: 24 })
          }
        }.layoutWeight(1).width('100%').padding({ left: 18, right: 18 }).backgroundColor(TC(this.dark).card).scrollBar(BarState.Off)
      }
    }.width('100%').height('100%').backgroundColor(TC(this.dark).bg)
      .bindSheet($$this.showTermPicker, this.termSheet(), { height: 270, dragBar: true, showClose: false, backgroundColor: TC(this.dark).card })
  }
}
