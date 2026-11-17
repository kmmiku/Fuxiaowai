# 项目地图索引

核对日期：2026-11-14。地图依据当前工作区源码生成，包含尚未提交的修改。它是定位入口，不是修复计划、线上审计结论或构建通过证明。

最近地图维护：2026-11-14，学校课表302有限恢复与换票校验已同步 API/STATE/MODULE，记录见根Solution.md的302问题；“我的”页检查更新入口及共用处理已同步 PAGE/COMPONENT/MODULE；周数滑块预览/松手提交与单次刷新已同步 PAGE/STATE/COMPONENT；分享直连IP、全文口令识别与游客登录覆盖规则已同步 API/STATE/DATABASE/PAGE/COMPONENT/MODULE；P1 三点菜单整合（主页移除课表切换/功能区，菜单双卡片）已更新页面与组件地图；GradePage 本地缓存展示策略及 Index 顶部新增/导入按钮触摸反馈已更新到页面、状态和组件地图。

## 地图清单

| 地图 | 解决的问题 | 建议何时阅读 |
|---|---|---|
| [PROJECT_MAP.md](PROJECT_MAP.md) | 技术栈、目录、应用/卡片/后端入口、前后端边界、主调用链 | 首次进入项目、架构边界变化 |
| [MODULE_MAP.md](MODULE_MAP.md) | 模块职责、真实文件、类与核心函数、直接依赖 | 定位业务实现、修改服务/仓储/网络 |
| [PAGE_MAP.md](PAGE_MAP.md) | 23 个页面、组件组成、事件处理、路由与参数 | 改按钮、页面交互、导航、表单 |
| [API_MAP.md](API_MAP.md) | 学校/扫码/自建服务请求、参数、响应、调用位置与认证 | 查登录、接口、解析或后台路由 |
| [DATABASE_MAP.md](DATABASE_MAP.md) | RDB 表与迁移、preferences、文件、服务端 JSON、事务和清理 | 改字段、缓存、账号隔离、数据导出/清理 |
| [STATE_MAP.md](STATE_MAP.md) | 账号身份、全局主题、任务版本、队列、页面和请求状态 | 查并发、退出登录、陈旧响应、自动刷新 |
| [COMPONENT_MAP.md](COMPONENT_MAP.md) | 公共/局部组件、参数、回调、消费者、卡片契约 | 改课表渲染、组件复用或样式 |
| [BUILD_MAP.md](BUILD_MAP.md) | 版本、Hvigor、测试/构建/签名/验包脚本、部署配置 | 构建、发版、换机器、验包、部署 |

## 按问题快速定位

| 要处理的任务 | 先看地图 | 首个源码定位点 |
|---|---|---|
| 首页课程显示、翻周、切换课表 | PAGE → COMPONENT → STATE | [Index.ets](../../entry/src/main/ets/pages/Index.ets)：`loadCourses()`、`courseArea()` |
| 登录失败、验证码、扫码 | API → MODULE → STATE | [ServiceLocator.ets](../../entry/src/main/ets/app/di/ServiceLocator.ets)：`syncAndSave()`、`syncWithCaptcha()`、`syncWithQr()`；[ZhengfangAuth.ets](../../entry/src/main/ets/data/remote/auth/ZhengfangAuth.ets)：`login()` |
| 成绩缺失、缓存、账号错乱 | STATE → API → DATABASE | [GradeSync.ets](../../entry/src/main/ets/data/remote/GradeSync.ets)：`run()`、`collect()`；[GradeCacheStore.ets](../../entry/src/main/ets/data/local/GradeCacheStore.ets)：`save()`、`load()` |
| 课表保存/覆盖失败 | DATABASE → MODULE | [CourseRepositoryImpl.ets](../../entry/src/main/ets/data/repository/CourseRepositoryImpl.ets)：`replaceAll()`；[Db.ets](../../entry/src/main/ets/data/local/Db.ets)：`transaction()` |
| 分享口令生成/导入 | API → PAGE → DATABASE | [ShareApi.ets](../../entry/src/main/ets/data/remote/ShareApi.ets)：`uploadShare()`、`fetchShare()`；[Index.ets](../../entry/src/main/ets/pages/Index.ets)：`makeShareCode()`、`applyImport()` |
| 反馈图片、失败重试、429 | API → STATE → DATABASE | [FeedbackDelivery.ets](../../entry/src/main/ets/data/remote/FeedbackDelivery.ets)：`send()`、`deliver()`、`flush()` |
| 提醒、日历重复、桌面卡片 | MODULE → COMPONENT → STATE | [TimetableStateStore.ets](../../entry/src/main/ets/data/local/TimetableStateStore.ets)：`refreshOwnedReminders()`；[CalendarExport.ets](../../entry/src/main/ets/common/util/CalendarExport.ets)：`exportCoursesToCalendar()`；[EntryFormAbility.ets](../../entry/src/main/ets/widget/EntryFormAbility.ets) |
| 退出登录/隐私撤回 | STATE → DATABASE → PAGE | [ServiceLocator.ets](../../entry/src/main/ets/app/di/ServiceLocator.ets)：`clearPersonalData()` |
| 管理后台、限流、数据保留 | API → DATABASE → BUILD | [server.js](../../server/server.js)：HTTP 回调、`rateLimited()`、`cleanup()`；[dashboard.html](../../server/dashboard.html) |
| 打包/签名/版本不一致 | BUILD → PROJECT | [构建.ps1](../../tools/构建.ps1)、[打包app.ps1](../../tools/打包app.ps1)、[AppScope/app.json5](../../AppScope/app.json5) |

