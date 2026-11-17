# 组件 Map

2026-11-15 列宽首帧修复：`TimetableGrid.colW()` 移除 `Math.max(80, ...)`，按屏幕宽减页面边距、卡片内边距和时间轴宽度估算七天/五天单列宽；同进程 `measuredColumnWidths` 只在与当前估值相差 15% 以内时复用，`onAreaChange` 持续记录实际宽度。下方自动生成的旧 `colW` 函数行仍展示修改前快照，以当前源码为准。

2026-11-15 配色补充：`TimetableGrid.isFirstCourse()` 判定该星期最早起始节次；`displayedColorIndex()` 将周一至周五首课映射为 0/1/2/3/4，课程 `colorOverride` 或历史手加课优先。`CourseBlock.displayColorIndex` 控制周卡片底色，`DayList.colorOf()` 与 `CourseDetailSheet.displayColorIndex` 沿用同色。`AddCoursePage` 的八个圆点直接使用八个实色，已选色描边。

更新：2026-11-14。依据当前实际源码静态核对；未启动应用、构建或执行测试。运行时、网络、系统授权与视觉效果待确认。源码行号为当前快照。仅记录字段名及表达式，不记录真实个人信息、密码、cookie、token值。

关联：[总览](README.md) · [项目](PROJECT_MAP.md) · [模块](MODULE_MAP.md) · [页面](PAGE_MAP.md) · [组件](COMPONENT_MAP.md) · [接口](API_MAP.md) · [数据库](DATABASE_MAP.md) · [状态](STATE_MAP.md) · [构建](BUILD_MAP.md)。

范围：11个公共ui组件、AddCoursePage本地LabeledField/StepSpin/PickChip及campusField/campusSheet构建器、1个DayCard；23个页面根组件详见页面Map。校区TextPicker仅两项并设置.canLoop(false)。回调默认均为空函数；无默认值的Prop/Link必须由调用方提供。消费者只统计实际Name({...})调用，不将import算挂载。

## BottomTabs

[entry/src/main/ets/ui/components/BottomTabs.ets](../../entry/src/main/ets/ui/components/BottomTabs.ets)

| 参数/状态类别 | 声明、类型、默认值原文 |
|---|---|
| @Prop | `@Prop current: number = 1;` |
| @Prop | `@Prop dark: boolean = false;` |
| @State | `@State pressedIdx: number = -1;` |

实际根调用点及参数（同一组件可多次使用）：

