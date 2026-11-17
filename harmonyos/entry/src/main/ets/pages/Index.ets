import { BeijingClock } from '../common/util/BeijingClock';
import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import { Course, DEFAULT_PERIODS, Period, isInWeek, displayedColorIndex } from '../domain/model/Course';
import { TimetableInfo } from '../domain/repository/CourseRepository';
import { currentWeek, weekDates, weekRangeLabel, getTermConfig, TOTAL_WEEKS } from '../common/util/TermCalendar';
import { TimetableStateStore, refreshOwnedReminders, resolveSchoolTerm } from '../data/local/TimetableStateStore';
import { nextClassLabel, nextClassOf } from '../common/util/NextClass';
import { Locator } from '../app/di/ServiceLocator';
import { Db } from '../data/local/Db';
import common from '@ohos.app.ability.common';
import { WeekBar } from '../ui/components/WeekBar';
import { TimetableGrid } from '../ui/components/TimetableGrid';
import { DayList } from '../ui/components/DayList';
import { TableOption, TableSwitcher } from '../ui/components/TableSwitcher';
import { MenuSheet } from '../ui/components/MenuSheet';
import { BottomTabs } from '../ui/components/BottomTabs';
import { LineIcon } from '../ui/components/LineIcon';
import { CourseDetailSheet } from '../ui/components/CourseDetailSheet';
import router from '@ohos.router';
import curves from '@ohos.curves';
import { Credential, CredentialStore } from '../data/local/CredentialStore';
import { Profile, ProfileStore } from '../data/local/ProfileStore';
import { SyncResult } from '../domain/usecase/SyncTimetable';
import { PeriodStore } from '../data/local/PeriodStore';
import { buildWeekText } from '../common/util/ShareText';
import { CalendarExportResult, countPlannedEvents, exportCoursesToCalendar, refreshOwnedCalendarEvents } from '../common/util/CalendarExport';
import { extractShareCode, ShareCodeResult, ShareTicket, ticketMessage } from '../data/local/ShareCodeStore';
import { fetchShare, ShareSnapshot, toLocalCourses, uploadShare } from '../data/remote/ShareApi';
import { periodsLabel, weekdayLabel, weeksLabel } from '../common/util/CourseFormat';
import { AppSettings, DENSITY_HEIGHT, DEFAULT_SETTINGS, SettingsStore } from '../data/local/SettingsStore';
import pasteboard from '@ohos.pasteboard';
import hilog from '@ohos.hilog';
import preferences from '@ohos.data.preferences';
import { LEGACY_DEMO_ID_HASHES, legacyDemoIdHash } from '../data/mock/MockData';
import { WidgetRefresh } from '../widget/WidgetRefresh';
import { AccountScope } from '../common/util/AccountScope';
import { checkForUpdate } from '../common/util/UpdateCheck';

/** 清除旧版本内置演示课表的一次性标记（存在 preferences 文件 fxw_migrate） */
const MIGRATE_FILE: string = 'fxw_migrate';
const K_CLEAN_DEMO: string = 'clean_demo_v2';

/** replaceUrl 会销毁课程页；仅在同进程、同账号和同课表内复用上一帧。 */
interface TimetableViewSnapshot {
  account: string;
  accountToken: number;
  tableId: string;
  week: number;
  totalWeeks: number;
  courses: Course[];
  allCourses: Course[];
  tables: TableOption[];
  periods: Period[];
  settings: AppSettings;
  showWeekend: boolean;
  isDay: boolean;
  signature: string;
}
let lastTimetableView: TimetableViewSnapshot | null = null;

/**
 * 首页（课程 Tab）
 * 结构：标题条 / 星期条 / 课表网格 / 周数与切换课表 / 功能宫格 / 底部 Tab
 * 数据：M1 阶段使用本地 mock，M3 接入 FuwaiAdapter 后替换为仓储查询
 */
@Entry
@Component
struct Index {
  @StorageLink('clockEpoch') @Watch('onClockChange') clockEpoch: number = 0;
  private clockDay: string = '';
  private clockWeek: number = currentWeek(20);
  @State @Watch('onWeekChange') week: number = currentWeek(20);
  @State previewWeek: number = currentWeek(20);
  private weekSliding: boolean = false;
  private weekSelectionEnabled: boolean = false;
  @State showWeekend: boolean = true;
  @State activeTableId: string = 't1';
  @State courses: Course[] = [];
  /** 该课表全部课程（含其他周），用于渲染「非本周」幽灵块 */
  @State allCourses: Course[] = [];
  @State gridRevision: number = 0;
  private courseSignature: string = '';
  @State tables: TableOption[] = [];
  /** 课表重命名 / 新建弹窗 */
  @State showRename: boolean = false;
  /** 'rename' 改名；'create' 新建 */
  @State tableSheetMode: string = 'rename';
  @State renameTargetId: string = '';
  @State renameText: string = '';
  @State weekDates: string[] = [];
  @State weekMonth: string = '';
  @State todayIndex: number = -1;
  @State periods: Period[] = DEFAULT_PERIODS;
  @State settings: AppSettings = DEFAULT_SETTINGS;
  @State nextHint: string = '';
  /** 课程详情弹窗 */
  @State showDetail: boolean = false;
  @State detailCourse: Course | null = null;
  /** 作用域：false = 仅本周，true = 所有周 */
  @State detailAllWeeks: boolean = false;
  private detailWeek: number = 1;
  /** 翻周用 Swiper 控制器：周页左右滑动交给原生跟手动画 */
  private swiperCtrl: SwiperController = new SwiperController();
  /** Swiper 的 20 个页面（周号） */
  private weekPages: number[] = [];
  /** 自绘三点菜单（弹簧动画）：面板位移、遮罩透明度、是否挂载 */
  @State menuOffset: number = 1200;
  @State menuMask: number = 0;
  @State menuOpen: boolean = false;
  /** 菜单面板实际高度（vp），关闭时据此推出屏幕 */
  private menuHeight: number = 488;
  /** 日视图 / 周视图切换：是否显示当天列表、卡片绕 Y 轴翻转的角度 */
  @State isDay: boolean = false;
  @State flipY: number = 0;
  /** 转发面板（分享课表 / 导出到日程） */
  @State showForward: boolean = false;
  /** 课表顶部加号 / 导入图标的短暂按压态 */
  @State pressedToolbarIcon: string = '';
  /** 分享口令卡片 */
  @State showCodeCard: boolean = false;
  @State codeText: string = '';
  @State codeBusy: boolean = false;
  @State exportBusy: boolean = false;
  /** 浠庡彛浠ゅ鍏?*/
  @State showImport: boolean = false;
  @State importCode: string = '';
  @State importBusy: boolean = false;
  @State importPreview: ShareSnapshot | null = null;
  private importRevision: number = 0;
  private importTimer: number = -1;
  private importPreviewRevision: number = -1;
  private importToken: number = -1;
  private importTable: string = '';
  private shareRevision: number = 0;
  /** 重新导入确认（自绘浮层，AlertDialog 在本页不显示） */
  @State showRelogin: boolean = false;
  /** 导出到日历确认（同样自绘，带提前提醒选择） */
  @State showExport: boolean = false;
  @State exportTotal: number = 0;
  @State exportRemind: number = 10;
  /** 自定义提醒：滚轮面板与 3 秒提示 */
  @State showRemindWheel: boolean = false;
  @State wheelMinutes: number = 30;
  @State remindTip: string = '';
  private remindTipTimer: number = -1;
  private wheelValues: string[] = [];
  @State reloginWhen: string = '之前';

  @State totalWeeks: number = 20;
  private courseRequest: number = 0;
  private hasLoadedCourses: boolean = false;
  private restoringView: boolean = false;
  private pageRefresh: Promise<void> | null = null;

  aboutToAppear(): void {
    this.restoreView();
    this.weekPages = [];
    for (let i = 1; i <= this.totalWeeks; i++) {
      this.weekPages.push(i);
    }
    this.wheelValues = [];
    for (let m = 5; m <= 90; m++) {
      this.wheelValues.push(`${m} 分钟`);
    }
    checkForUpdate(getContext(this) as common.UIAbilityContext, this.getUIContext(), true);
    this.refreshDates();
    this.refreshPage();
  }

  /** 从登录页 / 上课时间设置返回后重新查库与读设置 */
  onPageShow(): void {
    this.cancelImport();
    this.refreshPage();
  }

