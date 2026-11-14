import { AccountScope } from '../common/util/AccountScope';
import router from '@ohos.router';
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
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State needLogin: boolean = false;
  @State errMsg: string = '';
  @State terms: TermGrades[] = [];
  @State allItems: GradeRecord[] = [];
  @State activeTerm: number = -1;   // -1 = 全部
  @State showTermPicker: boolean = false;
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
    if (this.activeTerm < 0) {
      return this.allItems;
    }
    if (this.activeTerm >= this.terms.length) {
      return this.allItems;
    }
    return this.terms[this.activeTerm].items;
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
      Column() {
        Text('我的成绩')
          .fontSize(Font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(TC(this.dark).text)
        if (this.cachedAt > 0) {
          Row() {
            // 状态点表示本地成绩快照可用，不代表教务身份仍有效
            Circle({ width: 6, height: 6 })
              .fill('#2BB673')
            Text(this.statusText())
              .fontSize(Font.tiny)
              .fontColor(TC(this.dark).textHint)
              .margin({ left: 5 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .margin({ top: 3 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 普通刷新（只重新拉数据，不动身份）
      Text(this.refreshing ? '···' : '↻')
        .fontSize(18)
        .fontColor(this.refreshing ? TC(this.dark).textHint : TC(this.dark).text)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          if (!this.refreshing) {
            this.refresh(false);
          }
        })

      // 身份验证刷新：按下 90% 压缩，松手弹回；点了回登录页重新验证
      Row() {
        Text(this.cacheStatus === 'expired' ? '重新验证' : '身份验证')
          .fontSize(Font.small)
          .fontWeight(FontWeight.Medium)
          .fontColor(Palette.primary)
      }
      .height(32)
      .padding({ left: 12, right: 12 })
      .borderRadius(16)
      .backgroundColor(this.dark ? '#2A3350' : '#EEF1FF')
      .scale({ x: this.verifyPressed ? 0.9 : 1, y: this.verifyPressed ? 0.9 : 1 })
      .animation({ duration: 170, curve: curves.springMotion(0.42, 0.72) })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          this.verifyPressed = true;
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.verifyPressed = false;
        }
      })
      .onClick(() => this.goVerify())
    }
    .width('100%')
    .padding({ left: 12, right: 10, top: 6, bottom: 6 })
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
  @Builder
  termBar() {
    Row() {
      Text('学期')
        .fontSize(Font.small)
        .fontColor(TC(this.dark).textSub)
      Text(this.termTitle())
        .fontSize(Font.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(TC(this.dark).text)
        .margin({ left: 8 })
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text('▾')
        .fontSize(13)
        .fontColor(TC(this.dark).textHint)
    }
    .width('100%')
    .height(44)
    .padding({ left: 14, right: 14 })
    .borderRadius(12)
    .backgroundColor(TC(this.dark).card)
    .onClick(() => {
      this.showTermPicker = true;
    })
  }

  @Builder
  termSheet() {
    Column() {
      Row() {
        Text('选择学期')
          .fontSize(Font.section)
          .fontWeight(FontWeight.Medium)
          .fontColor(TC(this.dark).text)
        Blank()
        Text('完成')
          .fontSize(Font.body)
          .fontColor(Palette.primary)
          .onClick(() => {
            this.showTermPicker = false;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 4, bottom: 4 })

      TextPicker({ range: this.termLabels(), selected: this.termIndex() })
        .width('100%')
        .height(180)
        .selectedTextStyle({ color: Palette.primary, font: { size: 17, weight: FontWeight.Medium } })
        .textStyle({ color: TC(this.dark).textSub, font: { size: 15 } })
        .onChange((value: string | string[], index: number | number[]) => {
          const i: number = typeof index === 'number' ? index : index[0];
          this.activeTerm = i - 1;
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  gradeRow(g: GradeRecord) {
    Row() {
      Column() {
        Text(g.courseName)
          .fontSize(Font.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(TC(this.dark).text)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Row() {
          Text(`${g.credit} 学分`)
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textSub)
          if (g.nature.length > 0) {
            Text('·')
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textHint)
              .margin({ left: 5, right: 5 })
            Text(g.nature)
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textSub)
          }
          if (g.teacher.length > 0) {
            Text('·')
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textHint)
              .margin({ left: 5, right: 5 })
            Text(g.teacher)
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textSub)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
        }
        .width('100%')
        .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column() {
        Text(g.scoreText)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(LEVEL_FG[scoreLevel(g.score, g.score > 0)])
        Text(g.gpa > 0 ? `绩点 ${g.gpa.toFixed(1)}` : ' ')
          .fontSize(9)
          .fontColor(TC(this.dark).textHint)
          .margin({ top: 1 })
      }
      .width(64)
      .height(46)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.dark
        ? LEVEL_DARK_BG[scoreLevel(g.score, g.score > 0)]
        : LEVEL_BG[scoreLevel(g.score, g.score > 0)])
      .borderRadius(10)
      .margin({ left: 10 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(TC(this.dark).card)
    .borderRadius(12)
    .margin({ bottom: 8 })
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
        this.centerHint('还没有成绩数据', '去导入课表页登录一次，成绩会自动存到本地，之后没网也能看', '去登录', () => {
          this.goVerify();
        })
      } else if (this.loading) {
        Column() {
          LoadingProgress()
            .width(44)
            .height(44)
            .color(Palette.primary)
          Text('正在读取成绩…')
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textSub)
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.errMsg.length > 0 && !this.hasCache) {
        this.centerHint('没拿到成绩', this.errMsg, '重试', () => {
          this.refresh(false);
        })
      } else {
        List({ space: 8 }) {
          // 有缓存但这次没刷成功：明说这是离线数据，并给一键重新验证
          if (this.errMsg.length > 0 && !this.hasCache) {
            ListItem() {
              Row() {
                Text(this.errMsg)
                  .fontSize(Font.small)
                  .fontColor(TC(this.dark).textSub)
                  .layoutWeight(1)
                Text('重新验证')
                  .fontSize(Font.small)
                  .fontColor(Palette.primary)
                  .margin({ left: 10 })
                  .onClick(() => this.goVerify())
              }
              .width('100%')
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .borderRadius(12)
              .backgroundColor(this.dark ? '#2A2419' : '#FFF7E8')
            }
          }

          ListItem() {
            this.summaryCard()
          }
          .margin({ bottom: 4 })

          ListItem() {
            this.termBar()
          }

          ForEach(this.shown(), (g: GradeRecord) => {
            ListItem() {
              this.gradeRow(g)
            }
          }, (g: GradeRecord, i: number) => `${g.courseNo}-${g.courseName}-${g.xnm}-${g.xqm}-${i}`)

          ListItem() {
            Text(`数据来源：正方教务系统${this.statusText().length > 0 ? ' · ' + this.statusText() : ''}`)
              .fontSize(10)
              .fontColor(TC(this.dark).textHint)
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 10, bottom: 24 })
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 14, right: 14 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }

      BottomTabs({ current: 2, dark: this.dark })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
    .bindSheet($$this.showTermPicker, this.termSheet(), {
      height: 268,
      dragBar: true,
      showClose: false,
      backgroundColor: TC(this.dark).card
    })
  }
}
