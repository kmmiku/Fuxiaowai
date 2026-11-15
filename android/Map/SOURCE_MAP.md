# 当前源码与实施状态

更新：2026-11-14。本工程基于基线提交 `f2ce3c4` 的 Android 源码，在隔离副本中实施改造；上游基线保持原样。仓库内不包含 node_modules、构建输出、签名材料、真实 keystore.properties/local.properties 及临时探测脚本，依赖通过 `npm ci` 安装。

基线提交：`f2ce3c4`。分支：`codex/compat-hardening`。该提交包含原Android源码和先前Map文档。后端基于同日鸿蒙工作区server代码的独立副本，不代表生产版本；未部署。

|职责|Android实际落点|
|---|---|
|UI与导航|src/pages、src/components、src/styles；src/App.tsx、core/router.ts|
|数据/原子性|core/store.ts、persistence.ts、validation.ts；原版是localStorage，不存在Android RDB数据库可迁移|
|账号/任务|core/accountScope.ts、appState.tsx、timetableSync.ts；LoginPage/HomePage/GradePage/ExamPage/TermPage调用处护栏|
|凭据|core/secrets.ts；原生SecretVault.java、SecretChromeClient.java；公开同步Store调用保持同步|
|学期|core/termStore.ts、semester.ts；沿用原2026-08-31/20周配置并标注legacy来源，不按月份猜新学期|
|成绩|core/gradeStore.ts；zhengfang.ts的分页、结构和登录失效识别|
|反馈|core/feedback.ts、feedbackDelivery.ts、store.ts；FeedbackPage只变提交/重试逻辑与错误文字|
|清理|core/cleanup.ts；AccountPage、PersonalInfoPage、PrivacyDocPage共用；ProfilePage清缓存仅删fxw_tmp_|
|系统对象|core/remind.ts、calendar.ts、widget.ts；原生CalendarPlugin.java|
|学校网络|core/zhengfang.ts、cookieJar.ts、portal.ts；保留CapacitorHttp及学校HTTP链路，不套用鸿蒙RawHttp文件|
|共享后端隔离副本|server/server.js、admin-console.js、admin.js/admin.css/dashboard.html、site；server/package.json固定CommonJS|
|测试|tests/*.test.cjs；Android CompatibilityTest.java；Map/evidence截图|

## 主要工程决策

1. Android课程存储原本就是“每账号/每课表一个JSON数组”，同ID跨表天然隔离；不引入额外SQL或伪造数据库主键迁移。单键替换保留原子性，多键操作使用持久undo日志，启动恢复；对外Course.id保持原值。
2. React状态更新器内移除持久化副作用，先同步完成存储事务，再发布状态，避免StrictMode重复执行和存储失败后UI谎报成功。
3. 同步仍整表覆盖；保存最近一次旧快照，包含课程、学期、节次，可由内部restoreLastTimetable恢复。未增加UI入口或冲突合并。
4. Android保留minSdk22。23+使用Keystore AES-GCM；22使用Keystore RSA包装随机AES密钥，不写明文新密码。同步安全桥使用onJsPrompt的调用来源URL验证，只接受应用https://localhost来源；不引入无法验证调用帧来源的addJavascriptInterface。
5. 凭据迁移不能加密/解密验证时保留既有明文以便重试；已加密数据因密钥不可用时保留密文和账号元数据，允许读取课表并重新验证身份，不静默降级写明文。普通浏览器预览只在内存保留新秘密，不等同Android安全存储。
6. 后端保留Node和JSON；新幂等记录使用稳定ID散列+内容指纹，兼容旧记录同IP重试。新增termMetadata为可选扩展，原客户端忽略即可；原正常响应字段不删改。
7. 外部系统清理没有跨存储事务：失败继续其他步骤、保留待重试清单、明确提示；历史版本没有登记归属的日历事件不能安全批量删除。

## 验证边界（不能标为全部正式验收）

- 已有自动化回归与独立Android34测试模拟器验证；尚无真实学校账号的三种登录/验证码/完整业务验证，不能证明学校接口没有变化。
- 学期默认日期沿用原配置，本次已从学校官网第一学期校历图核对2026-08-31/20周一致；未知新学期仍需核验配置，不能承诺自动识别所有学校学期。成绩范围优先使用账号年级与已有缓存，未知时有8学年回溯边界；未得到学校完整学期目录的证明。HTTPS公开入口与校历核验结果见VERIFICATION_REPORT。
- CapacitorHttp原生通道提供连接/读取超时及底层分块/压缩处理；本轮补目标限制、响应发布前长度、重定向与Cookie。失效任务停止后续使用，但不宣称能物理取消已发出的原生HTTP请求或在原生读取前限制解压内存。替换底层需要学校样本验证后另行推进。
- 只构建并测试Debug包，未重新生成发布签名，没有证明正式签名覆盖升级或应用商店受理；正式构建必须显式传入原签名材料。
- 后端仅在临时数据根和本机端口测试；生产旧客户端、真实历史数据迁移/备份恢复、磁盘断电、校园共享出口负载仍需发布门禁验证。不得将源码完成等同已上线。

## 应用更新（2026-11-15）
- src/core/appUpdate.ts：原生版本读取、平台公告查询、自动/手动去重、公告弹窗及忽略版本；ProfilePage/HomePage/App共用。UpdateLinkPlugin.java：HTTPS外部系统打开。
- server/admin-console.js：platform隔离公告读写；server/admin.js/dashboard.html：双栏目。实际增量部署资源与恢复点见evidence/dual-update-deployment.json。旧无参数接口保留鸿蒙语义。

- 版本概览：admin-console.js认证app-version读写独立记录，admin.js双卡片展示与草稿保护；公告撤回不清版本。线上最新部署证据version-summary-deployment.json。

- 软件版本记录新增content真实更新说明，独立于公告发布；AGENTS.md为版本更新/打包/后台同步策略入口。Android当前0.1.1/code3。

- 2026-11-15字体：home.css时间轴12px；CourseBlock.tsx课名/教室16px/700/19px行高，教师模式字号与500字重保留。

- 课程块新布局：CourseBlock.tsx测量名称/地点/编号并分配行数；home.css .cb-centered/.cb-measures/.cb-number控制15px字体、居中、不可拆分编号；教师仅详情显示。

- 最新课块：CourseBlock.tsx纯色白字与固定标题槽，home.css上下1px/左右3px及固定15px行高18px；取消数字压缩，详情保留完整数据。solid-course-check.json记录实测。

- 最新CourseBlock改为实际内容整组居中（替代固定标题槽），柔和八色；短块保留编号。验证muted-centered-course-check.json。

- 最新课块最小顶部8px、字号15px/行高16px；CourseBlock使用附件取样红粉青蓝四主色。色彩统计reference-palette-sample.json，几何证据course-top-padding-check.json。

- courseAppearance.ts：八色取样调色板、几何邻接与seed稳定随机图着色；TimetableGrid.tsx首课标记/六节以上豁免/最小68px行高；CourseBlock/home.css统一16px顶部留白。最新证据reference-course-final-check.json。

- courseAppearance.ts调色板红/橙/深蓝现为用户指定HSL；精确值见palette-hsl-adjustment.json，其余保留截图取样色。

- 配色优先级：courseAppearance.preferredCourseColor（手动>首课星期默认>自动），assignCourseColors预置固定色；types/validation保留colorOverride，AddCoursePage八色直接选用。证据fixed-first-manual-color-check.json。

- 最新配色生命周期：store.loadCourses/saveCourses→courseAppearance.freezeCourseColors→持久autoColorIndex；appState加载已分配列表发布；TimetableGrid.storedCourseColor只读，不再按周random。types/validation保留autoColorIndex，可选兼容旧数据。flip-color-browser-check.json与flip-color-apk-delivery.json记录验收。
