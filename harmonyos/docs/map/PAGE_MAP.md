# 页面 Map

更新：2026-11-14。依据当前实际源码静态核对；未启动应用、构建或执行测试。运行时、网络、系统授权与视觉效果待确认。源码行号为当前快照。仅记录字段名及表达式，不记录真实个人信息、密码、cookie、token值。

关联：[总览](README.md) · [项目](PROJECT_MAP.md) · [模块](MODULE_MAP.md) · [页面](PAGE_MAP.md) · [组件](COMPONENT_MAP.md) · [接口](API_MAP.md) · [数据库](DATABASE_MAP.md) · [状态](STATE_MAP.md) · [构建](BUILD_MAP.md)。

23/23注册页面依据：[entry/src/main/resources/base/profile/main_pages.json](../../entry/src/main/resources/base/profile/main_pages.json)。另含1个桌面卡片页面。

## 共享与间接导航

| 入口 | 处理器 | 实际目的地/副作用 |
|---|---|---|
| BottomTabs 校历/课程/我的成绩/我的 | go(0/1/2/3) | replaceUrl → pages/AcademicCalendar / Index / GradePage / ProfilePage；已选项直接返回，无参数 |
| Index 顶部导入 | openLogin | 可先展示账号面板再 goLogin；三点菜单不再显示旧刷新/导入列表 |
| Index 菜单八宫格 | MenuSheet.onSelect → onFunctionTap | 上课时间、课表设置、提醒、小组件、联系我们、主题、夜间、更新；主题进入 AppearancePage，联系我们进入 AboutPage，更新仅提示未接入服务 |
| FunctionGrid 上课时间/课表设置/上课提醒/小组件 | onItem(period/table/remind/widget) → onFunctionTap | pages/PeriodSettings / TimetableSettings / RemindPage / WidgetGuide；组件是否消费见组件图 |
| MenuSheet 时间设置 | onSelect(period) → onFunctionTap | openPeriodSettings → pages/PeriodSettings |
| onFunctionTap 的 courses/contact/dark/theme 分支 | 内部 key 调度，非当前宫格全部公开项 | CourseListPage / AboutPage / 切换保存深色 / Toast主题即将上线 |
| Profile 菜单 | open(info/feedback/timetable/remind/appearance/account/faq/about/more) | PersonalInfoPage/FeedbackPage/TimetableSettings/RemindPage/AppearancePage/AccountPage/FaqPage/AboutPage/MorePage，无参数 |
| Profile 清除缓存/网络检测 | open(cache/network) | clearCache 删除 cacheDir 项；checkNetwork 探测HTTP并弹结果，不导航 |
| Profile 头像头 | loggedIn 条件 | LoginPage 或 PersonalInfoPage |
| MorePage 五项 | 点击r → pushUrl | PrivacyDocPage {kind:r.key}，key=collect/share/export/permission/revoke |
| Grade 重新验证/考试 | goVerify/openExam | LoginPage {refresh:'grade'} / ExamPage |
| Index 添加 | openAddCourse | AddCoursePage {tableId:activeTableId,week:week} |
| PersonalInfo 头像选择 | pickAvatar → 图片选择、复制到本机临时源后 pushUrl | AvatarCropPage {path:dest}；dest为运行时裁剪源文件路径，不记录个人文件实际路径 |
| Exam 原网页 | openWeb | ExamWebPage {url:EXAM_PAGE_URL,base:JW_BASE_URL,cookie:运行时会话（值省略）}；其Web访问不是ArkUI路由 |
| AcademicCalendar 原校历 | openInBrowser | 外部浏览器 startAbility，非 pages 路由 |
| DayCard 整卡 | postCardAction | action:'router',abilityName:'EntryAbility',params:{from:'day_card'} |

## 已确认边界

Index.courseDetailSheet 的编辑回调仅 toast('编辑课程（P1）')；复制仅 toast('复制到其他时段（P1）')，均未编辑仓储或跳 AddCoursePage。删除是真操作：所有周 remove；仅本周过滤 weeks，剩余0则 remove，否则 remove+add。TermPage 虽标题“切换学期”，实际只展示固定 TERM_LABEL 与周次并 syncAndSave 到 't1'，没有任意学期选择器；验证码需求只提示去导入课表。AppearancePage 内主题选择仍仅提示；Index theme 入口跳转 AppearancePage。


## Index

[entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets)；注册路由 `pages/Index`。

课程主屏：周/日视图、周次、滑动课表、详情、分享导入、课表管理/提醒弹层与BottomTabs。

组件/构造结构：Blank、BottomTabs、Column、CourseDetailSheet、Date、DayList、Divider、Error、ForEach、LineIcon、MenuSheet、PanGesture、Row、Scroll、Slider、Stack、Swiper、SwiperController、TC、TableSwitcher、Text、TextInput、TextPicker、TimetableGrid、Watch、WeekBar。本地Builder：remindWheelSheet、renameSheet、weekPanel、headerBar、nextHintBar、dayWeekBtn、iconBtn、forwardBtn、importCard、forwardMenu、forwardRow、courseArea、dayCard、gridCard、courseDetailSheet。

