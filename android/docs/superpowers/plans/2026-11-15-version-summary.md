# 双平台版本展示
已确认预览：每个平台上方软件版本、中间已发布公告、下方编辑。
1. server/admin-console.js增加认证app-version GET/PUT，按平台保存独立版本记录，公告撤回不删除版本；保留原客户端公告契约。
2. dashboard/admin.js增加只读版本与公告卡片、独立保存版本入口；异步轮询更新卡片且不覆盖草稿，纯文本渲染。
3. tests/app-update.test.cjs证明版本保存、平台隔离、撤回公告保留版本、认证和输入校验。
4. 基于线上源增量部署，备份回滚并核对业务数据。npm run check后build、cap sync、Gradle Debug APK；记录证据与交付路径。
正式签名未提供，交付Debug验收包，不生成替代发布密钥。
