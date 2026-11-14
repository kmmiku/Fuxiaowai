# 构建地图

核对日期：2026-11-14。地图初建时仅静态阅读；后续签名打包验证记录见“本次 0.1.1 打包验证”。入口：[README.md](README.md)。

## 1. 配置入口与版本

| 文件 | 当前源码事实 | 影响 |
|---|---|---|
| [AppScope/app.json5](../../AppScope/app.json5) | `bundleName=com.fuxiaowai.timetable`；`versionName=0.1.1`、`versionCode=1000001` | 应用身份和系统安装/商店版本 |
| [oh-package.json5](../../oh-package.json5) | 工程名 `fuxiaowai`、版本 0.1.1；无声明依赖 | 工程元信息；不是独立的系统安装版本来源 |
| [entry/oh-package.json5](../../entry/oh-package.json5) | 模块版本仍是 0.1.0；无声明依赖 | 与应用版本不同，待确认是否统一维护 |
| [build-profile.json5](../../build-profile.json5) | `default` 产品，`runtimeOS=HarmonyOS`，compatible/target 均 `5.0.0(12)`；`debug`/`release`；`signingConfigs=[]` | 不会自动配置正式签名；编译 SDK 的实际安装版本未由此文件完整锁定，待确认 |
| [entry/build-profile.json5](../../entry/build-profile.json5) | Stage、default target；release 混淆 `enable=false` | 不应把 release 等同于已开启混淆 |
| [hvigorfile.ts](../../hvigorfile.ts) | 导出 `system: appTasks`，plugins 为空 | 工程级 assembleApp 等任务 |
| [entry/hvigorfile.ts](../../entry/hvigorfile.ts) | 导出 `system: hapTasks`，plugins 为空 | 模块级 assembleHap 等任务 |
| [hvigor/hvigor-config.json5](../../hvigor/hvigor-config.json5) | modelVersion 5.0.0，其余配置为空对象 | Hvigor 运行配置 |
| [entry/obfuscation-rules.txt](../../entry/obfuscation-rules.txt) | release 配置引用的混淆规则文件 | 当前开关关闭；规则存在不代表生效 |

界面版本还出现在 [AboutPage.ets](../../entry/src/main/ets/pages/AboutPage.ets)、[ProfilePage.ets](../../entry/src/main/ets/pages/ProfilePage.ets)、[MenuSheet.ets](../../entry/src/main/ets/ui/components/MenuSheet.ets)，反馈版本出现在 [FeedbackDelivery.ets](../../entry/src/main/ets/data/remote/FeedbackDelivery.ets)。修改版本需同时核对这些显示/上报位置及输出命名。

## 2. 当前主流程

```text
tools/构建.ps1
  → Node tests/*.cjs
  → 校验 ASCII 构建目录
  → 同步 entry / AppScope / hvigor / 根构建配置
  → hvigorw assembleApp（release）
  → 检查日志 BUILD SUCCESSFUL
  → dist/build-manifest.json
tools/打包app.ps1
  → 检查环境签名参数与构建清单的源码哈希
  → Get-CertChainPem
  → sign-app 签 HAP → verify-app
  → 用 Hvigor APP 模板替换 HAP
  → 对 APP 再签名 → verify-app
  → 比较包内 HAP 与独立签名 HAP 的 SHA256
tools/验包.ps1
  → 结构、包内 HAP 签名、证书链、Profile 配对、独立 HAP 一致性
```

## 3. `tools/构建.ps1`

源码：[构建.ps1](../../tools/构建.ps1)。顶层脚本，无额外导出函数。

- 参数 `BuildDir` 默认 `D:\fxw_build\hardening\HarmonyOs`；脚本限制目标在 `D:\fxw_build\hardening\` 内且只含 ASCII。
- Node、Java、Hvigor、SDK 路径目前是 `D:\DevEco Studio\...` 的本机固定路径；其他开发机需要先核对并调整配置，不能假定已安装。
- 先运行 `node --test 'tests/*.cjs'`；失败停止。测试加载器另依赖本机 SDK 的 TypeScript，可由环境变量 `FXW_TYPESCRIPT` 指定。
- 用 `robocopy /MIR` 同步 `entry`、`AppScope`、`hvigor`，排除 `build`、`oh_modules`；复制根构建配置。**该脚本会修改构建副本，镜像模式可能删除副本内额外文件，不属于只读分析命令。**
- 设置 `DEVECO_SDK_HOME`、`JAVA_HOME`、Java/Node 内存参数，进入构建副本运行 release assembleApp。
- 以日志出现 `BUILD SUCCESSFUL` 判断成功；没有签名配置产生的告警不等于签名已完成。
- 成功后写 `dist/build-manifest.json`，含版本、UTC 构建时间、buildDir，以及选定源码/配置路径与 SHA256。
- 当前清单输入是 `entry/src/`、`AppScope/`、根 `build-profile.json5`、根 `oh-package.json5`。它没有覆盖所有构建脚本/模块配置；不要把清单描述成整个仓库的完整可复现证明。

在工程根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\构建.ps1
```

脚本中的等价 Hvigor 核心命令（需先进入 ASCII 副本并配置 SDK 环境）：

