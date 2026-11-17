# 状态与生命周期地图

2026-11-15 跨 Tab 首帧跳变修复：`BottomTabs.navigate()` 仍用 `router.replaceUrl()` 新建 Index；`Index.restoreView()` 在首帧前按账号代次/数据库账号/课表 ID 恢复同进程快照，`refreshPage()` 合并 `aboutToAppear/onPageShow` 的重复装载，`captureView()` 只保留成功加载后的课表。`TimetableGrid.colW()` 不再用 80vp 下限，而以页面可用宽度或同布局上次实测列宽起算。三条 Tab 返回课程的模拟器截图均显示正常列位；严格逐帧与真机待确认。

2026-11-15 课程编辑状态补充：`AddCoursePage` 用 `editCourse` 保存原课程身份，`weeksChanged=false` 时原样保留离散周次，`colorChosen` 标记用户明确选色；`Index.gridRevision` 仅在 `listAll()` 返回的全表数据变化后递增，以刷新缓存的周页。编辑与新增均复用当前账号课表仓储，教务重新同步仍会整表替换本地手改课程。

核对日期：2026-11-14。源码是权威；此图描述当前控制流及保护范围，不保证运行正确。账号状态、异步任务、存储键、清理顺序、页面生命周期改变时更新。

关联：[目录](README.md) · [项目](PROJECT_MAP.md) · [模块](MODULE_MAP.md) · [页面](PAGE_MAP.md) · [接口](API_MAP.md) · [数据库](DATABASE_MAP.md) · [组件](COMPONENT_MAP.md) · [构建](BUILD_MAP.md)。

## 状态归属

|状态|拥有者与源码|读取/变更入口及边界|
|---|---|---|
|全局主题 dark|[EntryAbility](../../entry/src/main/ets/entryability/EntryAbility.ets)、[SettingsStore](../../entry/src/main/ets/data/local/SettingsStore.ets)|EntryAbility.init 读设置后 AppStorage.setOrCreate；各页面 @StorageLink('dark') 跟随。AppearancePage 修改、Index.loadSettings/主题操作也写 AppStorage；持久值来自 SettingsStore。|
|账号操作代次|[AccountScope](../../entry/src/main/ets/common/util/AccountScope.ets)|begin(user) 改 owner 并递增 revision；token/valid 只比代次；adopt(user) 仅改 owner；invalidate 清 owner 并递增。不是认证成功证明，也不自动切换数据库或会话。|
|数据库当前账号|[Db](../../entry/src/main/ets/data/local/Db.ets)|accountUser/selectAccount 独立维护 account；CourseDao 按账号过滤；切账号保留各账号课程历史。初始空账号和 legacy 认领见 DATABASE_MAP。|
|教务会话归属与代次|[SessionStore](../../entry/src/main/ets/data/local/SessionStore.ets)|bindUser 换 owner/revision 并通过队列清异账号持久会话；同账号直接返回；isCurrent 同时比 owner/generation。use 注入上下文，saveJw/loadJw/clear 串行。|
|保存登录身份与选项|[CredentialStore](../../entry/src/main/ets/data/local/CredentialStore.ets)|load/save/clear，另有 lastSyncAt/markSyncAt、autoUpdateDay/markAutoUpdateDay。账号存在用于页面显示；不等于教务会话仍有效。|
|凭据加密|[SecretStore](../../entry/src/main/ets/data/local/SecretStore.ets)|seal/open 使用 HUKS；凭据和会话分别绑定上下文。仅描述概念和键，不记录值。|
|活动课表及学期|[TimetableStateStore](../../entry/src/main/ets/data/local/TimetableStateStore.ets)|init/select/saveTerm/activeTableId/term；state 内 activeTables 按账号，terms 按账号与课表组合键；持久写入检查 Db 当前账号。|
|成绩持久快照|[GradeCacheStore](../../entry/src/main/ets/data/local/GradeCacheStore.ets)|save/load/clear；按 user、串行队列、revision 与原子写入管理；lastUser 为辅助指针，不是自动选取当前账号的依据。|
|资料、头像、显示、节次|[ProfileStore](../../entry/src/main/ets/data/local/ProfileStore.ets)、[AvatarStore](../../entry/src/main/ets/data/local/AvatarStore.ets)、[SettingsStore](../../entry/src/main/ets/data/local/SettingsStore.ets)、[PeriodStore](../../entry/src/main/ets/data/local/PeriodStore.ets)|各自 load/save/clear 或 invalidate；并非均为多账号数据库表，不能从课程隔离推断全部资料隔离。|
|分享本地记录|[ShareCodeStore](../../entry/src/main/ets/data/local/ShareCodeStore.ets)|与 ShareApi 上传/下载配合；不属于 SessionStore 教务 Cookie。具体流程见 API_MAP。|