## 使用方法：先定位，后核实

1. 根据上表选择一到两张地图，不先扫描整个工程。
2. 打开地图引用的实际源文件，核对核心函数、调用者与被调用者；地图描述与源码冲突时，以源码为准。
3. 在已定位目录内按符号搜索，例如 `rg -n 'syncWithCaptcha|resumeCaptcha' entry/src/main/ets`；按需扩展范围。路由以 [main_pages.json](../../entry/src/main/resources/base/profile/main_pages.json) 为准，数据字段以定义/读写语句为准。
4. 修改源码时同步维护受影响的地图和交叉引用。只有地图明显过期、结构变化或当前地图未覆盖时，才扩大到全工程盘点。

所有相对源码链接均从本目录指向工程内真实文件；代码路径采用仓库相对形式。函数名用于稳定搜索，不依赖容易过期的行号。

## 事实、设计意图与待确认

- “代码已实现”仅表示函数/分支存在；不表示通过 ArkTS 编译、系统权限验证、真机回归或生产部署。
- 本轮只写地图与根 [AGENTS.md](../../AGENTS.md)，未执行测试、构建、安装、登录或部署；不延续此前已暂停的优化、清理任务。
- 主模块实际有 88 个 `.ets`，其中 23 个页面、11 个公共 UI 组件。测试目录有 20 个 `.cjs`（包含加载器）。文件数变化时须重新盘点。
- 本地源码版本声明是 0.1.1；旧安装包、旧交接文档、目录名或截图不能作为当前源码/线上状态的证据。
- 当前初始化顺序、验证码/扫码取消后的账号恢复、提醒发布中账号切换、日历权限导致清理中断等边界在 [STATE_MAP.md](STATE_MAP.md) 和相关地图中记录。它们属于待确认/待修复的实现边界，本轮没有修复。
- 学校 HTTP/TCP 链路、安全接入可用性、线上 nginx/systemd 环境、正式签名和商店受理状态均需独立确认。
- 地图不记录密码、会话值、扫码凭证、授权头、私钥、证书正文、真实测试账号或个人数据；仅说明字段名称、保管边界和认证依赖。

## 维护矩阵

| 变更 | 必须同步检查 |
|---|---|
| 增删模块、改入口/依赖 | PROJECT、MODULE、README |
| 增删页面、路由、事件 | PAGE、COMPONENT、MODULE；有权限/请求变化再看 STATE/API |
| 改公共组件参数/回调 | COMPONENT、PAGE |
| 改请求字段、认证、后端路由 | API、MODULE、STATE；持久化变化再看 DATABASE |
| 改表结构、文件格式、存储迁移 | DATABASE、MODULE、STATE |
| 改账号版本、队列、重试/取消 | STATE、MODULE、API/DATABASE 对应部分 |
| 改版本、SDK、构建/签名/部署 | BUILD、PROJECT；服务环境/数据路径再看 API/DATABASE |

