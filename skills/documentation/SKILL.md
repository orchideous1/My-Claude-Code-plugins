---
name: documentation
description: 当会话结束、切换任务或需要总结归档时触发
---

# 会话收尾与目标对齐

## 用途

在会话结束时帮助用户回顾本次产出、对齐目标完成度、评价回答质量，并安全归档经审查的会话总结。本技能负责生成回顾、评估、审查与归档方案；具体的文件归档、命名检查、内容迁移等机械操作交给 hooks 执行。

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

以「完成度 + 改进建议」的形式评价本次回答质量：

1. 本次回答在多大程度上解决了用户问题？（高 / 中 / 低 + 理由）
2. 是否遗漏了用户隐含的约束或上下文？
3. 是否存在可改进的表述、结构或技术细节？
4. 如果有下次，可以如何做得更好？

使用提示模板：`prompt-templates/documentation/evaluate.md`

### 4. PACKAGE（打包）

将回顾、对齐、评估结果整理为可交接的会话总结：

1. 根据 workflow 类型生成 `handoff.md` 或更新 `architecture.md`
2. 列出关键产物及其位置
3. 标注待办事项的优先级与负责人
4. 明确下次会话的入口

使用提示模板：`prompt-templates/documentation/package.md`

### 5. AUDIT（归档审查）

在触发归档前，审视以下核心问题，将发现按「阻塞 / 建议 / 通过」分类：

1. **提示词合理性**：现有 prompt 是否存在问题？能否从本次对话归纳通用提示？
2. **文档冲突**：`CLAUDE.md`、skill 文档、命令入口、提示模板之间是否一致？
3. **状态架构**：状态文件位置、frontmatter、分层边界是否正确？
4. **`CLAUDE.md` 优化**：哪些经验应沉淀到 `CLAUDE.md`？**仅输出建议，不得自动写入**。
5. **归档内容审查**：总结内容是否准确、简洁、无敏感信息？文件名是否符合命名规则？

使用提示模板：`prompt-templates/documentation/audit.md`

### 6. ARCHIVE_TRIGGER（归档触发）

**本阶段不直接操作文件**，而是：

1. 向用户展示 AUDIT 结果（阻塞 / 建议 / 通过）。
2. 向用户展示归档方案：
   - workflow 类型
   - 待归档文件来源与目标路径
   - `session.md` / `plan.md` 明确说明不归档
3. 询问用户是否归档总结文件。
4. 若用户选择不归档，由 skill 清空对应中间状态文件后再调用归档 hook。
5. 用户确认后，调用 `archive.sh`（仅传递 `DESCRIPTION` 与 `STATE_DIR`）。
6. 报告归档结果与待修复的 AUDIT 建议。

如用户认为回顾内容不满足，返回 REVIEW 或 ALIGN 重新生成，而不是触发归档。

## 与 hooks 的边界

| 职责 | 技能 `/summarize` | hooks |
|------|-------------------|-------|
| 生成回顾内容 | 是 | 否 |
| 目标对齐评估 | 是 | 否 |
| 回答质量评价 | 是 | 否 |
| 交接摘要生成 | 是 | 否 |
| 归档审查与 `CLAUDE.md` 优化建议 | 是 | 否 |
| 归档方案展示与用户确认 | 是 | 否 |
| 状态文件 frontmatter 检查 | 否 | 是 |
| 旧路径 `.claude/session.md` 检测 | 否 | 是 |
| 并发会话冲突检测 | 否 | 是 |
| 归档文件命名规范检查 | 否 | 是 |
| workflow 类型推断 | 否 | 是 |
| `archive/index.md` 维护 | 否 | 是 |
| 文件移动与 `session.md` 重置 | 否 | 是 |
| 会话退出前 dirty 状态提醒 | 否 | 是 |

## 内容分层

### 中间状态（单会话）

- 位置：`.claude/state/sessions/<CLAU_DE_SESSION_ID>/`
- 文件：`session.md`、`plan.md`、待归档的 `handoff.md` / `architecture.md`
- 生命周期：会话内工作草稿，归档后重置或清理

### 归档产物（只读快照）

- 位置：`.claude/state/archive/`
- 命名规则：
  - build：`handoff.md` → `<timestamp>-<desc>-build-handoff.md`
  - read：`handoff.md` → `<timestamp>-<desc>-read-report.md`
  - arch：`architecture.md` → `<timestamp>-<desc>-arch-model.md`
  - general：`handoff.md` → `<timestamp>-<desc>-general-summary.md`
- 生命周期：长期保存，供新会话通过 `archive/index.md` 发现

### 长期记忆（跨会话）

- `.claude/state/goal-tracker.md`：目标追踪
- `.claude/state/archive/index.md`：归档索引
- `CLAUDE.md`：项目协作规则，**所有增改必须经用户审核**
- 记忆文件：用户偏好、反馈、项目背景

## 归档约定

- 归档文件名：`<时间戳>-<简短描述>-<工作流类型>-<产物类型>.md`
- 示例：`2026-07-15-重构归档系统-build-handoff.md`
- 归档内容由 hook 从会话目录迁移到 `.claude/state/archive/`，中间状态文件按需重置。

## 并发会话

- 通过环境变量 `CLAUDE_SESSION_ID` 隔离不同会话的中间状态。
- 未设置时默认使用 `default`，存在其他会话目录时会收到警告。
- 推荐并发会话启动方式：`CLAUDE_SESSION_ID=feature-a claude`

## 输出产物

- `.claude/state/sessions/<id>/session.md`：更新为回顾、对齐、评估结果后重置
- `.claude/state/sessions/<id>/handoff.md` 或 `architecture.md`：可选的交接摘要
- `.claude/state/goal-tracker.md`：同步目标状态
- `.claude/state/archive/index.md`：由 hook 维护的归档索引
- `.claude/state/archive/<timestamp>-<desc>-<type>-<artifact>.md`：由 hook 生成的归档总结

## 提示模板

- `prompt-templates/documentation/review.md`
- `prompt-templates/documentation/align.md`
- `prompt-templates/documentation/evaluate.md`
- `prompt-templates/documentation/package.md`
- `prompt-templates/documentation/audit.md`
- `prompt-templates/documentation/session-summary.md`
- `prompt-templates/documentation/goal-tracker.md`
- `prompt-templates/documentation/plan-backup.md`

## 危险信号

- 未等用户确认就执行归档
- 将评价写成审计清单而非评估建议
- 直接在 skill 中操作归档文件
- 遗漏 `architecture.md` 等内容迁移检查
- AUDIT 阶段自动修改 `CLAUDE.md`
- 未处理并发会话冲突

