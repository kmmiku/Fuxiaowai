# 福小外 · Android 版

**福州外语外贸学院课表工具的安卓实现 —— 与鸿蒙版同一套页面、同一套口令协议、数据只留在本机**

![Platform](https://img.shields.io/badge/Platform-Android%205.1%2B%20(API%2022)-3DDC84?logo=android&logoColor=white)
![Web](https://img.shields.io/badge/Web-React%2018%20%2B%20TypeScript%205.6-3178C6?logo=typescript&logoColor=white)
![Shell](https://img.shields.io/badge/Shell-Capacitor%206-119EFF?logo=capacitor&logoColor=white)
![Version](https://img.shields.io/badge/Version-0.1.1%20(versionCode%203)-success)
![Tests](https://img.shields.io/badge/Tests-56%20pass-brightgreen)
![Build](https://img.shields.io/badge/APK-Debug%20验收包-orange)

[主要功能](#主要功能) · [技术栈](#技术栈) · [目录结构](#目录结构) · [开发与构建](#开发与构建) · [测试](#测试与自检) · [打包与发布](#打包与发布) · [原生能力对照](#原生能力对照) · [交付记录](#交付记录与证据)

---

## 这是什么

安卓版把鸿蒙版（[`../harmonyos`](../harmonyos)）的 22 个页面按 1:1 规格重新实现为一套 **React + TypeScript Web 层**，再用 **Capacitor 6** 装进原生壳：Java 侧负责教务登录窗口、系统日历写入、桌面小组件、密钥保管与更新链接，Web 层负责课表网格、周/日视图、三点菜单、成绩、考试、校历、提醒、分享与设置。

它与鸿蒙版**共用同一个包名 `com.fuxiaowai.timetable`、同一套 32 位口令分享协议、同一套后端接口**（[`../harmonyos/server`](../harmonyos/server)，本目录 `server/` 为加了双平台版本接口的新版），因此两端可以互相导入课表。

> **交付形态**：`0.1.1` / `versionCode 3`。当前发布的是 **Debug 验收包**（使用调试密钥签名，非应用商店发布签名），用于功能验收与内测安装；正式发行包需要外部签名材料，见 [打包与发布](#打包与发布)。

| 项目 | 信息 |
| --- | --- |
| 应用名称 | 福小外 |
| applicationId | `com.fuxiaowai.timetable` |
| 版本 | `versionName 0.1.1` / `versionCode 3` |
| 适配平台 | Android 5.1+（`minSdk 22`，`targetSdk 34`） |
| Web 容器 | Capacitor 6（`androidScheme: https`，`cleartext: true`） |
| 测试 | 56 个 Node 测试用例全通过；UI 合同覆盖 22 个页面 |
| 开发记录 | [`Map/`](Map) 9 份文档 + 证据 JSON/日志 |

---

## 主要功能

功能面与鸿蒙版一致，此处只列差异点；完整说明见[根 README](../README.md#主要功能)。

- **课表查看**：周视图 / 日视图，左右翻周、上下换课表，深色模式与自定义主题色，物理返回键在首页退出应用。
- **三点菜单**：周数滑块（拖动只跟手、松手才刷新）+ 课表切换 + 八入口（上课时间 / 课表设置 / 上课提醒 / 小组件 / 联系我们 / 主题设置 / 夜间模式 / 检查更新）。
- **手动添加课程**：课程名、教师、教室、校区、星期、节次、周次、颜色；支持 `2-4周,6-17周`、`10-16周(双)` 这类分段单双周写法。
- **教务同步**：正方 `jwglxt` 账号密码登录、CAS 跳转、企业微信扫码三通道；只有 HTTP 200 + 合法 JSON + `kbList` 数组才落库，登录返回学号与输入不一致时直接中止。
- **口令分享与游客导入**：32 位口令、30 天有效、整段文案自动识别；未登录也能先导入游客课表，正式登录成功后在同一事务里替换，失败完整回滚。
- **成绩 / 考试**：本地按学号分账号缓存，登录过期或离线时仍可看上次结果；考试支持 Web 兜底页。
- **校历 / 提醒 / 小组件**：校历对照教学周；提醒按本周课表生成（提前 5/10/15/30 分钟）或整学期写入系统日历；桌面「今天的课」小组件。
- **双平台版本公告**：`server/` 新增 `app-version` / `app-update` 的平台隔离接口，安卓与鸿蒙各自登记版本与更新说明，客户端「检查更新」只接受 HTTPS 更新入口。

---

## 技术栈

| 层 | 选型 |
| --- | --- |
| Web 框架 | React 18.3 + TypeScript 5.6（`strict`，JSX `react-jsx`） |
| 构建 | Vite 5.4（`base: './'`，产物 `dist/`） |
| 原生壳 | Capacitor 6.2：`@capacitor/android` `app` `core` `local-notifications` `splash-screen` |
| 原生层 | Java（`android/app/src/main/java/com/fuxiaowai/timetable/`）：登录窗口、日历、小组件、密钥库、更新链接 |
| 状态与存储 | 自建 store + `localStorage`（每账号、每课表一个 JSON 数组，带持久 undo 日志与整表快照恢复） |
| 网络 | `fetch` + Cookie Jar + 正方/CAS 适配（`src/core/zhengfang.ts`）；扫码走原生 WebView `onJsPrompt` 通道 |
| 加密 | 凭据经原生 `SecretVault` 封装（API 22 上用 RSA 包裹 AES 密钥），不可解密时保留密文、不降级写明文 |
| 测试 | `node --test tests/*.test.cjs`（`node:test` + `vm` 直接加载 TS） |
| 服务端 | Node.js 零依赖（`server/server.js` + `server/admin-console.js`）：口令分享、反馈、双平台版本、管理后台、站点托管 |

---

## 目录结构

```
android/                              # 本目录 = Android 版工程根
├── src/                              # Web 层（82 文件）
│   ├── App.tsx                       # 21 个路由 + /privacy/ 前缀 + 底部四标签
│   ├── main.tsx                      # 入口
│   ├── components/                   # 9 个：课表网格、课块、详情面板、周条、三点菜单、底部标签…
│   ├── core/                         # 28 个：store/appState、zhengfang 适配、日历、提醒、分享、校验…
│   ├── pages/                        # 22 个页面：周视图/日视图/登录/添加/成绩/考试/校历/我的/关于…
│   ├── styles/                       # 13 份 CSS（tokens + 分页面 px-*.css）
│   └── ui/                           # 6 个基础件：轮盘选择器、线性图标、裁剪器、toast…
├── android/                          # Capacitor 原生工程（Java + Gradle）
│   ├── app/src/main/java/com/fuxiaowai/timetable/
│   │   ├── MainActivity.java         # WebView 宿主、启动页、返回键
│   │   ├── PortalLoginActivity.java  # 教务登录窗口（含企业微信扫码上报）
│   │   ├── SecretChromeClient.java   # onJsPrompt 通道，只接受 https://localhost
│   │   ├── SecretVault.java          # Keystore 加密的凭据保管
│   │   ├── CalendarPlugin.java       # 系统日历读写（写入前先读，避免重复）
│   │   ├── FxwWidgetPlugin.java      # 桌面小组件桥
│   │   ├── DayCardWidgetProvider.java# 「今天的课」卡片
│   │   ├── ExamWebActivity.java      # 考试 Web 兜底页
│   │   └── UpdateLinkPlugin.java     # 检查更新，只接受 HTTPS 链接
│   ├── app/src/main/res/             # 图标、启动图、小组件布局
│   ├── app/src/test|androidTest/     # 单元测试 / 兼容性 instrumentation
│   ├── build.gradle                  # AGP 8.2.1
│   ├── variables.gradle              # minSdk 22 / compileSdk 34 / targetSdk 34
│   └── gradle/wrapper/               # Gradle 8.2.1
├── tests/                            # 17 个 .cjs 测试文件（56 个用例）
├── tools/                            # UI 合同校验、UI 回归、数据备份、模拟器启动脚本
├── server/                           # 口径分享 / 反馈 / 双平台版本 / 管理后台 / 官网静态页
├── Map/                              # 改造记录与验证证据（11 份文档 + evidence）
├── index.html · vite.config.ts · tsconfig.json · capacitor.config.ts
├── package.json                      # name: fuxiaowai-android, version 0.1.1
└── AGENTS.md                         # 本工程开发约定（版本策略、打包流程、后台同步）
```

---

## 环境要求

| 依赖 | 版本 |
| --- | --- |
| Node.js | 20+（实测 24.22.2 / npm 11.19.1） |
| JDK | 17（AGP 8.2.1 要求） |
| Android SDK | Platform 34 + Build-Tools 34.x（`ANDROID_SDK_ROOT` 或 `android/local.properties` 的 `sdk.dir`） |
| Gradle | 8.2.1（wrapper 自带，走腾讯云镜像） |

---

## 开发与构建

```powershell
cd android
npm ci                 # 安装 Web 依赖（Capacitor 插件同源）
npm run dev            # 浏览器调试：http://localhost:5173
npm run build          # tsc -b && vite build → dist/
npx cap sync android   # 把 dist/ 同步进原生工程（改完 Web 代码必须执行）
npm run apk            # android\gradlew.bat assembleDebug
```

产物：`android\app\build\outputs\apk\debug\app-debug.apk`。

> **顺序不能省**：`npm run build` → `npx cap sync android` → Gradle，否则 APK 里装的是旧的 `assets/public` 资源。

模拟器一键启动（带窗口，复用已开的 `fxw`，`adb install -r` 保留数据）：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\Start-Android.ps1          # 只安装启动
powershell -ExecutionPolicy Bypass -File .\tools\Start-Android.ps1 -Build   # 构建 + 同步 + 安装
powershell -ExecutionPolicy Bypass -File .\tools\Start-Android.ps1 -Restart # 重启 fxw
```

脚本按 `ANDROID_SDK_ROOT` → `ANDROID_HOME` → `android/local.properties` 的顺序定位 SDK，不会杀其它 emulator/qemu 进程。

---

## 测试与自检

```powershell
npm test        # node --test tests/*.test.cjs  → 56 passed
npm run check:ui# UI 源码合同：22 个页面的结构/文案/尺寸断言
npm run check   # test + check:ui + build（提交前必须全绿）
```

实测：`56 pass / 0 fail`，耗时约 2.8 s。测试用 `vm` 直接加载 TS 源码，不需要浏览器或模拟器；断言覆盖课表持久化、账号隔离、颜色冻结、undo 日志回滚、口令分享、分享接口失败话术、旧表快照恢复等。

> Node 测试只证明纯逻辑正确，**不能替代**真机/模拟器验收。Android 侧另有 `app/src/androidTest`（`CompatibilityTest`）在隔离 AVD 上验证安装与启动。

---

## 打包与发布

版本策略（详见 [`AGENTS.md`](AGENTS.md)）：

1. 改版本号时必须同步 `android/app/build.gradle`、`package.json`/`package-lock.json`、「我的」页与「关于」页；`versionCode` 只递增。
2. 打包顺序：`npm run check` → `npx cap sync android` → Gradle 构建 → 校验包内 `applicationId` / `versionName` / `versionCode` / 签名 / 大小 / SHA-256。
3. 命名 `福小外-Android-<versionName>.apk`，Debug 产物固定标注「Debug 验收包」。
4. 正式签名走外部材料：设置环境变量 `FXW_SIGNING_PROPERTIES` 指向 `storeFile/storePassword/keyAlias/keyPassword` 四键 properties（默认回退 `android/keystore.properties`，均不入库）。缺材料时 `assembleRelease` 会直接抛 `Release signing requires FXW_SIGNING_PROPERTIES ...`，**不会生成替代密钥**。

本次交付（0.1.1 / versionCode 3）：

| 文件 | 大小 | SHA-256 |
| --- | --- | --- |
| `福小外-Android-0.1.1.apk`（Debug 验收包） | 4 628 048 B | `C22D6D288EBC13921AE31C05E6B37E1D47E7131BC5E15BA418A1E8E651CF1229` |

发布说明见 [`../docs/release-notes/0.1.1-android.md`](../docs/release-notes/0.1.1-android.md)，安装包见 [Releases](../../releases)。

---

## 原生能力对照

| 能力 | 鸿蒙版 | Android 版 |
| --- | --- | --- |
| 教务登录 | `@ohos.net.http` + Cookie 管理 | 原生 `PortalLoginActivity` WebView + `onJsPrompt` 回传（只接受 `https://localhost`） |
| 凭据保管 | HUKS 加密 | `SecretVault`（Keystore 包裹 AES；API 22 用 RSA 包 AES） |
| 日历导出 | `@ohos.calendarManager` | `CalendarPlugin` → `CalendarContract`（写入前先查重） |
| 上课提醒 | 提醒代理 | `@capacitor/local-notifications` |
| 桌面卡片 | Form（今天的课） | `DayCardWidgetProvider` App Widget |
| 检查更新 | `UpdateCheck` | `UpdateLinkPlugin`（只接受 HTTPS） |
| 本地存储 | RDB + Preferences | `localStorage`（每账号/每课表独立命名空间 + undo 日志 + 快照） |

---

## 交付记录与证据

`Map/` 保留安卓版改造的全过程，需要追溯「为什么这么写」时先读这里：

| 文档 | 内容 |
| --- | --- |
| [`Map/README.md`](Map/README.md) | 地图索引导读 |
| [`Map/SOURCE_MAP.md`](Map/SOURCE_MAP.md) | 鸿蒙 → Android 的落地映射与 7 条关键工程决策 |
| [`Map/CHANGE_PLAN.md`](Map/CHANGE_PLAN.md) | 变更计划与范围边界 |
| [`Map/UI_CHANGE_PLAN.md`](Map/UI_CHANGE_PLAN.md) | UI 逐页对齐清单 |
| [`Map/EXECUTION.md`](Map/EXECUTION.md) | 执行手册（备份、验收、恢复门禁） |
| [`Map/IMPLEMENTATION_LOG.md`](Map/IMPLEMENTATION_LOG.md) | 实施日志 |
| [`Map/VERIFICATION_REPORT.md`](Map/VERIFICATION_REPORT.md) | 验证报告：测试矩阵、UI 对比、instrumentation、未完成门禁 |
| [`Map/ACCEPTANCE.md`](Map/ACCEPTANCE.md) | 验收清单与结论 |
| [`Map/solution.md`](Map/solution.md) | 交付记录：逐项问题 → 根因 → 修复 → 证据 |
| `Map/evidence/` | 机器可读证据：`apk-manifest.json`、`*-delivery.json`、测试与部署日志 |
| [`docs/superpowers/plans/`](docs/superpowers/plans) | 双平台版本展示的实施计划 |

---

## 已知限制

- 本次发布是 **Debug 验收包**（调试密钥签名），不适合长期分发；正式签名材料未入库。
- 真实学校账号的三通道登录（账号密码 / CAS / 企业微信扫码，含图片验证码）**尚未在真实环境完整验收**，仅做了结构与失败路径验证。
- 覆盖升级只在调试签名下验证过；跨签名（调试 → 正式）升级需要卸载重装。
- 生产环境的口令分享备份/恢复演练未执行。
- 未提交任何应用商店审核。
- UI 对比中仍有 1 处已知差异：深色模式提醒页「生成提醒」按钮底部 8 px（约 810 像素），已记录于 [`Map/VERIFICATION_REPORT.md`](Map/VERIFICATION_REPORT.md)。

---

## 数据与隐私

- 课表、成绩、资料与设置保存在应用私有存储（`localStorage`），**不上传服务器**；卸载即清空。
- 登录凭据只在原生 `SecretVault` 内以 Keystore 加密保存；密文不可解密时保留密文，不降级写明文。
- 只有你主动点「分享课表」时，课表快照才临时存到分享服务（`http://113.45.242.182`），**口令 30 天失效**。
- 只有你主动提交反馈时，反馈文字/联系方式/图片才发到 `https://fuxiaowai.xyz`。
- 桌面小组件与提醒只读取本机课表数据，不联网。

**权限**：网络（登录教务、口令分享、反馈）、通知（上课提醒）、日历读写（导出课表）、相册/文件（换头像、反馈附图）。除网络外均可拒绝，拒绝只影响对应功能。

---

## 免责声明

本应用为**个人开发的学习辅助工具**，与福州外语外贸学院及任何学校官方无关。课表与成绩数据来自你**自行登录**的学校教务系统，请勿用于商业用途或大规模抓取。课表误差、成绩显示异常以学校教务系统原始数据为准。