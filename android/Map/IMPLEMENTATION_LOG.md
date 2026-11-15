# 执行记录

## 基线与隔离

- 分支codex/compat-hardening；基线f2ce3c4；原Android目录没有Git，本工作区有独立Git。
- 原版npm run build成功；没有现成业务测试，新加失败用例后再修复。
- 首轮13项中11个业务用例失败，之后逐步转绿；后续分页、Cookie、分享、提醒等缺口另加用例并修复。
- 后端原参考副本7项测试通过；新增完整性、跨IP去重/冲突、并发容量、CSP测试先失败后通过。并发去重的微任务竞争由原回归检出，已修正。
- 学校登录协议/正式升级不具备真实账号及发布材料基线，不伪造“批次1已全部完成”。在可逆本地副本继续已授权代码工作，生产发布保持门禁。

## 已运行的验证

- npm ci --ignore-scripts --no-audit --no-fund（锁文件安装）。
- npm run build：TypeScript检查及Vite构建通过，CSS产物仍是index-CxOOYsrG.css。
- node --test tests/*.cjs（改名为*.test.cjs之前）：36项通过，其中1项是加载辅助文件自动发现，实际业务用例35项。最终数量以后续npm test为准。
- Gradle :app:assembleDebug / :app:assembleDebugAndroidTest、testDebugUnitTest曾通过；后续修改后需重跑最终命令。
- 隔离AVD codex_fxw_compat，Android34，端口5580，位于TEMP私有测试目录，未使用原fxw AVD。安装测试包，授予测试日历权限，am instrument：4 tests OK，含3项兼容用例与修正后的包名断言。
- 浏览器固定390×844、2026-11-14 09:00、虚构QA2024账号/课程，基线和当前8页截图逐字节相同；home-before/after.png保存于evidence。后续新增改动需最终再比一次。

## 决策记录

- Ruling: 在当前空仓库引入原Android源码的隔离副本 — 保留用户原工程 — 成本是两份工程，当前目录是本轮交付权威位置。
- Ruling: 按Android实际localStorage适配事务和唯一性，不引入RDB — 避免改变原存储格式/模型 — 成本是多键undo日志占额外存储，容量不足时明确失败。
- Ruling: 后端只改隔离源码，不覆盖生产 — 当前任务授权重构而无具体生产发布计划 — 成本是后端修复需后续部署才能生效。
- Ruling: 未用真实账号采集登录秘密或执行学校链路替换 — 缺少可核验基线 — 成本是正式发布前仍须授权账号回归。
- Ruling: 保留API22，通过Keystore RSA包装AES兼容 — 不提高最低系统版本 — 成本是API22真机分支仍需独立验证。

最终测试、审查发现与对应修正、源码提交和包哈希在本文件后续追加。

## 最终复核与本轮交付

- 新上下文只读复核：0 Critical、4 Important、0 Minor、0 Declined；4项Important按VERIFICATION_REPORT逐项用失败测试复现并修正。
- Final: fixed native Cookie write/clear race — in-flight native cookie writes cannot recreate cookies after clear RED→GREEN。
- Final: fixed cleanup blocked by full storage — full storage cannot prevent independent logout cleanup RED→GREEN。
- Final: fixed callback-only retry and lost cleanup journal — local cleanup operation survives restart without an in-memory callback / privacy wipe retains pending cleanup journal until external steps finish RED→GREEN。
- Final: fixed clear-courses bypass — clear timetables is one atomic operation, invalidates stale work, and preserves credentials通过。
- 追加发现并修正分页末页计数不全：advertised last page cannot hide missing grade records RED→GREEN。
- 最终npm run check：42/42；22页结构对照通过（允许3处据实隐私文字修正），样式/公共组件/动画工具源码完全相同；Web构建成功。
- 最终独立Android34 instrumentation：4/4。最终Debug APK摘要见evidence/apk-manifest.json。
- 用户提供可见模拟器启动方式后，新增AGENTS.md及tools/Start-Android.ps1；带窗口fxw启动、保留数据覆盖安装并进入首页成功。原D盘工程未覆盖；用户AVD未执行测试清理。
- 当前fxw一致应用数据已加密备份到工程外私有目录，并验证解密摘要；未导出Keystore密钥，也不冒充首次升级前备份/生产回滚演练。
- Ruling: 原始AVD/其他模拟器不做全局kill或卸载 — 复用或定向启动fxw并保留数据 — 成本是遇到具体实例故障时需指定-Restart。
- Ruling: 本轮只修正已列明的隐私文字与错误提示 — 原有声明与真实上传/Android Keystore不符 — 成本是这些文案不会与旧截图完全相同，布局/样式保持。
- Ruling: 提醒页残余810px截图差异不改产品CSS来迎合工具 — 计算样式和几何相同，证据如实保留 — 成本是不能声称40组截图全部位级一致，正式设备截图门禁继续保留。
- Deferred minors：无。正式未验收项见VERIFICATION_REPORT；不宣称全部6批或全部网络要求已验收。

## 2026-11-14 用户确认的P1–P6界面调整
- 校区两选项及右侧倒三角、SVG操作图标、15px校历日期和灰色横线已实施。npm run check通过42/42，Debug构建并保留数据安装fxw成功。方法与证据见solution.md；等待用户验收。

## 校历效果图确认后应用
- 星期字号13px、日期15px、横线在相邻数字行中心之间，移除本月标签。通过42/42测试与UI检查、Web及Android构建；浏览器测量各周横线中点误差0px。方法追加到solution.md，fxw保留数据覆盖安装供验收。

## 底部导航滑动
- 用户确认方案后将BottomTabs提升到App路由区域外，四主页面共用常驻底栏，加入250ms独立背景滑块，首次/尺寸变化直接定位，尊重减少动态效果。
- npm run check通过42/42，隔离浏览器动画中间值、DOM持续、连续点击、返回及尺寸变化验证通过；详细方法与证据见solution.md。

## 平台/扫码登录 Invalid base URL
- 复现根因：finishPortal以相对路径调用followRedirects，首跳Location解析误用该相对路径作URL base，两个入口共用此收尾，直登不经过。
- followRedirects首个请求前按ROOT规范化并校验地址。新增两条虚构响应回归RED→GREEN，网络8/8及npm run check 44/44通过。无真实密码/Cookie/票据读取或打印；真实学校登录待用户验收。详情见solution.md。

## 校区滚轮
- 用户确认效果图后用现有WheelPicker替代校区原生select；独立草稿，完成提交，遮罩取消，保留两个选项及字段外观。44/44及UI/Web检查通过；浏览器验证滚动、确认、取消、重新定位和立即确认通过。方法见solution.md。

## 周课表提示及字号
- 用户确认后移除下节提示，空位减半为12.25px；教室/教师与课程名字号一致、字重500，课程名700保持。npm run check 44/44通过，浏览器尺寸/字号/字重核对通过，构建Debug包并保留数据安装fxw，方法见solution.md。

## 三点菜单整合
- 用户确认预览及下排四入口后实施：移除首页下方卡片，将课表切换/管理与周数滑杆整合上卡，八项线条图标整合下卡。课表使用直线折角标准白勾。原菜单入口保留在其他功能。
- 联系邮箱/主题沿用现有页面，夜间直接保存开关；无在线更新服务，按钮如实提示未配置。44/44、UI/Web及隔离浏览器菜单交互/窄屏检查通过；Debug构建保留数据安装fxw。详见solution.md。

## 移除其他功能
- 按用户要求删除三点菜单底部折叠模块；44/44及UI/Web检查、浏览器模块移除核对通过。方法见solution.md。

## 分享连接断开
- 实测HTTPS握手重置、HTTP403‘非法阻断690’；缺云控制台/服务器连接条件，线上恢复待接入。客户端友好错误修复及回归45/45通过；未修改生产。见solution.md及evidence/share-connectivity.json。

## 临时IP分享修复
- 用户明确备案未完成，授权使用113.45.242.182的HTTP入口。生成/取回统一改为该地址；健康200、1份虚构课表线上上传取回一致。46/46及构建通过；未打印口令、未修改生产配置或真实历史数据。域名阻断仍待备案完成。

## 游客口令导入及整条消息粘贴
- 游客读写冲突修复，保留anon/账号隔离；完整消息提取唯一32位口令，查询与提交加账号/课表及过期请求防护、保存回读核对。48/48及UI/Web通过，隔离浏览器端到端导入/刷新显示通过，未访问真实口令。方法见solution.md。
2026-11-15：双平台公告本地实现与验证边界见solution.md；线上部署待可用服务器连接配置。

## 双平台公告上线与Android入口
- 后台独立鸿蒙/安卓栏目增量部署成功，分享反馈数据不变；Android我的检测更新及公告弹窗、外部HTTPS更新入口已实现。49/49及UI/Web通过，Debug安装fxw成功，正式升级待验收。详情见solution.md。
检测更新入口顺序与联网实测通过：网络检测→检测更新→更多；备案期公告查询使用授权HTTP IP，模拟器实际收到暂无新版。

## 版本概览与APK交付
- 已确认预览实施并上线，独立版本记录保留于公告撤回后；49/49、UI/Web与Debug构建通过，APK签名验证成功。详见solution.md与evidence/android-delivery-20261115.json。

## 0.1.1与版本策略
- Android版本0.1.1/code3打包交付，后台安卓/鸿蒙独立版本说明已同步回读；AGENTS.md记录后续版本更新和发布要求。详见solution.md。

## 课表字号最终调整
- 时间轴12px、课程名/教室16px及700字重、教师原样；49/49和Debug构建通过，fxw保留数据覆盖安装启动。方法见solution.md。

## 居中课程块
- 15px课名700/教室600、按实测高度居中或顶部、保留完整编号、教师仅详情显示。49/49和合成浏览器布局/详情验证通过，Debug构建并安装fxw。方法见solution.md。

## 纯色白字课块
- 固定字形、统一标题/地点起点、纯色白字小圆角；49/49和合成浏览器几何/编号完整性核对通过，最新Debug构建安装fxw。详见solution.md。

## 柔和配色与整组居中
- 按最新要求恢复按实际内容整组居中、使用较淡适中饱和度八色；49/49与浏览器几何/完整编号验证通过，fxw已更新。见solution.md。

## 最小顶部留白与取样主色
- 每块顶部最小8px，长块居中，15px字形不变/行高16；附件取样红粉青蓝四主色已应用。49/49、构建及合成布局核对通过，fxw已更新。详见solution.md。

## 首课对齐与完整参考色
- 八色随机邻接避重、每天第一门普通课16px顶距、超长块居中；最小行高68px保障编号空间。51/51与七天合成浏览器验证通过，已安装fxw。详见solution.md。

## 指定三色HSL
- 红S88/L55、橙S90/L60、深蓝S80/L45，保留色相；51/51与Debug构建通过，已安装fxw。见solution.md。

## 首课默认固定/手动选色优先
- 修复随机色覆盖保存颜色及旧调色板；新增可选colorOverride标记，五日首课默认固定、手动优先。53/53及浏览器编辑保存刷新验证通过，fxw已更新。见solution.md。

## 翻周颜色冻结及APK
- 根因：网格重挂载重新产生随机seed并按周重新配色。现保存整表一次性autoColorIndex，预加载网格直接读取；手动优先。56/56、真实合成触摸翻周/刷新验证通过，APK已打包并安装fxw，后台安卓说明同步。详见solution.md。