## 冷启动与页面重入

[Locator.init/initStores](../../entry/src/main/ets/app/di/ServiceLocator.ets) 合并初始化 Promise；失败重置以便重试：Db.open → 注入 ctx、SessionStore.use、GradeSync.use → TimetableStateStore.init → CredentialStore.load → Db.claimLegacyAccount → Db.selectAccount → AccountScope.adopt → SessionStore.bindUser。注意学期 Store 初始化在读取保存账号之前，具体按账号读取发生在其后使用入口。

[Index.aboutToAppear](../../entry/src/main/ets/pages/Index.ets) 初始化周列表/提醒分钟列表、日期，启动 loadPeriods/loadSettings/loadAll；onPageShow 读取 activeTableId 后再启动节次、设置、reloadTables/loadCourses。调用可重叠，不能按页面钩子顺序假定异步完成顺序。

Index.loadCourses 为每次请求递增 courseRequest，捕获 AccountScope token 和 tableId；先 Locator.init，再 TimetableStateStore.select，调整周数/日期，查 listByWeek/listAll；最终检查请求序号、活动表及 token 后更新显示，并触发 refreshOwnedReminders、refreshOwnedCalendarEvents、WidgetRefresh.update。异常分支会清显示并提示。loadAll 还包含 ensureSeed 和 dropLegacyDemoCourses；后者按 MockData 的课程 ID 过滤 t1/t2，不是整库清空。

[GradePage.aboutToAppear/onPageShow → boot](../../entry/src/main/ets/pages/GradePage.ets) 各增页面 revision；先读 CredentialStore，换账号即清旧显示，之后读账号缓存，再 refresh。validView 同时检查页面 revision、AccountScope token、owner 和 displayedUser；applySnapshot 检查快照 user。缓存先显示，网络失败保留已有结果；goVerify 返回登录页，重入再 boot。

[LoginPage](../../entry/src/main/ets/pages/LoginPage.ets) 的 qrToken 与 qrOpen 控制 watchQr 轮询结果是否可用于当前浮层；刷新递增 qrToken。done 进入 finishQr，cancel 停止并显示取消，expired/error 延迟后刷新；返回旧请求会检查 token/open。此页面代次与全局账号代次不同；关闭 UI 不等于取消底层 HTTP。其他页面的读取、返回及路由见 PAGE_MAP。

## 登录、换账号与验证码

1. Locator.syncAndSave 保存 previous=Db.accountUser；AccountScope.begin(user) 先使旧任务失效，再 SessionStore.bindUser(user)，随后 SyncTimetable.run。
2. FuwaiTimetableSource.fetch/resumeCaptcha/qrLogin 进入 SchoolTraffic 队列。验证码结果不写课程，source 持有同一 auth/pendingUser/pendingPwd；resumeCaptcha 复用；clear 清 auth 和 pendingPwd。
3. collect 抓课表、parseTimetable，拒绝空课表、未知学校学期和密码登录返回账号不符；之后 SessionStore.bindUser(sid) → AccountScope.adopt(sid) → saveJw → Db.selectAccount(sid)，关键 await 后检查 token。
4. SyncTimetable.commit 检查 token，repo.replaceAll 完成后再检查；仓库校验课程并事务替换。Locator.persist 保存学期元数据和 ProfileStore，启动 gradesInBackground。
5. 密码路径无验证码且失败时，Locator.syncAndSave 恢复 previous 的 Db 账号、AccountScope owner 与 SessionStore 绑定。验证码失败/扫码路径的恢复行为不相同，不应画成统一回滚。
6. Locator.qrStart 调 AccountScope.begin('')；扫码成功后 collect 认领 sid。rememberQrUser 同账号沿用凭据选项，换账号清空密码并关闭自动更新；它是账号记录更新，扫码本身拿不到密码。

## 成绩任务代次与完整快照

[GradeSync.run](../../entry/src/main/ets/data/remote/GradeSync.ets) 捕获 user、AccountScope.token、SessionStore.generation 及 ctx，以 user:token:generation 合并相同任务的 inflight Promise；不同代次不会加入旧 Promise。排队前捕获的 task 在 doRun 开始及后续 await/每学期读取处由 valid 检查：全局 token 有效、AccountScope.user 等于 task.user、SessionStore.isCurrent。

