# 打包交接摘要

请将本次会话的回顾、对齐、评估结果整理为一份交接摘要：

## 摘要标题

- 用一句话概括本次会话的核心成果。

## 关键产物清单

- 产物名称
- 产物位置
- 一句话说明其价值

## 决策与待办

- 已确认决策
- 待办事项（按优先级排序）
- 待办的入口或下一步动作

## 风险提示

- 有哪些地方需要下次会话特别注意？
- 有哪些假设可能在后续被推翻？

## 归档方案

根据本次 workflow 类型，向用户展示归档方案：

| workflow 类型 | 来源文件 | 归档目标 |
|---------------|----------|----------|
| build | `sessions/<id>/handoff.md` | `archive/<timestamp>-<desc>-build-handoff.md` |
| read | `sessions/<id>/handoff.md` | `archive/<timestamp>-<desc>-read-report.md` |
| arch | `sessions/<id>/architecture.md` | `archive/<timestamp>-<desc>-arch-model.md` |
| general | `sessions/<id>/handoff.md` | `archive/<timestamp>-<desc>-general-summary.md` |

- 明确说明 `session.md` 与 `plan.md` 为中间状态，**不归档**。
- 询问用户是否将本次总结文件归档到 `archive/`。
- 若用户选择不归档，清空对应的 `handoff.md` 或 `architecture.md`。

## 输出

- 向用户展示摘要内容
- 询问用户是否将摘要写入 `.claude/state/sessions/<id>/handoff.md` 或更新 `architecture.md`
- 摘要应足够简洁，使新会话能快速理解上下文

