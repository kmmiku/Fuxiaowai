# P1–P6 界面调整方法

日期：2026-11-14。用户确认方案后执行；补充要求为校区框右侧倒三角、日期数字15px。

## 定位与实现

先读Map/README.md、SOURCE_MAP.md、IMPLEMENTATION_LOG.md，从UI与导航定位到以下文件：

1. `src/pages/AddCoursePage.tsx`：校区自由输入改成原生select，仅长乐校区、滨海校区。沿用campus状态及保存逻辑，不批量迁移历史课程。Android由系统展示选项面板，具体呈现由WebView决定。
2. `src/styles/px-settings.css`：选择框沿用44px高度、背景、圆角；隐藏系统箭头，在右侧12px处绘制12×8px倒三角，pointer-events:none确保点击落到选择框。
3. `src/ui/TimetableIcon.tsx`：SVG currentColor圆角线条。新增为加号，导入为弯曲入框箭头，分享为右上出框箭头；面板为纸飞机、日历、钥匙。
4. `src/pages/HomePage.tsx`：替换三个顶部操作及分享面板的字符图标，保持原点击处理函数；增加操作按钮无障碍名称。顶部顺序为新增、导入、分享，末尾菜单保留。
5. `src/styles/px-cal.css`：日期字号13→15px；星期头下边框及相邻周上边框使用1px的var(--line)，兼容深色模式。保留日期红圈、周末灰字、事件圆点及网格尺寸。
6. `tools/check-ui-contract.cjs`与`Map/approved-ui-20261114.json`：对两页批准后的JSX及三份新增/调整的UI文件使用固定SHA256检查；其余页面、样式、组件继续对照f2ce3c4，保留三处已授权隐私文案例外。

## 验证与交付

- `npm run check`通过：42/42业务测试、22页UI范围检查、TypeScript与Vite构建。
- 隔离浏览器核对通过：两个校区选项及切换、顶部按钮顺序、面板三个SVG、15px日期和两种1px分割线。结果：`evidence/ui-adjustment-check.json`；截图：`ui-campus.png`、`ui-share.png`、`ui-calendar.png`。
- `tools/Start-Android.ps1 -Build`完成Web构建、Capacitor同步及assembleDebug；核实fxw后通过adb install -r覆盖安装成功，应用启动成功。未卸载、未清数据、未修改D盘参考工程或发布签名。
- 新APK：`android/app/build/outputs/apk/debug/app-debug.apk`。可见fxw已打开，等待用户验收。
- 启动截图：`evidence/boot-shot.png`。浏览器检查使用隔离空白环境，不操作真实学校账号。

用户验收：待确认。

## 首页下方卡片整合至三点菜单

- 用户确认预览，随后指定下排为联系我们、主题设置、夜间模式、检查更新。Map定位：HomePage的TableSwitcher/FunctionGrid、MenuSheet、home.css。
- 首页移除底部课表切换及功能卡片，三点菜单上方为周数range滑杆（1至学期总周数，拖动连续选择整数周）、分享、课表切换/新建/管理。复用TableSwitcher的账号课表隔离及删除、重命名流程，打开管理弹窗前关闭菜单以免遮挡。
- 下方八宫格上排为上课时间、课表设置、上课提醒、小组件；下排邮件、衣服、月亮、下载SVG线条图标。新增图标放入LineIcons；选中课表勾使用直线path及miter连接，无圆弯角，白色。
- 联系我们打开已有关于与反馈页面（显示联系邮箱），主题设置打开现有外观页，夜间模式调用updateSettings持久保存。项目没有在线更新源，检查更新如实提示当前v0.1.0及未配置在线更新服务，未虚构联网检查或最新版本结论。
- 原刷新/导入/学期/账号等入口保存在“其他功能”折叠列表；顶部导入与分享也继续可用。
- 保留既有菜单进退动画及遮罩；浅色使用参考预览的淡彩渐变，深色沿用主题token；面板限制高度并可滚动，320×640适配检查通过。
- 验证：npm run check 44/44及UI/Web构建通过；隔离浏览器八个SVG及标签、原首页卡片移除、夜间模式开关、7个旧菜单入口、新建弹窗及窄屏边界均通过。证据evidence/menu-integration-check.json。
- Android按Web构建→Capacitor同步→assembleDebug更新，adb install -r保留数据安装fxw。待用户验收；APK位于android/app/build/outputs/apk/debug/app-debug.apk。

