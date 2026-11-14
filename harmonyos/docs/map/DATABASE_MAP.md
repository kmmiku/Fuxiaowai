# 数据库与持久化地图

更新日期：2026-11-14。静态源码核对；没有打开用户数据库或生产数据，没有构建、测试或网络验证。设备绝对沙箱目录、生产FXW_ROOT及实际留存情况待确认。

导航：[总览](README.md) · [API](API_MAP.md) · [模块](MODULE_MAP.md) · [状态](STATE_MAP.md) · [构建](BUILD_MAP.md)。<ctx.filesDir>/<ctx.cacheDir>表示运行时Context目录。

## RDB结构、关系及并发

[Db](../../entry/src/main/ets/data/local/Db.ets)：getRdbStore，name=fuxiaowai.db，SecurityLevel.S1；open用共享opening Promise合并初始化，失败重置以允许重试。

| 表 | 全部字段（源码SQL） |
| --- | --- |
| course | id TEXT PRIMARY KEY；account_id TEXT NOT NULL DEFAULT ''；table_id TEXT NOT NULL；name TEXT NOT NULL；teacher/room/campus TEXT（可空）；weekday/start_period/end_period INTEGER NOT NULL；weeks TEXT NOT NULL；color_index INTEGER NOT NULL |
| timetable | id TEXT PRIMARY KEY；name TEXT NOT NULL；account_id TEXT NOT NULL DEFAULT ''；is_active INTEGER DEFAULT 0（未声明NOT NULL） |
| period | idx INTEGER PRIMARY KEY；start_time/end_time TEXT NOT NULL |
| meta | key TEXT PRIMARY KEY；value TEXT（可空） |

共4表。未声明额外CREATE INDEX、外键、UNIQUE或CHECK；主键之外无显式索引DDL。course.table_id→timetable.id是应用逻辑关系，无数据库级联删除。weeks存逗号分隔数字字符串。period虽建表，实际节次由PeriodStore preferences保存。

[CourseDao](../../entry/src/main/ets/data/local/dao/CourseDao.ets)的toBucket/toCourse转换模型；accountCourseId生成fxwa:<encoded account>:<encoded table>:<encoded original id>，兼容旧scopedCourseId。queryByWeek/queryAll/clear/insertAll/insertOne/remove/count均带account_id范围；queryByWeek按星期/节次排序再内存筛weeks，结束检查账号改变。tables返回当前账号及公共t1；createTable使t1归空账号；renameTable支持公共t1；removeTable显式删课程再删表。is_active不作为当前活动课表真值，活动选择见TimetableStateStore。

[CourseRepositoryImpl](../../entry/src/main/ets/data/repository/CourseRepositoryImpl.ets) replaceAll/add先validateCourses，写操作经Db.transaction；捕获账号并在前后检查，账号改变则抛错回滚。replaceAll事务clear+insertAll，removeTable事务删课及表；createTable用时间戳+进程序号ID。[SerialQueue](../../entry/src/main/ets/common/util/SerialQueue.ets)供Db.write/transaction串行执行，事务beginTransaction/commit/rollBack。DAO本身可直接写，事务保障在仓储层；RDB事务不覆盖偏好或文件。

## 迁移、认领与清理

Db.migrateAccounts通过PRAGMA table_info检查account_id；任一缺列先backup fuxiaowai_pre_account_v1.db，再事务ALTER缺列及写meta.account_schema='1'。新库已有列时不写该标记。claimLegacyAccount事务检查meta.legacy_account_claimed是否存在，只首次把空账号course及非t1 timetable认领给用户，再记用户；不重写旧主键。selectAccount是内存账号。clearMigrationBackup调用deleteRdbStore删除备份。eraseAllAccountData删除全部course、非t1 timetable并重置t1账号，保留period/meta及t1名称。

