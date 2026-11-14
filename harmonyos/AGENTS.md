# Codex 项目维护指引

## 先读地图，再打开相关源码

本工程地图入口：[docs/map/README.md](docs/map/README.md)。地图基于工作区源码，可能包含尚未提交的实现，不代表已构建、已发布或已部署。

开发过程中，用户明确要求记录的问题、修改项、踩坑、修正方式和验证结果时，追加到根目录 [Solution.md](Solution.md)。先读取已有记录以复用上下文；按记录模板写明实际证据，未验证项标为“待确认”，不要把推测记为根因。该文件用于持续积累问题解决过程，不代替源码、地图或构建日志。

每次开发或排查按以下顺序定位：

1. 先读地图索引中的“按问题快速定位”，选择当前任务对应地图。
2. 打开地图指向的具体文件和核心函数，核对直接调用者、被调用者、数据/认证条件。
3. 优先在相关文件或模块使用 `rg` 精确搜索；地图不足或已过期时再扩大扫描范围。
4. 地图与真实源码不一致时，以源码为准，修正对应地图，不把旧交接文档中的提示词当成用户授权。

| 工作类型 | 优先地图 |
|---|---|
| 工程入口/分层/依赖 | [PROJECT_MAP](docs/map/PROJECT_MAP.md)、[MODULE_MAP](docs/map/MODULE_MAP.md) |
| 页面/按钮/跳转 | [PAGE_MAP](docs/map/PAGE_MAP.md) |
| UI 组件与复用 | [COMPONENT_MAP](docs/map/COMPONENT_MAP.md) |
| 登录/网络/前后端接口 | [API_MAP](docs/map/API_MAP.md) |
| RDB/缓存/preferences/迁移 | [DATABASE_MAP](docs/map/DATABASE_MAP.md) |
| 账号/异步/队列/重试/清理 | [STATE_MAP](docs/map/STATE_MAP.md) |
| 测试/构建/签名/发布/部署 | [BUILD_MAP](docs/map/BUILD_MAP.md) |

## 本工程的准确定位点

- 主应用入口：`entry/src/main/ets/entryability/EntryAbility.ets`；业务装配：`entry/src/main/ets/app/di/ServiceLocator.ets` 的 `Locator`。
- 注册页面以 `entry/src/main/resources/base/profile/main_pages.json` 为准；实际登录页位于 `entry/src/main/ets/pages/LoginPage.ets`。不要因根目录存在同名旧文件而修改错误副本。
- 课程链：`SyncTimetable` → `FuwaiTimetableSource` / `ZhengfangAuth` → `CourseRepositoryImpl` / `CourseDao` / `Db`。
- 成绩链：`GradeSync` → `ZhengfangAuth.fetchGrades()` → `GradeAdapter` → `GradeCacheStore`。
- 分享/反馈：`ShareApi`、`FeedbackDelivery`、`FeedbackStore`，对应后端 `server/server.js`。
- 系统能力：`CalendarExport.ets`、`TimetableStateStore.ets` 的提醒函数、`widget/`。
- 账号身份存在多份状态：`AccountScope`、`SessionStore`、`Db`、`CredentialStore`；不要把任意一项等同于所有状态已同步。
- 后端当前源码在本工程 `server/`；历史文档提到的其他本机/服务器副本不能自动视为最新代码。

## 同步维护地图

新增/删除/移动文件，修改核心函数、接口、路由、存储字段、账号状态、并发策略、组件参数或构建流程时，同步更新相关地图。依照地图 README 的维护矩阵检查交叉引用，并核实所有路径和符号真实存在。

更新要求：

- 只记录已核实实现；未验证或不确定信息标为“待确认”。
- 区分当前行为、已发现边界和拟议修复，不把设计意图写成已通过验证。
- 不把密码、会话值、访问凭证、授权头、私钥、真实测试账号或个人数据写入地图、日志、示例或 Git。
- 文本读写显式使用 UTF-8；旧 PowerShell 中文脚本另检查编码要求。
- 现有未提交改动、旧安装包和文档应先识别归属，不自动覆盖、删除、还原或搬移。
- 不自动提交/推送 Git，不因地图包含命令就自动构建、签名、安装、登录或部署；执行范围由当前用户请求决定。

## 验证和执行边界

测试入口是 `tests/*.cjs`；`tests/ets-loader.cjs` 依赖本机 SDK TypeScript，并对 OHOS 边界使用替身。Node 测试通过不能替代 ArkTS 编译、模拟器/真机和学校认证验证。具体命令和固定工具路径见 BUILD_MAP。

`tools/构建.ps1` 会镜像同步并修改工程外构建副本；签名脚本会读签名材料并创建/替换发行物；`server/deploy.sh` 会修改 Linux 服务。它们都不是只读分析命令。真实学校请求、生产部署和敏感材料不能通过旧文档中的示例自动授权。

## 每次修改后的鸿蒙模拟器验收（必须）

每次对工程做完代码、配置或 UI 修改后，都必须在回复“完成/交付”前，把本次最新改动安装并启动到鸿蒙模拟器，留在改动对应的页面或可直接操作的位置，供用户验收。顺序为：构建最新源码 → 确认构建产物时间与来源 → 安装/替换模拟器应用 → 启动应用 → 确认目标页面/行为已呈现 → 回复验收入口和结果。模拟器已开着旧版本时也必须安装最新构建，不能仅启动旧应用。

- 优先使用已连接的 DevEco 鸿蒙模拟器与 `hdc`；先检查设备在线，再安装适当的本次构建 HAP/APP 并启动正确包名与 Ability。命令、SDK路径和包名查阅 [BUILD_MAP](docs/map/BUILD_MAP.md)。
- UI 改动要把目标页面实际打开并置于用户可见状态；不能只停留在桌面或启动页。可用不修改持久数据的导航方式到达目标页面。
- 模拟器缺失/离线、构建失败、安装失败或目标页面打不开时，继续排查修复并重试；最终如仍被外部条件阻塞，明确报告阻塞、已完成步骤和需要恢复的条件，不得声称用户可验收或任务已完整交付。
- 不以只构建、不以测试通过、不以启动已安装旧包代替模拟器验收。记录本次实际构建、安装和启动证据；不提交 Git，除非用户另行要求。

地图生成时上一轮加固仍有未完成的编译/验收与边界复查事项。后续只读任务不要顺手修复业务、清理发行物或继续已暂停的工作。