## 周课表提示与文字统一

- 用户确认预览并要求空位减半后实施。Map定位：HomePage的nextbar、CourseBlock的cb-name/cb-line及home.css。
- HomePage移除“下节”整条提示内容，换成aria-hidden的nextbar-spacer，保留原实测24.5px的一半12.25px固定空位。
- CourseBlock将教室、教师字号复用课程名的textSize分支：当前七天周课表为9px，其他网格模式按原课程名字号自适应；课程名700字重不变，教室及教师由400略增为500，保留原颜色和透明度。
- npm run check通过44/44、22页UI批准范围检查及Web构建；隔离浏览器确认提示数量0、间距12.25px、三类9px及700/500/500字重。证据：evidence/course-text-check.json、course-text-applied.png。
- 已执行Web构建→Capacitor同步→assembleDebug，保留数据覆盖安装fxw。交付APK为android/app/build/outputs/apk/debug/app-debug.apk。

## 校区由系统列表改为底部滚轮

- 用户确认`evidence/campus-wheel-preview.png`后实施。Map定位至AddCoursePage与已有`src/ui/WheelPicker.tsx`，复用项目滚动吸附组件和wheel-sheet样式，未新增依赖。
- 校区字段由原生select改为按钮，保留原背景、44px高度、文字及右侧倒三角。点击打开底部“选择校区”面板，只有长乐校区、滨海校区两个选项，中间高亮。
- 面板使用独立草稿；点击完成提交，点击遮罩取消不改原值，重新打开按当前校区定位。完成时读取实际滚动位置并取最近一项，避免110ms滚动回调尚未触发时提交旧值。旧课程仅打开面板不会被修改。
- `npm run check`通过44/44及UI/Web构建。隔离浏览器滚动确认、两选项、再次打开位置、取消保持原值、滚动后立即确认均通过。证据`evidence/campus-wheel-check.json`及`evidence/campus-wheel-applied.png`。
- 按Web构建、Capacitor同步、Debug构建顺序更新，保留数据覆盖安装fxw供用户验收。

## 企业微信扫码与教学综合平台 Invalid base URL 修复

- 症状：教务直登成功；扫码成功后的导入及教学平台登录收尾抛出Invalid base URL。
- Map定位：学校网络在`core/zhengfang.ts`，原生门户入口在`core/portal.ts`。两种失败方式最终调用`finishPortal()`，进入`followRedirects('/xtgl/login_cas.html')`。
- 原因：request内部将相对路径补为完整教务地址，但followRedirects仍保存原始相对路径。当首个302返回时，absoluteUrl使用相对路径作为new URL的base；即使Location本身是绝对URL，也会因base无效报错。教务直登不经过此链路。
- 最小修复：followRedirects在首个请求前，按request相同规则使用ROOT补全并checkedUrl校验起始地址；后续Location继续相对于每次实际请求的完整地址解析。未改变学校目标限制、Cookie处理、直登、登录界面或账号数据。
- 证明：`tests/network.test.cjs`新增平台及扫码两个虚构响应回归，修复前2/2失败并出现Invalid URL，堆栈定位absoluteUrl/followRedirects；修复后网络8/8、npm run check完整44/44及UI/Web构建通过。测试只用虚构会话及code，未调用真实学校账号。
- 交付：按Web构建→Capacitor同步→Debug构建顺序更新APK，保留数据覆盖安装fxw。真实学校扫码确认及教学平台登录待用户在新版验收，不能将虚构响应测试等同真实登录通过。