优先 loadJw → collect；只有会话过期才尝试密码重登，没有密码则 expiredResult。collect 从 currentSemester 和 ProfileStore.gradeOf 推断起始学年，未知账号有八学年边界；按 TERM_CODES=[3,12] 遍历，跳未来学期。所有请求成功后才 summarize 并 GradeCacheStore.save；任一学期失败返回失败，保留旧完整缓存。expiredResult 仅标记该账号已有快照 expired 并保留成绩。quiet 将异常转换为保留缓存的结果。代次是忽略旧结果/阻止后续写入的机制，不是传输层 abort。

GradePage.boot先按已保存账号读取 GradeCacheStore 快照，再尝试刷新；页面状态文案表达“本地已缓存”，不把缓存有效性等同于教务会话有效性。刷新失败或会话过期时保留快照；若 hasCache 为 true，页面不展示刷新失败提示卡，普通刷新及主动身份验证入口仍在。无缓存时仍显示失败/登录引导。此处是页面展示策略，不改变GradeSync错误、登录态或缓存内容。

## 串行与事务边界

- [SerialQueue.run](../../entry/src/main/ets/common/util/SerialQueue.ets)：当前 work 接到 tail；成功失败都把新 tail 转成 resolved void，因此失败不毒化后续任务。
- [SchoolTraffic.run](../../entry/src/main/ets/common/util/SchoolTraffic.ets)：应用内共享队列，课表取数/验证码续传/扫码完成和 GradeSync 使用。qrStart/qrPoll、refreshCaptcha 没有在 FuwaiTimetableSource 中走同一队列；不能称所有学校流量均串行。
- [Db.write/transaction](../../entry/src/main/ets/data/local/Db.ets)：数据库写入队列；transaction 执行 beginTransaction、work、commit，失败 rollBack。CourseRepositoryImpl 捕获账号，在事务前后 checkAccount；替换的 clear/insertAll 在同一事务，validateCourses 在清空前运行。
- SessionStore、CredentialStore、GradeCacheStore、TimetableStateStore 各有自己的队列；FeedbackStore 与 FeedbackDelivery 也分别串行。这些不是跨存储的总事务；数据库、Preferences、文件和系统服务不能整体回滚。

## 反馈待发送队列

[FeedbackPage](../../entry/src/main/ets/pages/FeedbackPage.ets) 保存本地记录再交 [FeedbackDelivery.send/flush](../../entry/src/main/ets/data/remote/FeedbackDelivery.ets)。[FeedbackStore](../../entry/src/main/ets/data/local/FeedbackStore.ets) 的 mutate 串行 push/markSent/defer/clear；pending 提供未发送记录。

send 捕获 AccountScope token 并排到 sending；deliver 检查 token、retryAt、记录仍存在和 sent；最多三图，经 encodeFeedbackImage 解码重编码 JPEG 并限大小；以 feedback.id 作为 requestId 上传。成功 markSent 并删除归属反馈的缓存图片；限流保存 retryAt；普通失败保留待发记录。flush 跳过未到期项，成功才继续，图片失败抛错，其他非 ok 停止。

[server/server.js](../../server/server.js) 对 requestId 与 IP 组合散列去重，feedbackRequests 内存 Promise 合并重试，持久反馈可带 requestKey；请求体、并发、配额及磁盘 admission 另见 API_MAP。重试不是无条件后台定时器，需由页面/调用入口 flush 触发。

## 退出与清除个人数据

[AccountPage](../../entry/src/main/ets/pages/AccountPage.ets)、[PersonalInfoPage](../../entry/src/main/ets/pages/PersonalInfoPage.ets)、[PrivacyDocPage](../../entry/src/main/ets/pages/PrivacyDocPage.ets) 收口到 Locator.clearPersonalData：

1. 要求 ctx；AccountScope.invalidate、SessionStore.invalidate；丢弃 Locator sourceImpl/syncImpl。
2. Db.eraseAllAccountData、clearMigrationBackup、selectAccount('')；CredentialStore、ProfileStore、SessionStore、GradeCacheStore、AvatarStore、FeedbackStore 清理；清分享 Preferences 与 Web Cookie。
3. 清应用拥有的提醒和日历，再 TimetableStateStore.clear、WidgetRefresh.update 空载荷；删除 files/cache 中归属头像、裁剪、反馈、成绩前缀的文件。

这是清全部账号课程数据的退出/隐私清理入口，不等于只删除当前账号。SettingsStore 和 PeriodStore 不在显式清理清单内。系统日历权限失败可向上抛出，清理可能部分完成，不能声称所有数据必然删除；SessionStore.clear 自身也会再次失效代次。系统提醒/日历、卡片归属和数据库结构另见 DATABASE_MAP/COMPONENT_MAP。

## 待确认与当前限制

## 2026-11-14 后台状态增量

