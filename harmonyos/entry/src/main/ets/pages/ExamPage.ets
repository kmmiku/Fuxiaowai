import { LineIcon } from '../ui/components/LineIcon';
import preferences from '@ohos.data.preferences';
import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import { Credential, CredentialStore } from '../data/local/CredentialStore';
import { SessionStore } from '../data/local/SessionStore';
import { ZhengfangAuth, LoginResult, JW_BASE_URL, EXAM_PAGE_URL } from '../data/remote/auth/ZhengfangAuth';
import { currentSemester, Semester } from '../data/remote/auth/RsaPublicKey';
import { ExamAdapter } from '../data/remote/parser/ExamAdapter';
import { daysUntil, ExamRecord } from '../domain/model/Exam';
import { SchoolTraffic } from '../common/util/SchoolTraffic';
import { AccountScope } from '../common/util/AccountScope';

@Entry
@Component
struct ExamPage {
  @StorageLink('dark') dark: boolean = false;
  @State selectedYear: number = currentSemester(new Date()).xnm;
  @State selectedTerm: number = currentSemester(new Date()).xqm;
  private years: number[] = [new Date().getFullYear(), new Date().getFullYear()-1, new Date().getFullYear()-2, new Date().getFullYear()-3, new Date().getFullYear()-4, new Date().getFullYear()-5];
  private cacheOwner: string = '';
  private request: number = 0;
  @State loading: boolean = true;
  @State needLogin: boolean = false;
  @State errMsg: string = '';
  @State exams: ExamRecord[] = [];
  @State showTermPicker: boolean = false;
  @State draftTerm: number = 0;
  @State cookie: string = '';
  @State now: number = Date.now();

  aboutToAppear(): void {
    this.restoreSelection();
  }

  private async restoreSelection(): Promise<void> {
    const token: number = AccountScope.token();
    const user: string = AccountScope.user();
    const store = await preferences.getPreferences(getContext(this) as common.UIAbilityContext, 'fxw_exam_cache');
    const saved: number = await store.get('selection:' + user, -1) as number;
    if (!AccountScope.valid(token)) { return; }
    if (Number.isInteger(saved) && saved >= 0 && saved < this.years.length * 2) {
      this.selectedYear = this.years[Math.floor(saved / 2)]; this.selectedTerm = saved % 2 === 0 ? 3 : 12;
    }
    this.load();
  }

