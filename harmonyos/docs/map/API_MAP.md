# API 地图

更新日期：2026-11-14。静态源码核对，未请求学校或生产服务；网络可用性、生产实际目录及配置均待确认。

导航：[总览](README.md) · [模块](MODULE_MAP.md) · [状态](STATE_MAP.md) · [数据库](DATABASE_MAP.md) · [构建](BUILD_MAP.md)。

## 传输与认证

[HttpClient](../../entry/src/main/ets/network/http/HttpClient.ets).get/postForm/getBytes 使用 @ohos.net.http，encodeForm逐字段编码；[CookieJar](../../entry/src/main/ets/network/http/CookieJar.ets) 按host/path/secure选择Cookie。[RawHttp](../../entry/src/main/ets/network/http/RawHttp.ets).get/postForm 是端口80的单跳TCP HTTP，拒绝HTTPS；保留Location/Set-Cookie，支持Content-Length/chunked及gzip/deflate，原始及解压响应上限8MiB。学校portal/jw会话、公开分享反馈、后台Basic Auth是三种独立作用域；本文不列凭据或票据值。

## 学校接口与消费者

来源：[ZhengfangAuth](../../entry/src/main/ets/data/remote/auth/ZhengfangAuth.ets)、[CasAuth](../../entry/src/main/ets/data/remote/auth/CasAuth.ets)、[CasTicket](../../entry/src/main/ets/data/remote/auth/CasTicket.ets)、[WecomQrLogin](../../entry/src/main/ets/data/remote/auth/WecomQrLogin.ets)。jw基址为http://jw.fzfu.edu.cn/jwglxt，portal基址为http://portal.fzfu.edu.cn；远端处理器不在仓库。

| 方法、路径 | 函数、输入、响应 |
| --- | --- |
| GET jw /xtgl/login_slogin.html；POST同路径 | ZhengfangAuth.loginDirect：GET HTML提取csrftoken；POST表单yhm/mm（RSA密文）/csrftoken/language/mmsfjm/dlsfbxyzm/yzcskz；HTML或跳转判断登录/验证码 |
| GET jw /xtgl/login_getPublicKey.html?time=<timestamp> | loginDirect；JSON modulus/exponent，RsaPublicKey.encrypt |
| GET jw /xtgl/login_cas.html | CasSession.prepare/reopen入口、ZhengfangAuth.afterCas桥接；302及Cookie |
| GET jw /xtgl/index_initMenu.html | 历史桥接探测；fetchTimetable已移除加载菜单重试，改为认证失效时有限换票 |
| GET portal /cas/login?service=<encoded service> | CasSession.loadFlow、CasTicket.mint；HTML execution及Location票据 |
| GET portal /cas/v2/getPubKey?t=<timestamp> | CasSession.loadKey；JSON modulus/exponent |
| GET portal /cas/v2/getKaptchaStatus | casNeedKaptcha；body包含true表示需验证码 |
| GET portal /cas/kaptcha（时间戳防缓存） | fetchKaptchaImage、refreshCaptcha；二进制验证码，刷新改变会话答案 |
| POST portal /cas/login?v=<timestamp> | CasSession.submit走RawHttp；表单username/password（casEncrypt）/authcode/execution/_eventId/rememberMe；CasTicket.follow逐跳接Cookie |
| GET jw /kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default | CasTicket.mint的JW_TIMETABLE_SERVICE；备用JW_CAS_LANDING为jw /xtgl/login_cas.html |
| POST jw /kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151&su=<encoded user> | postTimetable/fetchTimetable，RawHttp；表单xnm/xqm/kzlx；JSON kbList/xsxx |
| POST jw /cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005 | fetchGradePage/fetchGrades，RawHttp；xnm/xqm/_search/nd/queryModel.showCount/queryModel.currentPage/queryModel.sortName/queryModel.sortOrder/time；100条/页、最多100页，消费items/total/records/currentPage |
| POST jw /kwgl/kscx_cxXsksxxIndex.html?doType=query&gnmkdm=N358105 | fetchExams，RawHttp；上述分页字段加ksmcdmb_id/kch/kc/kskc/kssj/cxbj/fxbj；currentPage=1、showCount=100，没有成绩式分页循环 |
| GET jw /kwgl/kscx_cxXsksxxIndex.html?gnmkdm=N358105 | EXAM_PAGE_URL，经ExamWebPage WebView打开并注入教务Cookie |
| GET https://open.work.weixin.qq.com/wwopen/sso/qrConnect | WecomQrLogin.start；appid/agentid/redirect_uri/state查询字段，HTML取key；配置标识值不抄录 |
| GET https://open.work.weixin.qq.com/wwopen/sso/qrImg?key=<key> | start取二维码二进制 |
| GET https://open.work.weixin.qq.com/wwopen/sso/l/qrConnect?key=<key> | poll长轮询，客户端30s超时；JSONP解析status/auth_code |
| GET http://portal.fzfu.edu.cn/cas/login?client_name=QyWeiXinClient&code=<code>&state=STATE | exchange实际走RawHttp；声明的CAS_QR_CALLBACK/redirect_uri为https，但实际换票是HTTP；后续mint/follow |

