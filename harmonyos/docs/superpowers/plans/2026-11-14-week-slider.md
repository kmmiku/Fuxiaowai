# 周数滑块松手提交

用户已确认：拖动时滑块与菜单右上周数字跟手，背景课表不刷新；松手选定再刷新一次，关闭/取消不提交。

1. Index 增 previewWeek 与手势状态。打开菜单同步已提交 week；Begin/Moving 只更新 previewWeek；End/Click 有效且周数改变才修改 week。关闭、离页、取消丢弃预览。
2. 保留 onWeekChange 作为唯一周变化刷新入口，移除 Swiper.onChange 的重复 loadCourses。查询捕获请求周并拒绝失效结果/错误。
3. 同步 PAGE/STATE/COMPONENT 地图。运行现有回归与 ArkTS 构建，核对清单与产物哈希，安装模拟器；中途截图验证拖动数字变化但背景周不变，松手背景更新，未变周数不刷新，最终停在周数菜单。

不增加镜像源码的测试，不修改数据库结构、账号或分享行为，不提交 Git。

执行结果：[周数滑块验收记录](../../week-slider-20261114.md)。
