# 问题解决记录

本文专门记录开发过程中用户要求跟踪的问题、修改项、错误原因、修正方式和实际结果。新增记录时以源码、构建日志和运行验收为依据；未验证的部分标为“待确认”。避免写入密码、Cookie、Token、私钥或个人数据。

## 记录模板

### YYYY-MM-DD｜问题标题

- **现象 / 需修改项：**
- **排查与根因：**
- **踩坑 / 错误记录：**
- **改正方法：**
- **结果与验证：**
- **涉及文件：**
- **后续待办：** 无 / 描述

---

## 2026-11-14｜课表分享菜单图标在方形格窗内偏左上

- **现象 / 需修改项：** 分享课表、导出到日程、从口令导入三行左侧的纸飞机、日历、钥匙图标没有位于浅灰色圆角方格正中心。用户截图可见图形整体偏左上。
- **排查与根因：** `Index.ets` 中把 26×26 尺寸和背景直接施加给 16×16 的 `LineIcon`。`LineIcon` 内部 Canvas 仍按 16×16 绘制，因此改变组件尺寸并不会让实际绘图区域自动扩展并居中。
- **踩坑 / 错误记录：** 第一轮只调整 `LineIcon.ets` 里纸飞机和钥匙的路径坐标，构建成功，但没有解决容器布局造成的偏移。路径外接框调整不能代替布局容器居中。
- **改正方法：** 在 `Index.ets` 的 `forwardRow` 中增加 26×26 `Stack({ alignContent: Alignment.Center })` 作为格窗，把 16×16 `LineIcon` 放入 Stack；圆角和背景设置在 Stack 上。保留三个菜单行的原文字、间距及点击行为。
- **结果与验证：** release 构建成功；随构建脚本执行的现有用例 59 项通过、1 项跳过。新版 HAP 已安装到在线鸿蒙模拟器并启动，转发菜单已打开供验收。截图显示图标置于格窗内；最终光学居中效果仍以用户模拟器实机观感为准。
- **涉及文件：** `entry/src/main/ets/pages/Index.ets`、`entry/src/main/ets/ui/components/LineIcon.ets`、`docs/map/COMPONENT_MAP.md`。
- **后续待办：** 用户若反馈任一图标仍有视觉偏心，记录具体图标和方向，再仅调整该图标路径的光学边界，并重新构建、部署验证。

## 2026-11-14｜校历月历日期数字略微放大

- **现象 / 需修改项：** 用户确认采用预览，将校历月份网格中的日期数字稍微增大，其余保持不变。
- **排查与根因：** AcademicCalendar.dayCell() 的日期文本使用 13vp 字号。
- **踩坑 / 错误记录：** 无；此项为已确认的局部视觉调整。
- **改正方法：** 将日期文本字号从 13vp 调至 14vp；星期标题、节日日期、月份标题、周间分割线及其他布局不改。
- **结果与验证：** 待构建及鸿蒙模拟器验收。
- **涉及文件：** ntry/src/main/ets/pages/AcademicCalendar.ets、docs/map/PAGE_MAP.md。
- **后续待办：** 完成构建、安装并在模拟器打开校历页后更新本结果。
`n## 2026-11-14｜校历预览落实遗漏的修正`n`n- 现象：上一轮只将日期改为14vp，漏做用户已确认的周分割线及移除“本月”标签。`n- 错误原因：把整张预览的采用要求误解成仅调整字号；构建通过不能证明视觉需求全部完成。`n- 修正：日期改为16vp；每周之间新增0.5vp淡灰分割线；移除月份标题栏“本月”标签。`n- 验证：release构建成功，现有用例59通过、1跳过；最新HAP安装并启动成功。模拟器视觉核对见本次交付。`n- 涉及文件：entry/src/main/ets/pages/AcademicCalendar.ets、docs/map/PAGE_MAP.md。
`n## 2026-11-14｜校历数字与周分割线距离不对称`n`n- 现象：数字靠近上方分割线，距离下方分割线较远。`n- 根因：46vp日期格使用顶部对齐的Column，28vp数字框与事件点占据上部空间。`n- 修正：dayCell改为居中Stack，数字框中心固定在日期格中心；4vp事件点单独下移17vp，不参与数字定位。每周高度保持46vp，分割线位于相邻数字中心的中点，字号维持16vp。`n- 验证：release构建成功；现有用例59通过、1跳过；最新HAP安装和启动成功。`n- 涉及文件：entry/src/main/ets/pages/AcademicCalendar.ets。

## 2026-11-14｜在星期标题与日期之间增加分割线

