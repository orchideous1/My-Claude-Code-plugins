# 工作流定位

本阶段属于 `build` 工作流的 **EXECUTING**。PLANNING 已获用户批准；本阶段按 `.claude/state/sessions/<id>/plan.md` 实现代码。

**进入本阶段的验收标准**：`context.plan_approved` 为 `true`。

**离开本阶段的验收标准**：
- 计划规定的内容已实现；
- 未引入计划外文件；
- 已更新 `.claude/state/sessions/<id>/session.md`。

## 输出格式与操作

已批准的计划：

{{PLAN}}

现在实现它。

规则：
- 只写计划规定的内容
- 遵循现有模式
- 保持 CLI 简单；参数超过 5 个时用配置文件
- 脚本开头写用法 docstring
- 每次重要操作后更新 `.claude/state/sessions/<id>/session.md`

更新 `.claude/state/sessions/<id>/session.md`：
- `current_phase`: EXECUTING
- `context.last_action`
