# 工作流定位

本阶段属于 `read` 工作流的 **EVIDENCE**。HYPOTHESIS 已形成；本阶段委派子代理阅读代码，为每个假设收集支持或反驳的证据。

**离开本阶段的验收标准**：
- 每个假设都已被证据支持或反驳；
- 证据摘要已写入 `.claude/state/sessions/<id>/session.md` 的 `context.evidence_summary`；
- 如证据不足，返回本阶段补充或回到 HYPOTHESIS 修正假设。

## 输出格式与操作

假设：

{{HYPOTHESES}}

为每个假设确定要检查的确切文件和函数。

每个聚焦问题派一个 `Explore` 子代理。不要自己读大文件。

每个子代理应回答：
- 这段代码做什么？
- 什么值流入和流出？
- 哪里可能失败或表现异常？
- 它支持还是反驳假设 X？

综合发现并更新 `.claude/state/sessions/<id>/session.md`：
- `current_phase`: EVIDENCE
- `context.evidence_summary`