[Locator](../../entry/src/main/ets/app/di/ServiceLocator.ets).syncAndSave/syncWithCaptcha/syncWithQr → [FuwaiTimetableSource](../../entry/src/main/ets/data/remote/FuwaiTimetableSource.ets).fetch/resumeCaptcha/qrLogin → collect → fetchTimetable → parseTimetable → SyncTimetable/仓储写库；SchoolTraffic串行调度。[GradePage](../../entry/src/main/ets/pages/GradePage.ets) → Locator.syncGrades → [GradeSync.quiet/collect](../../entry/src/main/ets/data/remote/GradeSync.ets) → fetchGrades → GradeAdapter.parse。[ExamPage](../../entry/src/main/ets/pages/ExamPage.ets) → fetchExams → ExamAdapter.parse；[ExamWebPage](../../entry/src/main/ets/pages/ExamWebPage.ets)管理WebView Cookie。

消费schema（学校完整服务端schema未知）：

- [FuwaiAdapter.parseTimetable](../../entry/src/main/ets/data/remote/parser/FuwaiAdapter.ets)：{kbList?:[{kch,kcmc,xm,cdmc,xqmc,xqj,jcs,zcd,jxb_id,kclbmc,kcxz}],xsxx?:{XM,XH,BJMC,ZYMC,XNMC,XQMMC}}；原始字段为可选string；返回courses/student/dropped，按课程/星期/节次/周次去重。
- [GradeAdapter.parse](../../entry/src/main/ets/data/remote/parser/GradeAdapter.ets)：{items?:[{kcmc,kch,cj,bfzcj,jd,xf,kclbmc,kcxzmc,jsxm,xnm,xqm}],totalResult?:number}；item字段可选string，文字成绩保留。
- [ExamAdapter.parse](../../entry/src/main/ets/data/remote/parser/ExamAdapter.ets)：{items?:[{kcmc,kch,kssj,cdmc,zwh,ksfs,ksmc,xnm,xqm}],totalResult?:number}；item字段可选string，时间经领域模型解析。

## App与自建服务

[ShareApi](../../entry/src/main/ets/data/remote/ShareApi.ets)的SHARE_BASE为http://113.45.242.182（分享），FEEDBACK_BASE为https://fuxiaowai.xyz（反馈），独立@ohos.net.http请求；[Index](../../entry/src/main/ets/pages/Index.ets)调用uploadShare/fetchShare；处理端是[server.js](../../server/server.js)的http.createServer路由闭包（未拆命名控制器）。