  private restoreView(): void {
    const saved: TimetableViewSnapshot | null = lastTimetableView;
    if (!saved) { return; }
    if (saved.accountToken !== AccountScope.token() || saved.account !== Db.accountUser() ||
      saved.tableId !== TimetableStateStore.activeTableId()) {
      lastTimetableView = null;
      return;
    }
    this.restoringView = true;
    this.activeTableId = saved.tableId;
    this.totalWeeks = saved.totalWeeks;
    this.week = saved.week;
    this.previewWeek = saved.week;
    this.courses = saved.courses;
    this.allCourses = saved.allCourses;
    this.tables = saved.tables;
    this.periods = saved.periods;
    this.settings = saved.settings;
    this.showWeekend = saved.showWeekend;
    this.isDay = saved.isDay;
    this.courseSignature = saved.signature;
    this.hasLoadedCourses = true;
    this.restoringView = false;
  }

  private captureView(): void {
    if (!this.hasLoadedCourses) { return; }
    lastTimetableView = {
      account: Db.accountUser(), accountToken: AccountScope.token(), tableId: this.activeTableId,
      week: this.week, totalWeeks: this.totalWeeks, courses: this.courses, allCourses: this.allCourses,
      tables: this.tables, periods: this.periods, settings: this.settings,
      showWeekend: this.showWeekend, isDay: this.isDay, signature: this.courseSignature
    };
  }

  private refreshPage(): void {
    if (this.pageRefresh !== null) { return; }
    this.pageRefresh = this.doRefreshPage().finally(() => { this.pageRefresh = null; });
  }

  private async doRefreshPage(): Promise<void> {
    try { await this.loadPeriods(); } catch (e) { hilog.warn(0x0022, 'FuxiaoIdx', 'loadPeriods failed'); }
    try { await this.loadSettings(); } catch (e) { hilog.warn(0x0022, 'FuxiaoIdx', 'loadSettings failed'); }
    await this.loadAll();
  }

  onPageHide(): void {
    this.captureView();
    this.cancelWeekSelection();
    this.closeImport();
    this.shareRevision++;
    this.codeBusy = false;
    this.showCodeCard = false;
    this.codeText = '';
  }

  aboutToDisappear(): void { this.onPageHide(); }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // 整页翻转容器：标题、周日期条、课表卡片一起绕 Y 轴翻转
        Column() {
          this.headerBar()
          this.timetablePane()
        }
        .width('100%')
        .layoutWeight(1)
        .rotate({ y: 1, angle: this.flipY, centerX: '50%', centerY: '50%' })

