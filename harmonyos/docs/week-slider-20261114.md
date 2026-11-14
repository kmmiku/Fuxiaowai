# 周数滑块验收（2026-11-14）

- Index.weekPanel 增加 previewWeek，Begin/Moving 只更新滑块与右上周数字，不改已提交 week。End/Click 且周数改变才提交，由 onWeekChange 刷新一次。日期/背景课表在拖动期间不动。
- 打开菜单同步预览；关闭/离页/TouchType.Cancel 丢弃未提交值；Swiper.onChange 移除重复 loadCourses。
- loadCourses 捕获 requestedWeek，init/select/查询完成后验证请求代次、周数、课表与账号；过期成功/失败结果均不覆盖新界面。
- 构建：tools/构建.ps1 成功，release assembleApp BUILD SUCCESSFUL；67项测试66通过、1跳过、0失败。
- builtAt UTC：2026-11-14T12:57:49.5749352Z；清单内源码/配置 SHA256 全部匹配。
- HAP：D:\fxw_build\hardening\HarmonyOs\entry\build\default\outputs\default\entry-default-unsigned.hap；1498708字节；SHA256 18310CE85ABC0BC80F2BDDC9817F83BEF63AB5EF80B2D112647EF3863831602C。
- hdc 127.0.0.1:5555 安装最新 HAP 成功，force-stop 后启动 com.fuxiaowai.timetable/EntryAbility 成功。
- 实测慢速连续拖动：起始第11周；中途截图菜单第13周、背景仍第11周；松手后最终第19周，背景与日期更新。FuxiaoIdx 中 load table 日志计数起始13、拖动中13、松手后14；点击同一周仍14。没有清空系统日志，仅统计指定标签/消息。
- 实测截图位于工程外 D:/fxw_build/qa-week-slider/：before.jpeg、moving.jpeg、released.jpeg；不加入 Git。最后恢复第11周并停在菜单供验收。
- 未测：实体机帧率、系统级触摸取消、拖动同时账号切换。相应取消/过期保护存在于源码，不将其写成运行验证通过。
- 未修改账号、分享、课程数据或数据库结构，未提交/推送 Git。