[Locator.clearPersonalData](../../entry/src/main/ets/app/di/ServiceLocator.ets)：invalidate AccountScope/SessionStore、废弃同步源 → 擦账号RDB/备份 → Credential/Profile/Session/Grade/Avatar/Feedback及fxw_share → WebView Cookie → 自建提醒/日历事件 → TimetableState → 空卡片更新 → filesDir/cacheDir顶层avatar_/crop_src_/fb_/grades_文件。没有跨存储总事务，权限或写入失败可能中断后续步骤，末尾unlink异常被忽略。Settings/Period、meta、fxw_migrate、fxw_forms不在此整体删除；SecretStore没有删除HUKS密钥方法；未调用服务器删除分享或反馈。不能宣称全部本地/远端数据已物理清空。

[PrivacyDocPage.doRevoke](../../entry/src/main/ets/pages/PrivacyDocPage.ets)调用上述清理。[ProfilePage](../../entry/src/main/ets/pages/ProfilePage.ets)缓存清理遍历cacheDir，文件unlink、目录rmdir，未排除fb_待发图副本；可能使FeedbackStore仍有记录但图片丢失，不清preferences/RDB；头像替换/裁剪另有旧文件清理，不能保证崩溃遗留为零。

## Preferences 清单

下列“文件名”为getPreferences逻辑名称，真实系统落盘位置未硬编码；只列key/schema，不列用户值。

| 逻辑名称 / key | 内容与生命周期、源码 |
| --- | --- |
| fxw_auth / user,pwd_enc_v1,remember,auto_update,auto_day,last_sync_at；旧pwd | [CredentialStore](../../entry/src/main/ets/data/local/CredentialStore.ets)：账号默认空，remember/auto_update默认true；密码加密，旧明文迁移后删pwd；SerialQueue及AccountScope；clear清偏好 |
| fxw_session / jw_secret_v1,jw_user,jw_at；旧jw_cookie | [SessionStore](../../entry/src/main/ets/data/local/SessionStore.ets)：加密教务Cookie、属主、时间，默认空/0；bindUser清不匹配会话；generation阻止旧写，旧明文迁移后删除；clear清偏好 |
| fxw_profile / profile | [ProfileStore](../../entry/src/main/ets/data/local/ProfileStore.ets)：JSON{name,studentId,clazz,major,grade,updatedAt}，默认空字符串/0；队列及AccountScope护栏 |
| fxw_avatar / avatar_path | [AvatarStore](../../entry/src/main/ets/data/local/AvatarStore.ets)：头像路径，默认空；clear仅删key，本体由调用层处理 |
| fxw_settings / app_settings | [SettingsStore](../../entry/src/main/ets/data/local/SettingsStore.ets)：JSON{showWeekend:true,showGhost:false,density:1,cellHeight:60,dark:false,theme:'default',remindBefore:0,calendarRemind:true}为新默认；旧density迁移行高，cellHeight夹40..80；有内存cached/invalidate |
| fxw_settings / periods_json | [PeriodStore](../../entry/src/main/ets/data/local/PeriodStore.ets)：JSON Period[]{index,start,end}；缺失/损坏用默认节次；不读写SQL period |
| fxw_share / tickets | [ShareCodeStore](../../entry/src/main/ets/data/local/ShareCodeStore.ets)：JSON ShareTicket[]{code,createdAt,week,term,courses,periods,uploaded}，默认[]；本地30天清理，服务端另校验；不按账号分档 |
| fxw_feedback / items | [FeedbackStore](../../entry/src/main/ets/data/local/FeedbackStore.ets)：JSON Feedback[]{id,text,contact,images,createdAt,sent,retryAt?}，默认[]；串行读改写/flush，push按id防重复；pending不裁剪，markSent清images/retryAt，最多30条已发历史 |
| fxw_timetable_state / state | [TimetableStateStore](../../entry/src/main/ets/data/local/TimetableStateStore.ets)：JSON{schemaVersion:2,activeTables:Record<account,table>,terms:Record<JSON.stringify([account,table]),TermMetadata>}；TermMetadata={startMonday,totalWeeks,label,year,term}；兼容旧activeTableId/schema；默认t1及DEFAULT_TERM；SerialQueue和账号检查 |
| fxw_reminder_owned / ids,enabled_<encoded account>,schemaVersion；旧enabled | 同上：ids为JSON[{id:number,key:string}]，key含账号/table/course/week，v2迁移，串行排程/取消，只管理自建登记提醒 |
| fxw_calendar_owned / used,events,export_<encoded account>:<table>,reminder_<encoded account>:<table>,legacyAccount,schemaVersion；旧reminder_<table> | [CalendarExport](../../entry/src/main/ets/common/util/CalendarExport.ets)：events是JSON Record<string,number>业务key→系统event id；迁移v2账号范围/legacyAccount；清理依赖日历权限 |
| fxw_forms / form_<formId> | [EntryFormAbility](../../entry/src/main/ets/widget/EntryFormAbility.ets)：卡片名登记，卡片删除时删key；[WidgetRefresh](../../entry/src/main/ets/widget/WidgetRefresh.ets)据登记刷新 |
| fxw_migrate / clean_demo_v2 | [Index](../../entry/src/main/ets/pages/Index.ets)：旧演示数据清理标记 |