- **现象 / 需修改项：** 用户要求星期标题（周日到周六）和第一周日期之间也有分割线。
- **排查与根因：** `monthCard()` 之前仅在星期行后直接渲染周行；分割线只在后续周行前添加。
- **踩坑 / 错误记录：** 无。
- **改正方法：** 在星期标题行之后插入分割线，沿用周间分割线颜色和 0.5vp 粗细。
- **结果与验证：** release 构建成功；现有用例 59 项通过、1 项跳过。最新 HAP 安装启动后，在模拟器校历页确认星期标题下方的分割线可见。
- **涉及文件：** `entry/src/main/ets/pages/AcademicCalendar.ets`、`docs/map/PAGE_MAP.md`。
- **后续待办：** 更新构建和模拟器验收结果。


## 2026-11-14｜增大星期标题并平衡分割线上下间距

- 需求：星期标题略微增大，分割线到星期和日期文字的留白接近一致。
- 修改：AcademicCalendar.monthCard的星期文字从9vp改为12vp，居中于42vp高标题行；日期维持16vp、46vp行高。用字号差补偿行高，使分割线上下文字边缘间距接近一致。
- 结果：release构建成功，现有用例59通过、1跳过；新HAP安装启动成功，模拟器校历中已核对星期字号及分割线。

## 2026-11-14｜替换课表顶部新增、导入、分享图标

- 需求：采用确认的加号、框内弯箭头导入、方框右上箭头分享线条图标。
- 修改：LineIcon新增plus、import-file、share-out；Index顶部用18vp线条图标替代文字字形，继续使用原34×34按钮区域、排列和回调。分享弹出菜单绑定保持原逻辑。
- 验证：release构建成功，现有用例59通过、1跳过；最新HAP安装启动成功。

## 2026-11-14｜新建课表名称框闪现消失

- 现象：切换课表区域点击“＋新建”后名称框闪现即消失。
- 排查：openCreate仅置showRename为true，业务关闭操作仅在保存成功后；根Stack连续绑定名称框、提醒滚轮两个bindSheet，存在同宿主冲突。
- 修正：保留根Stack的名称框绑定，将提醒滚轮移至根Stack内独立、始终存在的零尺寸Stack宿主；弹框UI及新建、重命名保存逻辑不改。
- 结果：release构建成功；现有用例59通过、1跳过；新HAP安装启动成功。模拟器观察到“已新建”提示及新课表卡片；用户持续操作导致工具拒绝继续点击，未完成独立的弹框持续显示、重命名及提醒滚轮回归核对。
- 后续待办：补充重命名和提醒滚轮交互验收。

## 2026-11-14｜底部四标签选中背景滑动

- 修改：BottomTabs使用独立浅蓝底板，依据实测宽度在四格间平移；250ms cubicBezier(0.22,1,0.36,1)结束后replaceUrl。首帧按current定位；连续点击记录最新目标；路由失败恢复原选中。
- 验证：release构建成功，现有用例59通过、1跳过；新HAP安装启动成功；模拟器观察到切换至我的页面。连续点击、全部四页及系统减少动态效果适配尚待验证。

## 2026-11-14｜登录时安全存储初始化失败

- 现象：登录导入报“安全存储暂不可用，请重试”，另有302跳转提示。
- 根因：SecretStore.createKey只判断isKeyItemExist返回false；官方HUKS文档说明密钥不存在可能以12000011拒绝Promise，原实现因此跳过生成密钥并被ensureKey转换为通用错误。日志中的12000011来自系统组件，不能直接视为本应用日志证明；应用代码缺陷与官方契约已核实。
- 修正：仅将12000011视为密钥不存在并继续generateKeyItem；其他查询异常继续失败。保持AES-GCM及原密钥别名，不删除数据，不回退明文。
- 踩坑：首次编译不允许直接throw未知类型，改为Error后编译通过。
- 结果：release构建成功，现有用例59通过、1跳过，最新HAP安装启动成功。模拟器窗口最小化且恢复失败，尚未完成真实学校登录及设备端首次密钥创建验证。
- 后续：用户重试登录，若仍失败需继续采集本应用的HUKS错误码；302需按Location和会话链路单独判断。
- 依据：https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-huks/

## 2026-11-14｜成绩页过期/刷新提示与课表顶部按压动画待处理