更新地图时保留可验证的文件和符号引用，将不确定事实标成“待确认”，不要把后续计划写成当前事实。新增地图/源码链接后检查目标存在和跨图名称一致；不要自动运行地图中的有副作用命令。

## 本次建立时的静态校验

## 后续变更记录

- 2026-11-14：后台v2实际部署完成，新增管理扩展、五工作区、操作记录和告警；API_MAP、MODULE_MAP、DATABASE_MAP、STATE_MAP、BUILD_MAP同步记录真实函数/接口/存储及线上与工作区差异。部署证据与回滚定位见 [后台交付记录](../admin-console-20261114.md)。本页后面的“本次建立”仅指初次只读制图，不代表后续任务未部署。

- 88 个 ArkTS 源文件全部出现在模块地图；23 个注册页面和 11 个公共 UI 组件均有索引。
- 核对模块职责表中的 291 个核心函数名，以及页面/组件地图中的 496 个源码行号引用；路径和行号均对应当前真实文件。
- 检查全部地图与根 AGENTS 的本地链接和交叉引用，并对新文档执行敏感字面值检查。
- 对生成前已有的 689 个文件进行内容与路径哈希对比，确认未修改、删除或覆盖；本轮仅新增本目录 9 份 Markdown 与根 AGENTS。
- 本次未运行业务测试、构建或部署，也未自动提交 Git。以上校验只证明地图引用与只读边界，不证明应用运行正确。

- 2026-11-15：应用更新检测、公告弹窗、版本忽略与后台版本发布已同步API/STATE/DATABASE/PAGE/COMPONENT/MODULE；编译、模拟器和部署状态见Solution.md对应记录。

- 2026-11-15：版本发布后台增量上线，认证、公告发布/撤回及数据保持验证通过；部署与TLS验证边界见Solution.md和API/BUILD/MODULE/DATABASE地图。

2026-11-16工作台迁移：新增WorkbenchPage/ServiceWebPage，路由现25页；BottomTabs第三项工作台，成绩改工作台内页。页面/组件/状态/数据库补充见各地图末尾；构建验收见Solution.md。

2026-11-16：安卓最新课程文字、自适应比例宽度、日视图当天周迁移已同步PAGE/COMPONENT/DATABASE/STATE/MODULE；构建与模拟器证据见Solution。旧45～55整表横滚记录仅代表历史实现。

2026-11-16：独立 Node 下载引导服务已部署VPS，监听TCP 18080；Android/HarmonyOS 下载入口分别使用用户提供的链接和pwd参数，HarmonyOS 卡片添加改扩展名为 `.hap` 的安装提示。平台标志使用用户提供的双图原图裁成左 Android、右 HarmonyOS 两个静态资源并加入服务白名单。部署边界见 API_MAP、BUILD_MAP。

2026-11-16：下载页两个平台图标改为 HTML 内嵌 JPEG data URI，浏览器无需单独请求图片路径；图片内容沿用用户提供的左右图标裁切。

2026-11-16：Android 与 HarmonyOS 下载入口更新为用户本轮提供的新链接；静态 HTML 已同步 VPS，VPS 本机 HTTP 返回内容与本地 SHA-256 一致，两个链接及内嵌图标标记已核对。

2026-11-16：下载页在两张下载卡片之后、第三方提示之前新增 QQ 反馈卡片；用户提供的二维码随 HTML 内嵌，提供保存图片和复制群号（HTTP 下使用 execCommand 后备，失败显示手动复制提示）。已部署并确认 VPS 本机 HTTP 返回与本地 HTML 哈希一致。浏览器交互结果另见实际验收，未验证移动端 QQ 识别及加群。

2026-11-16：反馈卡片的保存二维码按钮替换为用户提供的 QQ 加群链接按钮，新窗口打开；保留内嵌二维码和复制群号。已部署，VPS 本机 HTTP 页面与本地哈希一致；真实 QQ 唤起及加群结果待用户验收。地图不记录链接中的授权参数。

2026-11-17：鸿蒙下载入口更新为用户本轮提供的新蓝奏云链接，保留提取码参数；已同步 VPS，VPS 本机 HTTP 返回与本地 HTML 哈希一致，安卓入口保持原值。