[SecretStore.seal/open](../../entry/src/main/ets/data/local/SecretStore.ets)使用HUKS AES-GCM、12字节随机nonce及账号上下文AAD，格式v1:<base64 nonce+cipher/tag>，context为credential:user或session:user。密钥留HUKS；本文不列alias或密钥值。

## App文件

| 路径 | 内容与生命周期 |
| --- | --- |
| <ctx.filesDir>/grades_<safe user>.json | [GradeCacheStore](../../entry/src/main/ets/data/local/GradeCacheStore.ets)：GradeSnapshot={at,user,status:'ok'或'expired',terms:TermGrades[],items:GradeRecord[],summary:GradeSummary}；safe仅留字母数字，空为anon；load检查属主/schema |
| <ctx.filesDir>/grades_last.txt | 最近缓存用户；save先快照后指针，两者非共同原子；同目录.tmp_<timestamp>_<sequence>完整写/fsync/rename，账号generation/revision验证；clear串行删除所有grades_前缀 |
| <ctx.filesDir>/avatar_<timestamp>.jpg、crop_src_<timestamp>.jpg | [AvatarCropPage](../../entry/src/main/ets/pages/AvatarCropPage.ets)/[PersonalInfoPage](../../entry/src/main/ets/pages/PersonalInfoPage.ets)：头像及裁剪源副本；AvatarStore引用 |
| <ctx.cacheDir>/fb_<timestamp>_<random>_<index>.jpg | [FeedbackPage](../../entry/src/main/ets/pages/FeedbackPage.ets)复制待发图片，FeedbackStore存路径；[FeedbackDelivery](../../entry/src/main/ets/data/remote/FeedbackDelivery.ets)成功markSent后删所属fb_副本，未发保留以便重试 |

GradeRecord完整字段为courseName/courseNo/score/scoreText/gpa/credit/category/nature/teacher/xnm/xqm/termLabel；TermGrades={xnm,xqm,label,items}，GradeSummary={count,credits,weightedScore,weightedGpa,failed,best}。嵌套领域类型见[Grade](../../entry/src/main/ets/domain/model/Grade.ets)、[Course](../../entry/src/main/ets/domain/model/Course.ets)，传输schema见[API地图](API_MAP.md)。

## 服务端文件与保留

[server.js](../../server/server.js)不用SQL；ROOT来自FXW_ROOT，源码默认/var/lib/fxw仅为默认值，生产目录待确认；启动创建tickets、feedback/img、release/shot。[fxw.env.example](../../server/fxw.env.example)、[fxw-share.service](../../server/fxw-share.service)为部署参考，不证明线上状态。