- [admin.js](../../server/admin.js)：`state.page` 切换 codes/feedback/probes/alerts/audit；口令分页20条，反馈分页50条；反馈搜索与已读筛选仅作用于当前页。`active` 合并同类请求，`again` 补一次更新；`failures` 分板块保留失败状态，其他板块成功不会清掉该错误。
- `poll` 正常5秒读取stats，约15秒刷新告警和当前板块；失败退避至60秒。`pollGeneration` 令旧轮询失效；隐藏页面暂停后续轮询，已在途请求可能完成；恢复只保留一条轮询链。口令检测和变更按钮禁用防重入，删除先确认，错误不显示为检测通过。
- [admin-console.js](../../server/admin-console.js)：`sample` 单航班，15秒后台采样；公网 HTTPS 每60秒检查，非每个用户分别采样。`ticketRows` 单航班、10秒缓存，删除前失效。
- `evaluate` 连续三次资源采样≥90%触发；`signal` active→resolved写恢复时间。进程重启将此前 active 历史标记 interrupted，不能伪称已恢复。接口错误与带认证头的失败登录按时间窗口计数；普通首次401挑战不计失败登录告警。
- `audit` / `events` 在内存与文件中保留；`dirty/timer/writing` 合并并串行持久化。`blocked` 阻止覆盖损坏历史文件，storageError反映读写异常，UI保留错误提示。单进程设计，不支持多实例共享写同一目录。

- 上轮暂停前的两处 ArkTS 类型错误已在后续 2026-11-14 签名打包任务中修正；该次构建、测试与模拟器安装记录见 [BUILD_MAP](BUILD_MAP.md)。此前其余加固边界仍待确认，不由编译通过证明。
- 源码可见保护点不等于竞态完全关闭：Locator.persist 的 ProfileStore.save 前后、FeedbackDelivery 上传完成后的 markSent/defer、Index.loadCourses 异常分支等并非处处重新核对账号/请求代次；是否会导致旧操作影响新状态待确认，本图不修复。
- qrStart 使 AccountScope owner 暂空，但数据库仍可能保持旧账号；取消扫码、离开页面后账号/会话恢复是否符合产品预期待确认。不能把这三种状态合并画成单个 loggedIn。
- 多账号课程隔离不自动等于所有 Preferences/资料、系统服务和组件进程隔离；不同队列间的交错、权限失败清理与卡片跨进程持久恢复需专门验证。
- 所有认证会话仅写名称和流程，不记录密码、Cookie、Token 或密钥内容。链接和符号据当前源码核对，线上响应、设备运行、权限和编译结果不由此图证明。
BottomTabs：selected是动画选中，current是实际页面；moving期间destination保留最近点击，slide完成后追踪最新目标，最终navigate；alive避免页面卸载后执行导航。
SecretStore.createKey兼容isKeyItemExist拒绝12000011的缺失密钥分支，其他错误仍失败；具体排查与设备验证边界见根Solution.md。


## 2026-11-14｜游客口令与学校覆盖

游客仍使用既有空账号空间，没有长期保留游客课表的新空间。退出/隐私撤回继续 clearPersonalData 清空全部课表。SyncTimetable.commit 对 replaceAll 传 clearGuest=true 与 AccountScope token，学校落库事务成功才删除空账号课程与自建课表，失败则整体回滚。Locator 记录 loginPrevious；验证码/扫码最终失败恢复原数据库账号；成功后 discardGuest 清游客学期/选择，从游客登录时串行重置 DEFAULT_PERIODS，并选中学校目标表。

Index 输入变化/关闭弹窗/onPageHide/aboutToDisappear 递增 importRevision 并清防抖、预览与 busy；查询只发布同代次同 token 同 tableId 的结果；确认覆盖将有效性回调传入 replaceAll、saveTerm、PeriodStore.save。数据库开始/提交前均检查操作有效性；节次写入在统一 SerialQueue 内检查 token/回调，写后失效则恢复此前值，再允许后续学校重置执行。Share 请求使用独立 shareRevision，离页后不弹出旧口令。已实际完成的数据库提交不因随后关闭页面而撤回。


本轮分享/游客覆盖的构建、测试与双模拟器证据见 [分享与游客验收记录](../share-guest-20261114.md)。


## 2026-11-14｜周数滑块松手刷新

Index.week 为已提交周，previewWeek 为菜单临时预览，weekSliding/ weekSelectionEnabled 管理有效手势。取消不写 week。loadCourses 捕获 requestedWeek 并在异步阶段验证请求版本/账号/课表/周数，过期异常也不清空当前课表。

构建/模拟器与日志证据见 [周数滑块验收记录](../week-slider-20261114.md)。