## 底部四标签滑动效果

用户确认方案后实施：

- Map定位：`BottomTabs.tsx`负责四个导航按钮，`app.css`负责尺寸和选中样式；原先四个页面各自挂载底栏，`App.tsx`路由切换会销毁底栏。
- 将底栏提升至App的带key路由区域外，仅在校历、课程、我的成绩、我的四个主页面显示。删除各页重复底栏及导入，底栏仍在原flex布局中占原高度，保持安全区和页面空间。
- 选中背景改成独立`tabs-pill`，根据选中按钮的offsetLeft/offsetWidth/offsetTop/offsetHeight定位，使用250ms、cubic-bezier(0.22,1,0.36,1)过渡transform及width。按钮原颜色、圆角、大小及按下缩放保留。
- useLayoutEffect在首次显示时关闭过渡定位；ResizeObserver及resize事件在尺寸改变时直接对齐。四主页面之间底栏保持同一DOM，快速点击由CSS从当前动画位置接续；进入其他页面卸载，返回首次直接定位。
- 尊重prefers-reduced-motion；底栏使用navigation语义，当前按钮aria-current=page，保留原导航行为。
- 验证：npm run check通过42/42、22页批准范围检查及Web构建。隔离浏览器验证首次定位、动画中间位置、DOM持续存在、连续点击、尺寸变化、子页隐藏及返回、减少动态效果均通过；之前校区/图标/校历检查也通过。证据`evidence/tabs-slide-check.json`、`evidence/tabs-slide.png`。
- 构建同步Android后保留数据覆盖安装fxw，等待用户实际交互验收；不改发布身份或D盘工程。

## 校历预览确认后的追加调整

用户确认`evidence/calendar-preview-proposed.png`后应用：

- `px-cal.css`：星期字号9→13px，日期仍15px；日期格保持46px高度并使用border-box，上内边距9px，使28px日期圆圈中心位于格内23px处。相邻行的1px横线中心恰好是两行数字中心的中点，事件圆点仍在数字下方。
- `AcademicCalendar.tsx`：移除本月标签及仅为标签服务的日期判断。
- 更新批准的UI摘要，其他界面仍由原检查保护。
- `npm run check`通过42/42及22页UI范围检查、Web构建；隔离浏览器检查星期13px、日期15px、本月标签数量0，各周分割线中点误差均0px。证据见`evidence/ui-adjustment-check.json`及`evidence/ui-calendar.png`。
- 重新Web构建、Capacitor同步、Debug APK构建，并保留数据覆盖安装fxw。等待用户验收。

## 移除其他功能模块
用户明确要求移除三点菜单底部‘其他功能 展开’，删除MenuSheet对应折叠按钮、列表及状态，保留上方课表/周数和八项图标入口。npm run check 44/44及UI/Web构建通过；隔离浏览器确认模块数量0、主入口仍8项。证据evidence/menu-no-more.png。重新构建同步并保留数据覆盖安装fxw。

## 分享服务断连检查（尚未恢复线上）
- 用户授权检查修复后实测：系统DNS为Clash虚拟地址198.18.0.130，公共DNS取得113.45.242.182；真实地址直连及本地代理HTTPS均握手失败，TLS1.2/1.3皆ECONNRESET。HTTP入口返回403，页面标题为‘非法阻断690’，表明请求在分享API之前被阻断，具体原因需云控制台/服务器核实。没有据此断言证书过期或Node故障。
- 当前无SSH配置/环境连接入口，未执行含清空反馈动作的旧部署脚本，未覆盖线上server.js。已请求用户提供控制台入口或既有连接配置路径，不索取秘密内容。
- 客户端uploadShare将连接重置/断开及超时转成可读提示；不降低TLS校验，不绕到HTTP，不自动重传POST。新增回归先失败后通过，npm run check 45/45及UI/Web构建通过。
- 证据Map/evidence/share-connectivity.json。线上阻断未解除，不能声称口令已恢复生成。