转发菜单 `forwardMenu` 保持三行原布局及各自事件：分享课表 `LineIcon(send)`，说明“生成口令，发给同学使用”并调用 `makeShareCode`；导出到日程 `LineIcon(calendar)` 并调用 `confirmExportCalendar`；从口令导入 `LineIcon(key)` 并打开导入面板。图标通过公共 Canvas 线条组件 `LineIcon` 绘制，菜单行由 `forwardRow` 负责。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `aboutToAppear` | this.weekPages = [];; this.wheelValues = [];; this.refreshDates();; this.loadPeriods();; this.loadSettings();; this.loadAll(); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `onPageShow` | this.activeTableId = TimetableStateStore.activeTableId();; this.loadPeriods();; this.loadSettings();; this.reloadTables();; this.loadCourses(); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `wheelIndex` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `openRename` | this.tableSheetMode = 'rename';; this.renameTargetId = t.id;; this.renameText = t.name;; this.showRename = true; |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `openCreate` | this.tableSheetMode = 'create';; this.renameTargetId = '';; this.renameText = '';; this.showRename = true; |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `saveRename` | this.toast('课表名称不能为空');; if (this.tableSheetMode === 'create') {; const t: TimetableInfo = await Locator.repo().createTable(name);; this.showRename = false;; await this.reloadTables();; this.activeTableId = t.id;; await this.loadCourses();; this.toast(′已新建「${name}」′);; await Locator.repo().renameTable(this.renameTargetId, name);; this.showRename = false;; await this.reloadTables();; this.toast('已重命名');; this.toast('保存失败：' + JSON.stringify(e)); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `confirmDeleteTable` | this.toast('至少保留一个课表');; this.getUIContext().showAlertDialog({; this.doDeleteTable(t); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `doDeleteTable` | await Locator.repo().removeTable(t.id);; if (this.activeTableId === t.id) {; this.activeTableId = rest.length > 0 ? rest[0].id : 't1';; await this.reloadTables();; await this.loadCourses();; this.toast(′已删除「${t.name}」′);; this.toast('删除失败：' + JSON.stringify(e)); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `reloadTables` | const list: TimetableInfo[] = await Locator.repo().tables();; this.tables = opts;; this.activeTableId = opts[0].id;; this.toast('读取课表失败'); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `openMenu` | this.menuOffset = this.menuHeight + 40;; this.menuMask = 0;; this.menuOpen = true;; this.menuMask = 0.45;; this.menuOffset = -8;; this.menuOffset = 3;; this.menuOffset = 0; |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `closeMenu` | this.menuOffset = this.menuHeight + 40;; this.menuMask = 0;; this.menuOpen = false;; this.menuOffset = this.menuHeight + 40; |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `toggleView` | this.flipY = 90;; this.isDay = !this.isDay;; this.flipY = -90;; this.flipY = 0; |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `gridHeight` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `openAddCourse` | router.pushUrl({ |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `loadAll` | await Locator.init(getContext(this) as common.UIAbilityContext);; await Locator.ensureSeed();; this.activeTableId = TimetableStateStore.activeTableId();; await this.dropLegacyDemoCourses();; const list: TimetableInfo[] = await Locator.repo().tables();; this.tables = opts;; this.activeTableId = opts[0].id;; await this.loadCourses();; this.maybeAutoSync();; this.toast('读取本地课表失败：' + JSON.stringify(e)); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `dropLegacyDemoCourses` | const p: preferences.Preferences = await preferences.getPreferences(ctx, MIGRATE_FILE);; const done: boolean = await p.get(K_CLEAN_DEMO, false) as boolean;; demoIds.add(mc.id);; const all: Course[] = await Locator.repo().listAll(tableIds[i]);; await Locator.repo().replaceAll(tableIds[i], keep);; await p.put(K_CLEAN_DEMO, true);; await p.flush(); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `loadCourses` | await Locator.init(getContext(this) as common.UIAbilityContext);; await TimetableStateStore.select(tableId);; this.totalWeeks = weeks;; this.weekPages = [];; this.week = Math.min(this.week, weeks);; this.refreshDates();; const courses: Course[] = await Locator.repo().listByWeek(tableId, this.week);; const all: Course[] = await Locator.repo().listAll(tableId);; this.courses = courses;; this.allCourses = all;; this.courses = [];; this.allCourses = [];; this.toast('加载课程失败');; this.refreshNextHint(); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `refreshNextHint` | this.nextHint = ′第 ${this.week} 周共 ${this.courses.length} 节课′;; this.nextHint = nextClassLabel(nextClassOf(this.courses, this.periods, this.week, new Date())); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `onWeekChange` | this.refreshDates();; this.loadCourses(); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `refreshDates` | this.weekDates = wd.dates;; this.weekMonth = wd.month;; this.todayIndex = wd.todayIndex; |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `onMenuTap` | this.quickRefresh();; this.openLogin();; this.onFunctionTap('period');; this.shareWeek();; this.go('pages/TermPage');; this.go('pages/AppearancePage');; this.go('pages/AccountPage');; this.go('pages/AboutPage');; this.toast(′${key}（P1）′); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `go` | router.pushUrl({ url: url }).catch((e: Error) => {; this.toast('打开页面失败：' + e.message); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `loadSettings` | const s: AppSettings = await SettingsStore.load(ctx);; this.settings = s;; this.showWeekend = true;; AppStorage.setOrCreate('dark', s.dark); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `loadPeriods` | PeriodStore.init(getContext(this) as common.UIAbilityContext);; this.periods = await PeriodStore.load();; this.refreshNextHint(); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `onFunctionTap` | this.openPeriodSettings();; this.go('pages/TimetableSettings');; this.go('pages/CourseListPage');; this.go('pages/WidgetGuide');; this.go('pages/RemindPage');; this.go('pages/AboutPage');; AppStorage.setOrCreate('dark', this.settings.dark);; this.persistSettings();; this.toast(this.settings.dark ? '已切到夜间模式' : '已切回浅色');; this.toast('主题功能即将上线');; this.toast(′${key}（P1）′); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `persistSettings` | SettingsStore.save(getContext(this) as common.UIAbilityContext, this.settings); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `openLogin` | const cred: Credential = await CredentialStore.load(ctx);; const ts: number = await CredentialStore.lastSyncAt(ctx);; when = this.fmtTime(ts);; this.goLogin();; this.reloginWhen = when;; this.showRelogin = true; |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `fmtTime` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `goLogin` | router.pushUrl({ url: 'pages/LoginPage' }).catch((e: Error) => {; this.toast('打开登录页失败：' + e.message); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `openPeriodSettings` | router.pushUrl({ url: 'pages/PeriodSettings' }).catch((e: Error) => {; this.toast('打开设置页失败：' + e.message); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `quickRefresh` | const cred: Credential = await CredentialStore.load(ctx);; this.toast('还没有保存的教务账号，先登录一次');; this.goLogin();; this.toast('正在刷新课表…');; const r: SyncResult = await Locator.syncAndSave(cred.user, cred.pwd, this.activeTableId);; this.toast('教务要求验证码，请到导入课表页完成验证');; this.goLogin();; await CredentialStore.markSyncAt(getContext(this) as common.UIAbilityContext, Date.now());; await this.loadCourses();; this.toast(r.message);; this.toast('刷新失败：' + r.message);; this.toast('刷新异常：' + (e instanceof Error ? e.message : JSON.stringify(e))); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `maybeAutoSync` | const cred: Credential = await CredentialStore.load(ctx);; const today: string = CredentialStore.today();; const lastDay: string = await CredentialStore.autoUpdateDay(ctx);; const r: SyncResult = await Locator.syncAndSave(cred.user, cred.pwd, this.activeTableId);; await CredentialStore.markSyncAt(ctx, Date.now());; await CredentialStore.markAutoUpdateDay(ctx, today);; await this.loadCourses(); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `hasPreview` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `previewLabel` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `copyCode` | await pasteboard.getSystemPasteboard().setData(data);; this.showCodeCard = false;; this.toast('口令已复制，发给同学即可');; this.toast('复制失败：' + (e instanceof Error ? e.message : JSON.stringify(e))); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `confirmExportCalendar` | this.toast('当前课表还没有课程');; this.exportTotal = total;; this.exportRemind = this.settings.calendarRemind ? 10 : 0;; this.showExport = true; |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `doExportCalendar` | this.exportBusy = true;; this.showExport = false;; this.toast('正在写入系统日历…');; const r: CalendarExportResult = await exportCoursesToCalendar(ctx, this.allCourses, this.periods,; this.toast(r.message);; this.toast('导出失败：' + (e instanceof Error ? e.message : JSON.stringify(e)));; this.exportBusy = false; |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `remindLabel` | return this.isCustomRemind() ? ′${this.exportRemind} 分钟′ : '自定义'; |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `isCustomRemind` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `remindActive` | return this.isCustomRemind();; return this.exportRemind === m; |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `pickRemind` | this.wheelMinutes = this.isCustomRemind() ? this.exportRemind : 30;; this.showRemindWheel = true;; this.exportRemind = m; |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `applyWheel` | this.exportRemind = minutes;; this.showRemindWheel = false;; this.showRemindTip(′已设为提前 ${minutes} 分钟提醒′); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `showRemindTip` | this.remindTip = text;; this.remindTipTimer = setTimeout(() => {; this.remindTip = '';; this.remindTipTimer = -1; |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `shareWeek` | await pasteboard.getSystemPasteboard().setData(data);; this.toast('本周课表已复制到剪贴板');; this.toast('复制失败：' + (e instanceof Error ? e.message : JSON.stringify(e))); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `openDetail` | this.detailCourse = c;; this.detailAllWeeks = !isInWeek(c, this.week);; this.showDetail = true; |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `deleteCourse` | await Locator.repo().remove(c.id);; this.toast(′已删除「${c.name}」′);; await Locator.repo().remove(c.id);; this.toast(′已删除「${c.name}」′);; await Locator.repo().remove(c.id);; await Locator.repo().add(kept, this.activeTableId);; this.toast(′已从第 ${this.week} 周移除「${c.name}」′);; this.showDetail = false;; this.detailCourse = null;; await this.loadCourses();; this.toast('删除失败：' + (e instanceof Error ? e.message : JSON.stringify(e))); |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `nameOf` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) `toast` | this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1600 }); |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) 容器/手势 | .onClick(() => this.closeMenu()) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) 容器/手势 | .onActionUpdate((e: GestureEvent) => { if (e.offsetY > 0) { this.menuOffset = e.offsetY; } }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) 容器/手势 | .onActionEnd((e: GestureEvent) => { if (e.offsetY > 90) { this.closeMenu(); return; } animateTo({ duration: 420, curve: curves.springMotion(0.5, 0.72) }, () => { this.menuOffset = 0; }); }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) 容器/手势 | .onClick(() => { this.showCodeCard = false; }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text(this.codeOnline / Text('复制') | .onClick(() => { this.copyCode(); }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text('复制') / Text('取消') | .onClick(() => { this.showCodeCard = false; }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text('取消') | .onClick(() => { }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) 容器/手势 | .onClick(() => { this.showRelogin = false; }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text(′当前课表于 ${this.reloginWhen} 同步，已有 ${this.allCourses.length} 门课。继续导入会重新登录教务系统并整体替换本机课表，手动添加的课程会被覆盖。是否继续导入？′) / Text('取消') | .onClick(() => { this.showRelogin = false; }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text('继续导入') | .onClick(() => { this.showRelogin = false; this.goLogin(); }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) 容器/手势 | .onClick(() => { }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) 容器/手势 | .onClick(() => { this.showExport = false; }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text('提前提醒') / Text(this.remindLabel(m)) | .onClick(() => this.pickRemind(m)) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text('取消') | .onClick(() => { this.showExport = false; }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text('导出') | .onClick(() => { this.doExportCalendar(); }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) 容器/手势 | .onClick(() => { }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text('提前多久提醒') / Text(′${this.wheelMinutes} 分钟′) | .onChange((value: string \| string[], index: number \| number[]) => { const i: number = Array.isArray(index) ? (index as number[])[0] : (index as number); this.wheelMinutes = i + 5; }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text('取消') | .onClick(() => { this.showRemindWheel = false; }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text('确定') | .onClick(() => { this.applyWheel(this.wheelMinutes); }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text(this.tableSheetMode === 'create' ? '新建课表' : '重命名课表') / Text('保存') | .onClick(() => { this.saveRename(); }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text('保存') | .onChange((v: string) => { this.renameText = v; }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) 容器/手势 | .onChange((value: number) => { this.week = Math.round(value); }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text(this.isDay ? '周' : '日') | .onClick(() => { this.toggleView(); }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text(glyph) | .onClick(action) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) 容器/手势 | .onClick(() => { this.showForward = !this.showForward; }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) 容器/手势 | .onClick(() => { this.showImport = false; }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text('从口令导入') / Text(this.importBusy ? '查询中' : (this.hasPreview() ? '覆盖导入' : '查询')) | .onClick(() => { if (this.hasPreview()) { this.applyImport(); } else { this.queryImport(); } }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text('粘贴同学发来的 32 位口令，查询后整份覆盖当前课表') | .onChange((v: string) => { this.importCode = v; this.importPreview = null; // 粘贴 / 输满 32 位就自动查，省得再点一次按钮 if (v.trim().length === 32) { setTimeout(() => { this.queryImport(); }, 350); } }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text('取消') | .onClick(() => { this.showImport = false; }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text('取消') | .onClick(() => { }) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) Text(title) / Text(sub) | .onClick(action) |
| [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets) 容器/手势 | .onChange((index: number) => { const w: number = index + 1; if (w !== this.week) { this.week = w; this.loadCourses(); } }) |

直接路由/参数索引：

- [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets)：`router.pushUrl({ url: 'pages/AddCoursePage', params: { tableId: this.activeTableId, week: this.week } });`
- [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets)：`router.pushUrl({ url: url }).catch((e: Error) => { this.toast('打开页面失败：' + e.message); });`
- [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets)：`router.pushUrl({ url: 'pages/LoginPage' }).catch((e: Error) => { this.toast('打开登录页失败：' + e.message); });`
- [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets)：`router.pushUrl({ url: 'pages/PeriodSettings' }).catch((e: Error) => { this.toast('打开设置页失败：' + e.message); });`

## LoginPage

[entry/src/main/ets/pages/LoginPage.ets](../../entry/src/main/ets/pages/LoginPage.ets)；注册路由 `pages/LoginPage`。

账号/二维码/验证码登录与同步；恢复保存选项，二维码轮询及取消，成功应用同步结果返回。

组件/构造结构：Blank、Button、CaptchaLayer、Circle、Column、Ellipse、Eye、Image、LoadingProgress、QrLayer、Row、Scroll、Stack、StorageLink、TC、Text、TextInput、Toggle。本地Builder：Eye、CaptchaLayer、QrLayer。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/LoginPage.ets:59](../../entry/src/main/ets/pages/LoginPage.ets#L59) `aboutToAppear` | this.restore(); |
| [entry/src/main/ets/pages/LoginPage.ets:63](../../entry/src/main/ets/pages/LoginPage.ets#L63) `restore` | const c: Credential = await CredentialStore.load(getContext(this) as common.UIAbilityContext);; this.user = c.user;; this.pwd = c.pwd;; this.remember = c.remember;; this.autoUpdate = c.autoUpdate; |
| [entry/src/main/ets/pages/LoginPage.ets:546](../../entry/src/main/ets/pages/LoginPage.ets#L546) `openQr` | this.qrOpen = true;; this.qrScanned = false;; this.qrPm = undefined;; this.qrMsg = '正在获取二维码…';; this.qrBusy = true;; await this.fetchQr(); |
| [entry/src/main/ets/pages/LoginPage.ets:555](../../entry/src/main/ets/pages/LoginPage.ets#L555) `closeQr` | this.qrOpen = false;; this.qrBusy = false;; this.qrScanned = false;; this.qrPm = undefined; |
| [entry/src/main/ets/pages/LoginPage.ets:564](../../entry/src/main/ets/pages/LoginPage.ets#L564) `fetchQr` | await Locator.init(ctx);; await Locator.ensureSeed();; const t: QrTicket = await Locator.qrStart();; this.qrMsg = t.message;; this.qrPm = undefined;; this.qrBusy = false;; this.qrPm = await LoginPage.toPixelMap(t.image);; this.qrMsg = '请用企业微信扫一扫，在手机上确认登录';; this.qrBusy = false;; this.watchQr(token);; this.qrMsg = '二维码获取失败：' + (e instanceof Error ? e.message : JSON.stringify(e));; this.qrBusy = false; |
| [entry/src/main/ets/pages/LoginPage.ets:594](../../entry/src/main/ets/pages/LoginPage.ets#L594) `refreshQr` | this.qrScanned = false;; this.qrPm = undefined;; this.qrMsg = '正在刷新二维码…';; this.qrBusy = true;; await this.fetchQr(); |
| [entry/src/main/ets/pages/LoginPage.ets:607](../../entry/src/main/ets/pages/LoginPage.ets#L607) `watchQr` | p = await Locator.qrPoll();; this.qrMsg = '状态获取失败，正在重试…';; await LoginPage.sleep(1200);; await this.finishQr(p.code, token);; this.qrMsg = p.message.length > 0 ? p.message : '已取消扫码，可刷新二维码重试';; this.qrScanned = false;; this.qrPm = undefined;; this.qrMsg = p.message.length > 0 ? p.message : '二维码已失效，正在换新码…';; this.qrScanned = false;; this.qrPm = undefined;; this.qrBusy = false;; await LoginPage.sleep(800);; await this.refreshQr();; this.qrScanned = true;; this.qrMsg = p.message;; await LoginPage.sleep(900); |
| [entry/src/main/ets/pages/LoginPage.ets:657](../../entry/src/main/ets/pages/LoginPage.ets#L657) `sleep` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/LoginPage.ets:664](../../entry/src/main/ets/pages/LoginPage.ets#L664) `finishQr` | this.qrMsg = '扫码成功，正在导入课表…';; this.qrBusy = true;; r = await Locator.syncWithQr(code, 't1');; this.qrMsg = '导入异常：' + (e instanceof Error ? e.message : JSON.stringify(e));; this.qrBusy = false;; this.qrBusy = false;; this.qrMsg = r.message.length > 0 ? r.message : '扫码后仍需人机验证，请改用密码登录';; await this.applyQr(r); |
| [entry/src/main/ets/pages/LoginPage.ets:689](../../entry/src/main/ets/pages/LoginPage.ets#L689) `applyQr` | this.status = ′导入失败：${r.message}′;; this.statusOk = false;; this.qrMsg = r.message.length > 0 ? r.message : '导入失败，请重新扫码';; this.qrScanned = false;; this.qrPm = undefined;; await LoginPage.sleep(1200);; await this.refreshQr();; await TimetableStateStore.select('t1');; await CredentialStore.markSyncAt(ctx, Date.now());; await CredentialStore.markAutoUpdateDay(ctx, CredentialStore.today());; this.qrOpen = false;; this.qrBusy = false;; this.statusOk = true;; this.status = ′${r.message}｜${r.student.name} ${r.student.clazz}′;; this.getUIContext().getPromptAction().showToast({ message: r.message, duration: 1600 });; router.back(); |
| [entry/src/main/ets/pages/LoginPage.ets:718](../../entry/src/main/ets/pages/LoginPage.ets#L718) `doLogin` | this.status = '请填写学号和密码';; this.statusOk = false;; this.busy = true;; this.status = this.loginMode === LOGIN_MODE_PORTAL ? '正在连接教学综合平台…' : '正在连接教务系统…';; this.statusOk = false;; await Locator.init(ctx);; await Locator.ensureSeed();; this.loginGeneration = AccountScope.token() + 1;; const r: SyncResult = await Locator.syncAndSave(this.user, this.pwd, 't1');; await this.apply(r);; this.status = '导入异常：' + (e instanceof Error ? e.message : JSON.stringify(e));; this.statusOk = false;; this.busy = false; |
| [entry/src/main/ets/pages/LoginPage.ets:747](../../entry/src/main/ets/pages/LoginPage.ets#L747) `apply` | this.status = '';; this.statusOk = false;; this.captchaMsg = r.message.length > 0 ? r.message : '教务系统要求输入验证码';; this.captchaCode = '';; this.captchaPm = await LoginPage.toPixelMap(r.captcha);; this.captchaOpen = true;; this.status = ′导入失败：${r.message}′;; this.statusOk = false;; await CredentialStore.save(ctx, {; await TimetableStateStore.select('t1');; await CredentialStore.markSyncAt(ctx, Date.now());; await CredentialStore.markAutoUpdateDay(ctx, CredentialStore.today());; this.statusOk = true;; this.status = ′${r.message}｜${r.student.name} ${r.student.clazz}′;; this.getUIContext().getPromptAction().showToast({ message: r.message, duration: 1600 });; router.back(); |
| [entry/src/main/ets/pages/LoginPage.ets:783](../../entry/src/main/ets/pages/LoginPage.ets#L783) `submitCaptcha` | this.captchaMsg = '请输入验证码';; this.captchaBusy = true;; const r: SyncResult = await Locator.syncWithCaptcha(code, this.user, 't1');; this.captchaMsg = r.message.length > 0 ? r.message : '验证码不正确，请重新输入';; this.captchaCode = '';; this.captchaPm = await LoginPage.toPixelMap(r.captcha);; this.captchaOpen = false;; await this.apply(r);; this.captchaMsg = '验证失败：' + (e instanceof Error ? e.message : JSON.stringify(e));; this.captchaBusy = false; |
| [entry/src/main/ets/pages/LoginPage.ets:810](../../entry/src/main/ets/pages/LoginPage.ets#L810) `refreshCaptcha` | const buf: ArrayBuffer = await Locator.refreshCaptcha();; this.captchaMsg = '验证码图片获取失败，请重试';; this.captchaPm = await LoginPage.toPixelMap(buf);; this.captchaMsg = '已换一张，请重新输入';; this.captchaCode = '';; this.captchaMsg = '验证码图片获取失败，请重试'; |
| [entry/src/main/ets/pages/LoginPage.ets:825](../../entry/src/main/ets/pages/LoginPage.ets#L825) `toPixelMap` | const pm: image.PixelMap = await src.createPixelMap();; await src.release(); |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/LoginPage.ets:85](../../entry/src/main/ets/pages/LoginPage.ets#L85) Text('←') | .onClick(() => router.back()) |
| [entry/src/main/ets/pages/LoginPage.ets:124](../../entry/src/main/ets/pages/LoginPage.ets#L124) Text('登录教务系统') | .onChange((v: string) => { this.user = v; }) |
| [entry/src/main/ets/pages/LoginPage.ets:140](../../entry/src/main/ets/pages/LoginPage.ets#L140) 容器/手势 | .onChange((v: string) => { this.pwd = v; }) |
| [entry/src/main/ets/pages/LoginPage.ets:150](../../entry/src/main/ets/pages/LoginPage.ets#L150) 容器/手势 | .onTouch((e: TouchEvent) => { if (e.type === TouchType.Down) { this.eyeClosed = true; this.reveal = true; } else if (e.type === TouchType.Up \|\| e.type === TouchType.Cancel) { this.eyeClosed = false; this.reveal = false; } }) |
| [entry/src/main/ets/pages/LoginPage.ets:186](../../entry/src/main/ets/pages/LoginPage.ets#L186) Text('教务登录入口') | .onClick(() => { this.loginMode = LOGIN_MODE_JW; }) |
| [entry/src/main/ets/pages/LoginPage.ets:212](../../entry/src/main/ets/pages/LoginPage.ets#L212) Text('教学综合平台入口') | .onClick(() => { this.loginMode = LOGIN_MODE_PORTAL; }) |
| [entry/src/main/ets/pages/LoginPage.ets:219](../../entry/src/main/ets/pages/LoginPage.ets#L219) Text('教学综合平台入口') | .onChange((on: boolean) => { this.remember = on; }) |
| [entry/src/main/ets/pages/LoginPage.ets:233](../../entry/src/main/ets/pages/LoginPage.ets#L233) Text('记住密码（用于定期更新课表）') | .onChange((on: boolean) => { this.autoUpdate = on; }) |
| [entry/src/main/ets/pages/LoginPage.ets:269](../../entry/src/main/ets/pages/LoginPage.ets#L269) Button(this.busy ? '正在登录…' : '登录并导入课表') | .onTouch((event: TouchEvent) => { if (this.busy) { return; } if (event.type === TouchType.Down) { this.mainPressed = true; } else if (event.type === TouchType.Up \|\| event.type === TouchType.Cancel) { this.mainPressed = false; } }) |
| [entry/src/main/ets/pages/LoginPage.ets:279](../../entry/src/main/ets/pages/LoginPage.ets#L279) 容器/手势 | .onClick(() => this.doLogin()) |
| [entry/src/main/ets/pages/LoginPage.ets:294](../../entry/src/main/ets/pages/LoginPage.ets#L294) Button('企业微信扫码登录') | .onTouch((event: TouchEvent) => { if (event.type === TouchType.Down) { this.qrPressed = true; } else if (event.type === TouchType.Up \|\| event.type === TouchType.Cancel) { this.qrPressed = false; } }) |
| [entry/src/main/ets/pages/LoginPage.ets:301](../../entry/src/main/ets/pages/LoginPage.ets#L301) 容器/手势 | .onClick(() => this.openQr()) |
| [entry/src/main/ets/pages/LoginPage.ets:400](../../entry/src/main/ets/pages/LoginPage.ets#L400) Text('验证码加载中…') | .onClick(() => this.refreshCaptcha()) |
| [entry/src/main/ets/pages/LoginPage.ets:410](../../entry/src/main/ets/pages/LoginPage.ets#L410) 容器/手势 | .onChange((v: string) => { this.captchaCode = v; }) |
| [entry/src/main/ets/pages/LoginPage.ets:422](../../entry/src/main/ets/pages/LoginPage.ets#L422) Button('取消') | .onClick(() => { this.captchaOpen = false; }) |
| [entry/src/main/ets/pages/LoginPage.ets:432](../../entry/src/main/ets/pages/LoginPage.ets#L432) Button('取消') / Button(this.captchaBusy ? '提交中…' : '确定') | .onClick(() => this.submitCaptcha()) |
| [entry/src/main/ets/pages/LoginPage.ets:447](../../entry/src/main/ets/pages/LoginPage.ets#L447) 容器/手势 | .onClick(() => { // 吞掉遮罩上的点击，避免误触后面的表单 }) |
| [entry/src/main/ets/pages/LoginPage.ets:469](../../entry/src/main/ets/pages/LoginPage.ets#L469) Text('企业微信扫码登录') / Text('✕') | .onClick(() => this.closeQr()) |
| [entry/src/main/ets/pages/LoginPage.ets:502](../../entry/src/main/ets/pages/LoginPage.ets#L502) Text('点此刷新二维码') | .onClick(() => this.refreshQr()) |
| [entry/src/main/ets/pages/LoginPage.ets:518](../../entry/src/main/ets/pages/LoginPage.ets#L518) Text(this.qrMsg.length > 0 ? this.qrMsg : '请用企业微信扫一扫') / Button('刷新二维码') | .onClick(() => this.refreshQr()) |
| [entry/src/main/ets/pages/LoginPage.ets:525](../../entry/src/main/ets/pages/LoginPage.ets#L525) Button('刷新二维码') / Button('取消') | .onClick(() => this.closeQr()) |
| [entry/src/main/ets/pages/LoginPage.ets:540](../../entry/src/main/ets/pages/LoginPage.ets#L540) 容器/手势 | .onClick(() => { // 吞掉遮罩点击 }) |

直接路由/参数索引：

- [entry/src/main/ets/pages/LoginPage.ets:85](../../entry/src/main/ets/pages/LoginPage.ets#L85)：`.onClick(() => router.back())`
- [entry/src/main/ets/pages/LoginPage.ets:714](../../entry/src/main/ets/pages/LoginPage.ets#L714)：`router.back();`
- [entry/src/main/ets/pages/LoginPage.ets:778](../../entry/src/main/ets/pages/LoginPage.ets#L778)：`router.back();`

## PeriodSettings

[entry/src/main/ets/pages/PeriodSettings.ets](../../entry/src/main/ets/pages/PeriodSettings.ets)；注册路由 `pages/PeriodSettings`。

节次列表、时间编辑sheet；新增/删除/恢复默认/校验保存PeriodStore。

组件/构造结构：Blank、Button、Column、Date、ForEach、List、ListItem、Row、StorageLink、TC、Text、TimePicker。本地Builder：editorSheet。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/PeriodSettings.ets:25](../../entry/src/main/ets/pages/PeriodSettings.ets#L25) `aboutToAppear` | this.ctx = getContext(this) as common.UIAbilityContext;; PeriodStore.init(this.ctx);; PeriodStore.load().then((list: Period[]) => {; this.periods = list; |
| [entry/src/main/ets/pages/PeriodSettings.ets:209](../../entry/src/main/ets/pages/PeriodSettings.ets#L209) `toast` | promptAction.showToast({ message: msg, duration: 1500 }); |
| [entry/src/main/ets/pages/PeriodSettings.ets:217](../../entry/src/main/ets/pages/PeriodSettings.ets#L217) `minutes` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/PeriodSettings.ets:221](../../entry/src/main/ets/pages/PeriodSettings.ets#L221) `fmt` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/PeriodSettings.ets:227](../../entry/src/main/ets/pages/PeriodSettings.ets#L227) `openEditor` | this.pos = pos;; this.editingIndex = p.index;; this.pickStart = this.parse(p.start, 8, 25);; this.pickEnd = this.parse(p.end, 9, 10);; this.sheetOn = true; |
| [entry/src/main/ets/pages/PeriodSettings.ets:236](../../entry/src/main/ets/pages/PeriodSettings.ets#L236) `parse` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/PeriodSettings.ets:243](../../entry/src/main/ets/pages/PeriodSettings.ets#L243) `applyCurrent` | if (this.minutes(this.pickEnd) <= this.minutes(this.pickStart)) {; this.toast('结束时间要晚于开始时间');; start: this.fmt(this.pickStart),; end: this.fmt(this.pickEnd); this.periods = next;; this.dirty = true;; this.sheetOn = false; |
| [entry/src/main/ets/pages/PeriodSettings.ets:263](../../entry/src/main/ets/pages/PeriodSettings.ets#L263) `removeCurrent` | this.periods = renum;; this.dirty = true;; this.sheetOn = false;; this.toast('已删除，记得保存'); |
| [entry/src/main/ets/pages/PeriodSettings.ets:284](../../entry/src/main/ets/pages/PeriodSettings.ets#L284) `addPeriod` | const e: Date = this.parse(last.end, 17, 15);; start: this.fmt(new Date(2026, 0, 1, sh, sm)),; end: this.fmt(new Date(2026, 0, 1, sh, sm + 45)); this.periods = next;; this.dirty = true;; this.pos = next.length - 1;; this.editingIndex = np.index;; this.pickStart = this.parse(np.start, sh, sm);; this.pickEnd = this.parse(np.end, sh, sm + 45);; this.sheetOn = true; |
| [entry/src/main/ets/pages/PeriodSettings.ets:310](../../entry/src/main/ets/pages/PeriodSettings.ets#L310) `saveAll` | const ok: boolean = await PeriodStore.save(this.periods);; this.dirty = false;; this.toast('已保存，课表同步更新');; setTimeout(() => router.back(), 500);; this.toast('保存失败'); |
| [entry/src/main/ets/pages/PeriodSettings.ets:321](../../entry/src/main/ets/pages/PeriodSettings.ets#L321) `goBack` | this.toast('有未保存的修改，点『保存』后生效');; router.back(); |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/PeriodSettings.ets:40](../../entry/src/main/ets/pages/PeriodSettings.ets#L40) Text('‹') | .onClick(() => this.goBack()) |
| [entry/src/main/ets/pages/PeriodSettings.ets:50](../../entry/src/main/ets/pages/PeriodSettings.ets#L50) Text('上课时间') / Text('＋ 添加') | .onClick(() => this.addPeriod()) |
| [entry/src/main/ets/pages/PeriodSettings.ets:92](../../entry/src/main/ets/pages/PeriodSettings.ets#L92) Text(′${p.start} – ${p.end}′) / Text('›') | .onClick(() => this.openEditor(i)) |
| [entry/src/main/ets/pages/PeriodSettings.ets:107](../../entry/src/main/ets/pages/PeriodSettings.ets#L107) Button('恢复默认') | .onClick(() => { this.periods = DEFAULT_PERIODS.map((p: Period) => { const n: Period = { index: p.index, start: p.start, end: p.end }; return n; }); this.dirty = true; this.toast('已恢复默认，记得保存'); }) |
| [entry/src/main/ets/pages/PeriodSettings.ets:121](../../entry/src/main/ets/pages/PeriodSettings.ets#L121) Button('保存') | .onClick(() => this.saveAll()) |
| [entry/src/main/ets/pages/PeriodSettings.ets:147](../../entry/src/main/ets/pages/PeriodSettings.ets#L147) Text('开始') | .onChange((v: TimePickerResult) => { this.pickStart = new Date(2026, 0, 1, v.hour, v.minute); // 结束早于开始就顺延 45 分钟 if (this.minutes(this.pickEnd) <= this.minutes(this.pickStart)) { this.pickEnd = new Date(2026, 0, 1, v.hour, v.minute + 45); } }) |
| [entry/src/main/ets/pages/PeriodSettings.ets:166](../../entry/src/main/ets/pages/PeriodSettings.ets#L166) Text('结束') | .onChange((v: TimePickerResult) => { this.pickEnd = new Date(2026, 0, 1, v.hour, v.minute); }) |
| [entry/src/main/ets/pages/PeriodSettings.ets:193](../../entry/src/main/ets/pages/PeriodSettings.ets#L193) Text('结束时间要晚于开始时间') / Button('删除本节') | .onClick(() => this.removeCurrent()) |
| [entry/src/main/ets/pages/PeriodSettings.ets:200](../../entry/src/main/ets/pages/PeriodSettings.ets#L200) Button('删除本节') / Button('完成') | .onClick(() => this.applyCurrent()) |

直接路由/参数索引：

- [entry/src/main/ets/pages/PeriodSettings.ets:315](../../entry/src/main/ets/pages/PeriodSettings.ets#L315)：`setTimeout(() => router.back(), 500);`
- [entry/src/main/ets/pages/PeriodSettings.ets:325](../../entry/src/main/ets/pages/PeriodSettings.ets#L325)：`router.back();`

## CourseListPage

[entry/src/main/ets/pages/CourseListPage.ets](../../entry/src/main/ets/pages/CourseListPage.ets)；注册路由 `pages/CourseListPage`。

读取路由tableId加载列表；搜索按本地关键词筛选。

组件/构造结构：Blank、Column、ForEach、List、ListItem、Row、StorageLink、TC、Text、TextInput。本地Builder：courseItem。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/CourseListPage.ets:22](../../entry/src/main/ets/pages/CourseListPage.ets#L22) `aboutToAppear` | const p: RouteParams = router.getParams() as RouteParams;; this.tableId = p.tableId;; this.tableName = p.tableName;; this.load(); |
| [entry/src/main/ets/pages/CourseListPage.ets:33](../../entry/src/main/ets/pages/CourseListPage.ets#L33) `load` | const all: Course[] = await Locator.repo().listAll(this.tableId);; this.courses = all.sort((a: Course, b: Course) => {; this.courses = []; |
| [entry/src/main/ets/pages/CourseListPage.ets:47](../../entry/src/main/ets/pages/CourseListPage.ets#L47) `filtered` | 纯计算/格式化辅助，见源码函数体 |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/CourseListPage.ets:63](../../entry/src/main/ets/pages/CourseListPage.ets#L63) Text('‹') | .onClick(() => router.back()) |
| [entry/src/main/ets/pages/CourseListPage.ets:91](../../entry/src/main/ets/pages/CourseListPage.ets#L91) Text('⌕') | .onChange((v: string) => { this.keyword = v; }) |

直接路由/参数索引：

- [entry/src/main/ets/pages/CourseListPage.ets:23](../../entry/src/main/ets/pages/CourseListPage.ets#L23)：`const p: RouteParams = router.getParams() as RouteParams;`
- [entry/src/main/ets/pages/CourseListPage.ets:63](../../entry/src/main/ets/pages/CourseListPage.ets#L63)：`.onClick(() => router.back())`

## TimetableSettings

[entry/src/main/ets/pages/TimetableSettings.ets](../../entry/src/main/ets/pages/TimetableSettings.ets)；注册路由 `pages/TimetableSettings`。

真实课表预览与行高滑块；拖动预览，结束/点击轨道才保存；loadCourses读取tables[0]，不可推断为当前课表。

组件/构造结构：Blank、Column、Row、Slider、Stack、StorageLink、TC、Text、TimetableGrid、Toggle。本地Builder：switchRow。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/TimetableSettings.ets:32](../../entry/src/main/ets/pages/TimetableSettings.ets#L32) `aboutToAppear` | this.ctx = getContext(this) as common.UIAbilityContext;; this.week = currentWeek(TOTAL_WEEKS);; PeriodStore.init(this.ctx);; SettingsStore.load(this.ctx).then((v: AppSettings) => {; this.s = v;; this.liveCell = v.cellHeight;; this.loadCourses(); |
| [entry/src/main/ets/pages/TimetableSettings.ets:43](../../entry/src/main/ets/pages/TimetableSettings.ets#L43) `loadCourses` | const tables = await Locator.repo().tables();; this.courses = await Locator.repo().listAll(tables[0].id);; this.periods = await PeriodStore.load();; this.courses = []; |
| [entry/src/main/ets/pages/TimetableSettings.ets:55](../../entry/src/main/ets/pages/TimetableSettings.ets#L55) `persist` | SettingsStore.save(this.ctx, this.s); |
| [entry/src/main/ets/pages/TimetableSettings.ets:61](../../entry/src/main/ets/pages/TimetableSettings.ets#L61) `snap` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/TimetableSettings.ets:66](../../entry/src/main/ets/pages/TimetableSettings.ets#L66) `onCellChange` | this.liveCell = this.snap(v);; this.dragging = false;; this.persist();; this.dragging = true; |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/TimetableSettings.ets:108](../../entry/src/main/ets/pages/TimetableSettings.ets#L108) Text('‹') | .onClick(() => router.back()) |
| [entry/src/main/ets/pages/TimetableSettings.ets:160](../../entry/src/main/ets/pages/TimetableSettings.ets#L160) 容器/手势 | .onChange((v: number, mode: SliderChangeMode) => this.onCellChange(v, mode)) |
| [entry/src/main/ets/pages/TimetableSettings.ets:218](../../entry/src/main/ets/pages/TimetableSettings.ets#L218) Text(title) / Text(desc) | .onChange((v: boolean) => onChange(v)) |

直接路由/参数索引：

- [entry/src/main/ets/pages/TimetableSettings.ets:108](../../entry/src/main/ets/pages/TimetableSettings.ets#L108)：`.onClick(() => router.back())`

## AccountPage

[entry/src/main/ets/pages/AccountPage.ets](../../entry/src/main/ets/pages/AccountPage.ets)；注册路由 `pages/AccountPage`。

保存账号/同步状态、重新登录、清课程和清全部数据确认入口。

组件/构造结构：Blank、Button、Column、Date、Divider、Row、StorageLink、TC、Text。本地Builder：infoRow。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/AccountPage.ets:20](../../entry/src/main/ets/pages/AccountPage.ets#L20) `aboutToAppear` | this.refresh(); |
| [entry/src/main/ets/pages/AccountPage.ets:24](../../entry/src/main/ets/pages/AccountPage.ets#L24) `refresh` | const c: Credential = await CredentialStore.load(ctx);; this.user = c.user;; this.masked = this.maskUser(c.user);; this.remember = c.remember;; const ts: number = await CredentialStore.lastSyncAt(ctx);; this.lastSync = ts > 0 ? this.formatTime(ts) : '从未同步'; |
| [entry/src/main/ets/pages/AccountPage.ets:34](../../entry/src/main/ets/pages/AccountPage.ets#L34) `maskUser` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/AccountPage.ets:45](../../entry/src/main/ets/pages/AccountPage.ets#L45) `formatTime` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/AccountPage.ets:167](../../entry/src/main/ets/pages/AccountPage.ets#L167) `clearCourses` | this.busy = true;; await Locator.init(getContext(this) as common.UIAbilityContext);; const all = await Locator.repo().tables();; await Locator.repo().replaceAll(t.id, []);; this.toast('本地课表已清空');; this.toast('清除失败');; this.busy = false; |
| [entry/src/main/ets/pages/AccountPage.ets:182](../../entry/src/main/ets/pages/AccountPage.ets#L182) `clearAll` | this.busy = true;; await Locator.init(ctx);; await Locator.clearPersonalData();; this.toast('已退出登录');; this.user = '';; this.masked = '';; this.lastSync = '从未同步';; router.back();; this.toast('操作失败');; this.busy = false; |
| [entry/src/main/ets/pages/AccountPage.ets:201](../../entry/src/main/ets/pages/AccountPage.ets#L201) `toast` | this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1600 }); |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/AccountPage.ets:61](../../entry/src/main/ets/pages/AccountPage.ets#L61) Text('‹') | .onClick(() => router.back()) |
| [entry/src/main/ets/pages/AccountPage.ets:92](../../entry/src/main/ets/pages/AccountPage.ets#L92) Text(this.user.length > 0 ? this.masked : '—') / Text('更新密码') | .onClick(() => { router.pushUrl({ url: 'pages/LoginPage' }); }) |
| [entry/src/main/ets/pages/AccountPage.ets:133](../../entry/src/main/ets/pages/AccountPage.ets#L133) Text('登录凭据经 HUKS 加密后保存在本机；分享与反馈仅在主动使用时发送。') / Button(this.busy ? '处理中…' : '清除本地课表') | .onClick(() => this.clearCourses()) |
| [entry/src/main/ets/pages/AccountPage.ets:142](../../entry/src/main/ets/pages/AccountPage.ets#L142) Button(this.busy ? '处理中…' : '清除本地课表') / Button('退出登录并清除账号') | .onClick(() => this.clearAll()) |

直接路由/参数索引：

- [entry/src/main/ets/pages/AccountPage.ets:61](../../entry/src/main/ets/pages/AccountPage.ets#L61)：`.onClick(() => router.back())`
- [entry/src/main/ets/pages/AccountPage.ets:93](../../entry/src/main/ets/pages/AccountPage.ets#L93)：`router.pushUrl({ url: 'pages/LoginPage' });`
- [entry/src/main/ets/pages/AccountPage.ets:193](../../entry/src/main/ets/pages/AccountPage.ets#L193)：`router.back();`

## AboutPage

[entry/src/main/ets/pages/AboutPage.ets](../../entry/src/main/ets/pages/AboutPage.ets)；注册路由 `pages/AboutPage`。

静态关于与版本；实际点击仅返回，不能把邮箱文本推断成发送邮件。

组件/构造结构：Blank、Column、Divider、ForEach、Row、StorageLink、TC、Text。本地Builder：无。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/AboutPage.ets:25](../../entry/src/main/ets/pages/AboutPage.ets#L25) Text('‹') | .onClick(() => router.back()) |

直接路由/参数索引：

- [entry/src/main/ets/pages/AboutPage.ets:25](../../entry/src/main/ets/pages/AboutPage.ets#L25)：`.onClick(() => router.back())`

## TermPage

[entry/src/main/ets/pages/TermPage.ets](../../entry/src/main/ets/pages/TermPage.ets)；注册路由 `pages/TermPage`。

固定当前学期展示与重新同步，详见已确认边界。

组件/构造结构：Blank、Button、Column、Row、StorageLink、TC、Text。本地Builder：无。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/TermPage.ets:115](../../entry/src/main/ets/pages/TermPage.ets#L115) `sync` | this.busy = true;; this.syncLabel = '';; const cred: Credential = await CredentialStore.load(ctx);; this.syncLabel = '还没有保存的账号，先去登录一次';; this.busy = false;; await Locator.init(ctx);; const r: SyncResult = await Locator.syncAndSave(cred.user, cred.pwd, 't1');; await CredentialStore.markSyncAt(ctx, Date.now());; this.syncLabel = '教务要求验证码，请到「导入课表」页完成验证';; this.syncLabel = r.ok ? ′同步完成：${r.message}′ : ′同步失败：${r.message}′;; this.syncLabel = '同步异常：' + (e instanceof Error ? e.message : JSON.stringify(e));; this.busy = false; |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/TermPage.ets:24](../../entry/src/main/ets/pages/TermPage.ets#L24) Text('‹') | .onClick(() => router.back()) |
| [entry/src/main/ets/pages/TermPage.ets:85](../../entry/src/main/ets/pages/TermPage.ets#L85) Text('用已保存的账号再拉一次课表，课程变动时用') / Button(this.busy ? '同步中…' : '同步') | .onClick(() => this.sync()) |

直接路由/参数索引：

- [entry/src/main/ets/pages/TermPage.ets:24](../../entry/src/main/ets/pages/TermPage.ets#L24)：`.onClick(() => router.back())`

## AppearancePage

[entry/src/main/ets/pages/AppearancePage.ets](../../entry/src/main/ets/pages/AppearancePage.ets)；注册路由 `pages/AppearancePage`。

加载设置、深色开关及主题提示；SettingsStore与共享dark。

组件/构造结构：Blank、Column、Divider、Row、StorageLink、TC、Text、Toggle。本地Builder：无。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/AppearancePage.ets:15](../../entry/src/main/ets/pages/AppearancePage.ets#L15) `aboutToAppear` | this.ctx = getContext(this) as common.UIAbilityContext;; SettingsStore.load(this.ctx).then((v: AppSettings) => {; this.s = v; |
| [entry/src/main/ets/pages/AppearancePage.ets:22](../../entry/src/main/ets/pages/AppearancePage.ets#L22) `persist` | SettingsStore.save(this.ctx, this.s); |
| [entry/src/main/ets/pages/AppearancePage.ets:29](../../entry/src/main/ets/pages/AppearancePage.ets#L29) `themeName` | 纯计算/格式化辅助，见源码函数体 |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/AppearancePage.ets:40](../../entry/src/main/ets/pages/AppearancePage.ets#L40) Text('‹') | .onClick(() => router.back()) |
| [entry/src/main/ets/pages/AppearancePage.ets:66](../../entry/src/main/ets/pages/AppearancePage.ets#L66) Text('深色模式') / Text('夜间看课表不刺眼') | .onChange((v: boolean) => { this.s.dark = v; AppStorage.setOrCreate('dark', v); this.persist(); }) |
| [entry/src/main/ets/pages/AppearancePage.ets:101](../../entry/src/main/ets/pages/AppearancePage.ets#L101) Text(this.themeName()) / Text('›') | .onClick(() => { promptAction.showToast({ message: '主题功能即将上线', duration: 1600 }); }) |

直接路由/参数索引：

- [entry/src/main/ets/pages/AppearancePage.ets:40](../../entry/src/main/ets/pages/AppearancePage.ets#L40)：`.onClick(() => router.back())`

## RemindPage

[entry/src/main/ets/pages/RemindPage.ets](../../entry/src/main/ets/pages/RemindPage.ets)；注册路由 `pages/RemindPage`。

提前分钟、提醒/振动开关、手动生成本周提醒；实际refreshOwnedReminders，权限/送达待确认。

组件/构造结构：Blank、Button、Column、Divider、ForEach、Row、StorageLink、TC、Text、Toggle。本地Builder：无。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/RemindPage.ets:27](../../entry/src/main/ets/pages/RemindPage.ets#L27) `aboutToAppear` | this.ctx = getContext(this) as common.UIAbilityContext;; SettingsStore.load(this.ctx).then((v: AppSettings) => {; this.s = v; |
| [entry/src/main/ets/pages/RemindPage.ets:165](../../entry/src/main/ets/pages/RemindPage.ets#L165) `persist` | SettingsStore.save(ctx, this.s).then(async () => {; await Locator.init(ctx);; await TimetableStateStore.init(ctx);; const courses: Course[] = await Locator.repo().listByWeek(TimetableStateStore.activeTableId(), currentWeek(TimetableStateStore.term().totalWeeks));; await refreshOwnedReminders(ctx, courses, await PeriodStore.load(), this.s.remindBefore);; }).catch((e: Error) => { this.status = e.message; }); |
| [entry/src/main/ets/pages/RemindPage.ets:177](../../entry/src/main/ets/pages/RemindPage.ets#L177) `scheduleWeek` | this.busy = true;; this.status = '';; this.persist();; await Locator.init(ctx);; await TimetableStateStore.init(ctx);; const week: number = currentWeek(TimetableStateStore.term().totalWeeks);; const courses: Course[] = await Locator.repo().listByWeek(TimetableStateStore.activeTableId(), week);; const periods: Period[] = await PeriodStore.load();; this.status = await refreshOwnedReminders(ctx, courses, periods, this.s.remindBefore, true);; this.status = '系统提醒服务返回配额限制：' + msg;; this.status = '生成失败：' + msg;; this.busy = false; |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/RemindPage.ets:41](../../entry/src/main/ets/pages/RemindPage.ets#L41) Text('‹') | .onClick(() => router.back()) |
| [entry/src/main/ets/pages/RemindPage.ets:67](../../entry/src/main/ets/pages/RemindPage.ets#L67) Text('开启上课提醒') / Text('每节课开始前提醒一次') | .onChange((v: boolean) => { this.s.remindBefore = v ? 15 : 0; this.persist(); }) |
| [entry/src/main/ets/pages/RemindPage.ets:90](../../entry/src/main/ets/pages/RemindPage.ets#L90) Text('提前') / Text(′${m} 分钟′) | .onClick(() => { this.s.remindBefore = m; this.persist(); }) |
| [entry/src/main/ets/pages/RemindPage.ets:120](../../entry/src/main/ets/pages/RemindPage.ets#L120) Text('日程提醒') / Text('导出到系统日历时，也带上提前提醒') | .onChange((v: boolean) => { this.s.calendarRemind = v; this.persist(); }) |
| [entry/src/main/ets/pages/RemindPage.ets:139](../../entry/src/main/ets/pages/RemindPage.ets#L139) Button(this.busy ? '正在排提醒…' : '按本周课表生成提醒') | .onClick(() => { hilog.info(0x0000, 'Fuxiaowai', 'remind: click, before=%{public}d', this.s.remindBefore); this.scheduleWeek(); }) |

直接路由/参数索引：

- [entry/src/main/ets/pages/RemindPage.ets:41](../../entry/src/main/ets/pages/RemindPage.ets#L41)：`.onClick(() => router.back())`

## WidgetGuide

[entry/src/main/ets/pages/WidgetGuide.ets](../../entry/src/main/ets/pages/WidgetGuide.ets)；注册路由 `pages/WidgetGuide`。

静态桌面小组件说明与返回；不是动态安装器。

组件/构造结构：Blank、Column、Divider、ForEach、Row、StorageLink、TC、Text。本地Builder：无。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/WidgetGuide.ets:23](../../entry/src/main/ets/pages/WidgetGuide.ets#L23) Text('‹') | .onClick(() => router.back()) |

直接路由/参数索引：

- [entry/src/main/ets/pages/WidgetGuide.ets:23](../../entry/src/main/ets/pages/WidgetGuide.ets#L23)：`.onClick(() => router.back())`

## AcademicCalendar

[entry/src/main/ets/pages/AcademicCalendar.ets](../../entry/src/main/ets/pages/AcademicCalendar.ets)；注册路由 `pages/AcademicCalendar`。

校历学期切换、月份周次、滚到当前月、外部浏览器原校历、BottomTabs。

月份日期数字由 `dayCell()` 以 16vp 绘制；月卡按 `monthRows()` 分周渲染，在星期标题行与日期周行之间、以及各周行之间均加入 0.5vp 分割线，标题栏不再显示“本月”标签。

组件/构造结构：Blank、BottomTabs、Column、Date、Divider、ForEach、Number、Row、Scroll、Scroller、Stack、StorageLink、TC、Text。本地Builder：header、termTabs、weekHint、dayCell、monthCard、summaryCard。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/AcademicCalendar.ets:36](../../entry/src/main/ets/pages/AcademicCalendar.ets#L36) `aboutToAppear` | this.tab = i >= 0 ? i : 0;; this.scrollToCurrentMonth(); |
| [entry/src/main/ets/pages/AcademicCalendar.ets:46](../../entry/src/main/ets/pages/AcademicCalendar.ets#L46) `scrollToCurrentMonth` | const term: CalTerm = this.cur();; this.autoScrolled = true; |
| [entry/src/main/ets/pages/AcademicCalendar.ets:83](../../entry/src/main/ets/pages/AcademicCalendar.ets#L83) `cur` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/AcademicCalendar.ets:88](../../entry/src/main/ets/pages/AcademicCalendar.ets#L88) `weekNow` | return weekOfTerm(this.cur(), new Date()); |
| [entry/src/main/ets/pages/AcademicCalendar.ets:92](../../entry/src/main/ets/pages/AcademicCalendar.ets#L92) `openInBrowser` | this.toast('没有可用的浏览器'); |
| [entry/src/main/ets/pages/AcademicCalendar.ets:103](../../entry/src/main/ets/pages/AcademicCalendar.ets#L103) `toast` | promptAction.showToast({ message: msg, duration: 2000 }); |
| [entry/src/main/ets/pages/AcademicCalendar.ets:112](../../entry/src/main/ets/pages/AcademicCalendar.ets#L112) `dayColor` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/AcademicCalendar.ets:121](../../entry/src/main/ets/pages/AcademicCalendar.ets#L121) `dotColor` | const e: CalEvent \| null = eventOfDay(this.cur(), m, d); |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/AcademicCalendar.ets:139](../../entry/src/main/ets/pages/AcademicCalendar.ets#L139) Text('校历') / Text('原文') | .onClick(() => this.openInBrowser()) |
| [entry/src/main/ets/pages/AcademicCalendar.ets:166](../../entry/src/main/ets/pages/AcademicCalendar.ets#L166) Text(t.label) | .onClick(() => { this.tab = i; }) |
| [entry/src/main/ets/pages/AcademicCalendar.ets:178](../../entry/src/main/ets/pages/AcademicCalendar.ets#L178) 容器/手势 | .onAreaChange((_o: Area, n: Area) => { this.segW = Number(n.width); }) |
| [entry/src/main/ets/pages/AcademicCalendar.ets:307](../../entry/src/main/ets/pages/AcademicCalendar.ets#L307) Text(e.title) | .onAreaChange((oldA: Area, newA: Area) => { // 记下每个月的真实高度，进页面后据此算出「当前月居中」的滚动位置 this.monthH.set(′${cm.year}-${cm.month}′, Number(newA.height)); }) |

直接路由/参数索引：

- [entry/src/main/ets/pages/AcademicCalendar.ets:94](../../entry/src/main/ets/pages/AcademicCalendar.ets#L94)：`ctx.startAbility({ action: 'ohos.want.action.viewData', entities: ['entity.system.browsable'], uri: 'https://www.fzfu.com/jwc/info/1084/5556.htm' }).catch(() => { this.toast('没有可用的浏览器'); });`

## GradePage

[entry/src/main/ets/pages/GradePage.ets](../../entry/src/main/ets/pages/GradePage.ets)；注册路由 `pages/GradePage`。

成绩快照、筛选、刷新与验证、考试入口；账户版本/请求序号抑制过期结果；BottomTabs。

组件/构造结构：Blank、BottomTabs、Circle、Column、ForEach、List、ListItem、LoadingProgress、Row、StorageLink、TC、Text、TextPicker。本地Builder：headerBar、summaryCard、termBar、termSheet、gradeRow、centerHint。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/GradePage.ets:51](../../entry/src/main/ets/pages/GradePage.ets#L51) `aboutToAppear` | this.boot(); |
| [entry/src/main/ets/pages/GradePage.ets:56](../../entry/src/main/ets/pages/GradePage.ets#L56) `onPageShow` | this.boot(); |
| [entry/src/main/ets/pages/GradePage.ets:64](../../entry/src/main/ets/pages/GradePage.ets#L64) `boot` | this.loading = true;; this.refreshing = false;; this.needLogin = false;; this.errMsg = '';; const cred: Credential = await CredentialStore.load(ctx);; this.displayedUser = cred.user;; this.terms = [];; this.allItems = [];; this.summary = summarize([]);; this.activeTerm = -1;; this.hasCache = false;; this.cachedAt = 0;; this.cacheStatus = '';; this.loading = false;; this.needLogin = true;; const cached: GradeSnapshot \| null = await Locator.loadGradeCache(cred.user);; if (!this.validView(revision, token, cred.user)) { return; }; this.applySnapshot(cached);; this.loading = false;; await this.refresh(cached !== null);; this.errMsg = '读取成绩失败，请稍后重试';; this.loading = false; |
| [entry/src/main/ets/pages/GradePage.ets:104](../../entry/src/main/ets/pages/GradePage.ets#L104) `validView` | return revision === this.revision && AccountScope.valid(token) && AccountScope.user() === user && this.displayedUser === user; |
| [entry/src/main/ets/pages/GradePage.ets:108](../../entry/src/main/ets/pages/GradePage.ets#L108) `applySnapshot` | this.terms = snap.terms;; this.allItems = snap.items;; this.summary = snap.summary;; this.cachedAt = snap.at;; this.cacheStatus = snap.status;; this.hasCache = true; |
| [entry/src/main/ets/pages/GradePage.ets:119](../../entry/src/main/ets/pages/GradePage.ets#L119) `refresh` | if (user.length === 0 \|\| !this.validView(revision, token, user)) { return; }; this.refreshing = true;; if (!silent) { this.loading = true; }; const r: GradeSyncResult = await Locator.syncGrades(user);; if (!this.validView(revision, token, user)) { return; }; this.applySnapshot(r.snapshot);; this.errMsg = r.message;; this.errMsg = r.message;; if (r.expired) { this.cacheStatus = 'expired'; }; if (!this.validView(revision, token, user)) { return; }; this.errMsg = '无法连接教务系统，已保留离线成绩';; this.loading = false;; this.refreshing = false; |
| [entry/src/main/ets/pages/GradePage.ets:146](../../entry/src/main/ets/pages/GradePage.ets#L146) `goVerify` | router.pushUrl({ url: 'pages/LoginPage', params: { refresh: 'grade' } }); |
| [entry/src/main/ets/pages/GradePage.ets:151](../../entry/src/main/ets/pages/GradePage.ets#L151) `statusText` | const when: string = GradeCacheStore.shortTime(this.cachedAt);; return this.cacheStatus === 'expired' |
| [entry/src/main/ets/pages/GradePage.ets:161](../../entry/src/main/ets/pages/GradePage.ets#L161) `shown` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/GradePage.ets:171](../../entry/src/main/ets/pages/GradePage.ets#L171) `termLabels` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/GradePage.ets:177](../../entry/src/main/ets/pages/GradePage.ets#L177) `termIndex` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/GradePage.ets:181](../../entry/src/main/ets/pages/GradePage.ets#L181) `termTitle` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/GradePage.ets:189](../../entry/src/main/ets/pages/GradePage.ets#L189) `openExam` | router.pushUrl({ url: 'pages/ExamPage' }); |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/GradePage.ets:226](../../entry/src/main/ets/pages/GradePage.ets#L226) Text(this.refreshing ? '···' : '↻') | .onClick(() => { if (!this.refreshing) { this.refresh(false); } }) |
| [entry/src/main/ets/pages/GradePage.ets:247](../../entry/src/main/ets/pages/GradePage.ets#L247) Text(this.cacheStatus === 'expired' ? '重新验证' : '身份验证') | .onTouch((e: TouchEvent) => { if (e.type === TouchType.Down) { this.verifyPressed = true; } else if (e.type === TouchType.Up \|\| e.type === TouchType.Cancel) { this.verifyPressed = false; } }) |
| [entry/src/main/ets/pages/GradePage.ets:254](../../entry/src/main/ets/pages/GradePage.ets#L254) 容器/手势 | .onClick(() => this.goVerify()) |
| [entry/src/main/ets/pages/GradePage.ets:294](../../entry/src/main/ets/pages/GradePage.ets#L294) Text('考试安排') / Text('教务系统 ›') | .onClick(() => this.openExam()) |
| [entry/src/main/ets/pages/GradePage.ets:355](../../entry/src/main/ets/pages/GradePage.ets#L355) Text(this.termTitle()) / Text('▾') | .onClick(() => { this.showTermPicker = true; }) |
| [entry/src/main/ets/pages/GradePage.ets:372](../../entry/src/main/ets/pages/GradePage.ets#L372) Text('选择学期') / Text('完成') | .onClick(() => { this.showTermPicker = false; }) |
| [entry/src/main/ets/pages/GradePage.ets:384](../../entry/src/main/ets/pages/GradePage.ets#L384) Text('完成') | .onChange((value: string \| string[], index: number \| number[]) => { const i: number = typeof index === 'number' ? index : index[0]; this.activeTerm = i - 1; }) |
| [entry/src/main/ets/pages/GradePage.ets:482](../../entry/src/main/ets/pages/GradePage.ets#L482) Text(desc) / Text(actionText) | .onClick(action) |
| [entry/src/main/ets/pages/GradePage.ets:532](../../entry/src/main/ets/pages/GradePage.ets#L532) Text(this.errMsg) / Text('重新验证') | .onClick(() => this.goVerify()) |

直接路由/参数索引：

- [entry/src/main/ets/pages/GradePage.ets:147](../../entry/src/main/ets/pages/GradePage.ets#L147)：`router.pushUrl({ url: 'pages/LoginPage', params: { refresh: 'grade' } });`
- [entry/src/main/ets/pages/GradePage.ets:190](../../entry/src/main/ets/pages/GradePage.ets#L190)：`router.pushUrl({ url: 'pages/ExamPage' });`

## ProfilePage

[entry/src/main/ets/pages/ProfilePage.ets](../../entry/src/main/ets/pages/ProfilePage.ets)；注册路由 `pages/ProfilePage`。

资料头像、菜单和BottomTabs；本机资料加载、清临时缓存、网络响应探测。

组件/构造结构：BottomTabs、Column、Divider、ForEach、Image、LineIcon、Row、Scroll、Stack、StorageLink、TC、Text。本地Builder：headerBar、accountCard、rowItem、menuCard、subCard。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/ProfilePage.ets:49](../../entry/src/main/ets/pages/ProfilePage.ets#L49) `aboutToAppear` | this.load(); |
| [entry/src/main/ets/pages/ProfilePage.ets:53](../../entry/src/main/ets/pages/ProfilePage.ets#L53) `onPageShow` | this.pressKey = '';; this.load(); |
| [entry/src/main/ets/pages/ProfilePage.ets:59](../../entry/src/main/ets/pages/ProfilePage.ets#L59) `rowBg` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/ProfilePage.ets:66](../../entry/src/main/ets/pages/ProfilePage.ets#L66) `toast` | promptAction.showToast({ message: text, duration: 2000 }); |
| [entry/src/main/ets/pages/ProfilePage.ets:70](../../entry/src/main/ets/pages/ProfilePage.ets#L70) `load` | const p: Profile = await ProfileStore.load(ctx);; this.profile = p;; this.loggedIn = p.name.length > 0;; this.avatarPath = await AvatarStore.load(ctx); |
| [entry/src/main/ets/pages/ProfilePage.ets:79](../../entry/src/main/ets/pages/ProfilePage.ets#L79) `clearCache` | this.toast(count > 0 ? ′已清理 ${count} 项临时文件′ : '缓存已经是干净的');; this.toast('清理失败，请稍后再试'); |
| [entry/src/main/ets/pages/ProfilePage.ets:105](../../entry/src/main/ets/pages/ProfilePage.ets#L105) `probe` | const res: http.HttpResponse = await client.request(url, { |
| [entry/src/main/ets/pages/ProfilePage.ets:123](../../entry/src/main/ets/pages/ProfilePage.ets#L123) `checkNetwork` | this.toast('正在检测…');; const jw: boolean = await this.probe('http://jw.fzfu.edu.cn/jwglxt/xtgl/login_slogin.html');; const server: boolean = await this.probe('https://fuxiaowai.xyz/healthz');; promptAction.showDialog({ |
| [entry/src/main/ets/pages/ProfilePage.ets:141](../../entry/src/main/ets/pages/ProfilePage.ets#L141) `open` | router.pushUrl({ url: 'pages/PersonalInfoPage' });; router.pushUrl({ url: 'pages/FeedbackPage' });; router.pushUrl({ url: 'pages/TimetableSettings' });; router.pushUrl({ url: 'pages/RemindPage' });; router.pushUrl({ url: 'pages/AppearancePage' });; router.pushUrl({ url: 'pages/AccountPage' });; router.pushUrl({ url: 'pages/FaqPage' });; router.pushUrl({ url: 'pages/AboutPage' });; router.pushUrl({ url: 'pages/MorePage' });; this.clearCache();; this.checkNetwork(); |
| [entry/src/main/ets/pages/ProfilePage.ets:187](../../entry/src/main/ets/pages/ProfilePage.ets#L187) `initial` | 纯计算/格式化辅助，见源码函数体 |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/ProfilePage.ets:276](../../entry/src/main/ets/pages/ProfilePage.ets#L276) Text('›') | .onClick(() => { if (!this.loggedIn) { router.pushUrl({ url: 'pages/LoginPage' }); } else { router.pushUrl({ url: 'pages/PersonalInfoPage' }); } }) |
| [entry/src/main/ets/pages/ProfilePage.ets:323](../../entry/src/main/ets/pages/ProfilePage.ets#L323) Text(r.desc) / Text('›') | .onTouch((e: TouchEvent) => { if (e.type === TouchType.Down) { this.pressKey = r.key; } else if (e.type === TouchType.Up \|\| e.type === TouchType.Cancel) { this.pressKey = ''; } }) |
| [entry/src/main/ets/pages/ProfilePage.ets:330](../../entry/src/main/ets/pages/ProfilePage.ets#L330) Text('›') | .onClick(() => { this.open(r.key); }) |

直接路由/参数索引：

- [entry/src/main/ets/pages/ProfilePage.ets:143](../../entry/src/main/ets/pages/ProfilePage.ets#L143)：`router.pushUrl({ url: 'pages/PersonalInfoPage' });`
- [entry/src/main/ets/pages/ProfilePage.ets:147](../../entry/src/main/ets/pages/ProfilePage.ets#L147)：`router.pushUrl({ url: 'pages/FeedbackPage' });`
- [entry/src/main/ets/pages/ProfilePage.ets:151](../../entry/src/main/ets/pages/ProfilePage.ets#L151)：`router.pushUrl({ url: 'pages/TimetableSettings' });`
- [entry/src/main/ets/pages/ProfilePage.ets:155](../../entry/src/main/ets/pages/ProfilePage.ets#L155)：`router.pushUrl({ url: 'pages/RemindPage' });`
- [entry/src/main/ets/pages/ProfilePage.ets:159](../../entry/src/main/ets/pages/ProfilePage.ets#L159)：`router.pushUrl({ url: 'pages/AppearancePage' });`
- [entry/src/main/ets/pages/ProfilePage.ets:163](../../entry/src/main/ets/pages/ProfilePage.ets#L163)：`router.pushUrl({ url: 'pages/AccountPage' });`
- [entry/src/main/ets/pages/ProfilePage.ets:167](../../entry/src/main/ets/pages/ProfilePage.ets#L167)：`router.pushUrl({ url: 'pages/FaqPage' });`
- [entry/src/main/ets/pages/ProfilePage.ets:171](../../entry/src/main/ets/pages/ProfilePage.ets#L171)：`router.pushUrl({ url: 'pages/AboutPage' });`
- [entry/src/main/ets/pages/ProfilePage.ets:175](../../entry/src/main/ets/pages/ProfilePage.ets#L175)：`router.pushUrl({ url: 'pages/MorePage' });`
- [entry/src/main/ets/pages/ProfilePage.ets:278](../../entry/src/main/ets/pages/ProfilePage.ets#L278)：`router.pushUrl({ url: 'pages/LoginPage' });`
- [entry/src/main/ets/pages/ProfilePage.ets:280](../../entry/src/main/ets/pages/ProfilePage.ets#L280)：`router.pushUrl({ url: 'pages/PersonalInfoPage' });`

## PersonalInfoPage

[entry/src/main/ets/pages/PersonalInfoPage.ets](../../entry/src/main/ets/pages/PersonalInfoPage.ets)；注册路由 `pages/PersonalInfoPage`。

头像选择/昵称编辑/资料展示/退出；复制裁剪临时源再push AvatarCropPage；返回重载头像。

组件/构造结构：ArrayBuffer、Column、Divider、ForEach、Image、PhotoViewPicker、Row、Scroll、Stack、StorageLink、TC、Text。本地Builder：headerBar、confirmView。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/PersonalInfoPage.ets:35](../../entry/src/main/ets/pages/PersonalInfoPage.ets#L35) `aboutToAppear` | this.load(); |
| [entry/src/main/ets/pages/PersonalInfoPage.ets:40](../../entry/src/main/ets/pages/PersonalInfoPage.ets#L40) `onPageShow` | this.load(); |
| [entry/src/main/ets/pages/PersonalInfoPage.ets:44](../../entry/src/main/ets/pages/PersonalInfoPage.ets#L44) `load` | const p: Profile = await ProfileStore.load(ctx);; this.profile = p;; this.rows = list;; this.avatarPath = await AvatarStore.load(ctx); |
| [entry/src/main/ets/pages/PersonalInfoPage.ets:59](../../entry/src/main/ets/pages/PersonalInfoPage.ets#L59) `initial` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/PersonalInfoPage.ets:66](../../entry/src/main/ets/pages/PersonalInfoPage.ets#L66) `tip` | this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1600 }); |
| [entry/src/main/ets/pages/PersonalInfoPage.ets:74](../../entry/src/main/ets/pages/PersonalInfoPage.ets#L74) `pickAvatar` | this.picking = true;; const res: photoAccessHelper.PhotoSelectResult = await pv.select(options);; this.picking = false;; this.purgeCropSrc(ctx.filesDir);; router.pushUrl({ url: 'pages/AvatarCropPage', params: params });; this.tip('当前设备没有可用图库，真机上可正常选图');; this.picking = false; |
| [entry/src/main/ets/pages/PersonalInfoPage.ets:112](../../entry/src/main/ets/pages/PersonalInfoPage.ets#L112) `purgeCropSrc` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/PersonalInfoPage.ets:128](../../entry/src/main/ets/pages/PersonalInfoPage.ets#L128) `logout` | await Locator.init(ctx);; await Locator.clearPersonalData();; this.getUIContext().getPromptAction().showToast({ message: '已退出登录', duration: 1500 });; router.back(); |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/PersonalInfoPage.ets:153](../../entry/src/main/ets/pages/PersonalInfoPage.ets#L153) Text('‹') | .onClick(() => { router.back(); }) |
| [entry/src/main/ets/pages/PersonalInfoPage.ets:213](../../entry/src/main/ets/pages/PersonalInfoPage.ets#L213) 容器/手势 | .onClick(() => { this.pickAvatar(); }) |
| [entry/src/main/ets/pages/PersonalInfoPage.ets:280](../../entry/src/main/ets/pages/PersonalInfoPage.ets#L280) Text('资料来自教务系统，在首页点 ⇩ 重新同步课表时会一并更新') / Text('退出登录') | .onClick(() => { this.confirmClear = true; }) |
| [entry/src/main/ets/pages/PersonalInfoPage.ets:325](../../entry/src/main/ets/pages/PersonalInfoPage.ets#L325) Text('会清除本机保存的学号密码、课表和成绩缓存，重新登录后自动恢复') / Text('取消') | .onClick(() => { this.confirmClear = false; }) |
| [entry/src/main/ets/pages/PersonalInfoPage.ets:337](../../entry/src/main/ets/pages/PersonalInfoPage.ets#L337) Text('退出') | .onClick(() => { this.confirmClear = false; this.logout(); }) |

直接路由/参数索引：

- [entry/src/main/ets/pages/PersonalInfoPage.ets:102](../../entry/src/main/ets/pages/PersonalInfoPage.ets#L102)：`router.pushUrl({ url: 'pages/AvatarCropPage', params: params });`
- [entry/src/main/ets/pages/PersonalInfoPage.ets:140](../../entry/src/main/ets/pages/PersonalInfoPage.ets#L140)：`router.back();`
- [entry/src/main/ets/pages/PersonalInfoPage.ets:154](../../entry/src/main/ets/pages/PersonalInfoPage.ets#L154)：`router.back();`

## AvatarCropPage

[entry/src/main/ets/pages/AvatarCropPage.ets](../../entry/src/main/ets/pages/AvatarCropPage.ets)；注册路由 `pages/AvatarCropPage`。

打开源图、拖动/缩放、取消/使用；裁剪AvatarStore保存、清临时源、返回。

组件/构造结构：ArrayBuffer、Blank、Button、Circle、Column、Image、LoadingProgress、PanGesture、Row、Slider、Stack、Text。本地Builder：无。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/AvatarCropPage.ets:33](../../entry/src/main/ets/pages/AvatarCropPage.ets#L33) `aboutToAppear` | const p: CropParams = router.getParams() as CropParams;; this.open(p.path); |
| [entry/src/main/ets/pages/AvatarCropPage.ets:40](../../entry/src/main/ets/pages/AvatarCropPage.ets#L40) `open` | const info: image.ImageInfo = await source.getImageInfo();; this.imgW = info.size.width;; this.imgH = info.size.height;; const pm: image.PixelMap = await source.createPixelMap();; this.buf = data;; this.cropPm = pm;; this.src = path;; const screenW: number = this.winWidth();; this.viewSize = Math.min(340, Math.max(240, Math.round(screenW * 0.78)));; this.cancel(); |
| [entry/src/main/ets/pages/AvatarCropPage.ets:68](../../entry/src/main/ets/pages/AvatarCropPage.ets#L68) `winWidth` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/AvatarCropPage.ets:81](../../entry/src/main/ets/pages/AvatarCropPage.ets#L81) `displayScale` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/AvatarCropPage.ets:87](../../entry/src/main/ets/pages/AvatarCropPage.ets#L87) `imageW` | return iw * this.displayScale(); |
| [entry/src/main/ets/pages/AvatarCropPage.ets:92](../../entry/src/main/ets/pages/AvatarCropPage.ets#L92) `imageH` | return ih * this.displayScale(); |
| [entry/src/main/ets/pages/AvatarCropPage.ets:97](../../entry/src/main/ets/pages/AvatarCropPage.ets#L97) `imageLeft` | return (this.viewSize - this.imageW()) / 2 + this.offsetX; |
| [entry/src/main/ets/pages/AvatarCropPage.ets:101](../../entry/src/main/ets/pages/AvatarCropPage.ets#L101) `imageTop` | return (this.viewSize - this.imageH()) / 2 + this.offsetY; |
| [entry/src/main/ets/pages/AvatarCropPage.ets:105](../../entry/src/main/ets/pages/AvatarCropPage.ets#L105) `clampOffsets` | this.offsetX = Math.max(-maxX, Math.min(maxX, nx));; this.offsetY = Math.max(-maxY, Math.min(maxY, ny)); |
| [entry/src/main/ets/pages/AvatarCropPage.ets:116](../../entry/src/main/ets/pages/AvatarCropPage.ets#L116) `cropRegion` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/AvatarCropPage.ets:137](../../entry/src/main/ets/pages/AvatarCropPage.ets#L137) `cropTo` | desiredRegion: this.cropRegion(),; const pm: image.PixelMap = await src.createPixelMap(opt); |
| [entry/src/main/ets/pages/AvatarCropPage.ets:148](../../entry/src/main/ets/pages/AvatarCropPage.ets#L148) `use` | if (this.busy \|\| this.cropPm === undefined) {; this.busy = true;; const pm: image.PixelMap = await this.cropTo(512);; const data: ArrayBuffer = await packer.packing(pm, opt);; const old: string = await AvatarStore.load(ctx);; await AvatarStore.save(ctx, dest);; this.getUIContext().getPromptAction().showToast({ message: '头像已更新', duration: 1500 });; this.cleanSrc();; router.back();; this.getUIContext().getPromptAction().showToast({ message: '保存失败，请重试', duration: 1500 });; this.busy = false; |
| [entry/src/main/ets/pages/AvatarCropPage.ets:184](../../entry/src/main/ets/pages/AvatarCropPage.ets#L184) `cleanSrc` | this.cropPm = undefined; |
| [entry/src/main/ets/pages/AvatarCropPage.ets:197](../../entry/src/main/ets/pages/AvatarCropPage.ets#L197) `cancel` | this.cleanSrc();; router.back(); |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/AvatarCropPage.ets:211](../../entry/src/main/ets/pages/AvatarCropPage.ets#L211) Button('取消', { type: ButtonType.Normal }) | .onTouch((e: TouchEvent) => { if (e.type === TouchType.Up) { this.cancel(); } }) |
| [entry/src/main/ets/pages/AvatarCropPage.ets:216](../../entry/src/main/ets/pages/AvatarCropPage.ets#L216) Button('取消', { type: ButtonType.Normal }) | .onClick(() => this.cancel()) |
| [entry/src/main/ets/pages/AvatarCropPage.ets:230](../../entry/src/main/ets/pages/AvatarCropPage.ets#L230) Text('调整头像') / Button(this.busy ? '处理中' : '使用', { type: ButtonType.Normal }) | .onTouch((e: TouchEvent) => { if (e.type === TouchType.Up) { this.use(); } }) |
| [entry/src/main/ets/pages/AvatarCropPage.ets:235](../../entry/src/main/ets/pages/AvatarCropPage.ets#L235) Text('调整头像') / Button(this.busy ? '处理中' : '使用', { type: ButtonType.Normal }) | .onClick(() => this.use()) |
| [entry/src/main/ets/pages/AvatarCropPage.ets:263](../../entry/src/main/ets/pages/AvatarCropPage.ets#L263) 容器/手势 | .onActionStart(() => { this.panBaseX = this.offsetX; this.panBaseY = this.offsetY; }) |
| [entry/src/main/ets/pages/AvatarCropPage.ets:267](../../entry/src/main/ets/pages/AvatarCropPage.ets#L267) 容器/手势 | .onActionUpdate((e: GestureEvent) => { this.clampOffsets(this.panBaseX + e.offsetX, this.panBaseY + e.offsetY); }) |
| [entry/src/main/ets/pages/AvatarCropPage.ets:301](../../entry/src/main/ets/pages/AvatarCropPage.ets#L301) Text('缩放') | .onChange((v: number) => { this.zoom = v; this.clampOffsets(this.offsetX, this.offsetY); }) |

直接路由/参数索引：

- [entry/src/main/ets/pages/AvatarCropPage.ets:34](../../entry/src/main/ets/pages/AvatarCropPage.ets#L34)：`const p: CropParams = router.getParams() as CropParams;`
- [entry/src/main/ets/pages/AvatarCropPage.ets:175](../../entry/src/main/ets/pages/AvatarCropPage.ets#L175)：`router.back();`
- [entry/src/main/ets/pages/AvatarCropPage.ets:199](../../entry/src/main/ets/pages/AvatarCropPage.ets#L199)：`router.back();`

## FeedbackPage

[entry/src/main/ets/pages/FeedbackPage.ets](../../entry/src/main/ets/pages/FeedbackPage.ets)；注册路由 `pages/FeedbackPage`。

类别/内容/联系/图片/提交/待发补传；失败保留本机队列，远端送达待确认。

组件/构造结构：Blank、Button、Circle、Column、DocumentViewPicker、ForEach、Image、PhotoViewPicker、Row、Scroll、Stack、StorageLink、TC、Text、TextArea、TextInput。本地Builder：doneOverlay、headerBar、imageGrid。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/FeedbackPage.ets:25](../../entry/src/main/ets/pages/FeedbackPage.ets#L25) `aboutToAppear` | this.refreshPending();; this.flushPending(); |
| [entry/src/main/ets/pages/FeedbackPage.ets:30](../../entry/src/main/ets/pages/FeedbackPage.ets#L30) `refreshPending` | this.pending = await FeedbackStore.pendingCount(ctx); |
| [entry/src/main/ets/pages/FeedbackPage.ets:35](../../entry/src/main/ets/pages/FeedbackPage.ets#L35) `tip` | this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1600 }); |
| [entry/src/main/ets/pages/FeedbackPage.ets:39](../../entry/src/main/ets/pages/FeedbackPage.ets#L39) `pickImages` | this.tip(′最多添加 ${MAX_IMAGES} 张图片′);; const gallery: string[] \| null = await this.pickFromGallery(remain);; uris = await this.pickFromFiles(remain);; this.tip('这张图读取失败，已跳过');; this.images = this.images.concat(added); |
| [entry/src/main/ets/pages/FeedbackPage.ets:75](../../entry/src/main/ets/pages/FeedbackPage.ets#L75) `pickFromGallery` | const res: photoAccessHelper.PhotoSelectResult = await pv.select(options); |
| [entry/src/main/ets/pages/FeedbackPage.ets:89](../../entry/src/main/ets/pages/FeedbackPage.ets#L89) `pickFromFiles` | return await dp.select(opts);; this.tip('当前设备没有可用的图库或文件选择器'); |
| [entry/src/main/ets/pages/FeedbackPage.ets:103](../../entry/src/main/ets/pages/FeedbackPage.ets#L103) `removeImage` | this.images = next; |
| [entry/src/main/ets/pages/FeedbackPage.ets:114](../../entry/src/main/ets/pages/FeedbackPage.ets#L114) `submit` | this.tip('先说点什么吧');; this.tip('留个联系方式吧，方便我们回你');; this.busy = true;; await FeedbackStore.push(ctx, f);; await this.refreshPending();; this.text = '';; this.contact = '';; this.images = [];; const state: string = await this.sendOne(f);; await this.refreshPending();; this.playDone();; this.tip('提交过于频繁，反馈已保存在本机，稍后重试');; this.tip('图片处理失败，反馈已保存在本机，请检查图片后重试');; this.tip('网络不通，已存本地，下次进入会重试');; this.tip('保存失败，请重试');; this.busy = false; |
| [entry/src/main/ets/pages/FeedbackPage.ets:162](../../entry/src/main/ets/pages/FeedbackPage.ets#L162) `playDone` | this.doneScale = 0.5;; this.showDone = true;; this.doneScale = 1;; this.showDone = false; |
| [entry/src/main/ets/pages/FeedbackPage.ets:217](../../entry/src/main/ets/pages/FeedbackPage.ets#L217) `toDataUrl` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/FeedbackPage.ets:221](../../entry/src/main/ets/pages/FeedbackPage.ets#L221) `sendOne` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/FeedbackPage.ets:226](../../entry/src/main/ets/pages/FeedbackPage.ets#L226) `flushPending` | await FeedbackDelivery.flush(ctx);; await this.refreshPending();; this.tip(error instanceof Error ? error.message : '本地反馈读取失败'); |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/FeedbackPage.ets:213](../../entry/src/main/ets/pages/FeedbackPage.ets#L213) Text('谢谢你的反馈，我们会在后续版本里处理') | .onClick(() => { }) |
| [entry/src/main/ets/pages/FeedbackPage.ets:245](../../entry/src/main/ets/pages/FeedbackPage.ets#L245) Text('‹') | .onClick(() => { router.back(); }) |
| [entry/src/main/ets/pages/FeedbackPage.ets:284](../../entry/src/main/ets/pages/FeedbackPage.ets#L284) Text('×') | .onClick(() => { this.removeImage(i); }) |
| [entry/src/main/ets/pages/FeedbackPage.ets:306](../../entry/src/main/ets/pages/FeedbackPage.ets#L306) Text('+') / Text('图片') | .onClick(() => { this.pickImages(); }) |
| [entry/src/main/ets/pages/FeedbackPage.ets:331](../../entry/src/main/ets/pages/FeedbackPage.ets#L331) 容器/手势 | .onChange((v: string) => { this.text = v; }) |
| [entry/src/main/ets/pages/FeedbackPage.ets:379](../../entry/src/main/ets/pages/FeedbackPage.ets#L379) Text('联系方式') | .onChange((v: string) => { this.contact = v; }) |
| [entry/src/main/ets/pages/FeedbackPage.ets:405](../../entry/src/main/ets/pages/FeedbackPage.ets#L405) Button(this.busy ? '提交中…' : '提交反馈') | .onClick(() => { this.submit(); }) |

直接路由/参数索引：

- [entry/src/main/ets/pages/FeedbackPage.ets:246](../../entry/src/main/ets/pages/FeedbackPage.ets#L246)：`router.back();`

## AddCoursePage

[entry/src/main/ets/pages/AddCoursePage.ets](../../entry/src/main/ets/pages/AddCoursePage.ets)；注册路由 `pages/AddCoursePage`。

3种本地组件组成课程信息、周次/单双周/颜色/节次表单；校区字段用非循环TextPicker滚轮从长乐校区、滨海校区中选择；校区行放大倒三角提示和点击区域；校验后仓储add并返回。校区初始值为长乐校区。

组件/构造结构：Blank、Circle、Column、ForEach、LabeledField、PickChip、Row、Scroll、Stack、StepSpin、StorageLink、TC、Text、TextInput。本地Builder：sectionTitle。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/AddCoursePage.ets:151](../../entry/src/main/ets/pages/AddCoursePage.ets#L151) `aboutToAppear` | const p: RouteParams = router.getParams() as RouteParams;; this.tableId = p.tableId;; this.weekStart = p.week;; this.weekEnd = Math.min(p.week + 15, this.totalWeeks);; this.loadPeriods(); |
| [entry/src/main/ets/pages/AddCoursePage.ets:165](../../entry/src/main/ets/pages/AddCoursePage.ets#L165) `loadPeriods` | PeriodStore.init(getContext(this) as common.UIAbilityContext);; const list: Period[] = await PeriodStore.load();; this.periods = list;; this.periods = DEFAULT_PERIODS; |
| [entry/src/main/ets/pages/AddCoursePage.ets:177](../../entry/src/main/ets/pages/AddCoursePage.ets#L177) `buildWeeks` | if (this.parity === PARITY_ODD && w % 2 === 0) {; if (this.parity === PARITY_EVEN && w % 2 === 1) { |
| [entry/src/main/ets/pages/AddCoursePage.ets:191](../../entry/src/main/ets/pages/AddCoursePage.ets#L191) `weeksHint` | const list: number[] = this.buildWeeks();; const parityText: string = this.parity === PARITY_ODD ? '（单周）'; : (this.parity === PARITY_EVEN ? '（双周）' : ''); |
| [entry/src/main/ets/pages/AddCoursePage.ets:204](../../entry/src/main/ets/pages/AddCoursePage.ets#L204) `periodTimeLabel` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/AddCoursePage.ets:213](../../entry/src/main/ets/pages/AddCoursePage.ets#L213) `save` | this.errMsg = '课程名不能为空';; this.errMsg = '结束节次不能早于开始节次';; this.errMsg = '结束周不能早于开始周';; const weeks: number[] = this.buildWeeks();; this.errMsg = '周次为空，检查一下单双周设置';; this.busy = true;; this.errMsg = '';; await Locator.init(ctx);; await Locator.repo().add(c, this.tableId);; this.getUIContext().getPromptAction().showToast({ message: '已添加', duration: 1400 });; router.back();; this.errMsg = '保存失败：' + (e instanceof Error ? e.message : JSON.stringify(e));; this.busy = false; |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/AddCoursePage.ets:47](../../entry/src/main/ets/pages/AddCoursePage.ets#L47) Text(this.label) | .onChange((v: string) => this.onValue(v)) |
| [entry/src/main/ets/pages/AddCoursePage.ets:74](../../entry/src/main/ets/pages/AddCoursePage.ets#L74) Text('−') | .onClick(() => { if (this.value > this.minValue) { this.onChange(this.value - 1); } }) |
| [entry/src/main/ets/pages/AddCoursePage.ets:76](../../entry/src/main/ets/pages/AddCoursePage.ets#L76) Text('−') | this.onChange(this.value - 1); |
| [entry/src/main/ets/pages/AddCoursePage.ets:93](../../entry/src/main/ets/pages/AddCoursePage.ets#L93) Text(′${this.value}′) / Text('＋') | .onClick(() => { if (this.value < this.maxValue) { this.onChange(this.value + 1); } }) |
| [entry/src/main/ets/pages/AddCoursePage.ets:95](../../entry/src/main/ets/pages/AddCoursePage.ets#L95) Text(′${this.value}′) / Text('＋') | this.onChange(this.value + 1); |
| [entry/src/main/ets/pages/AddCoursePage.ets:119](../../entry/src/main/ets/pages/AddCoursePage.ets#L119) Text(this.text) | .onClick(() => this.onTap()) |
| [entry/src/main/ets/pages/AddCoursePage.ets:294](../../entry/src/main/ets/pages/AddCoursePage.ets#L294) Text(hint) / Text('‹') | .onClick(() => router.back()) |
| [entry/src/main/ets/pages/AddCoursePage.ets:307](../../entry/src/main/ets/pages/AddCoursePage.ets#L307) Text('添加课程') / Text(this.busy ? '保存中' : '保存') | .onClick(() => { if (!this.busy) { this.save(); } }) |
| [entry/src/main/ets/pages/AddCoursePage.ets:549](../../entry/src/main/ets/pages/AddCoursePage.ets#L549) 容器/手势 | .onClick(() => { this.colorIndex = i; }) |
| AddCoursePage campusField | 点击校区值令showCampusPicker=true；TextPicker onChange按index写入campus，完成关闭；save将this.campus写入Course.campus |

直接路由/参数索引：

- [entry/src/main/ets/pages/AddCoursePage.ets:152](../../entry/src/main/ets/pages/AddCoursePage.ets#L152)：`const p: RouteParams = router.getParams() as RouteParams;`
- [entry/src/main/ets/pages/AddCoursePage.ets:257](../../entry/src/main/ets/pages/AddCoursePage.ets#L257)：`router.back();`
- [entry/src/main/ets/pages/AddCoursePage.ets:294](../../entry/src/main/ets/pages/AddCoursePage.ets#L294)：`.onClick(() => router.back())`

## PrivacyDocPage

[entry/src/main/ets/pages/PrivacyDocPage.ets](../../entry/src/main/ets/pages/PrivacyDocPage.ets)；注册路由 `pages/PrivacyDocPage`。

kind驱动隐私说明；export复制导出，revoke确认清本机个人数据、清路由replace Index。

组件/构造结构：Blank、Button、Column、Date、Divider、ForEach、Row、Scroll、StorageLink、TC、Text。本地Builder：headerBar、keyValueCard、sectionCard、actionArea、confirmSheet。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/PrivacyDocPage.ets:46](../../entry/src/main/ets/pages/PrivacyDocPage.ets#L46) `aboutToAppear` | const p = router.getParams() as Record<string, string>;; this.kind = (p && p.kind) ? p.kind : 'collect';; this.buildContent();; this.loadProfile(); |
| [entry/src/main/ets/pages/PrivacyDocPage.ets:53](../../entry/src/main/ets/pages/PrivacyDocPage.ets#L53) `loadProfile` | this.profile = await ProfileStore.load(ctx); |
| [entry/src/main/ets/pages/PrivacyDocPage.ets:58](../../entry/src/main/ets/pages/PrivacyDocPage.ets#L58) `toast` | promptAction.showToast({ message: msg, duration: 2000 }); |
| [entry/src/main/ets/pages/PrivacyDocPage.ets:66](../../entry/src/main/ets/pages/PrivacyDocPage.ets#L66) `buildContent` | if (this.kind === 'collect') {; this.title = '个人信息收集清单';; this.intro = '课表、成绩与个人资料主要保存在本机。主动分享课表或提交反馈时，所选内容会发送到福小外服务。';; this.rows = [; if (this.kind === 'share') {; this.title = '第三方信息共享清单';; this.intro = '手机直接连接学校认证与教务服务；主动分享或反馈时连接福小外服务，扫码时连接企业微信。';; this.sections = [; if (this.kind === 'permission') {; this.title = '权限中心';; this.intro = '福小外申请的权限都可以在系统“设置 → 应用 → 福小外 → 权限”里随时关闭，关闭后对应功能不可用，其余功能不受影响。';; this.rows = [; if (this.kind === 'export') {; this.title = '个人信息导出';; this.intro = '把本机保存的课表、成绩与个人资料导出为 JSON 文本并复制到剪贴板，你可以粘贴到备忘录或发给自己保存。导出过程完全在本机完成。';; this.title = '隐私协议撤回';; this.intro = '撤回同意后，福小外会删除本机保存的全部个人信息（登录凭据、个人资料、课表、成绩、反馈草稿），并回到未登录状态。此操作不可撤销。';; this.sections = [ |
| [entry/src/main/ets/pages/PrivacyDocPage.ets:155](../../entry/src/main/ets/pages/PrivacyDocPage.ets#L155) `doExport` | this.busy = true;; await Locator.init(ctx);; const tables = await Locator.repo().tables();; const courses = await Locator.repo().listAll('t1');; courses: await Locator.repo().listAll(table.id) };; const grades = await Locator.loadGradeCache(this.profile.studentId);; const feedback = await FeedbackStore.list(ctx);; await pasteboard.getSystemPasteboard().setData(data);; this.toast(′已导出 ${courses.length} 门课与个人资料到剪贴板′);; this.toast('导出失败，请稍后再试');; this.busy = false; |
| [entry/src/main/ets/pages/PrivacyDocPage.ets:195](../../entry/src/main/ets/pages/PrivacyDocPage.ets#L195) `doRevoke` | this.busy = true;; await Locator.init(ctx);; await Locator.clearPersonalData();; this.showConfirm = false;; this.toast('已撤回并清除本机数据');; router.clear();; router.replaceUrl({ url: 'pages/Index' });; this.toast('清除失败，请重试');; this.busy = false; |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/PrivacyDocPage.ets:227](../../entry/src/main/ets/pages/PrivacyDocPage.ets#L227) Text('‹') | .onClick(() => router.back()) |
| [entry/src/main/ets/pages/PrivacyDocPage.ets:334](../../entry/src/main/ets/pages/PrivacyDocPage.ets#L334) Button(this.busy ? '正在打包…' : '导出我的数据到剪贴板') | .onClick(() => { this.doExport(); }) |
| [entry/src/main/ets/pages/PrivacyDocPage.ets:357](../../entry/src/main/ets/pages/PrivacyDocPage.ets#L357) Button('撤回同意并清除本机数据') | .onClick(() => { this.showConfirm = true; }) |
| [entry/src/main/ets/pages/PrivacyDocPage.ets:441](../../entry/src/main/ets/pages/PrivacyDocPage.ets#L441) Text('登录凭据、课表、成绩、个人资料和反馈草稿都会被删除，且无法恢复。') / Button('取消') | .onClick(() => { this.showConfirm = false; }) |
| [entry/src/main/ets/pages/PrivacyDocPage.ets:451](../../entry/src/main/ets/pages/PrivacyDocPage.ets#L451) Button('取消') / Button(this.busy ? '处理中…' : '确认撤回') | .onClick(() => { this.doRevoke(); }) |

直接路由/参数索引：

- [entry/src/main/ets/pages/PrivacyDocPage.ets:47](../../entry/src/main/ets/pages/PrivacyDocPage.ets#L47)：`const p = router.getParams() as Record<string, string>;`
- [entry/src/main/ets/pages/PrivacyDocPage.ets:207](../../entry/src/main/ets/pages/PrivacyDocPage.ets#L207)：`router.clear();`
- [entry/src/main/ets/pages/PrivacyDocPage.ets:208](../../entry/src/main/ets/pages/PrivacyDocPage.ets#L208)：`router.replaceUrl({ url: 'pages/Index' });`
- [entry/src/main/ets/pages/PrivacyDocPage.ets:227](../../entry/src/main/ets/pages/PrivacyDocPage.ets#L227)：`.onClick(() => router.back())`

## ExamPage

[entry/src/main/ets/pages/ExamPage.ets](../../entry/src/main/ets/pages/ExamPage.ets)；注册路由 `pages/ExamPage`。

考试列表/下一场/刷新/验证/原网页；原网页入口push ExamWebPage。

组件/构造结构：Blank、Column、Date、ForEach、List、ListItem、LoadingProgress、Row、StorageLink、TC、Text、ZhengfangAuth。本地Builder：headerBar、summaryCard、examCard、centerHint。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/ExamPage.ets:24](../../entry/src/main/ets/pages/ExamPage.ets#L24) `aboutToAppear` | this.load(); |
| [entry/src/main/ets/pages/ExamPage.ets:29](../../entry/src/main/ets/pages/ExamPage.ets#L29) `load` | await this.loadNow(token); |
| [entry/src/main/ets/pages/ExamPage.ets:37](../../entry/src/main/ets/pages/ExamPage.ets#L37) `loadNow` | this.loading = true;; this.needLogin = false;; this.errMsg = '';; this.now = Date.now();; const cred: Credential = await CredentialStore.load(ctx);; const saved: string = await SessionStore.loadJw();; this.loading = false;; this.needLogin = true;; const r: LoginResult = await auth.login(cred.user, cred.pwd);; this.cookie = auth.cookieHeader();; await SessionStore.saveJw(this.cookie);; bodies.push(await auth.fetchExams(cur.xnm, cur.xqm));; const retry: LoginResult = await auth.login(cred.user, cred.pwd);; this.cookie = auth.cookieHeader();; await SessionStore.saveJw(this.cookie);; bodies.push(await auth.fetchExams(cur.xnm, cur.xqm));; this.loading = false;; this.exams = parsed;; this.errMsg = '';; this.exams = [];; this.errMsg = failed.length > 0 ? failed : '教务还没有发布本学期考试安排'; |
| [entry/src/main/ets/pages/ExamPage.ets:132](../../entry/src/main/ets/pages/ExamPage.ets#L132) `nextExam` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/ExamPage.ets:141](../../entry/src/main/ets/pages/ExamPage.ets#L141) `passed` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/pages/ExamPage.ets:146](../../entry/src/main/ets/pages/ExamPage.ets#L146) `openWeb` | router.pushUrl({ |
| [entry/src/main/ets/pages/ExamPage.ets:238](../../entry/src/main/ets/pages/ExamPage.ets#L238) `nextLabel` | const n: ExamRecord \| null = this.nextExam(); |
| [entry/src/main/ets/pages/ExamPage.ets:250](../../entry/src/main/ets/pages/ExamPage.ets#L250) `summaryLine` | const n: ExamRecord \| null = this.nextExam(); |
| [entry/src/main/ets/pages/ExamPage.ets:363](../../entry/src/main/ets/pages/ExamPage.ets#L363) `tagOf` | if (this.passed(e)) { |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/ExamPage.ets:162](../../entry/src/main/ets/pages/ExamPage.ets#L162) Text('‹') | .onClick(() => { router.back(); }) |
| [entry/src/main/ets/pages/ExamPage.ets:177](../../entry/src/main/ets/pages/ExamPage.ets#L177) Text('考试安排') / Text('↻') | .onClick(() => { if (!this.loading) { this.load(); } }) |
| [entry/src/main/ets/pages/ExamPage.ets:399](../../entry/src/main/ets/pages/ExamPage.ets#L399) Text(desc) / Text(actionText) | .onClick(action) |
| [entry/src/main/ets/pages/ExamPage.ets:455](../../entry/src/main/ets/pages/ExamPage.ets#L455) Text('期末考试一般提前两三周才排定，到时候点右上角 ↻ 重新读取。') / Text('重新读取') | .onClick(() => { if (!this.loading) { this.load(); } }) |
| [entry/src/main/ets/pages/ExamPage.ets:473](../../entry/src/main/ets/pages/ExamPage.ets#L473) Text('用网页查看教务原始页面 ›') | .onClick(() => this.openWeb()) |
| [entry/src/main/ets/pages/ExamPage.ets:498](../../entry/src/main/ets/pages/ExamPage.ets#L498) Text('用网页查看教务原始页面 ›') | .onClick(() => this.openWeb()) |

直接路由/参数索引：

- [entry/src/main/ets/pages/ExamPage.ets:147](../../entry/src/main/ets/pages/ExamPage.ets#L147)：`router.pushUrl({ url: 'pages/ExamWebPage', params: { url: EXAM_PAGE_URL, base: JW_BASE_URL, cookie: [运行时会话值省略] } });`
- [entry/src/main/ets/pages/ExamPage.ets:163](../../entry/src/main/ets/pages/ExamPage.ets#L163)：`router.back();`
- [entry/src/main/ets/pages/ExamPage.ets:415](../../entry/src/main/ets/pages/ExamPage.ets#L415)：`router.pushUrl({ url: 'pages/LoginPage' });`

## ExamWebPage

[entry/src/main/ets/pages/ExamWebPage.ets](../../entry/src/main/ets/pages/ExamWebPage.ets)；注册路由 `pages/ExamWebPage`。

内嵌Web，读取url/base/cookie字段，设置会话，加载失败重试与viewport修正；不记录会话值。

组件/构造结构：Column、Progress、Row、Stack、StorageLink、TC、Text、Web、WebviewController。本地Builder：headerBar。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/ExamWebPage.ets:27](../../entry/src/main/ets/pages/ExamWebPage.ets#L27) `aboutToAppear` | const p: WebParams = router.getParams() as WebParams;; this.target = p.url; |
| [entry/src/main/ets/pages/ExamWebPage.ets:49](../../entry/src/main/ets/pages/ExamWebPage.ets#L49) `fixViewport` | 纯计算/格式化辅助，见源码函数体 |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/ExamWebPage.ets:77](../../entry/src/main/ets/pages/ExamWebPage.ets#L77) Text('‹') | .onClick(() => { router.back(); }) |
| [entry/src/main/ets/pages/ExamWebPage.ets:94](../../entry/src/main/ets/pages/ExamWebPage.ets#L94) Text(this.title) / Text('↻') | .onClick(() => { try { this.controller.refresh(); } catch (e) { // 控制器未就绪时忽略 } }) |
| [entry/src/main/ets/pages/ExamWebPage.ets:123](../../entry/src/main/ets/pages/ExamWebPage.ets#L123) 容器/手势 | .onPageBegin(() => { this.loading = true; this.errMsg = ''; }) |
| [entry/src/main/ets/pages/ExamWebPage.ets:127](../../entry/src/main/ets/pages/ExamWebPage.ets#L127) 容器/手势 | .onPageEnd((ev: OnPageEndEvent) => { this.loading = false; this.fixViewport(); const t: string = ev !== undefined && ev.url !== undefined ? ev.url : ''; if (t.indexOf('login_slogin') >= 0) { this.title = '登录教务系统'; } else if (t.indexOf('kscx') >= 0) { this.title = '考试安排'; } else if (t.indexOf('cjcx') >= 0) { this.title = '成绩查询'; } }) |
| [entry/src/main/ets/pages/ExamWebPage.ets:184](../../entry/src/main/ets/pages/ExamWebPage.ets#L184) Text('校园网外访问不到 jw.fzfu.edu.cn，连接校园网或 VPN 后重试') / Text('重试') | .onClick(() => { this.errMsg = ''; try { this.controller.refresh(); } catch (e) { // 忽略 } }) |

直接路由/参数索引：

- [entry/src/main/ets/pages/ExamWebPage.ets:28](../../entry/src/main/ets/pages/ExamWebPage.ets#L28)：`const p: WebParams = router.getParams() as WebParams;`
- [entry/src/main/ets/pages/ExamWebPage.ets:78](../../entry/src/main/ets/pages/ExamWebPage.ets#L78)：`router.back();`

## FaqPage

[entry/src/main/ets/pages/FaqPage.ets](../../entry/src/main/ets/pages/FaqPage.ets)；注册路由 `pages/FaqPage`。

内置FAQ展开/收起与返回，无后端知识库。

组件/构造结构：Column、Divider、ForEach、LineIcon、Row、Scroll、StorageLink、TC、Text。本地Builder：headerBar、row。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/FaqPage.ets:61](../../entry/src/main/ets/pages/FaqPage.ets#L61) Text('‹') | .onClick(() => { router.back(); }) |
| [entry/src/main/ets/pages/FaqPage.ets:93](../../entry/src/main/ets/pages/FaqPage.ets#L93) Text(item.q) / Text(this.open === i ? '−' : '+') | .onClick(() => { this.open = this.open === i ? -1 : i; }) |

直接路由/参数索引：

- [entry/src/main/ets/pages/FaqPage.ets:62](../../entry/src/main/ets/pages/FaqPage.ets#L62)：`router.back();`

## MorePage

[entry/src/main/ets/pages/MorePage.ets](../../entry/src/main/ets/pages/MorePage.ets)；注册路由 `pages/MorePage`。

collect/share/export/permission/revoke五项统一进入PrivacyDocPage。

组件/构造结构：Column、Divider、ForEach、LineIcon、Row、Scroll、StorageLink、TC、Text。本地Builder：headerBar。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/pages/MorePage.ets:26](../../entry/src/main/ets/pages/MorePage.ets#L26) `rowBg` | 纯计算/格式化辅助，见源码函数体 |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/MorePage.ets:47](../../entry/src/main/ets/pages/MorePage.ets#L47) Text('‹') | .onClick(() => { router.back(); }) |
| [entry/src/main/ets/pages/MorePage.ets:101](../../entry/src/main/ets/pages/MorePage.ets#L101) Text(r.desc) / Text('›') | .onTouch((e: TouchEvent) => { if (e.type === TouchType.Down) { this.pressKey = r.key; } else if (e.type === TouchType.Up \|\| e.type === TouchType.Cancel) { this.pressKey = ''; } }) |
| [entry/src/main/ets/pages/MorePage.ets:108](../../entry/src/main/ets/pages/MorePage.ets#L108) Text('›') | .onClick(() => { router.pushUrl({ url: 'pages/PrivacyDocPage', params: { kind: r.key } }); }) |

直接路由/参数索引：

- [entry/src/main/ets/pages/MorePage.ets:48](../../entry/src/main/ets/pages/MorePage.ets#L48)：`router.back();`
- [entry/src/main/ets/pages/MorePage.ets:109](../../entry/src/main/ets/pages/MorePage.ets#L109)：`router.pushUrl({ url: 'pages/PrivacyDocPage', params: { kind: r.key } });`

## DayCard（桌面卡片，非main_pages路由）

[entry/src/main/ets/widget/pages/DayCard.ets](../../entry/src/main/ets/widget/pages/DayCard.ets)；由form_config和EntryFormAbility驱动。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/widget/pages/DayCard.ets:135](../../entry/src/main/ets/widget/pages/DayCard.ets#L135) Text(′还有 ${this.more} 门′) | .onClick(() => { postCardAction(this, { action: 'router', abilityName: 'EntryAbility', params: { 'from': 'day_card' } }); }) |

直接路由/参数索引：

- [entry/src/main/ets/widget/pages/DayCard.ets:136](../../entry/src/main/ets/widget/pages/DayCard.ets#L136)：`postCardAction(this, { action: 'router', abilityName: 'EntryAbility', params: { 'from': 'day_card' } });`

## 2026-11-14 Web管理后台（不属于ArkUI页面注册）

入口 [server/dashboard.html](../../server/dashboard.html)，导航由 [admin.js](../../server/admin.js) 的 `navigate` 在同页切换，不使用 Harmony router。

| 页块ID | 组件与事件 | 调用 |
| --- | --- | --- |
| page-codes | 统计卡、inspect-form、inspect-panel、tickets-filter、ticket-rows、分页；检测/复制/删除确认 | loadStats、loadTickets、inspectCode/renderInspection、copy、deleteTicket |
| page-feedback | feedback-list、feedback-detail、当前页搜索与已读筛选；详情查看联系方式、截图、已读、删除 | loadFeedback、renderFeedbackList、renderFeedbackDetail |
| page-probes | resource-metrics、probe-health/process/host、service-limits | loadProbes、loadStats |
| page-alerts | active-alerts、alert-history | loadAlerts、alertItem |
| page-audit | audit-rows | loadAudit |

公共confirm-dialog通过confirmAction先确认再调用删除API；image-dialog负责附件预览；refresh-all读取统计、告警、当前页；全局连接状态由connection按板块失败集合生成。真实Logo沿用/img/icon.png。

`n校历布局补充：AcademicCalendar.dayCell使用46vp高居中Stack承载28vp数字框，事件点translate y=17vp独立定位；周行之间的分割线与上下日期数字等距。

校历星期标题：monthCard内WEEK_HEAD文字12vp、行高42vp；日期16vp、行高46vp，以字号差补偿分割线两侧的视觉留白。
Index顶部图标：lineIconBtn(plus)→openAddCourse，lineIconBtn(import-file)→openLogin，forwardBtn内share-out→原showForward菜单；位置与按钮尺寸不变。
Index弹层宿主：showRename绑定页面根Stack；showRemindWheel绑定根Stack内独立且常驻的零尺寸Stack，避免同一节点重复bindSheet。

成绩缓存展示：GradePage.statusText只说明快照在本地缓存；headerBar不以 expired 显示红色过期告警，仍保留身份验证/重新验证按钮。build在有成绩缓存时隐藏刷新失败横幅，缓存缺失时仍显示错误重试引导。Index顶部新增、导入、分享、更多四个按钮统一按压90%及弹性回位、强调色/背景；分享菜单展开时保留选中强调，原回调不变。


## 2026-11-14｜P1 三点菜单整合

Index.build 的主 Scroll 仅渲染 courseArea，移除原课表下方 TableSwitcher、FunctionGrid 与附属文案。标题、WeekBar、BottomTabs 保留。menuOpen 时以 Scroll 包裹两张独立渐变圆角卡片（最大高度82%，下方为导航留白）；上卡由 weekPanel 与 TableSwitcher 组成，下卡 MenuSheet 为四列两行八项。weekPanel 保留周数刷新与日期范围，已移除“分享当前课表”按钮；课表切换仍调用 loadCourses。新建/长按重命名先关闭菜单再打开原 sheet，管理/删除沿用原回调。夜间模式在菜单内切换并持久化，其余功能先关闭菜单再执行 onFunctionTap。旧 onMenuTap 保留但不再由 MenuSheet 调用。

菜单按压、遮罩关闭、下滑关闭与弹入动画保留；管理状态超出容器时可纵向滚动。编译/模拟器验证证据见本次交付记录，未验证场景不由静态地图推断。


本次 P1 菜单的构建、安装与模拟器验证见 [菜单验收记录](../menu-ui-20261114.md)。


## 2026-11-14｜完整分享文案与游客导入

Index.importCard 提示无需登录，TextInput 接受完整文案；extractShareCode 提取唯一独立32位hex，多个不同口令/无合法口令提示错误，重复同一码按一个处理。唯一口令归一小写后350ms防抖查询，预览仍需覆盖确认；不自动写入。queryImport/applyImport 与输入/生命周期/身份/表编号共同校验，已取消的旧响应不会恢复预览。makeShareCode 仅远端成功才展示可复制分享文案，错误 toast 为“分享失败，请重试”，无离线伪口令弹层。


## 2026-11-14｜周数滑块松手刷新

Index.weekPanel 的 Slider/value 与右上周数字使用 previewWeek；Begin/Moving 只预览，End/Click 只在最终周改变时写 week；日期与课表仍绑定已提交 week。打开同步、关闭与离页取消未提交值；Swiper.onChange 只写 week，onWeekChange 为唯一周变化刷新入口。

构建/模拟器与日志证据见 [周数滑块验收记录](../week-slider-20261114.md)。


2026-11-14：Index.weekPanel 移除日期右侧“分享当前课表”按钮及其点击回调；日期、滑块和课表切换保留。顶部转发菜单的分享入口不变。

验证：本次 release 构建成功（builtAt UTC 2026-11-14T13:05:20.8676423Z），66项测试通过、1项跳过；清单源码哈希匹配。HAP SHA256 为 0CC0358C9A9188CCCAA89B06B4F2EC5C2CFD8E776420106DFF90A163CAA27B55；127.0.0.1:5555 安装成功，重启 EntryAbility 后实际打开菜单确认按钮已消失。截图工程外 D:/fxw_build/qa-week-slider/no-share.jpeg；未提交Git。


2026-11-14：AcademicCalendar.termTabs 的两学期文字字号调整为16vp，选中底块取消额外4vp纵向平移（y=0），使文字和34vp底块在42vp切换区域内共用垂直中心；文案与切换逻辑不变。

本次学期标签验证：release构建成功，66通过/1跳过；builtAt UTC 2026-11-14T13:08:50.7768766Z，源码清单哈希匹配；HAP SHA256 F882C29070346040CC5C90B10E8FBBA4263E1C2152F1A41C595A9E89A26092B1。127.0.0.1:5555替换安装成功、启动EntryAbility并打开校历；第一/第二学期选中态均实拍检查，截图工程外 D:/fxw_build/qa-term-tabs/first.jpeg 与 second.jpeg。未提交Git。


## 2026-11-14｜我的页面检查更新

ProfilePage.subRows 在 network 与 more 之间增加 update（检查更新，download图标）；open(update) 与 Index.onFunctionTap(update) 同调 UpdateCheck.checkForUpdate，当前仍提示版本0.1.1及未接入在线更新服务，不发网络请求。

本次检查更新入口验证：release构建成功，66测试通过、1跳过；builtAt UTC 2026-11-14T13:24:46.2817028Z，源码哈希匹配，HAP SHA256 29ADE2D299FDC796BC339225B4275691084D17F5279B8A79E6B5CE04D875EEB5。hdc 127.0.0.1:5555 替换安装并启动 EntryAbility，实际打开我的页滚动到底，确认网络检测→检查更新→更多顺序及download图标；点击显示与菜单共用的未接入更新服务提示。实拍在工程外 D:/fxw_build/qa-update-entry/entry.jpeg、clicked.jpeg。未提交Git。
