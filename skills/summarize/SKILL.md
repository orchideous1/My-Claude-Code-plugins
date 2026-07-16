---
name: summarize
description: 当会话结束、切换任务或需要总结归档时触发
---

# 会话收尾与目标对齐

## 用途

在会话结束时帮助用户回顾本次产出、对齐目标完成度、评价回答质量，并安全归档经审查的会话 guide。

本技能负责生成回顾、评估、审查与归档方案；具体的文件写入、归档、清理等机械操作交给 `scripts/core/` 与 hooks 执行。

## 何时使用

- 会话结束
- 切换任务前
- 完成目标后
- 用户要求总结

## 启动前必须执行

`summarize` **不创建新的会话 ID**，而是沿用当前 workflow 的会话目录：

1. 读取 `.claude/state/.current-session-id` 或 `CLAUDE_SESSION_ID` 环境变量。
2. 如果没有任何会话 ID 且不存在 dirty 的 `sessions/default/`，则按 `general` workflow 处理。
3. 调用：
   ```bash
   ~/.claude/scripts/core/ensure-state.sh general .claude/state "${SESSION_ID:-${CLAUDE_SESSION_ID:-default}}"
   ```

该调用仅确保目录与模板存在，不会覆盖已有 `session.md` 内容。

## 核心阶段

### 1. REVIEW（回顾）

梳理本次会话：

1. 关键产出是什么？
2. 做出了哪些决策？
3. 还有哪些未决问题？
4. 下一步是什么？
5. 用户意图是否被完整覆盖？

使用提示模板：`prompt-templates/summarize/review.md`

### 2. ALIGN（对齐）

对照 `.claude/state/goal-tracker.md` 检查：

1. 哪些目标已推进或完成？
2. 哪些目标出现偏差？
3. 是否需要新增、拆分或调整目标？
4. 阻塞目标是否有变化？

使用提示模板：`prompt-templates/summarize/align.md`

### 3. EVALUATE（评估）

以「完成度 + 改进建议」的形式评价本次回答质量：

1. 本次回答在多大程度上解决了用户问题？（高 / 中 / 低 + 理由）
2. 是否遗漏了用户隐含的约束或上下文？
3. 是否存在可改进的表述、结构或技术细节？
4. 如果有下次，可以如何做得更好？

使用提示模板：`prompt-templates/summarize/evaluate.md`

### 4. PACKAGE（打包）

根据 `.claude/state/sessions/<id>/session.md` 的完整轨迹，整理为一份可归档的 guide：

- `build` 工作流 → `.claude/state/sessions/<id>/handoff.md`
- `read` 工作流 → `.claude/state/sessions/<id>/handoff.md`
- `arch` 工作流 → 润色/确认 `.claude/state/sessions/<id>/architecture.md`
- `general` 工作流 → `.claude/state/sessions/<id>/handoff.md`

guide 必须保留足够过程信息，避免过度简化（例如保留关键决策理由、证据、代码位置、验证结果、待办与风险）。

同时生成归档方案：

- guide 来源文件
- 目标归档文件名（格式：`<timestamp>-<desc>-<workflow>-<handoff|report|model|summary>.md`）
- 一句话摘要

**本阶段必须向用户展示归档方案并询问是否归档。**

- 若用户同意归档 → 进入 ARCHIVE。
- 若用户不同意归档：
  - 询问是“需要继续修改 guide”还是“本次改进较小无需归档”。
  - 若继续修改 → 返回 REVIEW 或 PACKAGE。
  - 若无需归档 → 清空 guide 文件，结束 `summarize`。

使用提示模板：`prompt-templates/summarize/package.md`

### 5. ARCHIVE（归档）

用户确认归档后执行：

1. 确定 guide 来源文件和 workflow 类型。
2. 调用脚本实际归档：
   ```bash
   ~/.claude/scripts/core/write-archive.sh \
       <SOURCE_FILE> \
       <DESCRIPTION> \
       [<WORKFLOW_TYPE>] \
       .claude/state
   ```
   或使用 hook 入口：
   ```bash
   ~/.claude/hooks/summarize/archive.sh \
       <SOURCE_FILE> \
       <DESCRIPTION> \
       [<WORKFLOW_TYPE>] \
       .claude/state
   ```