| ROOT下路径 | schema与保留 |
| --- | --- |
| tickets/<32hex>.json | {code,createdAt,term,week,courses,periods}，随机16字节code，毫秒时间；课程/节次见API地图；30天TTL，GET按createdAt过期删除，启动/每小时cleanup亦删除 |
| feedback/<16hex>.json | {id,requestKey?,createdAt,text,contact,images,app,version,device,ip,read:false}；随机8字节id；images为文件名；requestKey=sha256(IP+NUL+requestId)，不存原header；后台写read=true；365天 |
| feedback/img/<id>_<idx>.jpeg或png/webp | dataURL解码二进制，单图≤1.5MiB；上传失败清已写图片；后台删除反馈清所列合法图；cleanup按图mtime保留365天，反馈JSON过期也按id前缀删图；孤图可等自身365天，并非即时引用扫描 |
| release/release.json | relMeta消费apk（文件名白名单必填）、可选version/date；releasePage/dlFile虽定义但无路由挂载，/download固定404 |
| release/shot/<filename> | shotFile公开静态图，未见自动保留清理 |

atomicWrite同目录随机.tmp（wx、mode0600）再rename，finally清临时文件，单文件原子发布，不是图+JSON跨文件事务。cleanup启动执行且每小时执行；JSON优先createdAt，否则mtime；清过期feedbackRequests/writeLimits并invalidate列表缓存。

feedbackRequests内存Map：requestKey→{at,promise}，同IP+requestId24h复用结果，最大10000条逐出最早插入项。start从24h内合法requestKey的已存反馈恢复成功结果；旧客户端无header仍兼容但无此去重。IP变化或窗口过期可能重复，失败结果仅内存留存；分享无requestId幂等。

FXW_MAX_TICKETS/FXW_MAX_FEEDBACK/FXW_MIN_FREE_BYTES控制容量，FXW_FEEDBACK_PER_MIN/FXW_MAX_ACTIVE_WRITES控制写入；cached计数通常30s、disk5s，可能短暂滞后；invalidate仅清ticket-list/feedback-list。目录权限、空间、定时清理实际运行均待确认。

## 更新触发

## 2026-11-14 后台记录存储

[admin-console.js](../../server/admin-console.js) 使用 ROOT/admin/audit.json 与 ROOT/admin/alerts.json（线上 ROOT=/var/lib/fxw），非 SQL 表。`record` 写入 `{id,time,actor,action,target,status}`；target只存SHA256前12位。`signal` 维护 `{id,time,lastSeen,key,title,detail,level,state,resolvedAt?,endedAt?}`。

`schedule` 合并写入，`flush` 串行执行0600随机临时文件→rename；每类最多2000条、最长30天，接口返回最近200条。失败保留内存状态、每5秒重试并暴露 storageError；损坏/无法读取的既有历史文件禁止覆盖，需管理员从备份恢复后重启。不存在的文件可新建。两文件不构成跨文件事务；异常断电仍可能丢失尚未落盘的短时间窗口。

口令检查 `inspect` / `ticketRows` 不写 tickets；公开接口原有30天有效期不变。2026-11-14部署逐文件核验8份原口令SHA256一致，按用户授权清空13条反馈及其附件。部署备份与校验见 [后台交付记录](../admin-console-20261114.md)。

Db SQL/迁移/认领、DAO账号筛选/id、仓储事务、Store key/schema、清理覆盖、文件命名/原子写、提醒日历所有权、server payload/TTL/幂等变动后更新。同步[API](API_MAP.md)、[状态](STATE_MAP.md)、[模块](MODULE_MAP.md)。依据为本页链接的当前源码，不依赖历史设计文档。


## 2026-11-14｜游客覆盖与节次写队列

CourseRepository.replaceAll(tableId,courses,clearGuest?,accountToken?,canCommit?) 在原事务内校验数据、替换目标课表；clearGuest 且当前账号非空时删除 account_id 空的课程与 id 非 t1 的游客课表，提交前复查 token/操作回调。失败不丢游客与原账号课表。TimetableStateStore.discardGuest 过滤 activeTables 空账号键与 terms 的空账号组合键，保留已登录账号；saveTerm 增加可选 token/操作回调。PeriodStore.save 增加 token/操作回调与 SerialQueue，避免旧导入在学校重置节次后写回。退出仍删除全部课程、分享偏好等，未改为保留游客数据。
