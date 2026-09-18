# 工作流定位

本阶段属于 `build` 工作流的 **EXECUTING**。PLANNING 已获用户批准；本阶段按已批准计划实现代码（已创建 session 时计划位于 `.claude/state/sessions/<id>/plan.md`）。

**进入本阶段的验收标准**：计划已获用户明确批准，schema 与抽象必要性表完整；已创建 session 时 `context.plan_approved` 为 `true`。

**离开本阶段的验收标准**：
- 计划规定的内容已实现；
- 未引入计划外文件；
- 已创建 session 时，已更新 `.claude/state/sessions/<id>/session.md`。

## 输出格式与操作

已批准的计划：

{{PLAN}}

现在实现它。

规则：
- 只写计划规定的内容
- 遵循现有模式
- 保持 CLI 简单；参数超过 5 个时用配置文件
- 脚本开头写用法 docstring
- 不保留纯转发、重复校验或仅包装后委托的层；底层操作的不变量由底层检查
- 独立横切机制须与算法主流程无关且有可验证的契约；事务细节留在 Tool、Store 等所属边界内部
- 从唯一状态源读取领域状态，不从消息、日志或序列化 payload 反推已有状态
- 不为统一形式引入无必要性的泛型抽象或假想兼容
- 已创建 session 时，每次重要操作后更新 `.claude/state/sessions/<id>/session.md`

已创建 session 时，更新 `.claude/state/sessions/<id>/session.md`：
- `current_phase`: EXECUTING
- `context.last_action`
