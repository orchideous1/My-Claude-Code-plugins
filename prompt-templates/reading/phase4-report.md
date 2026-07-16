# 工作流定位

本阶段属于 `read` 工作流的 **REPORT**。EVIDENCE 已收集；本阶段综合成根因报告，**必须获得用户批准后才能进入 FIX**。

**离开本阶段的验收标准**：
- 报告包含确认的根因、证据、被排除的假设及理由、修复计划、风险；
- 用户明确批准修复；
- 报告内容已写入 `.claude/state/sessions/<id>/session.md` 的 `context.root_cause` 与 `context.proposed_fix`。

## 输出格式与操作

将证据综合成根因报告。

## 必须包含的章节

1. **确认的根因** — 一句清晰陈述
2. **证据** — 阶段 3 的要点
3. **被排除的假设** — 每个为何被排除
4. **修复计划** — 分步
5. **风险** — 可能出错的地方

## 约束

不要实施修复。报告完成后停止，等待用户批准。

更新 `.claude/state/sessions/<id>/session.md`：
- `current_phase`: REPORT
- `context.root_cause`
- `context.proposed_fix`