## 分享改用用户授权的临时IP入口
- 用户说明域名备案未完成，并提供http://113.45.242.182/admin，授权暂用IP。健康检查http://113.45.242.182/healthz返回200。
- src/core/share.ts的SHARE_BASE统一改为http://113.45.242.182，生成和凭口令导入共用；Android原配置已允许HTTP，不修改学校登录及凭据链路。HTTP明文传输的临时方案已向用户说明，备案后应恢复HTTPS域名。
- 线上只新增1份虚构测试课表，成功POST生成32位口令并GET取回，课程名/教室/教师比对通过；未读取已有真实口令，未打印测试口令，未修改线上配置或历史数据。证据evidence/share-ip-roundtrip.json。
- endpoint回归RED→GREEN，npm run check 46/46及UI/Web构建通过。Web构建→Capacitor同步→Debug构建后，保留数据覆盖安装fxw。此前‘线上恢复待接入’结论已由本段IP通道实测更新；域名阻断本身尚未解除。

## 游客口令导入显示及整条消息识别
- 根因：saveCourses允许写anon命名空间，loadCourses未登录直接返回空数组；HomePage按下载课程数提示成功造成成功但空白。虚构课程复现保存成功/读取0门。
- 删除loadCourses的登录拦截，仍仅按coursesKey读取当前账号或anon；未登录主动导入、手动添加课程可显示，账号A/B/游客隔离不合并。游客持久化重载测试通过。
- extractShareCode支持完整分享消息或纯32位十六进制口令，统一小写；拒绝长串截断、无效字符和多个不同口令。输入自动提取为纯口令，点击查询预览后覆盖导入，不自动提交覆盖。
- 查询绑定账号生命周期及当前课表；输入/关闭/切换使旧请求失效，提交前复核scope，在原子事务中重新读取核对后才显示成功。
- 新回归RED→GREEN，npm run check 48/48及UI/Web构建通过；隔离浏览器虚构API响应验证整条消息识别、游客导入立即可见及刷新保留。没有读取用户真实分享口令及课表。证据evidence/guest-share-import.json及截图。
- 重新Web构建、Capacitor同步、Debug打包并保留数据覆盖安装fxw。
2026-11-15：双平台版本公告本地实现。后台新增鸿蒙版本、安卓版本栏目；platform参数隔离存储，旧无参数请求保持鸿蒙。Android接入启动/手动检查、版本忽略和HTTPS更新地址。npm run check通过；尚未部署或完成跨平台发布、模拟器与真实升级验收。不得视为最终交付。

## 2026-11-15 双平台版本发布上线与Android检测更新
- 参考鸿蒙Solution.md和UpdateCheck实现：Android“我的”次级卡片新增灰色下载线条图标“检测更新”，课程菜单检查更新与冷启动共用checkAppUpdate。原生读取真实versionCode，自动每进程一次，手动绕过版本忽略；失败不报最新版本。
- 公告弹窗显示版本、纯文字更新内容、忽略此版本、暂不更新/立即更新；UpdateLinkPlugin仅接受HTTPS，交由外部系统打开更新入口。当前方案不下载或静默安装APK。正式更新APK必须保持发布签名并递增versionCode，当前安装包build=2/version=1.1。
- 共用GET /api/app-update?platform=android|harmony；后台认证GET/PUT/DELETE /api/admin/app-update?platform=...。无参数保持原鸿蒙接口，harmony沿用app-update.json，android独立app-update-android.json；非法平台拒绝，安卓发布必须HTTPS地址。后台两个独立栏目“鸿蒙版本”“安卓版本”，编辑草稿不被轮询覆盖。
- 用户提供外部服务器连接文件授权部署，凭据仅在内存使用。在线管理资源基于实际线上源增量修改，未覆盖server.js或原D盘工程。部署备份/恢复点/哈希见evidence/dual-update-deployment.json，线上健康200、管理未认证401、跨站写403、发布与撤回验证成功，业务文件哈希保持一致。测试公告已撤回，没有保留未来版本虚假公告。
- npm run check：49/49通过、UI契约与Web构建通过。新增回归覆盖双平台隔离、旧鸿蒙请求兼容、非法平台/空请求/不安全URL、认证和撤回不影响另一端。浏览器隔离API验证双栏目切换、安卓地址输入、草稿保护；未把该替身测试称为真实在线浏览器验收。
- Web构建→Capacitor同步→Gradle Debug构建成功，fxw保留数据覆盖安装成功。真实新版发布后的下载/安装、签名升级和应用市场升级未验收；当前没有发布可下载的新版本。
2026-11-15验收补充：按用户要求将检测更新唯一入口放在网络检测与更多之间。模拟器实测原HTTPS请求失败，改用此前授权的备案期HTTP IP入口读取安卓公告，更新目标地址仍要求HTTPS。重新构建同步覆盖安装fxw，截图update-profile.png确认顺序，update-check-result.png确认点击返回“当前暂无已发布的新版本”。真实新版下载安装仍待发布后验收。