        BottomTabs({ current: 1, dark: this.settings.dark })
      }
      .width('100%')
      .height('100%')

      // 自绘三点菜单：遮罩 + 底部面板（弹簧动画）
      if (this.menuOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')
          .opacity(this.menuMask)
          .onClick(() => this.closeMenu())

        Scroll() {
          Column({ space: 14 }) {
            Column() {
              this.weekPanel()
              Divider().color(TC(this.settings.dark).line).margin({ left: 18, right: 18 })
              TableSwitcher({
                tables: this.tables,
                activeId: $activeTableId,
                onSwitch: (id: string) => { this.loadCourses(); },
                onCreate: () => { this.closeMenu(); this.openCreate(); },
                onDelete: (t: TableOption) => this.confirmDeleteTable(t),
                onRename: (t: TableOption) => { this.closeMenu(); this.openRename(t); },
                dark: this.settings.dark
              })
            }
            .width('100%')
            .linearGradient({ angle: 110, colors: [
              [this.settings.dark ? TC(true).card : '#F9FCF9', 0],
              [this.settings.dark ? TC(true).card : '#FFF7F8', 0.5],
              [this.settings.dark ? TC(true).card : '#F1F1FF', 1]
            ] })
            .borderRadius(24)
            .clip(true)

            MenuSheet({
              dark: this.settings.dark,
              onSelect: (key: string) => {
                if (key !== 'dark') { this.closeMenu(); }
                this.onFunctionTap(key);
              }
            })
          }
          .width('100%')
          .padding({ left: 14, right: 14, bottom: 62 })
        }
        .width('100%')
        .height(this.menuHeight)
        .constraintSize({ maxHeight: '82%' })
        .scrollBar(BarState.Off)
        .align(Alignment.Bottom)
        .translate({ y: this.menuOffset })
        .gesture(
          PanGesture({ direction: PanDirection.Vertical, distance: 8 })
            .onActionUpdate((e: GestureEvent) => {
              if (e.offsetY > 0) {
                this.menuOffset = e.offsetY;
              }
            })
            .onActionEnd((e: GestureEvent) => {
              if (e.offsetY > 90) {
                this.closeMenu();
                return;
              }
              animateTo({ duration: 420, curve: curves.springMotion(0.5, 0.72) }, () => {
                this.menuOffset = 0;
              });
            })
        )
      }

      // 分享口令卡片：居中浮层，p3 那种「生成口令 + 复制」
      // 遮罩与卡片必须分两层：opacity 会整棵子树叠加，写在父层上会把白卡也变透明
      if (this.showCodeCard) {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(Color.Black)
            .opacity(0.45)
            .onClick(() => {
              this.showCodeCard = false;
            })

          Column({ space: 12 }) {
            Text('生成口令')
              .fontSize(Font.section)
              .fontWeight(FontWeight.Medium)
              .fontColor(TC(this.settings.dark).text)
              .width('100%')
            Text(this.codeText)
              .fontSize(Font.body)
              .lineHeight(21)
              .fontColor(TC(this.settings.dark).textSub)
              .width('100%')
            Text('已上传服务器 · 同学粘贴完整分享文案即可导入')
              .fontSize(Font.small)
              .fontColor(Palette.primary)
              .width('100%')
            Text('复制')
              .fontSize(Font.body)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .width('100%')
              .height(42)
              .borderRadius(21)
              .backgroundColor(Palette.primary)
              .margin({ top: 4 })
              .onClick(() => {
                this.copyCode();
              })
            Text('取消')
              .fontSize(Font.small)
              .fontColor(TC(this.settings.dark).textHint)
              .onClick(() => {
                this.showCodeCard = false;
              })
          }
          .width('86%')
          .padding({ left: 20, right: 20, top: 22, bottom: 14 })
          .backgroundColor(TC(this.settings.dark).card)
          .borderRadius(Metric.cardRadius)
          // 吃掉点击，别让遮罩层的 onClick 把卡片一起关掉
          .onClick(() => {
          })
        }
        .width('100%')
        .height('100%')
        .alignContent(Alignment.Center)
      }

      // 浠庡彛浠ゅ鍏?
      if (this.showImport) {
        this.importCard()
      }

      // 重新导入确认（课表已是最新）
      if (this.showRelogin) {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(Color.Black)
            .opacity(0.45)
            .onClick(() => {
              this.showRelogin = false;
            })

          Column({ space: 10 }) {
            Text('课表已是最新')
              .fontSize(Font.section)
              .fontWeight(FontWeight.Medium)
              .fontColor(TC(this.settings.dark).text)
            Text(`当前课表于 ${this.reloginWhen} 同步，已有 ${this.allCourses.length} 门课。继续导入会重新登录教务系统并整体替换本机课表，手动添加的课程会被覆盖。是否继续导入？`)
              .fontSize(Font.small)
              .fontColor(TC(this.settings.dark).textSub)
              .lineHeight(20)

            Row({ space: 10 }) {
              Text('取消')
                .fontSize(Font.body)
                .fontColor(TC(this.settings.dark).textSub)
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
                .height(42)
                .borderRadius(21)
                .backgroundColor(TC(this.settings.dark).chip)
                .onClick(() => {
                  this.showRelogin = false;
                })
              Text('继续导入')
                .fontSize(Font.body)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
                .height(42)
                .borderRadius(21)
                .backgroundColor(Palette.primary)
                .onClick(() => {
                  this.showRelogin = false;
                  this.goLogin();
                })
            }
            .width('100%')
            .margin({ top: 4 })
          }
          .width('86%')
          .padding({ left: 20, right: 20, top: 20, bottom: 16 })
          .borderRadius(Metric.cardRadius)
          .backgroundColor(TC(this.settings.dark).card)
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {
          })
        }
        .width('100%')
        .height('100%')
        .alignContent(Alignment.Center)
      }

      // 导出到日历确认
      if (this.showExport) {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(Color.Black)
            .opacity(0.45)
            .onClick(() => {
              this.showExport = false;
            })

          Column({ space: 10 }) {
            Text('导出到系统日历')
              .fontSize(Font.section)
              .fontWeight(FontWeight.Medium)
              .fontColor(TC(this.settings.dark).text)
            Text(`${this.allCourses.length} 门课按周次展开共 ${this.exportTotal} 条日程，会写进系统日历。重复导出会多出一份，需要的话先在日历里删掉旧的那批。`)
              .fontSize(Font.small)
              .fontColor(TC(this.settings.dark).textSub)
              .lineHeight(20)

            Text('提前提醒')
              .fontSize(Font.small)
              .fontColor(TC(this.settings.dark).textSub)
              .margin({ top: 6 })
            Row({ space: 8 }) {
              ForEach([0, 10, 15, -1], (m: number) => {
                Text(this.remindLabel(m))
                  .fontSize(Font.small)
                  .fontColor(this.remindActive(m) ? Palette.primary : TC(this.settings.dark).textSub)
                  .fontWeight(this.remindActive(m) ? FontWeight.Medium : FontWeight.Normal)
                  .textAlign(TextAlign.Center)
                  .height(30)
                  .padding({ left: 12, right: 12 })
                  .borderRadius(15)
                  .borderWidth(1)
                  .borderColor(this.remindActive(m) ? Palette.primary : TC(this.settings.dark).line)
                  .backgroundColor(this.remindActive(m) ? TC(this.settings.dark).chip : Color.Transparent)
                  .onClick(() => this.pickRemind(m))
              }, (m: number) => `r${m}`)
            }
            .width('100%')

            Row({ space: 10 }) {
              Text('取消')
                .fontSize(Font.body)
                .fontColor(TC(this.settings.dark).textSub)
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
                .height(42)
                .borderRadius(21)
                .backgroundColor(TC(this.settings.dark).chip)
                .onClick(() => {
                  this.showExport = false;
                })
              Text('导出')
                .fontSize(Font.body)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
                .height(42)
                .borderRadius(21)
                .backgroundColor(Palette.primary)
                .onClick(() => {
                  this.doExportCalendar();
                })
            }
            .width('100%')
            .margin({ top: 4 })
          }
          .width('86%')
          .padding({ left: 20, right: 20, top: 20, bottom: 16 })
          .borderRadius(Metric.cardRadius)
          .backgroundColor(TC(this.settings.dark).card)
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {
          })
        }
        .width('100%')
        .height('100%')
        .alignContent(Alignment.Center)
      }
      if (this.remindTip.length > 0) {
        Column() {
          Column({ space: 10 }) {
            Text('✓')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .width(44)
              .height(44)
              .borderRadius(22)
              .backgroundColor('#2FA36B')
            Text('已创建提醒')
              .fontSize(Font.section)
              .fontWeight(FontWeight.Medium)
              .fontColor(TC(this.settings.dark).text)
            Text(this.remindTip)
              .fontSize(Font.small)
              .fontColor(TC(this.settings.dark).textSub)
          }
          .width(210)
          .padding({ left: 18, right: 18, top: 22, bottom: 20 })
          .borderRadius(18)
          .backgroundColor(TC(this.settings.dark).card)
          .alignItems(HorizontalAlign.Center)
          .shadow({ radius: 24, color: '#1A000000', offsetY: 8 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
      }
      // 每个系统半模态使用独立的稳定宿主，避免同节点多次 bindSheet 相互覆盖。
      Stack() {}
        .width(0)
        .height(0)
        .bindSheet($$this.showRemindWheel, this.remindWheelSheet(), {
          height: 380,
          dragBar: true,
          showClose: false,
          backgroundColor: TC(this.settings.dark).card
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.settings.dark).bg)
    .bindSheet($$this.showRename, this.renameSheet(), {
      height: 210,
      dragBar: true,
      showClose: false,
      backgroundColor: TC(this.settings.dark).card
    })
  }

  /** 滚轮式提醒时长选择：5 – 90 分钟 */
  @Builder
  remindWheelSheet() {
    Column({ space: 2 }) {
      Row() {
        Text('提前多久提醒')
          .fontSize(Font.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(TC(this.settings.dark).text)
        Blank()
        Text(`${this.wheelMinutes} 分钟`)
          .fontSize(Font.small)
          .fontColor(Palette.primary)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12 })

      TextPicker({ range: this.wheelValues, selected: this.wheelIndex() })
        .width('100%')
        .height(220)
        .onChange((value: string | string[], index: number | number[]) => {
          const i: number = Array.isArray(index) ? (index as number[])[0] : (index as number);
          this.wheelMinutes = i + 5;
        })

      Row({ space: 10 }) {
        Text('取消')
          .fontSize(Font.body)
          .fontColor(TC(this.settings.dark).textSub)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(42)
          .borderRadius(21)
          .backgroundColor(TC(this.settings.dark).chip)
          .onClick(() => {
            this.showRemindWheel = false;
          })
        Text('确定')
          .fontSize(Font.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(42)
          .borderRadius(21)
          .backgroundColor(Palette.primary)
          .onClick(() => {
            this.applyWheel(this.wheelMinutes);
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 10 })
    }
    .width('100%')
  }

  private wheelIndex(): number {
    const v: number = Math.round(this.wheelMinutes) - 5;
    return v < 0 ? 0 : (v > 85 ? 85 : v);
  }

  // ---------------- 课表：重命名 / 删除 ----------------
  @Builder
  renameSheet() {
    Column({ space: 14 }) {
      // 保存放在标题行：键盘弹出会遮住 sheet 下半部分，底部按钮点不到
      Row() {
        Text(this.tableSheetMode === 'create' ? '新建课表' : '重命名课表')
          .fontSize(Font.body)
          .fontColor(TC(this.settings.dark).text)
        Blank()
        Text('保存')
          .fontSize(Font.body)
          .fontColor(Palette.primary)
          .onClick(() => {
            this.saveRename();
          })
      }
      .width('100%')
      .margin({ top: 8 })

      TextInput({ text: this.renameText })
        .height(46)
        .borderRadius(12)
        .backgroundColor(TC(this.settings.dark).chip)
        .fontColor(TC(this.settings.dark).text)
        .placeholderColor(TC(this.settings.dark).textHint)
        .maxLength(12)
        .onChange((v: string) => {
          this.renameText = v;
        })

      Text(this.tableSheetMode === 'create'
        ? '新建的课表默认是空的，之后可导入教务课表或手动添加'
        : '长按方块可随时改名；名称最多 12 个字')
        .fontSize(10)
        .fontColor(TC(this.settings.dark).textHint)
        .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 20 })
  }

  private openRename(t: TableOption): void {
    this.tableSheetMode = 'rename';
    this.renameTargetId = t.id;
    this.renameText = t.name;
    this.showRename = true;
  }

  private openCreate(): void {
    this.tableSheetMode = 'create';
    this.renameTargetId = '';
    this.renameText = '';
    this.showRename = true;
  }

  private async saveRename(): Promise<void> {
    const name: string = this.renameText.trim();
    if (name.length === 0) {
      this.toast('课表名称不能为空');
      return;
    }
    try {
      if (this.tableSheetMode === 'create') {
        const t: TimetableInfo = await Locator.repo().createTable(name);
        this.showRename = false;
        await this.reloadTables();
        this.activeTableId = t.id;
        await this.loadCourses();
        this.toast(`已新建「${name}」`);
        return;
      }
      await Locator.repo().renameTable(this.renameTargetId, name);
      this.showRename = false;
      await this.reloadTables();
      this.toast('已重命名');
    } catch (e) {
      this.toast('保存失败：' + JSON.stringify(e));
    }
  }

  private confirmDeleteTable(t: TableOption): void {
    if (this.tables.length <= 1) {
      this.toast('至少保留一个课表');
      return;
    }
    this.getUIContext().showAlertDialog({
      title: `删除「${t.name}」？`,
      message: '这个课表里的全部课程会一起删除，且无法恢复。',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#E5484D',
        action: () => {
          this.doDeleteTable(t);
        }
      }
    });
  }

  private async doDeleteTable(t: TableOption): Promise<void> {
    try {
      await Locator.repo().removeTable(t.id);
      if (this.activeTableId === t.id) {
        const rest: TableOption[] = [];
        this.tables.forEach((x: TableOption) => {
          if (x.id !== t.id) {
            rest.push(x);
          }
        });
        this.activeTableId = rest.length > 0 ? rest[0].id : 't1';
      }
      await this.reloadTables();
      await this.loadCourses();
      this.toast(`已删除「${t.name}」`);
    } catch (e) {
      this.toast('删除失败：' + JSON.stringify(e));
    }
  }

  private async reloadTables(): Promise<void> {
    try {
      await Locator.init(getContext(this) as common.UIAbilityContext);
      await Locator.ensureSeed();
      const list: TimetableInfo[] = await Locator.repo().tables();
      const opts: TableOption[] = [];
      list.forEach((x: TimetableInfo) => {
        opts.push({ id: x.id, name: x.name });
      });
      this.tables = opts;
      let matched: boolean = false;
      opts.forEach((o: TableOption) => {
        if (o.id === this.activeTableId) {
          matched = true;
        }
      });
      if (!matched && opts.length > 0) {
        this.activeTableId = opts[0].id;
      }
    } catch (e) {
      hilog.warn(0x0022, 'FuxiaoIdx', 'reloadTables failed; retain current table list');
    }
  }

  // ---------------- 三点菜单（弹簧） ----------------
  /** 打开：从底部向上弹入，过冲后小幅回弹一次 */
  private openMenu(): void {
    this.previewWeek = this.week;
    this.weekSliding = false;
    this.weekSelectionEnabled = true;
    this.menuOffset = this.menuHeight + 40;
    this.menuMask = 0;
    this.menuOpen = true;
    setTimeout(() => {
      animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
        this.menuMask = 0.45;
      });
      // 弹簧三拍：上冲 → 冲过目标位 8vp → 回弹越过 0 → 阻尼停稳
      animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
        this.menuOffset = -8;
      });
      setTimeout(() => {
        animateTo({ duration: 130, curve: Curve.EaseInOut }, () => {
          this.menuOffset = 3;
        });
        setTimeout(() => {
          animateTo({ duration: 170, curve: Curve.EaseOut }, () => {
            this.menuOffset = 0;
          });
        }, 130);
      }, 300);
    }, 16);
  }

  private closeMenu(): void {
    this.cancelWeekSelection();
    animateTo({ duration: 230, curve: Curve.EaseIn }, () => {
      this.menuOffset = this.menuHeight + 40;
      this.menuMask = 0;
    });
    setTimeout(() => {
      this.menuOpen = false;
      this.menuOffset = this.menuHeight + 40;
    }, 250);
  }

  /** 菜单顶部的周数滑块（原来在主页面上，按要求收进菜单） */
  @Builder
  weekPanel() {
    Column() {
      Row() {
        Text('周数')
          .fontSize(Font.section)
          .fontWeight(FontWeight.Medium)
          .fontColor(TC(this.settings.dark).text)
        Blank()
        Text(`第 ${this.previewWeek} 周`)
          .fontSize(Font.body)
          .fontColor(TC(this.settings.dark).text)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      }
      .width('100%')

      Row() {
        Slider({
          value: this.previewWeek,
          min: 1,
          max: this.totalWeeks,
          step: 1,
          style: SliderStyle.OutSet
        })
          .layoutWeight(1)
          .selectedColor(this.settings.dark ? TC(true).chip : '#EEF1F5')
          .blockColor(TC(this.settings.dark).card)
          .blockBorderColor(Palette.primary)
          .blockBorderWidth(2)
          .blockSize({ width: 20, height: 20 })
          .trackColor(this.settings.dark ? '#33363E' : '#E8EBF2')
          .trackThickness(6)
          .onChange((value: number, mode: SliderChangeMode) => {
            if (!this.weekSelectionEnabled) { return; }
            const selected: number = Math.max(1, Math.min(this.totalWeeks, Math.round(value)));
            if (this.previewWeek !== selected) { this.previewWeek = selected; }
            if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
              this.weekSliding = true;
            } else if (mode === SliderChangeMode.Click || (mode === SliderChangeMode.End && this.weekSliding)) {
              this.weekSliding = false;
              if (this.week !== selected) { this.week = selected; }
            }
          })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Cancel) {
              this.weekSliding = false;
              this.previewWeek = this.week;
            }
          })
      }
      .width('100%')
      .margin({ top: 6 })

      Row() {
        Text(weekRangeLabel(this.week))
          .fontSize(Font.small)
          .fontColor(TC(this.settings.dark).textHint)
        Blank()
      }
      .width('100%')
      .margin({ top: 2 })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 10 })
  }

  private cancelWeekSelection(): void {
    this.weekSelectionEnabled = false;
    this.weekSliding = false;
    this.previewWeek = this.week;
  }

  // ---------------- 鏍囬鏉?----------------
  @Builder
  headerBar() {
    Row() {
      Column() {
        Row() {
          Text(`第 ${this.displayedWeek()} 周`)
            .fontSize(Font.title)
            .fontWeight(FontWeight.Bold)
            .fontColor(TC(this.settings.dark).text)
          if (this.displayedWeek() !== currentWeek(this.totalWeeks)) {
            Text('（非本周）')
              .fontSize(Font.small)
              .fontColor(TC(this.settings.dark).textHint)
              .margin({ left: 6, top: 4 })
          }
        }
        .alignItems(VerticalAlign.Top)

        Text(weekRangeLabel(this.displayedWeek()))
          .fontSize(Font.body)
          .fontColor(TC(this.settings.dark).textSub)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 4 }) {
        this.dayWeekBtn()
        this.lineIconBtn('plus', () => this.openAddCourse())
        this.lineIconBtn('import-file', () => this.openLogin())
        this.forwardBtn()
        this.iconBtn('⋯', () => {
          this.openMenu();
        })
      }
    }
    .width('100%')
    .padding({ left: Metric.pagePadding, right: 8, top: 8, bottom: 4 })
  }

  /** 下节课提示条：纯本地推算，不依赖系统提醒服务 */
  @Builder
  nextHintBar() {
    Row() {
      Text('下节')
        .fontSize(10)
        .fontColor(Color.White)
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .backgroundColor(Palette.primary)
        .borderRadius(6)
      Text(this.nextHint)
        .fontSize(Font.small)
        .fontColor(TC(this.settings.dark).textSub)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: 8 })
    }
    .width('100%')
    .padding({ left: Metric.pagePadding, right: Metric.pagePadding, bottom: 6 })
  }

  /** 日 / 周 视图切换按钮：点一下课表卡片翻面 */
  @Builder
  dayWeekBtn() {
    Text(this.isDay ? '周' : '日')
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(Color.White)
      .width(34)
      .height(34)
      .textAlign(TextAlign.Center)
      .backgroundColor(Palette.primary)
      .borderRadius(10)
      .onClick(() => {
        this.toggleView();
      })
  }

  @Builder
  iconBtn(glyph: string, action: () => void) {
    Text(glyph)
      .fontSize(18)
      .fontColor(this.pressedToolbarIcon === 'more'
        ? (this.settings.dark ? '#FFFFFF' : '#090B10')
        : TC(this.settings.dark).text)
      .width(34)
      .height(34)
      .textAlign(TextAlign.Center)
      .borderRadius(10)
      .backgroundColor(this.pressedToolbarIcon === 'more' ? TC(this.settings.dark).chip : Color.Transparent)
      .scale({ x: this.pressedToolbarIcon === 'more' ? 0.9 : 1, y: this.pressedToolbarIcon === 'more' ? 0.9 : 1 })
      .animation({ duration: 170, curve: curves.springMotion(0.42, 0.72) })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressedToolbarIcon = 'more';
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressedToolbarIcon = '';
        }
      })
      .onClick(action)
  }

  /** 转发按钮：点开是一个两栏小气泡（分享课表 / 导出到日程） */
  @Builder
  lineIconBtn(name: string, action: () => void) {
    Stack({ alignContent: Alignment.Center }) {
      LineIcon({ name: name, iconSize: 18, tone: this.pressedToolbarIcon === name ? 'text-strong' : 'text', strokeW: 1.6 })
    }
    .width(34)
    .height(34)
    .borderRadius(10)
    .backgroundColor(this.pressedToolbarIcon === name ? TC(this.settings.dark).chip : Color.Transparent)
    .scale({ x: this.pressedToolbarIcon === name ? 0.9 : 1, y: this.pressedToolbarIcon === name ? 0.9 : 1 })
    .animation({ duration: 170, curve: curves.springMotion(0.42, 0.72) })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedToolbarIcon = name;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedToolbarIcon = '';
      }
    })
    .onClick(action)
  }

  @Builder
  forwardBtn() {
    Stack({ alignContent: Alignment.Center }) {
      LineIcon({ name: 'share-out', iconSize: 18,
        tone: this.pressedToolbarIcon === 'share-out' || this.showForward ? 'text-strong' : 'text', strokeW: 1.6 })
    }
      .width(34)
      .height(34)
      .borderRadius(10)
      .backgroundColor(this.pressedToolbarIcon === 'share-out' || this.showForward
        ? TC(this.settings.dark).chip : Color.Transparent)
      .scale({ x: this.pressedToolbarIcon === 'share-out' ? 0.9 : 1, y: this.pressedToolbarIcon === 'share-out' ? 0.9 : 1 })
      .animation({ duration: 170, curve: curves.springMotion(0.42, 0.72) })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressedToolbarIcon = 'share-out';
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressedToolbarIcon = '';
        }
      })
      .bindPopup(this.showForward, {
        builder: this.forwardMenu(),
        placement: Placement.Bottom,
        popupColor: TC(this.settings.dark).card,
        radius: 16,
        shadow: ShadowStyle.OUTER_DEFAULT_MD,
        enableArrow: false,
        offset: { x: 0, y: 4 },
        onStateChange: (e: PopupStateChangeParam) => {
          if (!e.isVisible) {
            this.showForward = false;
          }
        }
      })
      .onClick(() => {
        this.showForward = !this.showForward;
      })
  }

  /** 浠庡彛浠ゅ鍏ワ細杈撳彛浠?鈫?鏌ラ瑙?鈫?瑕嗙洊瀵煎叆 */
  @Builder
  importCard() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .opacity(0.45)
        .onClick(() => {
          this.closeImport();
        })

      Column({ space: 12 }) {
        // 主按钮放标题行：软键盘弹起来只顶到屏幕下半，这里永远点得到
        Row() {
          Text('从口令导入')
            .fontSize(Font.section)
            .fontWeight(FontWeight.Medium)
            .fontColor(TC(this.settings.dark).text)
          Blank()
          Text(this.importBusy ? '查询中' : (this.hasPreview() ? '覆盖导入' : '查询'))
            .fontSize(Font.small)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .height(30)
            .padding({ left: 16, right: 16 })
            .borderRadius(15)
            .backgroundColor(this.importBusy ? TC(this.settings.dark).textHint : Palette.primary)
            .onClick(() => {
              if (this.hasPreview()) {
                this.applyImport();
              } else {
                this.queryImport();
              }
            })
        }
        .width('100%')

        Text('无需登录，可粘贴完整分享文案或口令，预览确认后覆盖当前课表')
          .fontSize(Font.small)
          .fontColor(TC(this.settings.dark).textSub)
          .width('100%')

        TextInput({ text: this.importCode, placeholder: '粘贴分享文案或32位口令' })
          .height(46)
          .fontSize(Font.body)
          .fontColor(TC(this.settings.dark).text)
          .placeholderColor(TC(this.settings.dark).textHint)
          .backgroundColor(TC(this.settings.dark).chip)
          .borderRadius(10)
          .width('100%')
          .onChange((v: string) => {
            this.importCode = v;
            this.cancelImport();
            const parsed: ShareCodeResult = extractShareCode(v);
            if (parsed.code.length > 0) {
              this.importCode = parsed.code;
              this.importTimer = setTimeout(() => { this.queryImport(); }, 350);
            }
          })

        if (this.hasPreview()) {
          Column({ space: 4 }) {
            Text(this.previewLabel())
              .fontSize(Font.body)
              .fontColor(TC(this.settings.dark).text)
              .width('100%')
            Text('导入会覆盖当前课表，原有课程不保留')
              .fontSize(Font.small)
              .fontColor(Palette.danger)
              .width('100%')
          }
          .width('100%')
          .padding(10)
          .borderRadius(10)
          .backgroundColor(TC(this.settings.dark).chip)
        }

        Text('取消')
          .fontSize(Font.body)
          .fontColor(TC(this.settings.dark).textSub)
          .textAlign(TextAlign.Center)
          .width('100%')
          .height(42)
          .borderRadius(21)
          .backgroundColor(TC(this.settings.dark).chip)
          .onClick(() => {
            this.closeImport();
          })
      }
      .width('86%')
      .padding({ left: 20, right: 20, top: 22, bottom: 18 })
      .backgroundColor(TC(this.settings.dark).card)
      .borderRadius(Metric.cardRadius)
      .onClick(() => {
      })
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }

  @Builder
  forwardMenu() {
    Column() {
      this.forwardRow('send', '分享课表', '生成口令，发给同学使用', () => {
        this.showForward = false;
        this.makeShareCode();
      })
      Divider()
        .color(TC(this.settings.dark).line)
        .margin({ left: 44, right: 12 })
      this.forwardRow('calendar', '导出到日程', '写进系统日历，可设提醒', () => {
        this.showForward = false;
        this.confirmExportCalendar();
      })
      Divider()
        .color(TC(this.settings.dark).line)
        .margin({ left: 44, right: 12 })
      this.forwardRow('key', '从口令导入', '粘贴同学发来的口令', () => {
        this.showForward = false;
        this.cancelImport();
        this.importCode = '';
        this.showImport = true;
      })
    }
    .width(228)
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  forwardRow(icon: string, title: string, sub: string, action: () => void) {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        LineIcon({ name: icon, iconSize: 16, tone: 'sub', strokeW: 1.6 })
      }
        .width(26)
        .height(26)
        .borderRadius(8)
        .backgroundColor(TC(this.settings.dark).chip)
      Column() {
        Text(title)
          .fontSize(Font.body)
          .fontColor(TC(this.settings.dark).text)
        Text(sub)
          .fontSize(Font.tiny)
          .fontColor(TC(this.settings.dark).textHint)
          .margin({ top: 1 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .onClick(action)
  }

  @Builder
  timetablePane() {
          WeekBar({
            dates: this.weekDates,
            todayIndex: this.todayIndex,
            showWeekend: this.showWeekend,
            month: this.weekMonth,
            dark: this.settings.dark,
          })

          Scroll() {
            Column({ space: Metric.gap }) {
              this.courseArea()
            }
            .width('100%')
            .padding({ left: Metric.pagePadding, right: Metric.pagePadding })
          }
          .layoutWeight(1)
          .align(Alignment.TopStart)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .bindSheet($$this.showDetail, this.courseDetailSheet(), {
            height: 400,
            dragBar: true,
            showClose: false,
            backgroundColor: TC(this.settings.dark).card
          })
  }

  // ---------------- 课表卡片 ----------------
  /** 卡片翻面容容器：正面周课表，背面当天列表 */
  @Builder
  courseArea() {
    Column() {
      if (this.isDay) {
        this.dayCard()
      } else {
        this.gridCard()
      }
    }
    .width('100%')
  }

  /** 翻面动画：转到 90° 时换内容，再从 -90° 转回来 */
  private toggleView(): void {
    const half: number = 190;
    animateTo({ duration: half, curve: Curve.EaseIn }, () => {
      this.flipY = 90;
    });
    setTimeout(() => {
      this.isDay = !this.isDay;
      this.refreshDates();
      this.flipY = -90;
      setTimeout(() => {
        animateTo({ duration: half, curve: Curve.EaseOut }, () => {
          this.flipY = 0;
        });
      }, 16);
    }, half);
  }

  /** 背面：当天课程列表 */
  @Builder
  dayCard() {
    Column() {
      DayList({
        courses: this.allCourses,
        week: this.displayedWeek(),
        periods: this.periods,
        dark: this.settings.dark,
        onCourseTap: (c: Course) => this.openDetail(c)
      })
    }
    .width('100%')
    .padding({ left: 6, right: 6, top: 6, bottom: 12 })
    .borderRadius(Metric.cardRadius)
    .backgroundColor(TC(this.settings.dark).card)
  }

  @Builder
  gridCard() {
    Column() {
      Row() {
        Text(`第 ${this.week} 周`)
          .fontSize(Font.small)
          .fontColor(TC(this.settings.dark).textSub)
        Blank()
        Text('2026-2027学年 第1学期')
          .fontSize(Font.small)
          .fontColor(TC(this.settings.dark).textHint)
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 10, bottom: 4 })

      // 20 周全部放进 Swiper：左右滑动是原生跟手动画，邻周页已经预渲染（cachedCount 1），
      // 手指拖到一半就能看到上一周 / 下一周的真实课表，松手落位后才同步周号，不会跳变
      Swiper(this.swiperCtrl) {
        ForEach(this.weekPages, (w: number) => {
          Column() {
            if (Math.abs(w - this.week) <= 1) {
              TimetableGrid({
                courses: this.allCourses,
                week: w,
                showWeekend: this.showWeekend,
                showGhost: this.settings.showGhost,
                periods: this.periods,
                cellHeight: Math.max(this.settings.cellHeight, 68),
                cellWidth: this.settings.cellWidth,
                cellWidthRatio: this.settings.cellWidthRatio,
                dark: this.settings.dark,
                onCourseTap: (c: Course) => this.openDetail(c)
              })
            }
          }
          .width('100%')
          .height('100%')
        }, (w: number) => `w${w}-${this.gridRevision}-${this.settings.cellWidth}-${this.settings.cellWidthRatio}`)
      }
      .index(this.week - 1)
      .loop(false)
      .indicator(false)
      .cachedCount(1)
      .duration(200)
      .curve(Curve.EaseOut)
      .width('100%')
      .height(this.gridHeight())
      .onChange((index: number) => {
        const w: number = index + 1;
        if (w !== this.week) {
          this.week = w;
        }
      })
    }
    .width('100%')
    .padding({ bottom: 8 })
    .borderRadius(Metric.cardRadius)
    .backgroundColor(TC(this.settings.dark).card)
  }

  /** Swiper 必须有确定高度，否则邻周页没渲染时高度会塌陷 */
  private gridHeight(): number {
    return Math.max(this.settings.cellHeight, 68) * 12 + 16;
  }

  // ---------------- 涓夌偣鑿滃崟鍐呭宸插唴鑱斿埌 build ----------------

  /** 添加课程 */
  private openAddCourse(): void {
    router.pushUrl({
      url: 'pages/AddCoursePage',
      params: { tableId: this.activeTableId, week: this.week }
    });
  }

  // ---------------- 课程详情弹窗 ----------------
  @Builder
  courseDetailSheet() {
    Column() {
      if (this.detailCourse) {
        CourseDetailSheet({
          course: this.detailCourse as Course,
          periods: this.periods,
          dark: this.settings.dark,
          allWeeks: this.detailAllWeeks,
          displayColorIndex: this.detailColorIndex(this.detailCourse as Course),
          onScope: (all: boolean) => {
            this.detailAllWeeks = all;
          },
          onEdit: () => this.editCourse(),
          onCopy: () => this.toast('复制到其他时段（P1）'),
          onDelete: () => this.deleteCourse()
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  // ---------------- 数据（M2：走仓储，不再直接吃 mock）----------------
  private async loadAll(): Promise<void> {
    try {
      await Locator.init(getContext(this) as common.UIAbilityContext);
      await Locator.ensureSeed();
      this.activeTableId = TimetableStateStore.activeTableId();
      await this.dropLegacyDemoCourses();
      const list: TimetableInfo[] = await Locator.repo().tables();
      const opts: TableOption[] = [];
      list.forEach((t: TimetableInfo) => {
        opts.push({ id: t.id, name: t.name });
      });
      this.tables = opts;
      let matched: boolean = false;
      opts.forEach((o: TableOption) => {
        if (o.id === this.activeTableId) {
          matched = true;
        }
      });
      if (!matched && opts.length > 0) {
        this.activeTableId = opts[0].id;
      }
      await this.loadCourses();
      this.maybeAutoSync();
    } catch (e) {
      this.toast('读取本地课表失败：' + JSON.stringify(e));
    }
  }

  /**
   * 一次性迁移：旧版本首次启动会写入 16 门演示课表。
   * 现在要求未登录用户看到空课表，所以升级后清一次。
   * 只清「没有保存教务账号」的情况：已登录用户的课表是真实的，不能动。
   */
  private async dropLegacyDemoCourses(): Promise<void> {
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const p: preferences.Preferences = await preferences.getPreferences(ctx, MIGRATE_FILE);
      const done: boolean = await p.get(K_CLEAN_DEMO, false) as boolean;
      if (done) {
        return;
      }
      // 只删「id 与演示数据完全一致」的行，绝不整表清空，
      // 用户的真实课表、手动添加的课程都不受影响。
      const demoIds: Set<number> = new Set<number>(LEGACY_DEMO_ID_HASHES);
      const tableIds: string[] = ['t1', 't2'];
      let removed: number = 0;
      for (let i = 0; i < tableIds.length; i++) {
        const all: Course[] = await Locator.repo().listAll(tableIds[i]);
        const keep: Course[] = all.filter((c: Course) => !demoIds.has(legacyDemoIdHash(c.id)));
        if (keep.length !== all.length) {
          await Locator.repo().replaceAll(tableIds[i], keep);
          removed += all.length - keep.length;
        }
      }
      hilog.info(0x0022, 'FuxiaoIdx', 'legacy demo cleanup removed=%{public}d', removed);
      await p.put(K_CLEAN_DEMO, true);
      await p.flush();
    } catch (e) {
      hilog.warn(0x0022, 'FuxiaoIdx', 'clean legacy demo failed %{public}s', JSON.stringify(e));
    }
  }

  private async loadCourses(): Promise<void> {
    const request: number = ++this.courseRequest;
    const accountToken: number = AccountScope.token();
    const tableId: string = this.activeTableId;
    const requestedWeek: number = this.week;
    const current: () => boolean = () => request === this.courseRequest && tableId === this.activeTableId &&
      requestedWeek === this.week && AccountScope.valid(accountToken);
    try {
      // onPageShow 会早于 aboutToAppear 里 loadAll 的 await 完成，
      // 杩欓噷蹇呴』鑷繁鍏滃簳鎵撳紑鏁版嵁搴擄紝鍚﹀垯鍐峰惎鍔ㄧ涓€娆℃煡搴撳繀澶辫触
      await Locator.init(getContext(this) as common.UIAbilityContext);
      if (!current()) { return; }
      await TimetableStateStore.select(tableId);
      if (!current()) { return; }
      const weeks: number = getTermConfig().totalWeeks;
      if (this.totalWeeks !== weeks) {
        this.totalWeeks = weeks;
        this.weekPages = [];
        for (let w = 1; w <= weeks; w++) { this.weekPages.push(w); }
        this.week = Math.min(this.week, weeks);
      }
      if (!current()) { return; }
      this.refreshDates();
      const courses: Course[] = await Locator.repo().listByWeek(tableId, requestedWeek);
      const all: Course[] = await Locator.repo().listAll(tableId);
      if (!current()) { return; }
      this.courses = courses;
      const signature: string = JSON.stringify(all);
      if (signature !== this.courseSignature) {
        this.courseSignature = signature;
        this.gridRevision++;
      }
      this.allCourses = all;
      this.hasLoadedCourses = true;
      refreshOwnedReminders(getContext(this) as common.UIAbilityContext, all, this.periods,
        this.settings.remindBefore).catch(() => {});
      refreshOwnedCalendarEvents(getContext(this) as common.UIAbilityContext, all, this.periods).catch(() => {});
      WidgetRefresh.update(getContext(this) as common.UIAbilityContext, all, this.periods).catch(() => {});
      hilog.info(0x0022, 'FuxiaoIdx', 'load table=%{public}s week=%{public}d weekCourses=%{public}d all=%{public}d',
        this.activeTableId, this.week, this.courses.length, this.allCourses.length);
    } catch (e) {
      if (!current()) { return; }
      if (!this.hasLoadedCourses) {
        this.courses = [];
        this.allCourses = [];
      }
      this.toast('加载课程失败');
    }
    this.refreshNextHint();
    this.captureView();
  }

  /** 下节课提示条：纯本地计算，不依赖系统提醒服务 */
  private refreshNextHint(): void {
    const wd = weekDates(this.week);
    // 只有查看当前周时才提示「下一节」，看别的周没意义
    if (wd.todayIndex < 0 && this.week !== currentWeek(TOTAL_WEEKS)) {
      this.nextHint = `第 ${this.week} 周共 ${this.courses.length} 节课`;
      return;
    }
    this.nextHint = nextClassLabel(nextClassOf(this.courses, this.periods, this.week, new Date()));
  }

  /** 周数变化 → 重新查库 */
  private onWeekChange(): void {
    if (this.restoringView) { return; }
    this.refreshDates();
    this.loadCourses();
  }

  /** 让星期条的日期跟着当前周走 */
  private onClockChange(): void {
    const key: string = BeijingClock.dayKey();
    if (key !== this.clockDay) {
      const week: number = currentWeek(this.totalWeeks);
      if (this.week === this.clockWeek) { this.week = week; }
      this.clockWeek = week;
      this.clockDay = key;
      this.refreshDates();
    }
  }

  private displayedWeek(): number {
    return this.isDay ? currentWeek(this.totalWeeks) : this.week;
  }

  private refreshDates(): void {
    const wd = weekDates(this.displayedWeek());
    this.weekDates = wd.dates;
    this.weekMonth = wd.month;
    this.todayIndex = wd.todayIndex;
  }

  // ---------------- 交互 ----------------
  private onMenuTap(key: string): void {
    switch (key) {
      case 'close':
        break;
      case 'refresh':
        this.quickRefresh();
        break;
      case 'import':
        this.openLogin();
        break;
      case 'period':
        this.onFunctionTap('period');
        break;
      case 'share':
        this.shareWeek();
        break;
      case 'term':
        this.go('pages/TermPage');
        break;
      case 'appearance':
        this.go('pages/AppearancePage');
        break;
      case 'account':
        this.go('pages/AccountPage');
        break;
      case 'about':
        this.go('pages/AboutPage');
        break;
      default:
        this.toast(`${key}（P1）`);
    }
  }

  private go(url: string): void {
    router.pushUrl({ url: url }).catch((e: Error) => {
      this.toast('打开页面失败：' + e.message);
    });
  }

  private async loadSettings(): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const s: AppSettings = await SettingsStore.load(ctx);
    this.settings = s;
    // 课表固定按 7 天排版：设置页的实时预览也是 7 天，两边列宽必须一致
    this.showWeekend = true;
    AppStorage.setOrCreate('dark', s.dark);
  }

  private async loadPeriods(): Promise<void> {
    PeriodStore.init(getContext(this) as common.UIAbilityContext);
    this.periods = await PeriodStore.load();
    this.refreshNextHint();
  }

  private onFunctionTap(key: string): void {
    switch (key) {
      case 'period':
        this.openPeriodSettings();
        break;
      case 'table':
        this.go('pages/TimetableSettings');
        break;
      case 'courses':
        this.go('pages/CourseListPage');
        break;
      case 'widget':
        this.go('pages/WidgetGuide');
        break;
      case 'remind':
        this.go('pages/RemindPage');
        break;
      case 'contact':
        this.go('pages/AboutPage');
        break;
      case 'dark':
        this.settings.dark = !this.settings.dark;
        AppStorage.setOrCreate('dark', this.settings.dark);
        this.persistSettings();
        this.toast(this.settings.dark ? '已切到夜间模式' : '已切回浅色');
        break;
      case 'theme':
        this.go('pages/AppearancePage');
        break;
      case 'update':
        checkForUpdate(getContext(this) as common.UIAbilityContext, this.getUIContext());
        break;
      default:
        this.toast(`${key}（P1）`);
    }
  }

  private persistSettings(): void {
    SettingsStore.save(getContext(this) as common.UIAbilityContext, this.settings);
  }

  /**
   * 导入课表入口
   * 已经有课表时不直接跳登录页，先确认一次——导入会整表替换，手加课会被冲掉
   */
  private async openLogin(): Promise<void> {
    hilog.info(0x0022, 'FuxiaoLogin', 'openLogin tapped, all=%{public}d', this.allCourses.length);
    // 未登录：直接进登录页，不弹「课表已是最新」
    let signedIn: boolean = false;
    let when: string = '之前';
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const cred: Credential = await CredentialStore.load(ctx);
      signedIn = cred.user.length > 0;
      const ts: number = await CredentialStore.lastSyncAt(ctx);
      when = this.fmtTime(ts);
    } catch (e) {
      signedIn = false;
    }
    if (!signedIn || this.allCourses.length === 0) {
      this.goLogin();
      return;
    }
    // 本页有 bindPopup / bindSheet 时 showAlertDialog 不显示，用自绘浮层代替
    this.reloginWhen = when;
    this.showRelogin = true;
  }

  private fmtTime(ts: number): string {
    if (ts <= 0) {
      return '从未同步';
    }
    const d: Date = new Date(ts);
    const pad = (n: number): string => n < 10 ? `0${n}` : `${n}`;
    return `${d.getMonth() + 1}月${d.getDate()}日 ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  private goLogin(): void {
    router.pushUrl({ url: 'pages/LoginPage' }).catch((e: Error) => {
      this.toast('打开登录页失败：' + e.message);
    });
  }

  private openPeriodSettings(): void {
    router.pushUrl({ url: 'pages/PeriodSettings' }).catch((e: Error) => {
      this.toast('打开设置页失败：' + e.message);
    });
  }

  /** 三点菜单里的『刷新课表』：有保存的凭据就静默同步，没有就引导去登录 */
  private async quickRefresh(): Promise<void> {
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const cred: Credential = await CredentialStore.load(ctx);
      if (cred.user.length === 0 || cred.pwd.length === 0) {
        this.toast('还没有保存的教务账号，先登录一次');
        this.goLogin();
        return;
      }
      this.toast('正在刷新课表…');
      const r: SyncResult = await Locator.syncAndSave(cred.user, cred.pwd, this.activeTableId);
      if (r.captcha.byteLength > 0) {
        this.toast('教务要求验证码，请到导入课表页完成验证');
        this.goLogin();
        return;
      }
      if (r.ok) {
        await CredentialStore.markSyncAt(getContext(this) as common.UIAbilityContext, Date.now());
        await this.loadCourses();
        this.toast(r.message);
      } else {
        this.toast('刷新失败：' + r.message);
      }
    } catch (e) {
      this.toast('刷新异常：' + (e instanceof Error ? e.message : JSON.stringify(e)));
    }
  }

  /** 启动时的静默刷新：勾选了「每天自动更新」且今天还没更新过才跑，失败不打扰用户 */
  private async maybeAutoSync(): Promise<void> {
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const cred: Credential = await CredentialStore.load(ctx);
      if (cred.user.length === 0 || cred.pwd.length === 0) {
        return;
      }
      if (!cred.autoUpdate) {
        hilog.info(0x0022, 'FuxiaoIdx', 'auto sync skipped: disabled by user');
        return;
      }
      const today: string = CredentialStore.today();
      const lastDay: string = await CredentialStore.autoUpdateDay(ctx);
      if (lastDay === today) {
        hilog.info(0x0022, 'FuxiaoIdx', 'auto sync skipped: already done today');
        return;
      }
      hilog.info(0x0022, 'FuxiaoIdx', 'auto sync start day=%{public}s', today);
      const r: SyncResult = await Locator.syncAndSave(cred.user, cred.pwd, this.activeTableId);
      if (r.ok) {
        await CredentialStore.markSyncAt(ctx, Date.now());
        await CredentialStore.markAutoUpdateDay(ctx, today);
        await this.loadCourses();
        hilog.info(0x0022, 'FuxiaoIdx', 'auto sync ok, %{public}d courses', r.count);
      } else if (r.captcha.byteLength > 0) {
        // 后台静默刷新遇到验证码只能停下来，等用户自己去导入页验证；今天不算更新过
        hilog.warn(0x0022, 'FuxiaoIdx', 'auto sync needs captcha, waiting for user');
      } else {
        hilog.warn(0x0022, 'FuxiaoIdx', 'auto sync failed %{public}s', r.message);
      }
    } catch (e) {
      hilog.error(0x0022, 'FuxiaoIdx', 'auto sync error %{public}s', JSON.stringify(e));
    }
  }

  /** 仅服务器确认上传成功后提供可分享口令，不再生成本机占位口令。 */
  private async makeShareCode(): Promise<void> {
    if (this.codeBusy) { return; }
    if (this.allCourses.length === 0) { this.toast('课表还是空的，先导入课表'); return; }
    const request: number = ++this.shareRevision;
    const token: number = AccountScope.token();
    const tableId: string = this.activeTableId;
    const courses: Course[] = this.allCourses;
    const periods: Period[] = this.periods;
    const term: string = getTermConfig().label;
    const week: number = this.week;
    this.codeBusy = true;
    this.showCodeCard = false;
    this.codeText = '';
    try {
      const code: string = await uploadShare(courses, periods, term, week);
      if (request !== this.shareRevision || !AccountScope.valid(token) || tableId !== this.activeTableId) { return; }
      const ticket: ShareTicket = { code: code, createdAt: Date.now(), term: term, week: week,
        courses: courses, periods: periods, uploaded: true };
      this.codeText = ticketMessage(ticket, this.totalWeeks);
      this.showCodeCard = true;
    } catch (e) {
      if (request === this.shareRevision && AccountScope.valid(token)) {
        this.toast('分享失败，请重试：' + (e instanceof Error ? e.message : '网络异常'));
      }
    } finally {
      if (request === this.shareRevision) { this.codeBusy = false; }
    }
  }

  private cancelImport(): void {
    this.importRevision++;
    if (this.importTimer >= 0) { clearTimeout(this.importTimer); this.importTimer = -1; }
    this.importPreview = null;
    this.importPreviewRevision = -1;
    this.importBusy = false;
  }

  private closeImport(): void {
    this.cancelImport();
    this.showImport = false;
  }

  private importCurrent(request: number, token: number, tableId: string): boolean {
    return this.showImport && request === this.importRevision && AccountScope.valid(token) && tableId === this.activeTableId;
  }

  private hasPreview(): boolean {
    return this.importPreview !== null;
  }

  private previewLabel(): string {
    const s: ShareSnapshot | null = this.importPreview;
    if (s === null) {
      return '';
    }
    return `${s.courses.length} 门课 · ${s.term} · 第 ${s.week} 周`;
  }

  /** 完整文案先解析为唯一口令；旧输入/旧身份的响应不得显示为可导入预览。 */
  private async queryImport(): Promise<void> {
    const parsed: ShareCodeResult = extractShareCode(this.importCode);
    if (parsed.code.length === 0) { this.toast(parsed.error); return; }
    if (this.importBusy || !this.showImport) { return; }
    this.cancelImport();
    const request: number = this.importRevision;
    const token: number = AccountScope.token();
    const tableId: string = this.activeTableId;
    this.importCode = parsed.code;
    this.importBusy = true;
    try {
      const snap: ShareSnapshot | null = await fetchShare(parsed.code);
      if (!this.importCurrent(request, token, tableId)) { return; }
      if (snap === null) { this.toast('口令不存在或已过期'); return; }
      this.importPreview = snap;
      this.importPreviewRevision = request;
      this.importToken = token;
      this.importTable = tableId;
    } catch (e) {
      if (this.importCurrent(request, token, tableId)) {
        this.toast('查询失败：' + (e instanceof Error ? e.message : '网络异常'));
      }
    } finally {
      if (request === this.importRevision) { this.importBusy = false; }
    }
  }

  /** 游客与登录用户均可确认覆盖；数据库事务在身份变更时回滚。 */
  private async applyImport(): Promise<void> {
    const snap: ShareSnapshot | null = this.importPreview;
    const request: number = this.importPreviewRevision;
    const token: number = this.importToken;
    const tableId: string = this.importTable;
    if (snap === null || this.importBusy) { return; }
    if (!this.importCurrent(request, token, tableId)) { this.cancelImport(); return; }
    this.importBusy = true;
    try {
      const list: Course[] = toLocalCourses(snap.courses);
      const metadata = resolveSchoolTerm(snap.term);
      if (metadata === null && snap.term !== getTermConfig().label) {
        throw new Error('该学期的开学日期尚未配置，无法正确导入');
      }
      await Locator.repo().replaceAll(tableId, list, false, token, () => this.importCurrent(request, token, tableId));
      if (!this.importCurrent(request, token, tableId)) { return; }
      if (metadata !== null) {
        await TimetableStateStore.saveTerm(tableId, metadata, token, () => this.importCurrent(request, token, tableId));
      }
      if (!this.importCurrent(request, token, tableId)) { return; }
      if (snap.periods.length > 0) {
        if (!await PeriodStore.save(snap.periods, token, () => this.importCurrent(request, token, tableId))) {
          throw new Error('课程已导入，上课时间保存失败，请重试');
        }
        if (!this.importCurrent(request, token, tableId)) { return; }
        this.periods = snap.periods;
      }
      await this.loadCourses();
      if (!this.importCurrent(request, token, tableId)) { return; }
      this.closeImport();
      this.importCode = '';
      this.toast(`已导入 ${list.length} 门课`);
    } catch (e) {
      if (this.importCurrent(request, token, tableId)) {
        this.toast('导入失败：' + (e instanceof Error ? e.message : '数据异常'));
      }
    } finally {
      if (request === this.importRevision) { this.importBusy = false; }
    }
  }

  /** 复制口令文案到剪贴板 */
  private async copyCode(): Promise<void> {
    try {
      const data: pasteboard.PasteData =
        pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.codeText);
      await pasteboard.getSystemPasteboard().setData(data);
      this.showCodeCard = false;
      this.toast('口令已复制，发给同学即可');
    } catch (e) {
      this.toast('复制失败：' + (e instanceof Error ? e.message : JSON.stringify(e)));
    }
  }

  /** 瀵煎嚭鍓嶅厛鎶ユ潯鏁帮紝鐢ㄦ埛鐐瑰ご鍐嶅啓 */
  private confirmExportCalendar(): void {
    const total: number = countPlannedEvents(this.allCourses);
    if (total === 0) {
      this.toast('当前课表还没有课程');
      return;
    }
    this.exportTotal = total;
    this.exportRemind = this.settings.calendarRemind ? 10 : 0;
    this.showExport = true;
  }

  private async doExportCalendar(): Promise<void> {
    if (this.exportBusy) {
      return;
    }
    this.exportBusy = true;
    this.showExport = false;
    this.toast('正在写入系统日历…');
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const r: CalendarExportResult = await exportCoursesToCalendar(ctx, this.allCourses, this.periods,
        this.exportRemind);
      this.toast(r.message);
      hilog.info(0x0000, 'FuxiaoShare', 'export ok=%{public}s count=%{public}d remind=%{public}d',
        `${r.ok}`, r.count, this.exportRemind);
    } catch (e) {
      this.toast('导出失败：' + (e instanceof Error ? e.message : JSON.stringify(e)));
    } finally {
      this.exportBusy = false;
    }
  }

  /** 提醒 chip 文案：不提醒 / 10 分钟 / 15 分钟 / 自定义（选过则显示具体分钟） */
  private remindLabel(m: number): string {
    if (m === 0) {
      return '不提醒';
    }
    if (m === -1) {
      return this.isCustomRemind() ? `${this.exportRemind} 分钟` : '自定义';
    }
    return `${m} 分钟`;
  }

  /** 当前值是否落在自定义区间（不是 0 / 10 / 15 就算自定义） */
  private isCustomRemind(): boolean {
    return this.exportRemind !== 0 && this.exportRemind !== 10 && this.exportRemind !== 15;
  }

  private remindActive(m: number): boolean {
    if (m === -1) {
      return this.isCustomRemind();
    }
    return this.exportRemind === m;
  }

  private pickRemind(m: number): void {
    if (m === -1) {
      this.wheelMinutes = this.isCustomRemind() ? this.exportRemind : 30;
      this.showRemindWheel = true;
      return;
    }
    this.exportRemind = m;
  }

  /** 滚轮选完：落到 exportRemind 并弹 3 秒提示 */
  private applyWheel(minutes: number): void {
    this.exportRemind = minutes;
    this.showRemindWheel = false;
    this.showRemindTip(`已设为提前 ${minutes} 分钟提醒`);
  }

  private showRemindTip(text: string): void {
    this.remindTip = text;
    if (this.remindTipTimer >= 0) {
      clearTimeout(this.remindTipTimer);
    }
    this.remindTipTimer = setTimeout(() => {
      this.remindTip = '';
      this.remindTipTimer = -1;
    }, 3000);
  }

  /** 分享当前周课表：拼成文本放进系统剪贴板 */
  private async shareWeek(): Promise<void> {
    try {
      const text: string = buildWeekText(this.week, this.courses, this.periods);
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await pasteboard.getSystemPasteboard().setData(data);
      this.toast('本周课表已复制到剪贴板');
    } catch (e) {
      this.toast('复制失败：' + (e instanceof Error ? e.message : JSON.stringify(e)));
    }
  }

  /** 点课程块 → 弹出详情 */
  private openDetail(c: Course): void {
    this.detailCourse = c;
    // 点的是「非本周」的幽灵块时，本周本来就没有这门课，
    // 作用域默认落到「所有周」，否则「仅本周删除」会删空气
    this.detailWeek = this.displayedWeek();
    this.detailAllWeeks = !isInWeek(c, this.detailWeek);
    this.showDetail = true;
  }

  private detailColorIndex(c: Course): number {
    let first: number = c.startPeriod;
    this.allCourses.forEach((item: Course) => {
      if (item.weekday === c.weekday && item.startPeriod < first) { first = item.startPeriod; }
    });
    return displayedColorIndex(c, c.startPeriod === first);
  }

  private editCourse(): void {
    const c: Course | null = this.detailCourse;
    if (!c) { return; }
    this.showDetail = false;
    router.pushUrl({ url: 'pages/AddCoursePage',
      params: { tableId: this.activeTableId, week: this.detailWeek, editId: c.id } }).catch((e: Error) => {
      this.toast('打开编辑页失败：' + e.message);
    });
  }

  /** 删除课程：按当前作用域决定只摘掉本周还是整条删除 */
  private async deleteCourse(): Promise<void> {
    const c: Course | null = this.detailCourse;
    if (!c) {
      return;
    }
    try {
      if (this.detailAllWeeks) {
        await Locator.repo().remove(c.id);
        this.toast(`已删除「${c.name}」`);
      } else {
        const left: number[] = c.weeks.filter((w: number) => w !== this.detailWeek);
        if (left.length === 0) {
          await Locator.repo().remove(c.id);
          this.toast(`已删除「${c.name}」`);
        } else {
          const kept: Course = {
            id: c.id, name: c.name, teacher: c.teacher, room: c.room, campus: c.campus,
            weekday: c.weekday, startPeriod: c.startPeriod, endPeriod: c.endPeriod,
            weeks: left, colorIndex: c.colorIndex, colorOverride: c.colorOverride
          };
          await Locator.repo().remove(c.id);
          await Locator.repo().add(kept, this.activeTableId);
          this.toast(`已从第 ${this.detailWeek} 周移除「${c.name}」`);
        }
      }
      this.showDetail = false;
      this.detailCourse = null;
      await this.loadCourses();
    } catch (e) {
      this.toast('删除失败：' + (e instanceof Error ? e.message : JSON.stringify(e)));
    }
  }

  private nameOf(id: string): string {
    const t: TableOption | undefined = this.tables.find((x: TableOption) => x.id === id);
    return t ? t.name : id;
  }

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1600 });
    } catch (e) {
      console.error('toast failed: ' + JSON.stringify(e));
    }
  }
}