```powershell
& 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --no-daemon assembleApp --mode project -p product=default -p buildMode=release
```

调试 HAP 可用 Hvigor 模块任务；此命令不是根脚本的另一个已封装入口：

```powershell
& 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --no-daemon assembleHap --mode module -p product=default -p module=entry@default
```

## 4. 签名配置与边界

源码：[打包app.ps1](../../tools/打包app.ps1)，关键函数 `Fail()`、`Get-CertChainPem()`。

| 输入/控制项 | 位置与用途 |
|---|---|
| `FXW_KEYSTORE` / `Keystore` | 从工程外传入私钥库文件路径；地图不记录其内容或真实口令 |
| `FXW_KEY_PASSWORD` / `KeyPwd` | 通过环境或参数注入；本地图仅记变量名，不提供值，避免写入命令历史/文档 |
| `CertFile` / `Profile` | 发布证书和发布 Profile 的路径；应显式指向匹配材料 |
| `KeyAlias` / `SignAlg` | 脚本支持选择；地图不复制个人签名标识。默认依次尝试 SHA256withECDSA、SHA384withECDSA |
| `Hap` / `PackInfo` / `AppTemplate` | 本次构建输入；优先选 ASCII 副本；找不到 APP 模板直接失败 |
| `Out` | 默认从 AppScope 版本生成 `dist/福小外-<version>-signed.app` |

证书/Profile 自动搜索会遍历工程签名材料目录、dist 和若干本机下载目录，按修改时间选候选。自动找到不等于匹配正确；真实文件、配对与商店受理状态待人工验证。本地图不读取这些材料。

签名脚本先读取构建清单并重新计算记录的源码哈希，源码变化则拒绝签名。`Get-CertChainPem()` 按证书关系排列叶子与中间证书；随后签 HAP、校验、保留独立 HAP，以 Hvigor APP 为模板组包，再签 APP 并比较内部 HAP 字节。

当前脚本的 Python 分支只写 `entry-default.hap`、`pack.info`、`pac.json`；PowerShell ZipArchive 后备分支保留其他模板条目。将来增加多模块时需重新检查，不能直接认为脚本已支持任意多 HAP APP。

PowerShell 5.1 场景应核对脚本 UTF-8 BOM 与原生命令 stderr 行为；当前脚本使用 `Continue` 配合退出码/日志检查。不要从历史发行脚本复制内置口令。

准备好工程外材料后使用现有环境值，不在文档里填写秘密：

```powershell
# 所有 FXW_* 环境变量均应由本机安全配置预先提供。
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\打包app.ps1 -CertFile $env:FXW_RELEASE_CERT -Profile $env:FXW_RELEASE_PROFILE
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\验包.ps1
```

`FXW_RELEASE_CERT`、`FXW_RELEASE_PROFILE` 在此仅作为命令示例的外部路径变量；签名脚本本身不会自动读取这两个变量，实际经 `-CertFile`、`-Profile` 传入。

## 5. 验包与产物

源码：[验包.ps1](../../tools/验包.ps1)；函数 `Ok()`、`Bad()`、`Info()`，累计失败计数决定退出码。

1. 解开 APP，检查三个指定条目。
2. 对包内 HAP 运行 `verify-app`。
3. 读取签名链，检查非自签链首与自签根。
4. 验证 Profile、release/app_gallery 声明、分发证书与链首配对。
5. 如提供或找到独立 HAP，比较 SHA256。

该脚本没有完整复现商店受理逻辑；其“链首非自签”检查也不能代替完整证书路径验证。不要把脚本成功直接写成“AGC 已通过”。

| 位置 | 预期类型/当前含义 |
|---|---|
| ASCII 副本 `entry/build/default/outputs/default/entry-default-unsigned.hap` | Hvigor 模块未签名 HAP |
| ASCII 副本 `build/outputs/default/HarmonyOs-default-unsigned.app` | 默认 BuildDir 名称下脚本寻找的 APP 模板；更换目录名后须核对实际文件名 |
| `dist/build-manifest.json` | 仅在当前构建脚本成功后生成；是否存在应现场核对，不能推导已有签名包对应它 |
| `dist/福小外-<version>-signed.app` / `.hap` | 签名脚本成功时交付；当前目录中仍有旧 0.1.0 命名文件，不能当作当前 0.1.1 已验收产物 |
| `assets/release/` | 历史 Android/Harmony 安装文件；命名版本不作为当前源码版本依据 |

设备验证需在授权后执行 `hdc list targets`、安装指定 HAP、启动 `EntryAbility`，并回归三种登录、课表、成绩、分享、反馈、日历、提醒和卡片。当前地图任务不执行安装或远程登录。

### 上轮暂停时的构建记录（待确认）

上轮暂停前最后一次构建日志记录了 [TimetableStateStore.init](../../entry/src/main/ets/data/local/TimetableStateStore.ets) 和 [WidgetRefresh.update](../../entry/src/main/ets/widget/WidgetRefresh.ets) 中对象字面量对应的 ArkTS 类型错误。建立地图时未重跑编译；后续用户要求签名安装包，已按下述记录完成必要类型修正与构建。此前暂停的其他业务边界复查没有因此自动完成。