## 2026-11-15 双平台版本概览确认后实施及APK交付
- 后台软件版本/公告/编辑三个区域独立展示；新增认证GET/PUT /api/admin/app-version?platform=...，版本保存至app-version-harmony/android.json，撤回公告不删除版本。版本记录仅表示后台登记，不推断商店已上架。
- 初始登记来自已核对构建身份：鸿蒙0.1.1/1000001，Android1.1/2；更新地址尚未登记，不虚构下载链接；当前没有已发布公告。
- 原公告客户端接口保持兼容，保存软件版本与发布公告分别操作；版本保存可不填公告内容或下载链接，发布安卓公告仍必须提供HTTPS链接。编辑草稿保留，上方卡片继续更新。
- npm run check 49/49、UI契约与Web构建通过；定向回归进一步验证独立版本保存、认证、双平台隔离、撤回公告保留版本。线上备份、健康、认证、业务数据一致证据见version-summary-deployment.json。管理资源在实际线上源增量修改，server.js未变。
- 浏览器隔离API核对概览字段、空公告、保存入口及390px无横向溢出；截图version-summary-applied.png为隔离数据展示，不冒充真实在线认证浏览器截图。
- Web构建后cap sync、Gradle assembleDebug成功；APK签名v1/v2验证成功，包名保持com.fuxiaowai.timetable。交付artifacts/福小外-Android-1.1-debug.apk，摘要见android-delivery-20261115.json。未配置外部正式签名，包为Debug验收包；真实应用市场上架和发布签名升级未验证。本轮未递增软件身份或发布虚假未来公告。

## 2026-11-15 安卓0.1.1与后台版本策略
- 按用户要求将Android版本名称统一为0.1.1，versionCode由2递增至3；Gradle、npm元数据、我的与关于页同步。package保持com.fuxiaowai.timetable。
- npm run check、Web构建、cap sync、Gradle Debug成功；签名与包内身份核验通过。交付artifacts/福小外-Android-0.1.1.apk，摘要见evidence/android-011-delivery.json。为Debug验收包，无替代正式签名。
- 用户追加要求后，将后台版本更新策略写入AGENTS.md。新增软件版本content说明字段及后台展示，支持无公告时登记真实版本说明；两端后台分别回读确认安卓0.1.1/3、鸿蒙0.1.1/1000001。真实更新地址尚未就绪，未伪造下载入口或发布新公告。
- 版本策略要求今后修改版本、打包、后台对应平台登记、更新说明、回读、证据记录一起完成。源版本、市场版本、Debug构建与公告发布状态须明确。
- 部署及校验证据version-notes-deployment.json/version-notes-verified.json；原D盘工程未修改，学校账号和个人课表未操作。

