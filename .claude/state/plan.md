---
title: 重构 documentation 技能为会话收尾与对齐技能
status: completed
phase: REFLECTING
created: 2026-07-07
updated: 2026-07-07
---

# 重构 documentation 技能为会话收尾与对齐技能

## 目标

让 `/summarize` 从单纯的文件归档工具升级为「回顾 - 对齐 - 评估 - 触发归档」的会话收尾技能；将具体的归档、命名检查、内容迁移等机械操作下沉为 hooks，由 `/summarize` 在用户确认后调用。

## 约束

- 不新增工作流命令，仅改造 `documentation` 技能及其入口。
- 所有提示文档使用中文撰写。
- 归档操作必须等待用户确认回顾内容后再触发。
- 回答质量评价采用「评估」（完成度 + 改进建议），而非审计清单。
- 不破坏现有 `.claude/state/*.md` 的 YAML frontmatter 格式。
- 技能是单一真相源，命令入口保持薄壳。

## 改动清单

### 1. `skills/documentation/SKILL.md`

重写技能说明：

- **定位**：会话收尾与目标对齐技能。
- **何时使用**：会话结束、切换任务、完成目标、用户要求总结。
- **核心阶段**：
  1. **REVIEW（回顾）**：梳理关键产出、决策、未决问题、下一步。
  2. **ALIGN（对齐）**：对照 `goal-tracker.md` 检查目标完成度、偏差、新增目标。
  3. **EVALUATE（评估）**：以完成度 + 改进建议的形式评价本次回答质量。
  4. **PACKAGE（打包）**：生成交接摘要、关键产物索引、待办优先级。
  5. **ARCHIVE_TRIGGER（归档触发）**：用户确认后调用归档 hook，报告结果。
- **与 hooks 的边界**：技能负责生成回顾与评估内容；hooks 负责校验规则并执行文件移动/重置。
- **输出产物**：
  - `.claude/state/session.md` 更新为回顾结果
  - `.claude/state/goal-tracker.md` 同步目标状态
  - `.claude/state/handoff.md`（可选）交接摘要
  - `.claude/state/archive/<timestamp>-<desc>.md` 由 hook 生成

### 2. 新增/重写提示模板 `prompt-templates/documentation/`

- `review.md`：REVIEW 阶段执行模板
- `align.md`：ALIGN 阶段执行模板
- `evaluate.md`：EVALUATE 阶段执行模板
- `package.md`：PACKAGE 阶段执行模板
- 保留并更新 `session-summary.md`、`goal-tracker.md`、`plan-backup.md` 作为产物模板

### 3. 新增归档 hooks

新建 `hooks/documentation/` 目录：

- `pre-summarize.sh`：检查 `session.md` / `goal-tracker.md` frontmatter 完整性，状态异常时阻断。
- `archive.sh`：在用户确认后执行归档：
  - 按 `<timestamp>-<简短描述>.md` 命名生成归档文件
  - 校验 `architecture.md` 等产物是否已正确迁移
  - 将 `session.md` 内容移动到归档文件
  - 重置 `session.md` 为初始状态
- `session-exit.sh`：会话退出前检测未归档 dirty 状态，提示用户是否需要 `/summarize`。

### 4. `commands/summarize.md`

保持薄壳入口，仅更新 description 以匹配新定位。

### 5. `CLAUDE.md`

在「状态文件保护」或「阶段门控」章节补充 hooks 说明，明确：

- `/summarize` 负责生成回顾与评估
- 归档由 hooks 执行
- 命名规范与内容迁移校验内嵌在 `archive.sh`

## 算法流程

```
用户输入 /summarize
  → pre-summarize hook 检查状态文件 frontmatter
  → REVIEW：生成本次会话回顾
  → ALIGN：对照 goal-tracker.md 检查目标
  → EVALUATE：评估回答质量（完成度 + 改进建议）
  → PACKAGE：生成交接摘要与产物索引
  → 向用户展示回顾、对齐、评估、打包结果
  → 用户确认后调用 archive.sh
  → archive.sh 执行命名检查、内容迁移校验、归档、重置
  → 报告归档结果
```

## 验证步骤

1. ✓ 读取更新后的 `skills/documentation/SKILL.md`，确认阶段划分清晰、与 hooks 边界明确。
2. ✓ 检查新增提示模板是否覆盖 REVIEW / ALIGN / EVALUATE / PACKAGE 四个阶段。
3. ✓ 检查 `hooks/documentation/archive.sh` 是否包含命名规范和内容迁移校验逻辑。
4. ✓ 检查 `commands/summarize.md` 仍为薄壳入口，未重复 skill 细节。
5. ✓ 检查 `CLAUDE.md` 是否已补充 hooks 说明。
6. ✓ 通过 dry-run 方式验证 `archive.sh` 不会破坏 `.claude/state/*.md` 的 frontmatter。
7. ✓ 运行 `pre-summarize.sh` 与 `session-exit.sh`，确认 hook 逻辑正常。
