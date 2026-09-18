# 工作流定位

本阶段属于 `build` 工作流的 **REFLECTING**。VERIFYING 已通过；本阶段总结、更新目标，并决定下一步。

**离开本阶段的验收标准**：
- 变更内容、验证结果、文档更新已总结；
- 已记录实际抽象、schema、状态归属与批准计划的偏差；
- 需要跟踪的长期目标已更新到 `.claude/state/goal-tracker.md`；
- 下一步方向明确（完成 / 新一轮 / 新目标）。

## 输出格式与操作

总结本次工作。

1. 改了什么？
2. 验证了什么？
3. 更新了哪些文档？
4. 哪些抽象保留、新增、内联、下沉或删除？与必要性表及目标流程图有无偏差？
5. 实际 schema、状态归属与批准计划有无偏差？若有，是否重新获批？
6. 下一步是什么？（完成 / 新一轮 / 新目标）

如长期目标有变化，更新 `.claude/state/goal-tracker.md`。

已创建 session 时，更新 `.claude/state/sessions/<id>/session.md`：
- `current_phase`: REFLECTING
- `context.reflection`