## 2026-11-15 课表字号按用户最终要求调整
- Map定位：TimetableGrid.tsx的tt-period/tt-clock与home.css；课程文字位于CourseBlock.tsx，内联字号覆盖原CSS。
- 节次数字和开始时间均12px；课程名称与教室均16px/700字重，行高19px；教师继续原textSize逻辑（七天compact=9px，普通五天=12px）及500字重，行高保持原CSS。未更改列宽/课块高度或自动扩大布局。
- npm run check 49/49、UI契约及Web构建通过；build→cap sync→Gradle Debug构建成功，已保留数据覆盖安装并启动可见fxw。浏览器会话关闭，未取得本轮运行时计算字号测量，不将源码核对冒充浏览器验证。
- 本轮为用户授权字号修改，未变更版本、发布后台公告或覆盖此前已交付artifacts APK；最新验收构建位于android/app/build/outputs/apk/debug/app-debug.apk。

## 2026-11-15 居中课程块与教室编号
- 用户确认：课程名15px/700、教室15px/600，整组水平垂直居中，卡片隐藏教师、详情保留。CourseBlock使用ResizeObserver测量实际文字高度；长课块居中，溢出时顶部排列，按剩余高度分配行数。
- 教室不再固定两行。短块优先保留课名与完整教室编号，长地点不够时提取教5-103等编号；编号作为不可拆分单元，极窄列按可用宽度横向压紧以避免裁掉103，字号基准仍15px。容量不足以容纳全部课名时仍须裁切，详情保留全部原数据，不可能在固定尺寸内无限容纳文字。
- 隐藏教师仅变更渲染，不修改Course数据、导入、分享和详情。左侧时间轴保持此前12px。
- npm run check49/49、UI契约与Web构建通过；一次原有后台持久化重试测试因临时audit文件时序失败，未修改该测试，重跑通过。浏览器用一节短课与八节长课合成数据验证15px/700、15px/600、顶部/居中分支、编号完整且横纵边界内，点击详情确认完整地点和教师可见。证据centered-course-check.json。
- build→cap sync→Gradle Debug成功，保留数据覆盖安装并启动可见fxw供验收。版本未变、后台公告未发布、此前artifacts交付包未覆盖。

## 2026-11-15 纯色白字与统一对齐
- 用户确认方案后实施CourseBlock/home.css：纯色背景、白字、5px小圆角，移除左色条。保留15px课名700/教室600，教师仅详情可见。
- 取消上一版所有数字横向缩放；允许按原字形自然换行。名称使用统一最大三行占位，同高度课块名称和教室起点一致；单节短块采用一行名称与两行编号，不够时优先提取教室编号。左右3px/上下1px内边距及0px组间隙，避免标准56px短课块裁掉103。
- 浏览器合成数据实测：390px宽，短块教5-103区域clientHeight=scrollHeight=36px，字体15px且transform=none；两张476px高课块名称顶距均1px、教室顶距均55px。截图工具超时，不称截图验收通过。极小行高或极窄并排列的固定容量限制依然存在，完整信息在详情查看。
- npm run check49/49、UI契约与Web构建通过；重新构建同步并安装fxw供用户验收。未修改版本号、后台公告或历史课程数据；此前artifacts包未自动替换。

## 2026-11-15 整组居中与柔和纯色
- 用户最新要求覆盖此前统一顶部对齐：CourseBlock移除固定标题槽高度，名称与教室按实际内容高度整组垂直/水平居中；溢出的短块仍顶部安排并保留编号。保留15px/700课名、15px/600教室与白字、5px圆角，教师仍只在详情。
- 八色调淡并降低饱和度，配色与浏览器合成验证见muted-centered-course-check.json。未使用字形缩放。390px宽长块中心偏差小于0.01px，56px短块教5-103完整可见。
- npm run check49/49、UI契约及Web构建通过；build→cap sync→Gradle Debug成功并保留数据安装启动fxw供验收。未更改版本或发布公告，历史交付APK未覆盖。

