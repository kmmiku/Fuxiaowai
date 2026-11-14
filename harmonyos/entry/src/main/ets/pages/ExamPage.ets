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
  @State loading: boolean = true;
  @State needLogin: boolean = false;
  @State errMsg: string = '';
  @State exams: ExamRecord[] = [];
  @State cookie: string = '';
  @State now: number = Date.now();

  aboutToAppear(): void {
    this.load();
  }

  /** 读凭据 → 登录 → 拉本学期考试 → 解析；没有数据就显示「近期没有考试」 */
  private async load(): Promise<void> {
    const token: number = AccountScope.token();
    return SchoolTraffic.run(async () => {
      if (!AccountScope.valid(token)) { return; }
      await this.loadNow(token);
    });
  }

  private async loadNow(token: number): Promise<void> {
    this.loading = true;
    this.needLogin = false;
    this.errMsg = '';
    this.now = Date.now();
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const cred: Credential = await CredentialStore.load(ctx);
    const saved: string = await SessionStore.loadJw();
    if (!AccountScope.valid(token)) { return; }
    const hasPwd: boolean = cred.user.length > 0 && cred.pwd.length > 0;
    if (!hasPwd && saved.length === 0) {
      this.loading = false;
      this.needLogin = true;
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
        const cur: Semester = currentSemester(new Date());
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
    if (!AccountScope.valid(token)) { return; }
    this.loading = false;
    if (parsed.length > 0) {
      this.exams = parsed;
      this.errMsg = '';
      return;
    }
    this.exams = [];
    this.errMsg = failed.length > 0 ? failed : '教务还没有发布本学期考试安排';
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
      Text('‹')
        .fontSize(26)
        .fontColor(TC(this.dark).text)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          router.back();
        })
      Text('考试安排')
        .fontSize(Font.title)
        .fontWeight(FontWeight.Bold)
        .fontColor(TC(this.dark).text)
        .margin({ left: 4 })
      Blank()
      Text('↻')
        .fontSize(18)
        .fontColor(this.loading ? TC(this.dark).textHint : TC(this.dark).text)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          if (!this.loading) {
            this.load();
          }
        })
    }
    .width('100%')
    .padding({ left: 6, right: 10, top: 6, bottom: 6 })
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
    Row() {
      // 左侧日期块
      Column() {
        Text(`${new Date(e.startAt > 0 ? e.startAt : this.now).getDate()}`)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(passed ? TC(this.dark).textHint : '#C2582B')
        Text(`${new Date(e.startAt > 0 ? e.startAt : this.now).getMonth() + 1}月`)
          .fontSize(10)
          .fontColor(passed ? TC(this.dark).textHint : '#C2582B')
          .margin({ top: 1 })
      }
      .width(52)
      .height(e.clockLabel.length > 0 ? 62 : 52)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(passed
        ? (this.dark ? '#23262D' : '#EDEFF3')
        : (this.dark ? '#33251B' : '#FBEBDE'))
      .borderRadius(12)
      .margin({ right: 12 })

      Column() {
        Row() {
          Text(e.course)
            .fontSize(Font.body)
            .fontWeight(FontWeight.Medium)
            .fontColor(passed ? TC(this.dark).textSub : TC(this.dark).text)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(this.tagOf(e))
            .fontSize(Font.tiny)
            .fontColor(passed ? TC(this.dark).textHint : '#C2582B')
            .padding({ left: 7, right: 7, top: 2, bottom: 2 })
            .backgroundColor(passed
              ? (this.dark ? '#23262D' : '#EDEFF3')
              : (this.dark ? '#33251B' : '#FBEBDE'))
            .borderRadius(8)
            .margin({ left: 6 })
        }
        .width('100%')

        Row() {
          Text(e.dateLabel)
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textSub)
          if (e.clockLabel.length > 0) {
            Text('·')
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textHint)
              .margin({ left: 5, right: 5 })
            Text(e.clockLabel)
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textSub)
          }
        }
        .width('100%')
        .margin({ top: 5 })

        Row() {
          if (e.room.length > 0) {
            Text('考场')
              .fontSize(Font.tiny)
              .fontColor(TC(this.dark).textHint)
            Text(e.room)
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textSub)
              .margin({ left: 4 })
          }
          if (e.seat.length > 0) {
            Text('·')
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textHint)
              .margin({ left: 6, right: 6 })
            Text(`${e.seat} 号`)
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textSub)
          }
          if (e.method.length > 0) {
            Text('·')
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textHint)
              .margin({ left: 6, right: 6 })
            Text(e.method)
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textSub)
          }
        }
        .width('100%')
        .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor(TC(this.dark).card)
    .borderRadius(12)
    .margin({ bottom: 8 })
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

      if (this.needLogin) {
        this.centerHint('还没有保存教务账号', '先在首页用 ⇩ 登录一次，之后就能直接看考试安排', '去登录', () => {
          router.pushUrl({ url: 'pages/LoginPage' });
        })
      } else if (this.loading) {
        Column() {
          LoadingProgress()
            .width(44)
            .height(44)
            .color(Palette.primary)
          Text('正在读取考试安排…')
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textSub)
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.exams.length === 0) {
        Column() {
          Column() {
            Text('近期没有考试')
              .fontSize(Font.section)
              .fontWeight(FontWeight.Medium)
              .fontColor(TC(this.dark).text)
            Text(this.errMsg)
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textSub)
              .margin({ top: 10 })
              .textAlign(TextAlign.Center)
            Text('期末考试一般提前两三周才排定，到时候点右上角 ↻ 重新读取。')
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textHint)
              .margin({ top: 6 })
              .textAlign(TextAlign.Center)
            Text('重新读取')
              .fontSize(Font.body)
              .fontColor(Color.White)
              .padding({ left: 24, right: 24, top: 10, bottom: 10 })
              .backgroundColor(Palette.primary)
              .borderRadius(10)
              .margin({ top: 22 })
              .onClick(() => {
                if (!this.loading) {
                  this.load();
                }
              })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .padding(32)

          Text('用网页查看教务原始页面 ›')
            .fontSize(Font.small)
            .fontColor(Palette.primary)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 24 })
            .onClick(() => this.openWeb())
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ListItem() {
            this.summaryCard()
          }
          .margin({ bottom: 4 })

          ForEach(this.exams, (e: ExamRecord) => {
            ListItem() {
              this.examCard(e, this.passed(e))
            }
          }, (e: ExamRecord) => e.id)

          ListItem() {
            Column() {
              Text('用网页查看教务原始页面 ›')
                .fontSize(Font.small)
                .fontColor(Palette.primary)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 12, bottom: 12 })
                .onClick(() => this.openWeb())
              Text('数据来源：正方教务系统 · 点右上角 ↻ 重新读取')
                .fontSize(10)
                .fontColor(TC(this.dark).textHint)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ bottom: 24 })
            }
            .width('100%')
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 14, right: 14 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
  }
}