- [entry/src/main/ets/pages/AcademicCalendar.ets:366](../../entry/src/main/ets/pages/AcademicCalendar.ets#L366)：`BottomTabs({ current: 0, dark: this.dark })`
- [entry/src/main/ets/pages/GradePage.ets:572](../../entry/src/main/ets/pages/GradePage.ets#L572)：`BottomTabs({ current: 2, dark: this.dark })`
- [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets)：`BottomTabs({ current: 1, dark: this.settings.dark })`
- [entry/src/main/ets/pages/ProfilePage.ets:399](../../entry/src/main/ets/pages/ProfilePage.ets#L399)：`BottomTabs({ current: 3, dark: this.dark })`

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/ui/components/BottomTabs.ets:24](../../entry/src/main/ets/ui/components/BottomTabs.ets#L24) `press` | this.pressedIdx = i; |
| [entry/src/main/ets/ui/components/BottomTabs.ets:30](../../entry/src/main/ets/ui/components/BottomTabs.ets#L30) `release` | this.pressedIdx = -1; |
| [entry/src/main/ets/ui/components/BottomTabs.ets:39](../../entry/src/main/ets/ui/components/BottomTabs.ets#L39) `go` | router.replaceUrl({ url: 'pages/AcademicCalendar' });; router.replaceUrl({ url: 'pages/Index' });; router.replaceUrl({ url: 'pages/GradePage' });; router.replaceUrl({ url: 'pages/ProfilePage' }); |
| [entry/src/main/ets/ui/components/BottomTabs.ets:58](../../entry/src/main/ets/ui/components/BottomTabs.ets#L58) `selBg` | 纯计算/格式化辅助，见源码函数体 |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/ui/components/BottomTabs.ets:85](../../entry/src/main/ets/ui/components/BottomTabs.ets#L85) Text(name) | .onTouch((e: TouchEvent) => { if (e.type === TouchType.Down) { this.press(i); } else if (e.type === TouchType.Up \|\| e.type === TouchType.Cancel) { this.release(); } }) |
| [entry/src/main/ets/ui/components/BottomTabs.ets:92](../../entry/src/main/ets/ui/components/BottomTabs.ets#L92) 容器/手势 | .onClick(() => this.go(i)) |

直接路由/参数索引：

- [entry/src/main/ets/ui/components/BottomTabs.ets:44](../../entry/src/main/ets/ui/components/BottomTabs.ets#L44)：`router.replaceUrl({ url: 'pages/AcademicCalendar' });`
- [entry/src/main/ets/ui/components/BottomTabs.ets:48](../../entry/src/main/ets/ui/components/BottomTabs.ets#L48)：`router.replaceUrl({ url: 'pages/Index' });`
- [entry/src/main/ets/ui/components/BottomTabs.ets:52](../../entry/src/main/ets/ui/components/BottomTabs.ets#L52)：`router.replaceUrl({ url: 'pages/GradePage' });`
- [entry/src/main/ets/ui/components/BottomTabs.ets:55](../../entry/src/main/ets/ui/components/BottomTabs.ets#L55)：`router.replaceUrl({ url: 'pages/ProfilePage' });`

## CourseBlock

[entry/src/main/ets/ui/components/CourseBlock.ets](../../entry/src/main/ets/ui/components/CourseBlock.ets)

2026-11-15 核实补充：课程块已改为与安卓端相同的八色实心底、白色 15fp 课名和教室、5vp 圆角；卡片隐藏教师（详情仍保留）。新增 `@Prop alignFirst: boolean = false`，由 TimetableGrid 对每天首门且少于六节的课传入，顶部至少留 16vp；其他课名/教室组居中。窄重叠列或过长教室保留编号。旧的 `rows/onlyName/showTeacher/nameLines/roomLines` 表格为修改前快照，当前以源码为准。安卓的测量式逐字排版尚未移植，窄列最终显示效果待模拟器确认。

| 参数/状态类别 | 声明、类型、默认值原文 |
|---|---|
| @Prop | `@Prop course: Course;` |
| @Prop | `@Prop compact: boolean = false;` |
| @Prop | `@Prop narrow: boolean = false;` |
| @Prop | `@Prop cellHeight: number = 52;` |
| @Prop | `@Prop startTime: string = '';` |
| @Prop | `@Prop endTime: string = '';` |
| @Prop | `@Prop ghost: boolean = false;` |
| @Prop | `@Prop dark: boolean = false;` |
| @Prop | `@Prop blockHeight: number = 0;` |
| @Prop | `@Prop cols: number = 1;` |

实际根调用点及参数（同一组件可多次使用）：

- [entry/src/main/ets/ui/components/TimetableGrid.ets:244](../../entry/src/main/ets/ui/components/TimetableGrid.ets#L244)：`CourseBlock({ course: c, compact: this.days().length >= 7, narrow: this.showWeekend, cellHeight: this.cellHeight, startTime: this.timeOf(c.startPeriod, true), endTime: this.timeOf(c.endPeriod, false), ghost: cell.ghost, dark: this.dark, cols: cell.cols, blockHeight: ((cell.end - cell.start + 1) * this.cellHeight - 4) / cell.courses.length - 3 })`
- [entry/src/main/ets/ui/components/TimetableGrid.ets:260](../../entry/src/main/ets/ui/components/TimetableGrid.ets#L260)：`CourseBlock({ course: cell.courses[0], compact: this.days().length >= 7, narrow: this.showWeekend, cellHeight: this.cellHeight, startTime: this.timeOf(cell.start, true), endTime: this.timeOf(cell.end, false), ghost: cell.ghost, dark: this.dark, cols: cell.cols, blockHeight: (cell.end - cell.start + 1) * this.cellHeight - 4 })`

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/ui/components/CourseBlock.ets:27](../../entry/src/main/ets/ui/components/CourseBlock.ets#L27) `span` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/ui/components/CourseBlock.ets:32](../../entry/src/main/ets/ui/components/CourseBlock.ets#L32) `h` | return this.blockHeight > 0 ? this.blockHeight : this.span() * this.cellHeight - 4; |
| [entry/src/main/ets/ui/components/CourseBlock.ets:37](../../entry/src/main/ets/ui/components/CourseBlock.ets#L37) `rows` | return Math.max(1, Math.floor((this.h() - 6) / 13)); |
| [entry/src/main/ets/ui/components/CourseBlock.ets:42](../../entry/src/main/ets/ui/components/CourseBlock.ets#L42) `onlyName` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/ui/components/CourseBlock.ets:47](../../entry/src/main/ets/ui/components/CourseBlock.ets#L47) `showRoom` | return !this.ghost && !this.onlyName() && this.course.room.length > 0; |
| [entry/src/main/ets/ui/components/CourseBlock.ets:52](../../entry/src/main/ets/ui/components/CourseBlock.ets#L52) `showTeacher` | return !this.ghost && !this.onlyName() && this.course.teacher.length > 0; |
| [entry/src/main/ets/ui/components/CourseBlock.ets:57](../../entry/src/main/ets/ui/components/CourseBlock.ets#L57) `nameLines` | const rest: number = this.rows() - (this.showRoom() ? 1 : 0) - (this.showTeacher() ? 1 : 0);; return this.rows() >= 3 ? 2 : 1;; return this.onlyName() ? Math.max(1, this.rows()) : Math.max(2, rest); |
| [entry/src/main/ets/ui/components/CourseBlock.ets:72](../../entry/src/main/ets/ui/components/CourseBlock.ets#L72) `roomLines` | 纯计算/格式化辅助，见源码函数体 |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|

直接路由/参数索引：

- 无直接路由调用；共享/间接导航见总表。

## CourseDetailSheet

[entry/src/main/ets/ui/components/CourseDetailSheet.ets](../../entry/src/main/ets/ui/components/CourseDetailSheet.ets)

| 参数/状态类别 | 声明、类型、默认值原文 |
|---|---|
| @Prop | `@Prop course: Course;` |
| @Prop | `@Prop periods: Period[] = [];` |
| @Prop | `@Prop dark: boolean = false;` |
| @Prop | `@Prop allWeeks: boolean = false;` |
| @State | `@State scopeAll: boolean = false;` |
| 回调（默认空函数） | `onScope: (all: boolean) => void = () => {};` |
| 回调（默认空函数） | `onEdit: () => void = () => {};` |
| 回调（默认空函数） | `onCopy: () => void = () => {};` |
| 回调（默认空函数） | `onDelete: () => void = () => {};` |

实际根调用点及参数（同一组件可多次使用）：

- [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets)：`CourseDetailSheet({ course: this.detailCourse as Course, periods: this.periods, dark: this.settings.dark, allWeeks: this.detailAllWeeks, onScope: (all: boolean) => { this.detailAllWeeks = all; }, onEdit: () => this.toast('编辑课程（P1）'), onCopy: () => this.toast('复制到其他时段（P1）'), onDelete: () => this.deleteCourse() })`

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/ui/components/CourseDetailSheet.ets:22](../../entry/src/main/ets/ui/components/CourseDetailSheet.ets#L22) `aboutToAppear` | this.scopeAll = this.allWeeks; |
| [entry/src/main/ets/ui/components/CourseDetailSheet.ets:26](../../entry/src/main/ets/ui/components/CourseDetailSheet.ets#L26) `accent` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/ui/components/CourseDetailSheet.ets:31](../../entry/src/main/ets/ui/components/CourseDetailSheet.ets#L31) `timeText` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/ui/components/CourseDetailSheet.ets:48](../../entry/src/main/ets/ui/components/CourseDetailSheet.ets#L48) `placeText` | 纯计算/格式化辅助，见源码函数体 |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/ui/components/CourseDetailSheet.ets:89](../../entry/src/main/ets/ui/components/CourseDetailSheet.ets#L89) Text(text) | .onClick(action) |
| [entry/src/main/ets/ui/components/CourseDetailSheet.ets:144](../../entry/src/main/ets/ui/components/CourseDetailSheet.ets#L144) Text('操作范围') / Text('仅本周') | .onClick(() => { this.scopeAll = false; this.onScope(false); }) |
| [entry/src/main/ets/ui/components/CourseDetailSheet.ets:157](../../entry/src/main/ets/ui/components/CourseDetailSheet.ets#L157) Text('所有周') | .onClick(() => { this.scopeAll = true; this.onScope(true); }) |
| [entry/src/main/ets/ui/components/CourseDetailSheet.ets:180](../../entry/src/main/ets/ui/components/CourseDetailSheet.ets#L180) Text('编辑') | .onClick(() => this.onEdit()) |
| [entry/src/main/ets/ui/components/CourseDetailSheet.ets:190](../../entry/src/main/ets/ui/components/CourseDetailSheet.ets#L190) Text('复制') | .onClick(() => this.onCopy()) |
| [entry/src/main/ets/ui/components/CourseDetailSheet.ets:200](../../entry/src/main/ets/ui/components/CourseDetailSheet.ets#L200) Text('删除') | .onClick(() => this.onDelete()) |

直接路由/参数索引：

- 无直接路由调用；共享/间接导航见总表。

## DayList

[entry/src/main/ets/ui/components/DayList.ets](../../entry/src/main/ets/ui/components/DayList.ets)

| 参数/状态类别 | 声明、类型、默认值原文 |
|---|---|
| @Prop | `@Prop courses: Course[] = [];` |
| @Prop | `@Prop week: number = 1;` |
| @Prop | `@Prop periods: Period[] = [];` |
| @Prop | `@Prop dark: boolean = false;` |
| @Prop | `@Prop dayOfWeek: number = 0;` |
| 回调（默认空函数） | `onCourseTap: (c: Course) => void = () => {};` |

实际根调用点及参数（同一组件可多次使用）：

- [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets)：`DayList({ courses: this.allCourses, week: this.week, periods: this.periods, dark: this.settings.dark, onCourseTap: (c: Course) => this.openDetail(c) })`

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/ui/components/DayList.ets:26](../../entry/src/main/ets/ui/components/DayList.ets#L26) `today` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/ui/components/DayList.ets:34](../../entry/src/main/ets/ui/components/DayList.ets#L34) `timeOf` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/ui/components/DayList.ets:44](../../entry/src/main/ets/ui/components/DayList.ets#L44) `items` | const day: number = this.today();; start: this.timeOf(c.startPeriod, true),; end: this.timeOf(c.endPeriod, false) |
| [entry/src/main/ets/ui/components/DayList.ets:63](../../entry/src/main/ets/ui/components/DayList.ets#L63) `dateLabel` | return ′${now.getMonth() + 1}月${now.getDate()}日 ${names[this.today() - 1]}′; |
| [entry/src/main/ets/ui/components/DayList.ets:187](../../entry/src/main/ets/ui/components/DayList.ets#L187) `roomText` | 纯计算/格式化辅助，见源码函数体 |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/ui/components/DayList.ets:172](../../entry/src/main/ets/ui/components/DayList.ets#L172) 容器/手势 | .onClick(() => this.onCourseTap(it.course)) |

直接路由/参数索引：

- 无直接路由调用；共享/间接导航见总表。

## FunctionGrid

[entry/src/main/ets/ui/components/FunctionGrid.ets](../../entry/src/main/ets/ui/components/FunctionGrid.ets)

| 参数/状态类别 | 声明、类型、默认值原文 |
|---|---|
| @Prop | `@Prop dark: boolean = false;` |
| 回调（默认空函数） | `onItem: (key: string) => void = () => {` |

实际根调用点及参数（同一组件可多次使用）：

当前无页面挂载；Index 的菜单功能改由 MenuSheet 承担。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/ui/components/FunctionGrid.ets:49](../../entry/src/main/ets/ui/components/FunctionGrid.ets#L49) Text(it.glyph) / Text(it.label) | .onClick(() => this.onItem(it.key)) |

直接路由/参数索引：

- 无直接路由调用；共享/间接导航见总表。

## LineIcon

[entry/src/main/ets/ui/components/LineIcon.ets](../../entry/src/main/ets/ui/components/LineIcon.ets)

| 参数/状态类别 | 声明、类型、默认值原文 |
|---|---|
| @Prop | `@Prop name: string = 'grid';` |
| @Prop | `@Prop iconSize: number = 20;` |
| @Prop | `@Prop tone: string = 'sub';` |
| @Prop | `@Prop strokeW: number = 1.6;` |

实际根调用点及参数（同一组件可多次使用）：

- [entry/src/main/ets/pages/FaqPage.ets:131](../../entry/src/main/ets/pages/FaqPage.ets#L131)：`LineIcon({ name: 'help', iconSize: 15, tone: 'sub' })`
- [entry/src/main/ets/pages/MorePage.ets:72](../../entry/src/main/ets/pages/MorePage.ets#L72)：`LineIcon({ name: r.icon, iconSize: 17, tone: 'sub' })`
- [entry/src/main/ets/pages/ProfilePage.ets:237](../../entry/src/main/ets/pages/ProfilePage.ets#L237)：`LineIcon({ name: 'user', iconSize: 30, tone: 'sub', strokeW: 1.4 })`
- [entry/src/main/ets/pages/ProfilePage.ets:289](../../entry/src/main/ets/pages/ProfilePage.ets#L289)：`LineIcon({ name: r.icon, iconSize: quiet ? 17 : 19, tone: quiet ? 'sub' : 'pri', strokeW: 1.6 })`
- [entry/src/main/ets/ui/components/BottomTabs.ets:66](../../entry/src/main/ets/ui/components/BottomTabs.ets#L66)：`LineIcon({ name: this.icons[i], iconSize: 22, tone: i === this.current ? 'pri' : 'sub', strokeW: i === this.current ? 1.9 : 1.6 })`
- [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets)：`LineIcon({ name: icon, iconSize: 16, tone: 'sub', strokeW: 1.6 })`；`forwardMenu`传入 `send`（纸飞机）、`calendar`（日历）、`key`（钥匙）。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/ui/components/LineIcon.ets](../../entry/src/main/ets/ui/components/LineIcon.ets) `color` | if (this.tone === 'pri') { |
| [entry/src/main/ets/ui/components/LineIcon.ets](../../entry/src/main/ets/ui/components/LineIcon.ets) `dot` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/ui/components/LineIcon.ets](../../entry/src/main/ets/ui/components/LineIcon.ets) `draw` | Canvas path绘制；支持 `user`、`help`、`calendar`、`bell`、`shirt`、`lock`、`info`、`trash`、`book`、`award`、`send`（纸飞机，按可见轮廓居中）、`key`（钥匙，按可见轮廓居中）、`wifi`，其他名称绘制四格网格图标。 |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|

直接路由/参数索引：

- 无直接路由调用；共享/间接导航见总表。

## MenuSheet

[MenuSheet.ets](../../entry/src/main/ets/ui/components/MenuSheet.ets)：三点菜单下方独立圆角渐变卡片，四列两行，八项顺序为上课时间、课表设置、上课提醒、小组件、联系我们、主题设置、夜间模式、检查更新。LineIcon 置于居中的36vp圆底内；pressedKey 管理按压缩放。

参数保持 `@Prop dark: boolean = false`、`onSelect: (key: string) => void`。Index.build 是根调用者，key 发往 onFunctionTap，夜间模式不关闭菜单，其他项先 closeMenu。组件不直接调用 router，不再使用旧纵向列表与 badge。

## TableSwitcher

[entry/src/main/ets/ui/components/TableSwitcher.ets](../../entry/src/main/ets/ui/components/TableSwitcher.ets)

| 参数/状态类别 | 声明、类型、默认值原文 |
|---|---|
| @Prop | `@Prop tables: TableOption[] = [];` |
| @Prop | `@Prop dark: boolean = false;` |
| @Link | `@Link activeId: string;` |
| 回调（默认空函数） | `onSwitch: (id: string) => void = () => {` |
| 回调（默认空函数） | `onCreate: () => void = () => {` |
| 回调（默认空函数） | `onDelete: (t: TableOption) => void = () => {` |
| 回调（默认空函数） | `onRename: (t: TableOption) => void = () => {` |
| @State | `@State managing: boolean = false;` |

实际根调用点及参数（菜单上卡片）：

- [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets)：`TableSwitcher({ tables: this.tables, activeId: $activeTableId, onSwitch: (id: string) => { this.loadCourses(); }, onCreate: () => { this.closeMenu(); this.openCreate(); }, onDelete: (t: TableOption) => this.confirmDeleteTable(t), onRename: (t: TableOption) => { this.closeMenu(); this.openRename(t); }, dark: this.settings.dark })`

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/ui/components/TableSwitcher.ets](../../entry/src/main/ets/ui/components/TableSwitcher.ets) `isSel` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/ui/components/TableSwitcher.ets](../../entry/src/main/ets/ui/components/TableSwitcher.ets) `cardBg` | if (this.isSel(id)) { |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/ui/components/TableSwitcher.ets](../../entry/src/main/ets/ui/components/TableSwitcher.ets) Text(t.name) | .onClick(() => { this.activeId = t.id; this.onSwitch(t.id); }) |
| [entry/src/main/ets/ui/components/TableSwitcher.ets](../../entry/src/main/ets/ui/components/TableSwitcher.ets) 容器/手势 | .onAction(() => { this.onRename(t); }) |
| [entry/src/main/ets/ui/components/TableSwitcher.ets](../../entry/src/main/ets/ui/components/TableSwitcher.ets) Text('×') | .onClick(() => { this.onDelete(t); }) |
| [entry/src/main/ets/ui/components/TableSwitcher.ets](../../entry/src/main/ets/ui/components/TableSwitcher.ets) Text('切换课表') / Text(this.managing ? '完成' : '管理课表') | .onClick(() => { this.managing = !this.managing; }) |

直接路由/参数索引：

- 无直接路由调用；共享/间接导航见总表。

## TimetableGrid

[entry/src/main/ets/ui/components/TimetableGrid.ets](../../entry/src/main/ets/ui/components/TimetableGrid.ets)

| 参数/状态类别 | 声明、类型、默认值原文 |
|---|---|
| @Prop | `@Prop courses: Course[] = [];` |
| @Prop | `@Prop week: number = 1;` |
| @Prop | `@Prop showWeekend: boolean = true;` |
| @Prop | `@Prop showGhost: boolean = false;` |
| @Prop | `@Prop periods: Period[] = DEFAULT_PERIODS;` |
| @Prop | `@Prop cellHeight: number = 52;` |
| @Prop | `@Prop dark: boolean = false;` |
| 回调（默认空函数） | `onCourseTap: (c: Course) => void = () => {};` |
| @State | `@State colWidth: number = 0;` |

实际根调用点及参数（同一组件可多次使用）：

- [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets)：`TimetableGrid({ courses: this.allCourses, week: w, showWeekend: this.showWeekend, showGhost: this.settings.showGhost, periods: this.periods, cellHeight: this.settings.cellHeight, dark: this.settings.dark, onCourseTap: (c: Course) => this.openDetail(c) })`
- [entry/src/main/ets/pages/TimetableSettings.ets:83](../../entry/src/main/ets/pages/TimetableSettings.ets#L83)：`TimetableGrid({ courses: this.courses, week: this.week, showWeekend: true, periods: this.periods, cellHeight: this.liveCell, dark: this.dark, onCourseTap: (c: Course) => {} })`

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|
| [entry/src/main/ets/ui/components/TimetableGrid.ets:40](../../entry/src/main/ets/ui/components/TimetableGrid.ets#L40) `colW` | return Math.max(80, (sw - Metric.timeColWidth - 32) / this.days().length); |
| [entry/src/main/ets/ui/components/TimetableGrid.ets:57](../../entry/src/main/ets/ui/components/TimetableGrid.ets#L57) `blockW` | const unit: number = this.colW() / cell.cols; |
| [entry/src/main/ets/ui/components/TimetableGrid.ets:66](../../entry/src/main/ets/ui/components/TimetableGrid.ets#L66) `blockX` | const unit: number = this.colW() / cell.cols; |
| [entry/src/main/ets/ui/components/TimetableGrid.ets:71](../../entry/src/main/ets/ui/components/TimetableGrid.ets#L71) `days` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/ui/components/TimetableGrid.ets:76](../../entry/src/main/ets/ui/components/TimetableGrid.ets#L76) `timeOf` | 纯计算/格式化辅助，见源码函数体 |
| [entry/src/main/ets/ui/components/TimetableGrid.ets:89](../../entry/src/main/ets/ui/components/TimetableGrid.ets#L89) `cellsOfDay` | return this.layoutColumns(arr); |
| [entry/src/main/ets/ui/components/TimetableGrid.ets:153](../../entry/src/main/ets/ui/components/TimetableGrid.ets#L153) `layoutColumns` | 纯计算/格式化辅助，见源码函数体 |

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/ui/components/TimetableGrid.ets:257](../../entry/src/main/ets/ui/components/TimetableGrid.ets#L257) 容器/手势 | .onClick(() => this.onCourseTap(c)) |
| [entry/src/main/ets/ui/components/TimetableGrid.ets:277](../../entry/src/main/ets/ui/components/TimetableGrid.ets#L277) 容器/手势 | .onClick(() => this.onCourseTap(cell.courses[0])) |
| [entry/src/main/ets/ui/components/TimetableGrid.ets:282](../../entry/src/main/ets/ui/components/TimetableGrid.ets#L282) 容器/手势 | .onAreaChange((_o: Area, n: Area) => { const w: number = Number(n.width); if (w > 0 && Math.abs(w - this.colWidth) > 0.5) { this.colWidth = w; } }) |

直接路由/参数索引：

- 无直接路由调用；共享/间接导航见总表。

## WeekBar

[entry/src/main/ets/ui/components/WeekBar.ets](../../entry/src/main/ets/ui/components/WeekBar.ets)

| 参数/状态类别 | 声明、类型、默认值原文 |
|---|---|
| @Prop | `@Prop dates: string[] = []; // 日号，如 '10'` |
| @Prop | `@Prop todayIndex: number = 0; // 0-based（周一=0）` |
| @Prop | `@Prop showWeekend: boolean = true;` |
| @Prop | `@Prop month: string = '11月';` |
| @Prop | `@Prop dark: boolean = false;` |

实际根调用点及参数（同一组件可多次使用）：

- [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets)：`WeekBar({ dates: this.weekDates, todayIndex: this.todayIndex, showWeekend: this.showWeekend, month: this.weekMonth, dark: this.settings.dark })`

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|

直接路由/参数索引：

- 无直接路由调用；共享/间接导航见总表。

## WeekSlider

[entry/src/main/ets/ui/components/WeekSlider.ets](../../entry/src/main/ets/ui/components/WeekSlider.ets)

| 参数/状态类别 | 声明、类型、默认值原文 |
|---|---|
| @Link | `@Link week: number;` |
| @Prop | `@Prop totalWeeks: number = 20;` |
| @Prop | `@Prop dark: boolean = false;` |
| 回调（默认空函数） | `onShare: () => void = () => {` |

实际根调用点及参数（同一组件可多次使用）：

- 当前ets中无直接构造；DayCard由form_config.src加载，其他组件不能因存在源码就认定已显示。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/ui/components/WeekSlider.ets:26](../../entry/src/main/ets/ui/components/WeekSlider.ets#L26) Text('周数') / Text('分享当前课表') | .onClick(() => this.onShare()) |
| [entry/src/main/ets/ui/components/WeekSlider.ets:42](../../entry/src/main/ets/ui/components/WeekSlider.ets#L42) 容器/手势 | .onChange((value: number) => { this.week = Math.round(value); }) |

直接路由/参数索引：

- 无直接路由调用；共享/间接导航见总表。

## LabeledField

[entry/src/main/ets/pages/AddCoursePage.ets](../../entry/src/main/ets/pages/AddCoursePage.ets)

| 参数/状态类别 | 声明、类型、默认值原文 |
|---|---|
| @Prop | `@Prop dark: boolean = false;` |
| @Prop | `@Prop label: string = '';` |
| @Prop | `@Prop placeholder: string = '';` |
| @Prop | `@Prop value: string = '';` |
| @Prop | `@Prop numeric: boolean = false;` |
| 回调（默认空函数） | `onValue: (v: string) => void = () => {` |

实际根调用点及参数（同一组件可多次使用）：

- [entry/src/main/ets/pages/AddCoursePage.ets:330](../../entry/src/main/ets/pages/AddCoursePage.ets#L330)：`LabeledField({ dark: this.dark, label: '课程名 *', placeholder: '', value: this.name, onValue: (v: string) => { this.name = v; } })`
- [entry/src/main/ets/pages/AddCoursePage.ets:339](../../entry/src/main/ets/pages/AddCoursePage.ets#L339)：`LabeledField({ dark: this.dark, label: '教师', placeholder: '', value: this.teacher, onValue: (v: string) => { this.teacher = v; } })`
- [entry/src/main/ets/pages/AddCoursePage.ets:350](../../entry/src/main/ets/pages/AddCoursePage.ets#L350)：`LabeledField({ dark: this.dark, label: '教室', placeholder: '', value: this.room, onValue: (v: string) => { this.room = v; } })`
- [entry/src/main/ets/pages/AddCoursePage.ets:362](../../entry/src/main/ets/pages/AddCoursePage.ets#L362)：`LabeledField({ dark: this.dark, label: '校区', placeholder: '', value: this.campus, onValue: (v: string) => { this.campus = v; } })`

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/AddCoursePage.ets:47](../../entry/src/main/ets/pages/AddCoursePage.ets#L47) Text(this.label) | .onChange((v: string) => this.onValue(v)) |

直接路由/参数索引：

- 无直接路由调用；共享/间接导航见总表。

## StepSpin

[entry/src/main/ets/pages/AddCoursePage.ets](../../entry/src/main/ets/pages/AddCoursePage.ets)

| 参数/状态类别 | 声明、类型、默认值原文 |
|---|---|
| @Prop | `@Prop dark: boolean = false;` |
| @Prop | `@Prop value: number = 1;` |
| @Prop | `@Prop minValue: number = 1;` |
| @Prop | `@Prop maxValue: number = 12;` |
| 回调（默认空函数） | `onChange: (v: number) => void = () => {` |

实际根调用点及参数（同一组件可多次使用）：

- [entry/src/main/ets/pages/AddCoursePage.ets:413](../../entry/src/main/ets/pages/AddCoursePage.ets#L413)：`StepSpin({ dark: this.dark, value: this.startPeriod, minValue: 1, maxValue: this.periods.length, onChange: (v: number) => { this.startPeriod = v; if (this.endPeriod < v) { this.endPeriod = v; } } })`
- [entry/src/main/ets/pages/AddCoursePage.ets:430](../../entry/src/main/ets/pages/AddCoursePage.ets#L430)：`StepSpin({ dark: this.dark, value: this.endPeriod, minValue: this.startPeriod, maxValue: this.periods.length, onChange: (v: number) => { this.endPeriod = v; } })`
- [entry/src/main/ets/pages/AddCoursePage.ets:462](../../entry/src/main/ets/pages/AddCoursePage.ets#L462)：`StepSpin({ dark: this.dark, value: this.weekStart, minValue: 1, maxValue: this.weekEnd, onChange: (v: number) => { this.weekStart = v; } })`
- [entry/src/main/ets/pages/AddCoursePage.ets:476](../../entry/src/main/ets/pages/AddCoursePage.ets#L476)：`StepSpin({ dark: this.dark, value: this.weekEnd, minValue: this.weekStart, maxValue: this.totalWeeks, onChange: (v: number) => { this.weekEnd = v; } })`

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/AddCoursePage.ets:74](../../entry/src/main/ets/pages/AddCoursePage.ets#L74) Text('−') | .onClick(() => { if (this.value > this.minValue) { this.onChange(this.value - 1); } }) |
| [entry/src/main/ets/pages/AddCoursePage.ets:76](../../entry/src/main/ets/pages/AddCoursePage.ets#L76) Text('−') | this.onChange(this.value - 1); |
| [entry/src/main/ets/pages/AddCoursePage.ets:93](../../entry/src/main/ets/pages/AddCoursePage.ets#L93) Text(′${this.value}′) / Text('＋') | .onClick(() => { if (this.value < this.maxValue) { this.onChange(this.value + 1); } }) |
| [entry/src/main/ets/pages/AddCoursePage.ets:95](../../entry/src/main/ets/pages/AddCoursePage.ets#L95) Text(′${this.value}′) / Text('＋') | this.onChange(this.value + 1); |

直接路由/参数索引：

- 无直接路由调用；共享/间接导航见总表。

## PickChip

[entry/src/main/ets/pages/AddCoursePage.ets](../../entry/src/main/ets/pages/AddCoursePage.ets)

| 参数/状态类别 | 声明、类型、默认值原文 |
|---|---|
| @Prop | `@Prop dark: boolean = false;` |
| @Prop | `@Prop text: string = '';` |
| @Prop | `@Prop active: boolean = false;` |
| 回调（默认空函数） | `onTap: () => void = () => {` |

实际根调用点及参数（同一组件可多次使用）：

- [entry/src/main/ets/pages/AddCoursePage.ets:386](../../entry/src/main/ets/pages/AddCoursePage.ets#L386)：`PickChip({ dark: this.dark, text: d, active: this.weekday === i + 1, onTap: () => { this.weekday = i + 1; } })`
- [entry/src/main/ets/pages/AddCoursePage.ets:489](../../entry/src/main/ets/pages/AddCoursePage.ets#L489)：`PickChip({ dark: this.dark, text: '全部周', active: this.parity === PARITY_ALL, onTap: () => { this.parity = PARITY_ALL; } })`
- [entry/src/main/ets/pages/AddCoursePage.ets:495](../../entry/src/main/ets/pages/AddCoursePage.ets#L495)：`PickChip({ dark: this.dark, text: '单周', active: this.parity === PARITY_ODD, onTap: () => { this.parity = PARITY_ODD; } })`
- [entry/src/main/ets/pages/AddCoursePage.ets:501](../../entry/src/main/ets/pages/AddCoursePage.ets#L501)：`PickChip({ dark: this.dark, text: '双周', active: this.parity === PARITY_EVEN, onTap: () => { this.parity = PARITY_EVEN; } })`
- [entry/src/main/ets/pages/AddCoursePage.ets:508](../../entry/src/main/ets/pages/AddCoursePage.ets#L508)：`PickChip({ dark: this.dark, text: '整学期', active: this.weekStart === 1 && this.weekEnd === this.totalWeeks, onTap: () => { this.weekStart = 1; this.weekEnd = this.totalWeeks; this.parity = PARITY_ALL; } })`

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/pages/AddCoursePage.ets:119](../../entry/src/main/ets/pages/AddCoursePage.ets#L119) Text(this.text) | .onClick(() => this.onTap()) |

直接路由/参数索引：

- 无直接路由调用；共享/间接导航见总表。

## DayCard

[entry/src/main/ets/widget/pages/DayCard.ets](../../entry/src/main/ets/widget/pages/DayCard.ets)

| 参数/状态类别 | 声明、类型、默认值原文 |
|---|---|
| @LocalStorageProp('ready') | `@LocalStorageProp('ready') ready: string = '0';` |
| @LocalStorageProp('weekLabel') | `@LocalStorageProp('weekLabel') weekLabel: string = '';` |
| @LocalStorageProp('dateLabel') | `@LocalStorageProp('dateLabel') dateLabel: string = '今天';` |
| @LocalStorageProp('count') | `@LocalStorageProp('count') count: string = '0';` |
| @LocalStorageProp('empty') | `@LocalStorageProp('empty') empty: string = '1';` |
| @LocalStorageProp('more') | `@LocalStorageProp('more') more: string = '';` |
| @LocalStorageProp('lines') | `@LocalStorageProp('lines') lines: string = '';` |

实际根调用点及参数（同一组件可多次使用）：

- 当前ets中无直接构造；DayCard由form_config.src加载，其他组件不能因存在源码就认定已显示。

| 函数/生命周期 | 实际调用与状态副作用（原文压缩） |
|---|---|

事件“邻近内容”只是源码定位，不保证所属按钮文案；以绑定及处理器副作用为准。

| 事件行 / 邻近内容 | 处理器或直接副作用原文 |
|---|---|
| [entry/src/main/ets/widget/pages/DayCard.ets:135](../../entry/src/main/ets/widget/pages/DayCard.ets#L135) Text(′还有 ${this.more} 门′) | .onClick(() => { postCardAction(this, { action: 'router', abilityName: 'EntryAbility', params: { 'from': 'day_card' } }); }) |

直接路由/参数索引：

- [entry/src/main/ets/widget/pages/DayCard.ets:136](../../entry/src/main/ets/widget/pages/DayCard.ets#L136)：`postCardAction(this, { action: 'router', abilityName: 'EntryAbility', params: { 'from': 'day_card' } });`

## 卡片数据、依赖及参数契约

[FormData](../../entry/src/main/ets/widget/FormData.ets) 导出COURSE_BG/COURSE_FG、startClock/endClock（缺节次则回退DEFAULT_PERIODS）、todayDateLabel/todayWeekday、buildDayLines。buildDayLines按weekday与weeks包含当前周筛选，按startPeriod排序；每行按 `\t` 分隔：时间、课名、教室、底色、主色；课程行按 `\n` 分隔。

[EntryFormAbility](../../entry/src/main/ets/widget/EntryFormAbility.ets)：onAddForm读取Want的IDENTITY_KEY/NAME_KEY，remember写fxw_forms的form_<id>，立即返回ready=0，再异步push；onUpdateForm读取记住的cardName再push；onRemoveForm忘记form ID。buildPayload依次Db.open、读取当前账户并claimLegacyAccount/selectAccount、TimetableStateStore.init/activeTableId、CourseDao.queryAll、PeriodStore.load；currentWeek(TOTAL_WEEKS)与todayWeekday决定当天课，最多发5行。

[WidgetRefresh](../../entry/src/main/ets/widget/WidgetRefresh.ets).update(ctx,courses,periods)接受调用方数据，构造相同payload并遍历fxw_forms合法数字form ID，经AccountScope快照校验后updateForm；单卡失败被捕获。当前实际调用点：

- [entry/src/main/ets/pages/Index.ets](../../entry/src/main/ets/pages/Index.ets)：`WidgetRefresh.update(getContext(this) as common.UIAbilityContext, all, this.periods).catch(() => {});`
- [entry/src/main/ets/app/di/ServiceLocator.ets](../../entry/src/main/ets/app/di/ServiceLocator.ets)：`await WidgetRefresh.update(ctx, [], []);`

| LocalStorageProp字段（均string） | 默认 | 数据含义 |
|---|---|---|
| ready | 0 | 1表示真实数据就绪，否则显示正在读取 |
| weekLabel | 空 | 第N周 |
| dateLabel | 今天 | 当前月日与星期 |
| count | 0 | 当天总课程数 |
| empty | 1 | 无课1/有课0 |
| more | 空 | 超出前5门的数量，无则空 |
| lines | 空 | 最多5行的扁平字符串 |

[form_config](../../entry/src/main/resources/base/profile/form_config.json) 声明day_card；src=./ets/widget/pages/DayCard.ets；uiSyntax=arkts；designWidth=720/autoDesignWidth=true；colorMode=auto；isDefault/updateEnabled=true；scheduledUpdateTime=06:10；updateDuration=1；defaultDimension=2*4；supportDimensions=2*4与4*4。以上是声明，不保证系统实际准时刷新。DayCard的linePart/lineList/subOf纯解析字符串；点击整卡postCardAction(action=router,abilityName=EntryAbility,params.from=day_card)，非直接main_pages路径。

## 组件实际边界与待确认

TimetableGrid将同日区间重叠课程分簇再贪心分列；showGhost默认false，开启后仅保留当前及未来尚有课的最近周候选，且排除与本周真实课程相交区间。CourseBlock只展示，点击由Grid父层onCourseTap处理；startTime/endTime虽公开但当前build不显示。Grid当前没有blockRatio属性，不把旧注释当实现。

TableSwitcher点卡先写Link activeId再onSwitch；420ms长按onRename；管理/完成只切本地managing，课表数量大于1才显示删除；真正新建/删除/改名由父回调承担。WeekSlider滑动只改Link week，分享调用onShare。WeekBar只显示日期。DayList筛指定weekday或系统今天的本周课程；dateLabel使用系统日期并以names[this.today()-1]取星期文本，显示正确性待确认。

CourseDetailSheet.aboutToAppear把allWeeks复制到scopeAll，切范围onScope；编辑/复制/删除仅发回调，当前Index编辑复制是P1 Toast。LineIcon使用Canvas.onReady绘制；tone/dark 变化通过 Watch 重绘。FunctionGrid/MenuSheet只发key、不拥有router；是否挂载及实际父处理以根调用点和页面Map为准。

LabeledField输入回调onValue；StepSpin减/加只在minValue/maxValue内调用onChange；PickChip只回调onTap；状态归AddCoursePage。三个组件没有网络或数据库职责。

## 2026-11-14 Web后台组件

[dashboard.html](../../server/dashboard.html) + [admin.css](../../server/admin.css) + [admin.js](../../server/admin.js) 为原生DOM组件，不引入ArkUI或第三方框架。

- el(tag,text,className)统一textContent创建元素，badge/fields/empty复用在各页，用户字符串不进入innerHTML。
- .metric/.panel/.table-wrap/.pager复用统计、详情、列表；create DOM依赖由PAGE_MAP列出。
- confirmAction(title,description)复用confirm-dialog确认口令/留言删除；image-dialog和image-preview用于受认证反馈图片预览。
- renderFeedbackDetail(r,animate)复用反馈详情，read标记和删除调用原接口；联系方式显式点击后显示，截图URL限制为合法管理图片路径。
- CSS的enter/dialog-in动画、按钮hover/active、进度条过渡用于交互反馈；prefers-reduced-motion关闭动画与过渡。Logo来自已存在server/site/img/icon.png，经/img/icon.png引用。


菜单图标居中：Index.forwardRow 使用 26×26 Stack(alignContent: Alignment.Center) 包裹 16×16 LineIcon；背景与圆角施加于 Stack，避免改变 Canvas 布局尺寸而绘图区域仍停留左上。
LineIcon新增plus、import-file、share-out，由Index.lineIconBtn/forwardBtn使用；tone=text用于正文颜色，tone=text-strong用于按压强调；tone与全局dark变化时重绘Canvas。顶部四个按钮（新增、导入、分享、更多）区域保持34×34；触摸按下scale至0.9并加深颜色/显示chip背景，抬起或取消时弹性回位；分享菜单打开时保持选中强调，业务回调不变。Index.pressedToolbarIcon统一保存短暂按压项。
BottomTabs滑动：selected、barWidth、moving、destination管理动画；go→slide→navigate，250ms结束后replaceUrl，失败回退current；aboutToDisappear用alive禁止过期动画回调导航。


## 2026-11-14｜菜单组件调整

TableSwitcher 仅挂载于 Index 的菜单上卡片，标题行增加“新建课表”，移除 newCard；66×84vp 课表卡片在选中时显示勾选标识，背景透明以透出父卡片渐变。activeId、onSwitch/onCreate/onDelete/onRename 契约未变。FunctionGrid 文件保留，Index 已不再挂载。LineIcon 增加 clock/sliders/phone/mail/moon/download 六种 Canvas 路径，供 MenuSheet 使用。


本次 P1 菜单的构建、安装与模拟器验证见 [菜单验收记录](../menu-ui-20261114.md)。


## 2026-11-14｜标准直线勾

TableSwitcher 选中态用 LineIcon(name=check,iconSize=27,tone=white,strokeW=2.2) 替代字体勾。LineIcon.check 为两段直线，lineCap=butt、lineJoin=miter，无弧线；其他图标保留原绘制方式。


## 2026-11-14｜周数滑块松手刷新

本次改动作用于 Index 内置 weekPanel，并非独立 WeekSlider 组件。仅滑块与右上周数字消费 previewWeek；背景课表与日期不消费该值。现有 Slider 样式不变。

构建/模拟器与日志证据见 [周数滑块验收记录](../week-slider-20261114.md)。


2026-11-14：Index 内置 weekPanel 的日期行仅显示日期范围，移除右侧分享按钮；滑块预览/松手提交行为不变。


## 2026-11-14｜我的页面检查更新

ProfilePage.rowItem 的 update 项复用 MenuSheet 同名 download LineIcon，tone=text（其余行色调不变），沿用列表圆底与按压反馈。

## 2026-11-15｜更新公告
[UpdateAnnouncement](../../entry/src/main/ets/ui/components/UpdateAnnouncement.ets) 为@Component，参数version/content/canIgnore/preview/onDismiss/onUpdate；updateDialogBuilder包装UpdateDialogParams，UpdateCheck通过ComponentContent及UIContext.getPromptAction().openCustomDialog展示。内容区可滚动，按钮暂不更新/立即更新，标准Checkbox。ProfilePage长按检查更新打开明确标注的本地样式预览；预览不保存偏好、不发起安装。

## 2026-11-15｜图标与首次加载
ProfilePage更新图标与网络检测统一tone=sub，亮色#8A90A0，深色#A9AEBD。

2026-11-16：BottomTabs第三项工作台→pages/WorkbenchPage，LineIcon新增toolbox。WorkbenchPage本地WorkbenchFavorites通过@Link favorites绑定数组，避免bindSheet捕获初始空列表；双列服务卡与通栏卡、500ms长按菜单（244vp）、菜单按来源卡片上下避让。


2026-11-16 格子宽度：TimetableGrid 新增 blockWidthScale（默认1）和 onBaseBlockWidth 回调；实际课程块宽度乘缩放比例，测量列宽后回报未缩放基础宽度。Index传入设置并将比例纳入Swiper子项key。

2026-11-16 宽度重叠修正：上条0.875～1.25范围已替换为0.875～1；SettingsStore.load夹回旧超限值，TimetableGrid.blockW按子列unit-1设上限（移除14vp最小宽导致的多列越界）。设置页P1布局为格子高度/格子宽度、下方灰色vp、蓝色滑块，无底部范围文字；宽度0.1vp步进。原背景/面板opacity未改。

2026-11-16 安卓列宽方案替换此前卡片缩放方案：TimetableGrid/WeekBar新增cellWidth，0自动、45～55vp手动。日期和课程共用同一列宽；Grid卡片在子列内留2vp间隔，不使用14/18vp最小宽。旧blockWidthScale属性已移除。

2026-11-16 时间轴样式对齐安卓solution最新423段：TimetableGrid左侧三行（节次/开始/结束）均12fp字号、12vp行高及高度，间距1vp、居中；节次Normal/textHint，时间textHint且opacity0.75。读取periods，不改默认时间、个人设置、列宽或卡片。

2026-11-16 安卓最新自适应/课程文字/日视图迁移（替换此前宽度方案）：TimetableGrid.cellWidth仅兼容旧绝对值，cellWidthRatio为0自动/0.8～1；日列始终layoutWeight等分，onBaseBlockWidth返回实测列宽。CellWidth.effectiveWidth按实测列计算0.1vp上下界。课程块居中且不越出撞课子列。CourseBlock用@ohos.measure逐字测量并BREAK_ALL换行，CourseTextLayout计算行数/教室至少两行留位，长地点按需退回编号；字号/颜色未改。WeekBar取消手动固定宽度。

2026-11-16 安卓最终方案同步：替换此前45～55vp横滚方案：TimetableGrid列宽始终等分容器，onBaseBlockWidth返回实测值，cellWidthRatio控制卡片在所属日列/撞课子列中居中缩放。CellWidth范围实际列宽80%～100%。CourseTextLayout辅助逐字换行、至少两行教室留位及fixedRoomCode；CourseBlock测字配合BREAK_ALL，教5404固定为教5\n404，完整信息仍在详情。

2026-11-16 日视图时间配色逻辑：DayList.colorOf不再按课程色号，改用DayCourseStatus.hasCourseEnded与实际末节结束时间，已结束引用COURSE_COLORS[3]蓝，未结束引用[0]红；原浅底/实色色值及周视图配色不变。组件出现启动1秒刷新，消失清理计时器。

2026-11-16 联网北京时间：DayList的clockTime来自BeijingClock，civil(clockTime)取UTC字段；hasCourseEnded接收北京时间civil，getUTC*禁止系统时区介入。

2026-11-16 工作台常用功能退役：WorkbenchPage删除LongPressGesture、菜单遮罩、添加/移除/查看常用、WorkbenchFavorites弹层及preferences读写/状态。五项服务及官网点击入口不变。PrivacyDocPage删除常用收集条目，ServiceLocator仍清理旧fxw_workbench数据以兼容历史版本；不自动清除用户其他数据。

2026-11-17 成绩/考试按安卓当前开发日志复刻：LineIcon新增search、query-back/query-refresh/query-down，query-blue色#168BD1；成绩分数亮色#1675C8暗色#6CAAFF。GradeRow分隔线/白底，ExamCard布局左弹性、中60vp、右126vp、日历线图标，最小108vp高、12vp圆角。
