# 工作流定位

本阶段属于 `read` 工作流的 **SCOPE**。`read` 工作流用于排查 bug、理解代码行为，共分为 SCOPE → HYPOTHESIS → EVIDENCE → REPORT → FIX 五个阶段。

**进入本阶段的前提**：用户已提出需要排查的问题或异常。

**离开本阶段的验收标准**：
- 问题已用一句话重述；
- 入口点、预期行为、实际行为、涉及组件、可疑文件/模块、不在范围内的部分均已明确；
- 可疑位置只列不读；
- 已创建 session 时，范围已写入 `.claude/state/sessions/<id>/session.md` 的 `context.scope`。

## 输出格式与操作

你要调查的问题：{{INVESTIGATION_TARGET}}

用一句话重述症状或问题。

然后填写：

- 入口点：
- 预期行为：
- 实际行为：
- 涉及组件：
- 可疑文件/模块（只列不读）：
- 不在范围内：

**操作**：
- 先判断本调查是否需要跨会话状态或用户是否明确要求 session；只有结论为需要时，调用 `~/.claude/scripts/core/ensure-state.sh read`。
- 已创建 session 时，将范围写入 `.claude/state/sessions/<id>/session.md` 的 `context.scope` 中，并更新 `current_phase: SCOPE`。