3. 归档成功后，调用 `cleanup-session.sh` 删除原 `sessions/<id>/` 目录。
4. 向用户总结归档内容：文件名、位置、摘要。

使用提示模板：`prompt-templates/summarize/archive.md`

### 6. AUDIT（归档审查）

AUDIT 与前面的回顾/对齐/评估在上下文上解耦。启动一个**独立 sub-agent**，仅向其暴露审计所需材料：

- `.claude/state/sessions/` 下本次会话的 `session.md`、`plan.md`、guide 文件（如已归档，可传 archive 中副本）
- 本次会话涉及的代码 diff（`git diff`）
- `CLAUDE.md`

sub-agent 的任务：

1. 审查提示词合理性、文档冲突、状态架构、`CLAUDE.md` 优化建议、归档内容。
2. 如发现目标偏差或架构理解问题，向用户提出重新对齐的问题。
3. 输出分类结果：阻塞 / 建议 / 通过。

主代理将 sub-agent 的报告展示给用户。AUDIT 结果**只向用户展示，不写入文件，也不进入 archive**。

使用提示模板：`prompt-templates/summarize/audit.md`

## 与 hooks / 脚本的边界

| 职责 | 技能 `summarize` | scripts/core / hooks |
|------|------------------|----------------------|
| 生成回顾内容 | 是 | 否 |
| 目标对齐评估 | 是 | 否 |
| 回答质量评价 | 是 | 否 |
| guide 生成与归档方案 | 是 | 否 |
| 用户确认归档 | 是 | 否 |
| 实际写入 archive / 更新 index | 否 | 是 |
| 归档后删除 `sessions/<id>/` | 否 | 是 |
| 状态文件 frontmatter 检查 | 否 | 是 |
| 旧路径 `.claude/session.md` 检测 | 否 | 是 |
| 并发会话冲突检测 | 否 | 是 |
| 会话退出前 dirty 状态提醒 | 否 | 是 |

## 内容分层

### 中间状态（单会话）

- 位置：`.claude/state/sessions/<CLAUDE_SESSION_ID>/`
- 文件：`session.md`、`plan.md`、待归档的 `handoff.md` / `architecture.md`
- 生命周期：会话内工作草稿，归档后删除

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
- 只归档 guide；`session.md` 与 `plan.md` 等中间状态在归档后随 `sessions/<id>/` 一起删除，不进入 archive。

## 并发会话

- 通过环境变量 `CLAUDE_SESSION_ID` 隔离不同会话的中间状态。
- 未设置时默认使用 `default`。
- 推荐并发会话启动方式：`CLAUDE_SESSION_ID=feature-a claude`
- 若未设置 ID 且存在其他会话目录，`pre-summarize.sh` 会发出警告。

## 输出产物

- `.claude/state/archive/<timestamp>-<desc>-<type>-<artifact>.md`：归档 guide
- `.claude/state/archive/index.md`：由 hook 维护的归档索引
- `.claude/state/goal-tracker.md`：同步目标状态
- 归档成功后，原 `sessions/<id>/` 目录被删除

## 提示模板

- `prompt-templates/summarize/review.md`
- `prompt-templates/summarize/align.md`
- `prompt-templates/summarize/evaluate.md`
- `prompt-templates/summarize/package.md`
- `prompt-templates/summarize/archive.md`
- `prompt-templates/summarize/audit.md`
- `prompt-templates/summarize/session-summary.md`
- `prompt-templates/summarize/goal-tracker.md`
- `prompt-templates/summarize/plan-backup.md`

## 危险信号

- 未等用户确认就执行归档
- 将评价写成审计清单而非评估建议
- 直接在 skill 中操作归档文件
- 遗漏 `architecture.md` 等内容迁移检查
- AUDIT 阶段自动修改 `CLAUDE.md`
- 未处理并发会话冲突
- AUDIT 结果误写入文件或归档
- guide 过度简化，丢失关键过程信息
- summarize 创建新的会话 ID 或覆盖其他会话目录