## 2026-11-15 固定最小顶部留白与附件配色取样
- 用户要求每个课块顶部至少保留参考标记空位，设最小8px；长块仍整组居中，上下8px，短块顶部8px/底部0px使用剩余空间，字号仍15px/700与15px/600，行高收紧为16px以容纳编号。字形不做横纵缩放。
- 用System.Drawing对用户附件四个背景区域取样，排除白字/边框/绿色标记，按8级RGB桶统计主色。近似值#F82050/#F06880/#10C0B0/#3080F8；HSL饱和度约82–94%，明度约41–68%，属于较鲜艳纯色，并非此前的柔和低饱和方案。四种取样主色按colorIndex循环映射。精确统计见reference-palette-sample.json（截图近似不冒充设计源色）。
- 浏览器合成数据验证顶部最小8px、长块居中偏差小于0.01px、编号行盒位于56px短块边界内，15px字形无缩放。16px行高下字体scrollHeight可能包含超出行盒的字形度量，未以scrollHeight声称全部字形像素零裁切。证据course-top-padding-check.json。
- npm run check49/49、UI与Web构建通过，build→cap sync→Gradle Debug成功，保留数据安装启动fxw供验收。未变更版本或云端公告。

## 2026-11-15 完整参考配色、邻色避重及首课对齐
- 用户确认要求后提取P1八色近似主色：红#F82050、粉#F06880、青绿#10C0B0、蓝#3080F8、紫#A078F8、橙#F89010、浅蓝#2898F0、深蓝#1060B0；取样HSL数据见full-reference-palette.json。排除文字/边框，8级RGB桶主色为截图近似值，不是设计源色。
- P3裁图56×146像素，背景顶y4，首行白字顶y24，相距20截图像素。按课块显示比例估计，本项目最小顶部留白16 CSS px；不能据截图证明原应用精确vp。标题与教室维持15px/700和15px/600、16px行高，不缩放字形。
- 新courseAppearance.ts对当前实际渲染课块建立上下/左右邻接关系，随机图着色，种子在网格生命周期内保持稳定，拒绝邻块同色。不修改课程数据colorIndex、不跨账号保存配色。超高邻接数时补充不同HSL色，避免颜色不足。
- TimetableGrid标记每天第一门非幽灵普通课程，强制名称顶距16px；跨度六节及以上为超长块，不参与首课对齐，继续整组居中。同开始节次首课全局平行；开始节次不同仍保留真实时间轴位置，仅统一各自顶距，不将课程移出所属时段。
- 所有课块顶部最小16px。为满足15px字体及完整教5-103编号，网格实际单节行高下限68px，课程块64px；不改用户已保存cellHeight值。低于此下限的设置以此阅读下限渲染。教师和完整原始地点仍在详情中。
- 新增两项颜色/邻接回归，20组种子覆盖左右/上下/长块邻接及同seed稳定性；npm run check51/51、UI与Web构建通过。浏览器七天合成首课实测顶距[16,16,16,16,222,16,16]，周五八节长课保持居中；编号保留，邻色不同。证据reference-course-final-check.json。
- build→cap sync→Gradle Debug成功，保留数据覆盖安装fxw供验收。本轮不改版本、后台公告和既有artifacts包。

## 2026-11-15 指定HSL调整
- 按用户要求直接应用：红hsl(346.6667,88%,55%)、橙hsl(33.1034,90%,60%)、深蓝hsl(210,80%,45%)，色相由原HEX计算保留。仅覆盖调色板对应三色，其余颜色/随机邻接避重/课程布局不变。
- 实际代码src/core/courseAppearance.ts，覆盖记录evidence/palette-hsl-adjustment.json。原full-reference-palette.json继续作为附件原始取样证据，不伪改原始取样值。
- npm run check51/51、UI契约及Web构建通过；Web构建→cap sync→Gradle Debug成功，保留数据安装并启动可见fxw供验收。本轮未修改版本、后台公告或artifacts历史交付包。

