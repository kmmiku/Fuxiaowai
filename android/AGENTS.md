# 工程代理指南

## 范围与兼容约束

- 当前工程根即本目录（仓库内 `android/`）：Web 层在 `src/`，Capacitor 原生层在 `android/`，改造记录与验证证据在 `Map/`。下文所有相对路径都以本目录为基准。
- 执行前读Map/README.md、Map/SOURCE_MAP.md、Map/IMPLEMENTATION_LOG.md；原始基线f2ce3c4。
- 保持页面结构、尺寸、颜色、动画、按钮和导航；只允许已明确记录的隐私/错误文字修正。保留公开调用、登录入口、账号隔离、历史数据和发布身份。
- 验证用 `npm run check`；Android构建前先 `npm run build` 和 `npx cap sync android`，防止APK装入旧Web资源。
- 不读取/打印真实密码、Cookie、票据、分享口令或签名口令；生产和学校真实账号操作必须在对应授权范围内。
- 保留 `com.fuxiaowai.timetable`，不生成替代发布签名。正式打包用外部 `FXW_SIGNING_PROPERTIES`，详见Map。

## 用户指定的安卓模拟器启动方式

用户要求带窗口启动AVD `fxw`。启动参数为 `-avd fxw -netdelay none -netspeed full -no-boot-anim`，`Start-Process` 使用 `-WindowStyle Normal`；不要给用户交互模拟器加 `-no-window`、`-gpu swiftshader_indirect` 或重定向输出。

优先执行本工程脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\Start-Android.ps1
# 修改源码后构建、同步再启动：
powershell -ExecutionPolicy Bypass -File .\tools\Start-Android.ps1 -Build
# 仅需要重启fxw时：
powershell -ExecutionPolicy Bypass -File .\tools\Start-Android.ps1 -Restart
```

脚本按 `$env:ANDROID_SDK_ROOT`（其次 `$env:ANDROID_HOME`、`android/local.properties` 的 `sdk.dir`）定位SDK，优先复用正在运行的fxw，仅操作已核实AVD名称的目标设备；不默认杀所有emulator/qemu进程或重启adb服务，避免误关其他测试环境。用户原命令中的全实例清理仅作为明确要求全部重置时的排查手段。

APK使用本工程 `android\app\build\outputs\apk\debug\app-debug.apk`；使用 `adb install -r` 保留数据。若签名不兼容，停止并报告，不自动卸载或清空用户账号/课表。

截图默认保存至本工程 `Map\evidence\boot-shot.png`。原参考命令使用D盘旧工程APK，不能当成本轮新产物。

隔离自动化测试可以使用独立headless AVD `codex_fxw_compat`，不能把它当作用户看得到的fxw窗口，也不能在用户fxw里跑清数据的测试。

## 版本更新、后台同步与交付策略（2026-11-15用户确认）

- Android版本名称自0.1.1开始；当前versionName=0.1.1、versionCode=3。以后修改版本名称时必须同步android/app/build.gradle、package.json/package-lock.json、“我的”和“关于”页；versionCode只能递增，不能因版本名称重排而回退。
- 用户要求打包时，先执行npm run check（含build），再npx cap sync android与Gradle构建，核验包内applicationId/versionName/versionCode、APK签名、文件大小及SHA256。命名“福小外-Android-<versionName>.apk”，交付至artifacts。正式签名缺失时明确标注Debug包，不生成替代发布密钥。
- 每次完成版本更新及打包后，同步后台对应平台的软件版本及真实更新说明，并回读校验；鸿蒙与安卓分别管理、版本代码独立比较。修改Android不得把Android版本代码写入鸿蒙。
- 后台软件版本记录与公告独立：认证GET/PUT /api/admin/app-version?platform=android|harmony登记当前版本及版本说明；认证GET/PUT/DELETE /api/admin/app-update?platform=...管理面向客户端的更新公告。无平台参数的旧公告接口继续保留鸿蒙语义。
- “软件版本说明”记录本次实际完成内容，可在无新公告/无下载地址时登记；“发布公告”会影响客户端提示。只有真实可用的新包或商店更新及正确平台HTTPS更新入口就绪，才发布更新公告。撤回公告不删除软件版本。不得使用虚假未来版本或占位下载地址发布公告。
- 用户已授权本次后台两平台版本内容同步。今后用户要求更新版本/发布时，按上述流程同步对应后台；仅查询或制作预览不触发发布。跨平台同步时先核对各自源码及交付日志，只记录已有证据，不冒充市场受理成功。
- 服务器连接材料及签名文件保持工程外私有存储，按已授权路径仅在进程内读取使用，不打印、复制进工程、提交Git或写入日志；不在AGENTS中保存密码、令牌、私钥或签名口令。
- 将版本变化、后台回读结果、部署/回滚点和APK摘要追加Map/solution.md、IMPLEMENTATION_LOG.md及evidence。区分构建成功、后台已登记、公告已发布和实际升级通过。