## 2026-11-14｜302问题

302恢复不创建新的账号代次，沿用fetchTimetable捕获的token；mint入口捕获token并传follow，各请求前/后及吸收Cookie前复查。账号失效后禁止继续恢复与发布课表；有效教务业务落地不等于课表导入成功，后续必须返回合法kbList JSON。失败仍由现有同步源/事务机制保留原课表。

问题证据与验证边界见 [Solution.md 的302问题](../../Solution.md)。

## 2026-11-15｜更新检查
UpdateCheck模块busy合并并发、startupChecked使每进程自动检测一次，dialog防重复展示。Index.aboutToAppear触发自动检查，菜单与ProfilePage手动检查绕过ignoredVersion；只有市场确认新版且公告versionCode高于当前安装版本才展示公告和忽略选项。网络失败自动静默、手动提示失败。版本公告与市场灰度版本的对应关系需管理员确保，官方普通应用接口无法返回目标版本号。

## 2026-11-15｜图标与首次加载
Index.reloadTables等待初始化及默认表创建后查询；异常保留现有列表并记录固定日志，不弹读取课表失败。

2026-11-15：成功persist且AccountScope代次有效后异步reportLoginMetric；失败静默，不新增本地学号存储或重试队列。后端单进程Promise队列串行原子写摘要，重复摘要不增人数；不具备服务器验证学校身份能力。

2026-11-16：工作台常用读写检查AccountScope owner/token；考试页请求捕获年/学期/请求代次，SchoolTraffic队列只执行当前代次，返回时复查再发布。服务网页在加载时检查账号代次，退出页面stop，官网临时页不操作全局Cookie。


2026-11-16 格子宽度：宽度拖动只更新liveWidthScale并共用dragging半透明预览，End/Click写入设置。重新进入按实测列宽恢复vp显示，Index载入设置后重建相应网格。

2026-11-16 宽度重叠修正：上条0.875～1.25范围已替换为0.875～1；SettingsStore.load夹回旧超限值，TimetableGrid.blockW按子列unit-1设上限（移除14vp最小宽导致的多列越界）。设置页P1布局为格子高度/格子宽度、下方灰色vp、蓝色滑块，无底部范围文字；宽度0.1vp步进。原背景/面板opacity未改。

2026-11-16 安卓列宽方案替换此前卡片缩放方案：liveWidth拖动即时更新预览，松手/点击保存cellWidth。0为未手动设置的自动布局；手动后横向手势用于滚动不翻周，Index网格key含cellWidth。无新增权限或账号数据变化。

2026-11-16 安卓最新自适应/课程文字/日视图迁移（替换此前宽度方案）：周浏览week与日视图当天displayedWeek分离；toggleView换内容时refreshDates，onWeekChange仍刷新周浏览，日课程过滤使用当天周。openDetail捕获detailWeek，后续编辑/删除使用该上下文，避免混用浏览周；切回周视图保留旧week。未新增跨午夜计时器。宽度liveRatio/旧值在保存时同步转换，避免高度保存导致预览跳变。

2026-11-16 安卓最终方案同步：周浏览week独立于日视图displayedWeek；toggleView切换后refreshDates，详情打开捕获detailWeek，避免日视图操作错误周。列宽比例随布局测量适配，legacyWidth只兼容首次读取，保存时同步liveRatio避免预览跳变。

2026-11-16 日视图时间配色逻辑：DayList.clockTime为显示状态，不持久化；aboutToAppear校正时钟并启动1秒刷新，aboutToDisappear取消；无效/缺失结束时间按未结束处理，避免误标已完成。

2026-11-16 联网北京时间：校准基于systemDateTime.STARTUP单调时间，系统时间调整不影响校准后推进；离线保留当次进程校准，冷启离线用Date.now。无跨重启持久化。Index收clockEpoch并在北京时间日期变化时刷新日期；若仍浏览旧当前周则跟到新当前周，其他浏览周保留。

2026-11-16 工作台常用功能退役：WorkbenchPage删除LongPressGesture、菜单遮罩、添加/移除/查看常用、WorkbenchFavorites弹层及preferences读写/状态。五项服务及官网点击入口不变。PrivacyDocPage删除常用收集条目，ServiceLocator仍清理旧fxw_workbench数据以兼容历史版本；不自动清除用户其他数据。

2026-11-17 成绩/考试按安卓当前开发日志复刻：GradePage.draftTerm与activeTerm分离，滚动不立即生效；ExamPage.draftTerm完成后选year/term并查询。保留Grade账号代次/缓存防陈旧数据与Exam请求代次；取消滚轮不提交。
