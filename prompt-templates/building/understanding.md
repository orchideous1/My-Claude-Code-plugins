# 工作流定位

本阶段属于 `build` 工作流的 **UNDERSTANDING**。`build` 工作流用于生成、重构或修改代码，共分为 UNDERSTANDING → PLANNING → EXECUTING → VERIFYING → REFLECTING 五个阶段。

**进入本阶段的前提**：用户已表达需要生成/修改代码的意图。

**离开本阶段的验收标准**：
- 最终要做什么、硬约束、成功标准均已明确；
- 可复用模式与公开接口已识别；
- 如存在模糊点，必须继续询问，不得进入 PLANNING。

## 输出格式与操作

目标：{{USER_GOAL}}

规划前先澄清：

1. 最终结果应该做什么？
2. 硬约束有哪些？
3. 成功是什么样？
4. 有哪些已有代码或模式可复用？
5. 公开接口是什么（函数、CLI、API）？

如有不清楚，询问用户。意图确认前不要进入规划。

**操作**：
- 调用 `~/.claude/scripts/core/ensure-state.sh build` 初始化状态。
- 更新 `.claude/state/sessions/<id>/session.md`：
  - `current_phase`: UNDERSTANDING
  - `context.user_goal`
  - `context.clarifications`