### 本次 0.1.1 打包验证

2026-11-14：为 `TimetableStateStore.init()` 的旧学期字典提供显式类型变量，为 `WidgetRefresh.update()` 的载荷增加 `WidgetPayload` 接口。仅修正编译类型，未修改 UI、公开方法或业务流程。

- `tools/构建.ps1`：56 项 Node 测试通过，Hvigor release `assembleApp` 成功。
- `tools/打包app.ps1`：HAP/APP 签名成功，源码清单哈希与包内 HAP 字节比较通过。
- `tools/验包.ps1`：五项检查通过。Python 子进程启动 Windows PowerShell 时须使用 Windows 自身的模块路径，避免继承 PowerShell 7 的模块路径而找不到 `Get-FileHash`；此次已在子进程环境中明确设置，没有修改系统环境。
- 交付文件：`dist/福小外-0.1.1-signed.hap`（安装用）及同版本 `.app`（应用市场容器）；构建来源见 `dist/build-manifest.json`，摘要记录见 `dist/package-verification-0.1.1.json`。
- 同一最终 HAP 已在连接的鸿蒙模拟器上通过 `hdc install -r` 安装并成功启动 `EntryAbility`；没有验证实体手机、文件管理器点击安装、完整登录回归或商店受理。

## 6. 后端运行与部署

| 文件 | 真正执行内容 |
|---|---|
| [server.js](../../server/server.js) | 原生 Node 服务；环境变量控制绑定、端口、数据根、配额、代理信任；启动需要管理员环境凭据，见 [API_MAP.md](API_MAP.md) |
| [fxw.env.example](../../server/fxw.env.example) | 环境变量名称示例；不要把真实配置抄入地图 |
| [fxw-share.service](../../server/fxw-share.service) | `fxw` 用户、`/opt/fxw-service`、`/etc/fxw-share.env`、回环后端；示例 `MemoryMax=512M`；systemd 重启和沙箱设置 |
| [nginx.conf.example](../../server/nginx.conf.example) | 现有 HTTPS server 内片段；反代 `127.0.0.1:8080`，覆盖客户端 IP 头、请求体 4m、超时；不包含完整域名/证书配置 |
| [deploy.sh](../../server/deploy.sh) | 要求 root 与既有环境文件；创建服务账号/目录，复制源码、安装 unit、enable/restart、请求本机 healthz |
| [OPERATIONS.md](../../server/OPERATIONS.md) | 单进程假设、配额、日志和数据保留期、备份恢复操作说明 |

从 `server/` 目录执行 `bash deploy.sh` 会真实修改 Linux 主机、服务与文件，不是验证或只读命令。示例与实际生产配置是否一致待确认；本轮不自动部署。

## 7. Git 与长期维护

## 2026-11-14 后台增量部署记录

本次已按用户明确授权部署，不能再将“本轮不自动部署”的历史分析描述用于判断本次状态。公开入口 https://fuxiaowai.xyz/admin；线上 Node v22.22.1。采用 [tools/deploy-admin-console.py](../../tools/deploy-admin-console.py) 对已核验的线上server.js插入管理扩展钩子，仅更新 dashboard.html/admin-console.js/admin.js/admin.css，未部署工作区其他加固差异，未更改服务配置与管理员凭据。

验证命令：`node --test tests/admin-console.cjs tests/server-http.cjs`；浏览器测试另设置 `FXW_QA_PLAYWRIGHT` 后 `node --test tests/admin-ui.cjs`。外部QA工具不属于产品依赖，不自动安装到工程。实际8项测试通过，Linux额外3项管理扩展测试通过；线上10条已认证路由、未认证边界、既有口令读取、HTTPS健康及全部原口令哈希核验通过。详见 [交付记录](../admin-console-20261114.md)。不自动重跑部署脚本；脚本包含真实反馈清空动作。

- 当前存在本地 `.git`；本地图基于工作区而非仅 HEAD。不要继承旧文档“没有 Git”的描述。
- 开始开发先只读执行 `git status --short`，区分已存在未提交改动和本轮范围；不得自动覆盖、清理或提交。
- `.gitignore` 忽略发行材料、私钥与部分历史文档；文件被忽略不等于可以安全分享。
- 本轮未自动提交 Git。应用编译、脚本完整运行、正式签名、商店受理、模拟器回归均需独立记录日期和对应源码/包哈希。

更新触发：版本、SDK/工具路径、Hvigor 参数、签名输入、包名、模块数、环境变量或部署脚本变化。同步 [PROJECT_MAP.md](PROJECT_MAP.md)、[API_MAP.md](API_MAP.md)、[DATABASE_MAP.md](DATABASE_MAP.md)。


本次 P1 菜单的构建、安装与模拟器验证见 [菜单验收记录](../menu-ui-20261114.md)。


本轮分享/游客覆盖的构建、测试与双模拟器证据见 [分享与游客验收记录](../share-guest-20261114.md)。


周数滑块本次构建/安装/运行证据见 [验收记录](../week-slider-20261114.md)。