## 2026-11-15 首课固定色与颜色编辑修复
- 用户要求周一首课红、周二粉、周三青绿、周四浅蓝、周五紫色；另明确回答首课默认固定但手动选色优先。周末继续自动配色。配色与超长块对齐规则独立，周五全天课也采用紫色默认。
- 原因：随机渲染颜色覆盖保存的colorIndex，选色器仍使用旧浅色配色。courseAppearance增加preferredCourseColor与pinnedColor预着色；优先手动、其次首课固定、最后自动邻接避重。手动相邻同色尊重用户，不强制改色。备用配色也仅限八种实际调色板色，不再额外生成HSL。
- Course新增可选colorOverride布尔字段，AddCoursePage选择色块时标记true，保存/校验/分享导入回读保留；旧课程没有该字段继续自动默认，不迁移覆盖旧记录。手动颜色仅接受0–7，旧自动colorIndex仍兼容0–255。
- 选色器直接使用COURSE_PALETTE实色，详情/日列表强调色同步同一索引配色。其他页面结构、字号、留白不变。
- 新增回归验证五日默认、手动覆盖优先、20组seed固定色不变、手动标记回读和非法颜色拒绝。npm run check53/53、UI契约和Web构建通过。浏览器合成课表实际点击周一课程→编辑→橙色→保存→刷新，确认colorIndex5/colorOverridetrue且橙色保持；选色器八种颜色与实际调色板一致。证据fixed-first-manual-color-check.json。
- build→cap sync→Gradle Debug成功，保留数据安装启动fxw供验收。本轮未变更版本、公告或既有artifacts交付包。

## 2026-11-15 翻周结束颜色跳变与一次性随机
- 沿Map定位TimetableGrid原有useRef(Math.random())种子及appearance useMemo：当前/前/后周是独立网格；翻动结束重挂载会生成不同种子，且可见周课程集合改变也会改变图着色。原来“同一网格生命周期稳定”并不等于翻周稳定，这是确认的源码机制。
- 调整为store.saveCourses对整张课表进行一次自动配色，新增可选autoColorIndex持久字段；已有课表loadCourses在首次显示前原子补齐一次，账号/课表隔离沿用原课程键。已有自动色记录直接返回，不再随机；重复保存相同id/name/日期节次的课程沿用旧自动色。手动colorOverride继续优先，不改变手动选择。
- TimetableGrid移除Math.random与assignCourseColors调用，预渲染的前/当前/后周直接读取storedCourseColor；不在拖动或动画结束时写颜色。appState同步/导入/新增/编辑后读取已分配课程再发布，避免首次渲染fallback后变色。
- 所有自动颜色基于整张课表分配并冻结，而非各周重新计算首课/邻接；因此不同周课程集合变化不会改已分配颜色。新增课程仅为缺失色分配，不重排已有颜色。极端情况下新邻接或用户手动同色可能产生重复，稳定/手动选择优先。可选字段随原校验/分享/导入保留，旧数据不清空。
- 选色器编辑初值读取已保存自动色（手动标记为true时读取手动色），与已渲染颜色一致。未更改课程布局或动画参数。
- 新增三项回归覆盖整表冻结/新增不重排、加载/重复保存/重启/账号隔离、旧数据首次持久迁移；npm run check56/56、UI/Web通过。浏览器合成数据实际touch翻动第11到12周，颜色数组完全一致，刷新后仍一致，三个预加载网格也一致。证据flip-color-browser-check.json；未用无效的随机调用计数器声称运行时零调用。
- build→cap sync→Gradle Debug构建成功并保留数据安装启动fxw；按用户要求重新打包artifacts/福小外-Android-0.1.1.apk，包名和versionName=0.1.1/versionCode3核验、签名验证通过，摘要flip-color-apk-delivery.json。本轮仍为Debug验收包，未生成替代发布签名。
- 后台安卓0.1.1版本说明追加本次颜色稳定修复，保持版本代码3，回读通过；仅更新说明，未发布缺正式下载地址的新公告。备份与结果见flip-color-backend-notes.json。鸿蒙未修改。
