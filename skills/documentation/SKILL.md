---
name: documentation
description: 当会话结束、切换任务或需要总结归档时触发
---

# 会话收尾与目标对齐

## 用途

在会话结束时帮助用户回顾本次产出、对齐目标完成度、评价回答质量，并将最终状态安全归档。本技能负责生成回顾与评估内容；具体的文件归档、命名检查、内容迁移等机械操作交给 hooks 执行。

## 何时使用

- 会话结束
- 切换任务前
- 完成目标后
- 用户要求总结

## 核心阶段

### 1. REVIEW（回顾）

梳理本次会话：

1. 关键产出是什么？
2. 做出了哪些决策？
3. 还有哪些未决问题？
4. 下一步是什么？
5. 用户意图是否被完整覆盖？

使用提示模板：`prompt-templates/documentation/review.md`

### 2. ALIGN（对齐）

对照 `.claude/state/goal-tracker.md` 检查：

1. 哪些目标已推进或完成？
2. 哪些目标出现偏差？
3. 是否需要新增、拆分或调整目标？
4. 阻塞目标是否有变化？

使用提示模板：`prompt-templates/documentation/align.md`

### 3. EVALUATE（评估）

以「完成度 + 改进建议」的形式评价本次回答质量，而不是审计清单：

1. 本次回答在多大程度上解决了用户问题？（高 / 中 / 低 + 理由）
2. 是否遗漏了用户隐含的约束或上下文？
3. 是否存在可改进的表述、结构或技术细节？
4. 如果有下次，可以如何做得更好？

使用提示模板：`prompt-templates/documentation/evaluate.md`

### 4. PACKAGE（打包）

将回顾、对齐、评估结果整理为可交接的内容：

1. 生成交接摘要（可选写入 `.claude/state/handoff.md`）
2. 列出关键产物及其位置
3. 标注待办事项的优先级与负责人
4. 明确下次会话的入口

使用提示模板：`prompt-templates/documentation/package.md`

### 5. ARCHIVE_TRIGGER（归档触发）

**本阶段不直接操作文件**，而是：

1. 向用户展示 REVIEW / ALIGN / EVALUATE / PACKAGE 的结果
2. 等待用户确认内容是否满足
3. 用户确认后，调用归档 hook 执行归档
4. 报告归档结果

如用户认为回顾内容不满足，返回 REVIEW 或 ALIGN 重新生成，而不是触发归档。

## 与 hooks 的边界

| 职责 | 技能 `/summarize` | hooks |
|------|-------------------|-------|
| 生成回顾内容 | 是 | 否 |
| 目标对齐评估 | 是 | 否 |
| 回答质量评价 | 是 | 否 |
| 交接摘要生成 | 是 | 否 |
| 状态文件 frontmatter 检查 | 否（依赖 pre-summarize hook） | 是 |
| 归档文件命名规范检查 | 否 | 是 |
| `architecture.md` 等内容迁移校验 | 否 | 是 |
| 文件移动与 `session.md` 重置 | 否 | 是 |
| 会话退出前 dirty 状态提醒 | 否 | 是 |

## 归档约定

归档文件名：`<时间戳>-<简短描述>.md`

示例：`2026-07-07-重构-documentation-技能.md`

归档内容由 hook 从 `session.md` 迁移到 `.claude/state/archive/`，然后将 `session.md` 重置为初始状态。

## 输出产物

- `.claude/state/session.md`：更新为回顾、对齐、评估结果
- `.claude/state/goal-tracker.md`：同步目标状态
- `.claude/state/handoff.md`：可选的交接摘要
- `.claude/state/archive/<时间戳>-<简短描述>.md`：由 hook 生成

## 提示模板

- `prompt-templates/documentation/review.md`
- `prompt-templates/documentation/align.md`
- `prompt-templates/documentation/evaluate.md`
- `prompt-templates/documentation/package.md`
- `prompt-templates/documentation/session-summary.md`
- `prompt-templates/documentation/goal-tracker.md`
- `prompt-templates/documentation/plan-backup.md`

## 危险信号

- 未等用户确认就执行归档
- 将评价写成审计清单而非评估建议
- 直接在 skill 中操作归档文件
- 遗漏 `architecture.md` 等内容迁移检查