[download-center/server.js](../../server/download-center/server.js) 是独立只读静态服务，默认监听 `0.0.0.0:18080`，仅 `GET/HEAD /`、`/index.html`、`/icon.png`、`/android-logo.jpg` 和 `/harmony-logo.jpg`；其他路径404、其他方法405。页面是 [download-center/index.html](../../server/download-center/index.html)，公网访问形式 `http://<VPS公网IP>:18080/`；Android 与 HarmonyOS 按钮分别直达用户提供的蓝奏云页面并附 `pwd` 查询参数，提取码在页面明示；HarmonyOS 卡片提示用户将下载文件后缀改为 `.hap` 后安装。蓝奏云网页是否原生据该参数自动填码未确认。两个平台标志取自用户提供的左右并列图，经裁切为独立 JPEG 静态资源。该服务无数据库、登录或指向分享接口的调用。2026-11-16 更新后通过 SFTP 读回确认两条链接、`.hap` 提示和平台图标资源；本地/VPS `server.js`、`index.html`、两个 JPEG 的 SHA-256 均匹配，下载服务与原分享服务均 active。先前外网探测代理返回502、直连无HTTP响应，其他网络可达性及云安全组/备案影响待确认。

| 接口 | 契约 |
| --- | --- |
| POST /api/share | JSON {courses,periods,term,week}；200 {ok:true,code,expiresAt}。validShare要求courses 1..800；name非空≤300；id/teacher/room/campus可选≤300；weekday1..7，start/endPeriod1..48且有序，weeks≤60项且每项1..60，colorIndex可选0..255。term可选≤200，week可选0..60；periods可选≤48，index1..48、start/end为HH:mm；readBody上限64KiB |
| GET /api/share/:code | 32位hex（转小写）；200 {ok:true,code,createdAt,term,week,courses,periods}；400格式错、404不存在/过期、500损坏。fetchShare → validateSnapshot → toLocalCourses；客户端更严格：id唯一、weeks非空、period索引唯一/end>start，缺teacher/campus/colorIndex补值 |
| POST /api/feedback | JSON {text,contact,images,app,version,device,requestId?}；200 {ok:true,id}。text trim后≤2000，文字或图至少一项；最多3张dataURL，jpeg/jpg/png/webp，各≤1.5MiB，body≤4MiB；contact/app/version/device截断120/32/32/120 |

反馈调用：[FeedbackPage](../../entry/src/main/ets/pages/FeedbackPage.ets) → [FeedbackDelivery.send/deliver/flush](../../entry/src/main/ets/data/remote/FeedbackDelivery.ets) → uploadFeedback。图片重新编码JPEG≤900000字节；本地id复用为可选requestId及X-FXW-Request-ID。服务端只用header去重；旧客户端不带header仍能提交。header合法格式8..128位字母数字/下划线/横线；同IP+requestId哈希去重24h，重启可从已存JSON恢复成功结果。IP改变/过期可能再次创建。

429解析JSON retryAfter和Retry-After（秒或HTTP日期），默认1800秒，FeedbackStore.defer持久化下次时间；flush按队列补发，失败停止，保留未发送内容。503的Retry-After当前客户端作为普通HTTP失败处理。错误通常{ok:false,msg,retryAfter?}。

## 全部服务端路由

后台调用端为[dashboard.html](../../server/dashboard.html)同源fetch；checkAuth/needAuth用FXW_ADMIN_USER/FXW_ADMIN_PASS独立Basic Auth，401包含WWW-Authenticate。未明确限制方法的分支按源码标注，不能当成仅GET。

