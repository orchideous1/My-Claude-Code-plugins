# 工作流定位

本阶段属于 `arch` 工作流的 **SURVEY**。SCOPE 已定义焦点；本阶段在不读内部的情况下映射高层结构。

**离开本阶段的验收标准**：
- 已获得高层地图（目录、模块、入口点、关键配置、测试结构）；
- 已确定 3-5 个最值得深入解读的核心组件；
- 高层地图已写入 `.claude/state/sessions/<id>/session.md` 的 `context.high_level_map`。

## 输出格式与操作

映射焦点区域的高层结构。

不要读文件内部，只关注结构。

记录：

- 顶层目录及其作用
- 模块/包及边界
- 入口点（main、CLI、服务端点等）
- 配置文件
- 测试结构
- 构建/包文件
- 可绘制的整体结构图素材（组件及其关系）
- 最值得深入解读的 3-5 个核心组件

大型项目使用子代理，每个模块一个。

更新 `.claude/state/sessions/<id>/session.md`：
- `current_phase`: SURVEY
- `context.high_level_map`