- **现象 / 需修改项：** 成绩页在本地已有成绩快照时，后台刷新失败仍显示黄色错误横幅（截图包含“Incomplete HTTP response”）；扫码登录身份过期时状态文案提示身份过期、右上按钮变红，页面另有黄色重新验证提示。用户希望本机已有一次成绩备份后继续可查看成绩，去掉此类黄色提示。课表顶部“新增课表”（加号）与“导入课表”按压点击动画消失，需补回按下缩至90%、松开回弹和选中时深色图标提示动画，效果参考分享课表。
- **地图定位与源码核对：** `docs/map/README.md` 将成绩缓存定位到 STATE → API → DATABASE；`docs/map/STATE_MAP.md` 描述 `GradeSync` 失败保留旧完整成绩缓存、会话过期标记缓存 expired。页面实现位于 `entry/src/main/ets/pages/GradePage.ets`：`statusText()` 输出身份过期/已缓存状态；`headerBar()` 按 expired 改为红色状态点与红色重新验证按钮；`build()` 在已有成绩但 `errMsg` 非空时显示黄色提示卡。成绩快照从 `GradeCacheStore` 载入，已有缓存可先展示并继续刷新。
- **按钮地图定位与源码核对：** `docs/map/PAGE_MAP.md` 的 Index 页面条目记录 `openAddCourse`、`openLogin` 及顶部新增/导入入口；`docs/map/COMPONENT_MAP.md` 的 `Index.lineIconBtn/forwardBtn` 条目定位共享按钮构建器。真实实现位于 `entry/src/main/ets/pages/Index.ets`：headerBar 将 plus、import-file、share-out 分别绑定新增、登录导入、分享；`lineIconBtn()` 当前只居中绘制图标并绑定 onClick，没有 pressed 状态、scale 或选中颜色动画；`forwardBtn()` 仅在分享弹层打开时显示 chip 背景，也没有自身按压动画。故“分享课表动画保持一致”的确切参照细节待确认，源码当前未见与所述相同的按压/深色图标状态动画。
- **实施方法：** GradePage有完整本地成绩快照时继续显示缓存且不渲染刷新错误卡；状态文案明确为本地缓存，不将教务会话过期展示成红色/黄色告警；无缓存时原错误和登录引导仍保留，手动刷新/验证入口未删除。Index顶部新增、导入、分享、更多四个按钮统一以170ms springMotion按下压至0.9并回弹，触摸时加深图标颜色并显示chip背景；分享菜单展开时保留选中强调，34×34区域和原始点击回调保持不变。LineIcon为tone和dark状态增加Canvas重绘。
- **结果与验证：** 最终范围（顶部四按钮）release构建成功，现有用例59项通过、1项跳过。最终HAP重新安装，EntryAbility启动成功。此前在模拟器确认成绩页显示本地缓存、成绩列表和手动验证入口，未见黄色刷新错误卡；首次版本的课表页也曾打开。加入分享/更多按钮统一动效后又重建并重新安装；桌面端报告用户按下物理Escape停止Computer Use，因此最终HAP的最新课表页画面和四按钮触摸效果未能再次目视确认，需用户验收。
- **涉及文件：** `docs/map/README.md`、`docs/map/STATE_MAP.md`、`docs/map/PAGE_MAP.md`、`docs/map/COMPONENT_MAP.md`、`entry/src/main/ets/pages/GradePage.ets`、`entry/src/main/ets/pages/Index.ets`。
- **后续待办：** 用户在模拟器点击新增/导入确认按压动画观感；如需精确复刻分享入口的按压基准，再按验收反馈微调。

## 2026-11-14｜公网后台显示 Authentication required

