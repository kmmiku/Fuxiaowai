# android/ — Android 工程（预留）

> ⏳ **本目录当前没有可编译代码，仅作位置预留。**

## 状态

| 项 | 状态 |
| --- | --- |
| 鸿蒙版（`../harmonyos/`） | ✅ 已实现，v0.1.1 |
| Android 版 | ⏳ **未开始**，本目录仅占位 |
| 跨平台框架 | ❌ 未使用（鸿蒙端为原生 ArkTS，不是 Flutter/RN 产物） |

## 为什么单独留一个目录

本项目一开始就按「一个仓库、多端」的方式组织，避免日后把 Android 代码塞进鸿蒙工程造成结构混乱：

```
Fuxiaowai/
├── harmonyos/   # 鸿蒙工程（唯一实现）
└── android/     # 未来 Android 工程（本目录）
```

这样做的三个好处：

1. **互不污染**：两端的构建配置（hvigor vs Gradle）、依赖管理、产物路径完全隔离。
2. **共享协议**：口令分享（32 位口令、30 天有效）与后端接口（`../harmonyos/server/`）与平台无关，两端接同一套即可互通。
3. **可对比**：同一个功能在两端各自实现，便于对照 UI 规范与领域模型。

## 后续移植计划

| 阶段 | 目标 | 参照物 |
| --- | --- | --- |
| 1. 领域模型对齐 | 课程 / 学期 / 成绩 / 考试模型字段语义一致 | `../harmonyos/entry/src/main/ets/domain/` |
| 2. 数据层移植 | 本地库结构与鸿蒙端一致，口令协议互通 | `../harmonyos/entry/src/main/ets/data/local/` |
| 3. UI 重写 | Jetpack Compose 实现周视图 / 日视图 / 添加课程 | `../harmonyos/assets/docs/01-UI规格.md` |
| 4. 系统能力映射 | 日历→`CalendarContract`；提醒→`AlarmManager`/`WorkManager`；桌面卡片→App Widget | `../harmonyos/entry/src/main/ets/common/util/CalendarExport.ets` |

## 技术选型（拟定）

- 语言：Kotlin
- UI：Jetpack Compose（Material 3）
- 本地存储：Room
- 网络：OkHttp + 自建 CookieJar（对应鸿蒙端 `network/http/RawHttp.ets` 的行为）
- 最低支持版本：拟定 Android 8.0 (API 26)

> 以上为规划，未开始实现。目标结构示意：

```
android/
├── app/                 # 应用模块（compose UI）
├── core/
│   ├── domain/          # 与鸿蒙端 domain 对齐的模型与接口
│   ├── data/            # Room + 远端数据源 + 认证适配
│   └── network/         # OkHttp 封装、Cookie、RSA
├── build.gradle.kts
└── settings.gradle.kts
```

---

返回主仓库说明：[../README.md](../README.md)