  private termLabels(): string[] {
    const labels: string[] = [];
    this.years.forEach((year: number) => {
      labels.push(`${year}-${year + 1} 学年 · 第一学期`);
      labels.push(`${year}-${year + 1} 学年 · 第二学期`);
    });
    return labels;
  }
  private termIndex(): number { return Math.max(0, this.years.indexOf(this.selectedYear)) * 2 + (this.selectedTerm === 3 ? 0 : 1); }
  private async commitTerm(): Promise<void> {
    const token: number = AccountScope.token(); const user: string = AccountScope.user();
    this.selectedYear = this.years[Math.floor(this.draftTerm / 2)]; this.selectedTerm = this.draftTerm % 2 === 0 ? 3 : 12;
    this.showTermPicker = false;
    const store = await preferences.getPreferences(getContext(this) as common.UIAbilityContext, 'fxw_exam_cache');
    if (!AccountScope.valid(token)) { return; }
    await store.put('selection:' + user, this.draftTerm); await store.flush();
    this.load();
  }
  @Builder
  termBar() {
    Row() {
      Column({ space: 5 }) {
        Text('学年学期').fontSize(12).fontColor(TC(this.dark).textHint)
        Text(this.termLabels()[this.termIndex()]).fontSize(15).fontColor(TC(this.dark).text)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      LineIcon({ name: 'query-down', iconSize: 18, tone: 'sub', strokeW: 2 })
    }.height(60).width('100%').padding({ left: 12, right: 12 }).borderRadius(10)
      .border({ width: 1, color: TC(this.dark).line }).backgroundColor(TC(this.dark).card)
      .onClick(() => { this.draftTerm = this.termIndex(); this.showTermPicker = true; })
  }
  @Builder
  termSheet() {
    Column() {
      Row() {
        Text('选择学年学期').fontSize(17).fontWeight(FontWeight.Medium).fontColor(TC(this.dark).text)
        Blank()
        Text('完成').fontSize(15).fontColor(Palette.primary).padding(10).onClick(() => this.commitTerm())
      }.width('100%').padding({ left: 20, right: 10 })
      TextPicker({ range: this.termLabels(), selected: this.draftTerm }).width('100%').height(180).canLoop(false)
        .selectedTextStyle({ color: Palette.primary, font: { size: 17 } })
        .onChange((value: string | string[], index: number | number[]) => { this.draftTerm = typeof index === 'number' ? index : index[0]; })
    }.width('100%').height('100%')
  }

  /** 读凭据 → 登录 → 拉本学期考试 → 解析；没有数据就显示「近期没有考试」 */
  private async load(): Promise<void> {
    const token: number = AccountScope.token();
    const request: number = ++this.request;
    const year: number = this.selectedYear; const term: number = this.selectedTerm;
    return SchoolTraffic.run(async () => {
      if (!AccountScope.valid(token) || request !== this.request) { return; }
      await this.loadNow(token, request, year, term);
    });
  }

  private async loadNow(token: number, request: number, year: number, term: number): Promise<void> {
    const cacheKey: string = AccountScope.user() + ':' + year + ':' + term;
    if (this.cacheOwner !== cacheKey) { this.exams = []; this.cacheOwner = cacheKey; }
    this.loading = this.exams.length === 0;
    this.needLogin = false;
    this.errMsg = '';
    this.now = Date.now();
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const cache: preferences.Preferences = await preferences.getPreferences(ctx, 'fxw_exam_cache');
    try {
      const savedExams: ExamRecord[] = JSON.parse(await cache.get(cacheKey, '[]') as string) as ExamRecord[];
      if (AccountScope.valid(token) && request === this.request && Array.isArray(savedExams)) { this.exams = savedExams; this.loading = savedExams.length === 0; }
    } catch (_) {}
    const cred: Credential = await CredentialStore.load(ctx);
    const saved: string = await SessionStore.loadJw();
    if (!AccountScope.valid(token)) { return; }
    const hasPwd: boolean = cred.user.length > 0 && cred.pwd.length > 0;
    if (!hasPwd && saved.length === 0) {
      this.loading = false;
      this.needLogin = this.exams.length === 0;
      return;
    }
    let parsed: ExamRecord[] = [];
    let failed: string = '';
    try {
      const auth: ZhengfangAuth = new ZhengfangAuth();
      if (saved.length > 0) {
        auth.attachSession(saved);
      }
      let logged: boolean = false;
      let loginMsg: string = '';
      let freshLogin: boolean = false;
      if (hasPwd && saved.length === 0) {
        const r: LoginResult = await auth.login(cred.user, cred.pwd);
        if (!AccountScope.valid(token)) { return; }
        logged = r.ok;
        freshLogin = r.ok;
        loginMsg = r.message;
        if (!r.ok && saved.length > 0) {
          auth.attachSession(saved);
          logged = true;
        }
      } else {
        logged = true;
      }
      if (!logged) {
        failed = loginMsg;
      } else {
        // 顺带留下登录 Cookie，给内置 Web 页免登录注入
        this.cookie = auth.cookieHeader();
        // 只有「刚登录成功」才回写会话：复用旧会话时若教务在跳转里下发了
        // 新的未认证 JSESSIONID，回写会把好会话覆盖成失效会话
        if (freshLogin) {
          if (!AccountScope.valid(token)) { return; }
          await SessionStore.saveJw(this.cookie);
        }
        const cur: Semester = { xnm: year, xqm: term, label: '' };
        // 考试一般排在学期末，先查本学期；没数据再往前查一个学期
        const bodies: string[] = [];
        try {
          bodies.push(await auth.fetchExams(cur.xnm, cur.xqm));
          if (!AccountScope.valid(token)) { return; }
        } catch (e) {
          // 单学期失败不致命，但「会话过期」要如实告诉用户
          const msg: string = (e as Error).message;
          if (!AccountScope.valid(token)) { return; }
          if (msg.indexOf('过期') >= 0) {
            if (hasPwd && !freshLogin) {
              const retry: LoginResult = await auth.login(cred.user, cred.pwd);
              if (!AccountScope.valid(token)) { return; }
              if (retry.ok) {
                this.cookie = auth.cookieHeader();
                await SessionStore.saveJw(this.cookie);
                bodies.push(await auth.fetchExams(cur.xnm, cur.xqm));
              } else { failed = retry.message; }
            } else { failed = msg; }
          } else {
            failed = msg.length > 0 ? msg : '考试安排读取失败，请稍后重试';
          }
        }
        for (let i = 0; i < bodies.length; i++) {
          const list: ExamRecord[] = ExamAdapter.parse(bodies[i]);
          for (let k = 0; k < list.length; k++) {
            parsed.push(list[k]);
          }
        }
      }
    } catch (e) {
      failed = '无法连接教务系统，请检查校园网';
    }
    if (!AccountScope.valid(token) || request !== this.request) { return; }
    this.loading = false;
    if (!failed) {
      this.exams = parsed;
      this.errMsg = '';
      await cache.put(cacheKey, JSON.stringify(parsed)); await cache.flush();
    } else { this.errMsg = failed; }
  }

  /** 下一场未结束的考试；没有则返回 null */
  private nextExam(): ExamRecord | null {
    for (let i = 0; i < this.exams.length; i++) {
      if (this.exams[i].startAt >= this.now) {
        return this.exams[i];
      }
    }
    return null;
  }

  private passed(e: ExamRecord): boolean {
    return e.startAt > 0 && e.startAt < this.now;
  }

  /** 网页查看：把 cookie 一起带过去，内置 WebView 免登录 */
  private openWeb(): void {
    router.pushUrl({
      url: 'pages/ExamWebPage',
      params: { url: EXAM_PAGE_URL, base: JW_BASE_URL, cookie: this.cookie }
    });
  }

  @Builder
  headerBar() {
    Row() {
      Row() { LineIcon({ name: 'query-back', iconSize: 24, tone: 'query-blue', strokeW: 2 }) }
        .width(44).height(44).justifyContent(FlexAlign.Center).onClick(() => router.back())
      Text('考试安排').fontSize(20).fontWeight(FontWeight.Bold).fontColor(TC(this.dark).text).layoutWeight(1).textAlign(TextAlign.Center)
      Row() { LineIcon({ name: 'query-refresh', iconSize: 22, tone: 'query-blue', strokeW: 1.8 }) }
        .width(44).height(44).justifyContent(FlexAlign.Center)
        .opacity(this.loading ? 0.5 : 1).onClick(() => { if (!this.loading) { this.load(); } })
    }.width('100%').height(56)
  }

  @Builder
  summaryCard() {
    Column() {
      Row() {
        Column() {
          Text('共安排')
            .fontSize(Font.small)
            .fontColor('#F2E4D5')
          Text(`${this.exams.length}`)
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column() {
          Text('下一场')
            .fontSize(Font.small)
            .fontColor('#F2E4D5')
          Text(this.nextLabel())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ top: 6 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1.6)
      }
      .width('100%')

      Text(this.summaryLine())
        .fontSize(Font.small)
        .fontColor('#F6EADF')
        .width('100%')
        .margin({ top: 14 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(18)
    .borderRadius(Metric.cardRadius)
    .linearGradient({
      angle: 135,
      colors: [['#C2582B', 0.0], ['#E08A4A', 1.0]]
    })
  }

  private nextLabel(): string {
    const n: ExamRecord | null = this.nextExam();
    if (n === null) {
      return '已全部结束';
    }
    const d: number = daysUntil(n.startAt, this.now);
    if (d <= 0) {
      return '就在今天';
    }
    return `${d} 天后`;
  }

  private summaryLine(): string {
    const n: ExamRecord | null = this.nextExam();
    if (n === null) {
      return '本学期的考试都过去了，成绩出来后在「我的成绩」里能看到。';
    }
    const room: string = n.room.length > 0 ? ` · ${n.room}` : '';
    return `最近一场 ${n.dateLabel} ${n.clockLabel} ${n.course}${room}`;
  }

  @Builder
  examCard(e: ExamRecord, passed: boolean) {
    Row({ space: 8 }) {
      Column() {
        Text(e.course).fontSize(16).lineHeight(22).fontWeight(FontWeight.Bold).fontColor(TC(this.dark).text).width('100%').margin({ bottom: 10 })
        Text(`课程号：${e.courseCode || '未提供'}`).fontSize(10).lineHeight(16).fontColor(TC(this.dark).textSub).width('100%')
        Text(`教师：${e.teacher || '未提供'}`).fontSize(10).lineHeight(16).fontColor(TC(this.dark).textSub).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column() {
        Text(e.room || '教室待定').fontSize(13).lineHeight(19).fontColor(TC(this.dark).text).textAlign(TextAlign.Center)
        Text(`座位：${e.seat || '未安排'}`).fontSize(11).lineHeight(18).fontColor(TC(this.dark).textSub).margin({ top: 12 })
      }.width(60).alignItems(HorizontalAlign.Center)
      Column() {
        Row({ space: 5 }) {
          LineIcon({ name: 'calendar', iconSize: 17, tone: 'query-blue' })
          Text(e.dateLabel.replace(/ (周.)$/, '（$1）')).fontSize(12).lineHeight(18).fontColor(TC(this.dark).text).layoutWeight(1)
        }.width('100%')
        Text(e.clockLabel).fontSize(12).lineHeight(18).fontColor(TC(this.dark).textHint).width('100%').padding({ left: 22 }).margin({ top: 14 })
      }.width(126).padding({ left: 9, top: 4, bottom: 4 }).border({ width: { left: 1 }, color: TC(this.dark).line })
    }.width('100%').constraintSize({ minHeight: 108 }).padding({ left: 11, right: 11, top: 13, bottom: 13 })
      .border({ width: 1, color: TC(this.dark).line }).backgroundColor(TC(this.dark).card).borderRadius(12)
  }

  private tagOf(e: ExamRecord): string {
    if (this.passed(e)) {
      return '已结束';
    }
    const d: number = daysUntil(e.startAt, this.now);
    if (e.startAt <= 0) {
      return '待定';
    }
    if (d === 0) {
      return '今天';
    }
    if (d === 1) {
      return '明天';
    }
    return `${d} 天后`;
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
        Text(`共 ${this.exams.length} 场考试`).fontSize(14).lineHeight(20).fontColor(TC(this.dark).textSub)
          .width('100%').padding({ left: 2, top: 22, bottom: 12 })
      }.width('100%').padding({ left: 14, right: 14 })
      if (this.needLogin) {
        this.centerHint('请先登录教务系统', '', '去登录', () => { router.pushUrl({ url: 'pages/LoginPage' }); })
      } else if (this.loading && this.exams.length === 0) {
        this.centerHint('正在读取考试安排…', '', '', () => {})
      } else {
        List({ space: 8 }) {
          ForEach(this.exams, (e: ExamRecord) => { ListItem() { this.examCard(e, false) } }, (e: ExamRecord) => e.id)
          if (this.exams.length === 0) {
            ListItem() { Text(this.errMsg || '该学期暂无考试安排，可切换学期查看过往考试').fontSize(14).fontColor(TC(this.dark).textSub).padding(30).width('100%').textAlign(TextAlign.Center) }
          }
          if (this.exams.length > 0) {
          ListItem() {
            Text(this.errMsg ? `更新未成功，当前显示缓存：${this.errMsg}` : '数据来源：教务考试安排')
              .fontSize(10).fontColor(TC(this.dark).textHint).width('100%').textAlign(TextAlign.Center).padding(14)
          }
          }
        }.width('100%').layoutWeight(1).padding({ left: 14, right: 14, bottom: 20 }).scrollBar(BarState.Off)
      }
    }.width('100%').height('100%').backgroundColor(TC(this.dark).bg)
      .bindSheet($$this.showTermPicker, this.termSheet(), { height: 280, dragBar: false, showClose: false, backgroundColor: TC(this.dark).card })
  }
}