- **现象：** 访问 http://113.45.242.182/admin 返回正文 Authentication required。
- **排查与根因：** 当前只读 GET 收到HTTP 401，响应头包含 WWW-Authenticate: Basic realm="Fuxiaowai Admin"；正文、realm与 server/server.js 的 needAuth() 完全吻合。后台 /admin 在 server.js 路由中先调用 checkAuth()，没有有效 Authorization: Basic ... 就返回401，这是管理后台预期的认证门禁，不表示管理服务崩溃，也不是福小外App口令。服务器进程启动时要求环境配置 FXW_ADMIN_USER 与 FXW_ADMIN_PASS；服务仍返回该响应说明请求到达配置了该门禁的Web链路，但不能由此确定实际配置值或浏览器是否保存过凭据。
- **访问方式风险及对照：** 该链接使用HTTP明文和公网IP；Basic认证内容只是Base64编码，不应在此地址输入管理员凭据。项目 server/OPERATIONS.md 记录的规范入口为HTTPS域名，并要求真实TLS证书。当前执行环境对 https://fuxiaowai.xyz/admin 的TLS握手被提前关闭；http://fuxiaowai.xyz/admin 返回 Server: ADM/2.1.1 和403“非法阻断214”，这与IP入口响应不同，疑似域名/前置安全网关或链路策略问题；仅凭本机探测尚不能定位到具体代理、证书、DNS或源站配置。
- **改正/访问建议：** 管理员应使用受信任的HTTPS规范域名访问，并使用部署时配置的后台管理员Basic Auth账户；不要使用App口令、SSH账户或在HTTP/IP链接上提交口令。若HTTPS域名仍无法访问，服务器管理员需核对域名DNS及TLS监听/证书、Nginx虚拟主机与上游转发，并检查前置WAF/ADM策略和源站日志；不应为消除提示而关闭认证。
- **结果与验证：** 只读GET与本地源码比对完成；没有提交认证信息、探测密码、修改服务器配置或尝试绕过认证。认证门禁根因已确认；HTTPS域名当前不可达的具体网络层原因待服务器侧日志和配置确认。
- **涉及文件：** docs/map/README.md、docs/map/API_MAP.md、server/server.js、server/OPERATIONS.md、server/nginx.conf.example。
- **后续待办：** 如需进一步定位HTTPS/TLS及域名403，需要在服务器侧检查对应域名Nginx/TLS与WAF/ADM日志，并核对当前生效配置。


## 2026-11-14｜302问题

- **现象 / 需修改项：** 教学综合平台入口导入课表显示“课表接口 HTTP 302”。要求识别认证重定向、有限恢复后再取课表；失败不覆盖已有课表。
- **排查与根因：** 已从 API/STATE 地图定位 ZhengfangAuth.fetchTimetable → postTimetable。已证实 postTimetable 遇非200立即抛错，外层无kbList时的菜单重试无法处理302；CasTicket.mint/CasAuth.submit 以旧 JSESSIONID 是否存在判成功，可能把门户登录HTML误判成教务换票成功；follow 固定以门户 /cas/login 为初始相对跳转基准。截图未提供该次响应 Location，未复现真实学校账号，故“本次服务端为什么返回302”的确切原因仍待确认，不能写成已证实密码错误或会话过期。
- **踩坑 / 错误记录：** 初次 ArkTS 编译不允许直接 throw 捕获的任意类型，已改为构造 Error。独立复核另发现 mint 首次请求期间切换身份后仍会吸Cookie/继续跟随；已补失败测试再修正，原 token 贯穿 mint/follow，写Cookie前检查失效。
- **改正方法：**
  1. postTimetable 保留响应状态，Cookie按实际请求路径接收；仅有限处理同教务 /jwglxt/kbcx/ 目录内业务跳转，最多3次重定向；301/302/303后使用GET，307/308保留当前方法与表单。拒绝不受信任主机、未知业务路径、缺目标或循环跳转；HTTPS明确报当前裸连接不支持，不静默降级。
  2. fetchTimetable 遇登录/CAS跳转或200登录表单时，最多调用一次 CasTicket.mint，成功后重试一次课表；仍未建会话则提示重新登录，不再反复加载首页菜单。只有HTTP200、合法JSON且kbList为数组才返回成功；权限HTML/伪kbList文本不放行。
  3. CasTicket.follow 保留最终host/path，按真实上一跳解析相对位置并接收Cookie；mint/CasAuth须确认HTTP200、教务业务落地、非登录表单及可发送到课表路径的JSESSIONID，不能只看旧Cookie存在。课表JSON仍是最终认证/数据有效性验证。
  4. 全程检查账号代次；新增运行诊断仅输出固定跳转类别与状态码，不输出响应正文、账号、URL查询、Cookie或ticket。沿用原失败不落库和事务回滚，保留已有课表。
- **结果与验证：** 新增 tests/auth-302.cjs、tests/cas-ticket.cjs。修复前10项中9项失败，覆盖302恢复、连续跳转、旧Cookie假成功、相对跳转等；补充身份变更用例也先复现失败。修复后两文件11项通过，连同既有认证/账号用例共16项通过。最终完整构建及模拟器安装结果见下方追加证据。
- **涉及文件：** entry/src/main/ets/data/remote/auth/ZhengfangAuth.ets、CasTicket.ets、CasAuth.ets；tests/auth-302.cjs、tests/cas-ticket.cjs；API_MAP、STATE_MAP、MODULE_MAP、BUILD_MAP。
- **后续待办：** 待用户在模拟器的教学综合平台入口实际登录验证该学校响应；真实学校302的目标、账号权限、网络与端到端成功状态待确认。未使用截图账号自动登录、未读取或记录凭据、未部署服务器、未提交Git。