| 路径/方法约束 | 处理及响应 |
| --- | --- |
| /favicon.ico（不限方法） | 204 |
| /healthz（不限方法） | 200 text/plain ok |
| /、/index.html、/privacy.html、/terms.html、/style.css、/screens/*、/img/*（不限方法） | siteFile从server/site取文件，禁..及白名单外字符；缺文件404，可gzip，缓存300s；位于限流前 |
| /shot/*（不限方法） | shotFile → serveStatic，ROOT/release/shot；Range 206/416，缓存3600s；限流前 |
| /download/*（不限方法） | 固定404；dlFile/releasePage有定义但无路由挂载，不能视为可用下载接口 |
| /admin、/admin/（不限方法） | Basic；dashboard HTML/gzip/no-store |
| /api/admin/stats（不限方法） | Basic；{ok,time,uptimeSec,host:{hostname,cores,load1,load5,load15},cpu:{percent},mem:{total,free,used,percent},disk:{total,used,avail,percent},net:{rxBps,txBps},proc:{rss,heap},tickets:{count,bytes,today,oldest,newest,now},feedback:{total,today,unread,newest},limits:{ratePerMin,maxBody,ttlDays,maxCourses}}；sampleCpu/sampleNet/diskUsage/ticketStats/fbStats |
| GET /api/admin/tickets?limit= | Basic；limit默认50/范围1..200；{ok,total,rows:[{code,size,mtime,term,week,count,createdAt}]}倒序 |
| DELETE /api/admin/tickets/:code | Basic；validCode/ticketPath/unlink；200{ok:true}、400非法、404缺失 |
| GET /api/admin/feedback?offset=&limit= | Basic；offset默认0/≥0，limit默认50/1..100；listFeedback → {ok,total,offset,limit,rows:[{id,createdAt,text,contact,app,version,device,ip,read,images}]}；images转后台图片URL |
| GET /api/admin/feedback/img/:name | Basic；16hex_1..2位序号.jpeg/png/webp；200图片/private max-age3600，400非法，404缺失 |
| POST /api/admin/feedback/read | Basic；{ids:[...]}至多100，非法/损坏JSON当空列表，逐项validId；{ok:true,updated} |
| DELETE /api/admin/feedback/:id | Basic；validId，删JSON和所列合法图片；缺失也200{ok:true} |
| 其他路径/不匹配方法 | text/plain 404；未知/api/admin/*先认证再404 |

公开share/feedback三路见上表，同样位于server路由闭包。总限流1200/IP/分钟；share写120/IP/分钟、全局600；feedback默认20/IP/分钟、全局100，429/Retry-After=60。FXW_MAX_ACTIVE_WRITES默认8/范围1..32，所有body写入共享并发门槛，满时503/Retry-After=5。容量由FXW_MIN_FREE_BYTES/FXW_MAX_TICKETS/FXW_MAX_FEEDBACK控制。

send/json默认no-store/nosniff，>256字节可gzip，异常500；cached通常30s、disk5s，invalidate仅清列表，计数可能短暂滞后。[nginx.conf.example](../../server/nginx.conf.example)为4m body、35s代理超时、覆盖X-FXW-Client-IP模板；仅FXW_TRUST_PROXY开启且peer loopback时信任合法该header。[fxw.env.example](../../server/fxw.env.example)是变量模板，不证明生产实际应用。

## 更新触发

## 2026-11-14 后台 v2 增量

实现：[admin-console.js](../../server/admin-console.js) 的 `createAdminConsole` → `observe` / `handle`；[admin.js](../../server/admin.js) 同源调用。`server.js` 在原路由之前接入，公开分享与反馈接口契约不变。工作区原有其他加固内容没有随本次线上增量部署。

| 方法与路径 | 参数与响应 | 前端调用 |
| --- | --- | --- |
| GET /admin/admin.js、/admin/admin.css | Basic Auth；no-store；管理 JS/CSS | dashboard.html |
| POST /api/admin/inspect | `{code}`，32位hex；`{ok,code,status:valid/expired/invalid/missing,createdAt?,expiresAt?,term?,week?,count?,checks?,warnings?,message?}`；校验对齐 ShareApi.validateSnapshot，文件只读 | inspectCode → renderInspection |
| GET /api/admin/ticket-search | q（口令/学期，≤200字符）、status（unchecked/expired/invalid）、offset、limit（1..100，默认20）；`{ok,total,allTotal,offset,limit,rows:[{code,createdAt,expiresAt,term,week,count,size,status}]}` | loadTickets |
| GET /api/admin/probes | `{ok,sampledAt,uptimeSec,host:{hostname,cores,load},metrics:{cpu,mem,disk,net,proc:{rss,heap,eventLoopMs}},health,external,storageError}`；health/external 含 state、checkedAt、status?/latencyMs?，external 另含 certificateExpiresAt? | loadProbes |
| GET /api/admin/alerts | `{ok,time,sampledAt,storageError,active,rows,thresholds}`；行含 id/time/lastSeen/key/title/detail/level/state/resolvedAt?/endedAt?；最多200条 | loadAlerts |
| GET /api/admin/audit | `{ok,time,storageError,retentionDays:30,rows:[{id,time,actor,action,target,status}]}`；target为SHA256前12位，非原口令；最多200条 | loadAudit |

全部新增路由先 checkAuth；方法错误405。所有 `/api/admin/*` 写请求由 `sameOrigin` 拒绝跨站与跨协议 Origin；固定公网 Origin 默认 https://fuxiaowai.xyz，可用 FXW_ADMIN_ORIGIN 配置。无 Origin 的已认证命令行请求兼容。反馈已读/删除、口令删除仍调用原接口并被 observe 审计。审核记录不包含认证头、正文或联系方式。

URL、表单、认证/重定向、parser字段、ShareApi/FeedbackDelivery、server路由/配额、dashboard或代理模板变更时更新；同步[数据库](DATABASE_MAP.md)及[状态](STATE_MAP.md)。依据为上述实际源码；没有包含真实密码、Cookie、票据、密钥或配置凭据值。


## 2026-11-14｜分享直连 IP

ShareApi.SHARE_BASE 改为 `http://113.45.242.182`，仅 uploadShare/fetchShare 使用；FEEDBACK_BASE 保持 `https://fuxiaowai.xyz`，uploadFeedback 使用该 HTTPS 地址。上传响应 code 必须是32位hex并归一小写。Index.makeShareCode 只在远端上传成功且身份/课表/页面代次仍有效时生成 ticketMessage；不再调用 createTicket 生成离线占位或保存完整课表副本。服务器源码/部署未修改。


本轮分享/游客覆盖的构建、测试与双模拟器证据见 [分享与游客验收记录](../share-guest-20261114.md)。


## 2026-11-14｜302问题

ZhengfangAuth.postTimetable 返回 RawResponse，识别认证跳转并有限处理同jw的/kbcx/业务跳转（最多3，307/308保留方法/表单）；fetchTimetable 在认证重定向或200登录表单时仅一次mint+课表重试，不再加载首页菜单。HTTP200且合法JSON/kbList数组才放行。CasTicket.follow 返回 TicketLanding（host/path），支持实际origin/priorPath/token，最多6跳；resolveTarget只信任portal/jw且不降级HTTPS；mint/CasAuth.submit以有效业务落地和可发送课表Cookie判断。诊断只输出状态及固定类别，真实学校响应待确认。

问题证据与验证边界见 [Solution.md 的302问题](../../Solution.md)。

## 2026-11-15｜应用更新
UpdateCheck.checkForUpdate(context, uiContext, automatic) 调用 AppGalleryKit.updateManager.checkAppUpdate，仅市场判定有新版才获取 HTTPS /api/app-update。GET返回{ok,release:null|{versionCode,versionName,content,publishedAt}}；后台 GET/PUT/DELETE /api/admin/app-update 复用 Basic 认证及写操作 sameOrigin。PUT 校验正整数versionCode、数字版本名称与≤2500字内容，临时文件原子rename。DELETE撤回。无公告/读取失败时使用通用说明且不提供按版本忽略。立即更新调用showUpdateDialog。线上部署与真实市场升级待确认。

2026-11-15后续：版本发布后台已实际增量部署四个管理文件，发布/撤回/认证/同源校验通过；服务器经公网域名HTTPS的健康和公告接口均200，本机Windows直连TLS握手异常待确认。备份及回滚见根Solution.md“更新后台线上部署验收”。tools/deploy-app-update.py是有副作用的部署脚本，不自动运行。真实商店升级仍待确认。

## 2026-11-15 登录去重统计
Locator.persist成功且AccountScope有效 → UserMetrics.reportLoginMetric → POST /api/user-metrics/login，JSON仅studentId，当前HTTP IP、注释HTTPS域名；5秒超时、无队列无请求日志。server/user-metrics.js内存HMAC、服务器密钥、摘要原子去重，不存原学号。GET /api/admin/users需后台认证，只返回total/daily(近30日北京时间)/users(序号及首次日期)，offset分页50。HTTP传输与客户端上报可伪造边界见根Solution.md；不等于学校认证人数证明。

2026-11-15更新：/api/admin/users.daily现在固定7日；users仅userId(两位起递增字符串)/registeredAt(本地格式时间，历史仅日期)，移除note。

2026-11-16工作台：成绩/考试为原生内部页；自主选课JW N253512入口，四六级passport.neea.edu.cn/CETLogin与iam.neea.edu.cn/login.html入口，官网www.fzfu.com。WebView仅JW精确域注入教务Cookie，其他站点独立认证。接口真实业务验收待确认，不恢复安卓已删除的其他25项服务或附加SSO。

2026-11-16工作台：官网https://www.fzfu.com/与考试院passport.neea.edu.cn/CETLogin、iam.neea.edu.cn/login.html使用自身网页会话；自主选课JW /jwglxt/xsxk/zzxkyzb_cxZzxkYzbIndex.html?gnmkdm=N253512&layout=default仅该入口注入现有JW Cookie。ServiceWebPage限制初始入口；未核实所有远端跳转或真实业务提交。考试仍fetchExams(xnm,xqm)单页100，未新增网络认证协议。

2026-11-16 联网北京时间：ClockSync仅请求https://www.fzfu.com/ HEAD，保持TLS验证，不发送Cookie/账号。接受200且有效Date，拒绝Age非0与超10秒请求；失败静默。官网本机已验证Date，模拟器结果见Solution。

2026-11-16：下载页两个平台图标改为 HTML 内嵌 JPEG data URI，浏览器无需单独请求图片路径；图片内容沿用用户提供的左右图标裁切。

2026-11-16：Android 与 HarmonyOS 下载入口更新为用户本轮提供的新链接；静态 HTML 已同步 VPS，VPS 本机 HTTP 返回内容与本地 SHA-256 一致，两个链接及内嵌图标标记已核对。

2026-11-16：下载页在两张下载卡片之后、第三方提示之前新增 QQ 反馈卡片；用户提供的二维码随 HTML 内嵌，提供保存图片和复制群号（HTTP 下使用 execCommand 后备，失败显示手动复制提示）。已部署并确认 VPS 本机 HTTP 返回与本地 HTML 哈希一致。浏览器交互结果另见实际验收，未验证移动端 QQ 识别及加群。

2026-11-16：反馈卡片的保存二维码按钮替换为用户提供的 QQ 加群链接按钮，新窗口打开；保留内嵌二维码和复制群号。已部署，VPS 本机 HTTP 页面与本地哈希一致；真实 QQ 唤起及加群结果待用户验收。地图不记录链接中的授权参数。

2026-11-17：鸿蒙下载入口更新为用户本轮提供的新蓝奏云链接，保留提取码参数；已同步 VPS，VPS 本机 HTTP 返回与本地 HTML 哈希一致，安卓入口保持原值。
