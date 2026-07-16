# 工作流定位

本阶段属于 `read` 工作流的 **HYPOTHESIS**。SCOPE 已定义范围；本阶段基于范围形成根因理论。

**离开本阶段的验收标准**：
- 已形成 1-3 个具体假设；
- 每个假设都有清晰的证实证据、证伪证据和可能性评估；
- 假设已写入 `.claude/state/sessions/<id>/session.md` 的 `context.hypotheses`。

## 输出格式与操作

基于范围：

{{SCOPE}}

形成 1-3 个具体根因假设。

对每个假设：
1. 清晰陈述
2. 什么证据能证实它？
3. 什么证据能证伪它？
4. 可能性多高？（高 / 中 / 低）

更新 `.claude/state/sessions/<id>/session.md`：
- `current_phase`: HYPOTHESIS
- `context.hypotheses`
