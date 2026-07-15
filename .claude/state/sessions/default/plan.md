---
title: 重新设计 summarize 归档系统：内容分层、审查逻辑与并发隔离
status: planning
phase: PLANNING
created: 2026-07-14
updated: 2026-07-14
---

# 重新设计 summarize 归档系统

## 设计目标

1. **内容分层清晰**：明确区分「中间状态」「归档产物」「长期记忆」三类内容。
2. **减少冗余**：仅归档经审查后的高价值产物，`session.md` / `plan.md` 等中间状态不进入 archive。
3. **自动可发现**：维护 `.claude/state/archive/index.md` 作为 handoff 指南，并在 `CLAUDE.md` 中显式引用。
4. **工作流感知的总结命名**：针对 build / read / arch / general 提炼不同的归档总结文档命名规则。
5. **并发安全**：中间状态按会话隔离，避免多会话同时写入 `session.md`。
6. **归档审查**：每次触发归档时，审视对话内容并检查提示词合理性、文档冲突、状态架构、`CLAUDE.md` 优化等核心问题。
7. **CLAUDE.md 变更受控**：所有 `CLAUDE.md` 的内容增改必须在用户审核后执行，不得自动写入。

## 内容分层

| 类型 | 内容 | 存储位置 | 生命周期 | 说明 |
|------|------|----------|----------|------|
| 中间状态 | `session.md`、`plan.md`、待归档的 `handoff.md` / `architecture.md` | `.claude/state/sessions/<session-id>/` | 单会话 | 工作草稿，会话结束后重置或清理 |
| 归档产物 | 已确认的 `handoff.md`、`architecture.md` | `.claude/state/archive/` | 长期只读 |  distilled 成果，供新会话读取 |
| 长期记忆 | `goal-tracker.md`、`archive/index.md`、`CLAUDE.md`、记忆文件 | `.claude/state/`、`CLAUDE.md`、memory dir | 跨会话维护 | 目标、索引、协作规则、用户偏好 |

### 中间状态

- 每个会话拥有独立目录，避免多会话冲突。
- `session.md` 记录当前会话阶段、上下文与计划状态。
- `plan.md` 记录 `/build` 流程的当前计划。
- `handoff.md` 在 PACKAGE 阶段生成，归档前仍是中间状态。
- `architecture.md` 在 `/arch` 流程中生成，归档前仍是中间状态。

### 归档产物

- 仅当用户确认后，会话总结才会被迁移到 `archive/`。
- 根据 workflow 类型采用不同的归档命名：

| workflow 类型 | 来源文件 | 归档命名 |
|---------------|----------|----------|
| build | `handoff.md` | `archive/<timestamp>-<desc>-build-handoff.md` |
| read | `handoff.md` | `archive/<timestamp>-<desc>-read-report.md` |
| arch | `architecture.md` | `archive/<timestamp>-<desc>-arch-model.md` |
| general | `handoff.md` | `archive/<timestamp>-<desc>-general-summary.md` |

- 归档产物为只读快照，供新会话通过 `archive/index.md` 发现。

### 长期记忆

- `goal-tracker.md`：跨会话目标追踪。
- `archive/index.md`：归档总结的目录与摘要。
- `CLAUDE.md`：项目级协作规则与状态架构说明，**所有内容增改必须经用户审核**。
- 记忆文件：用户偏好、反馈、项目背景。

## 并发会话隔离方案

- 使用环境变量 `CLAUDE_SESSION_ID` 标识会话。
- 中间状态目录：`.claude/state/sessions/<session-id>/`。
- 若未设置 `CLAUDE_SESSION_ID`，默认使用 `default`，并检测是否存在其他非 `default` 会话或 dirty 的 `default` 会话，输出警告。
- 长期记忆文件仍位于 `.claude/state/` 根目录，所有会话共享，采用追加或显式合并策略。
- `archive.sh` 通过 `CLAUDE_SESSION_ID` 定位对应会话目录，无需额外 CLI 参数。

## 归档审查逻辑（AUDIT 阶段）

在 `/summarize` 的 `ARCHIVE_TRIGGER` 之前新增 **AUDIT** 阶段。每次归档触发时，系统应审视以下核心问题：

### 1. 提示词合理性

- 当前对话是否暴露出现有 prompt 模板的问题？
- 是否有 prompt 过于冗长、模糊或与实际流程脱节？
- 基于本次对话，是否有 prompt 需要新增、删除或重写？
- 能否从本次对话中归纳出可复用的通用提示或检查项？

### 2. 文档冲突

- `CLAUDE.md` 与 skill 文档是否存在矛盾？
- 命令入口 `commands/*.md` 是否与 skill 描述一致？
- 提示模板是否引用了已废弃的文件路径或阶段名称？
- 状态文件格式要求在不同文档中是否一致？

### 3. 状态架构

- 状态文件是否按约定存放在正确位置？
- YAML frontmatter 是否完整、一致？
- 是否存在冗余状态文件或缺失的关键状态文件？
- 中间状态、归档产物、长期记忆的边界是否清晰？

### 4. `CLAUDE.md` 优化

- 本次对话中的经验、约束或规则是否应沉淀到 `CLAUDE.md`？
- 现有 `CLAUDE.md` 是否有表述不清或与实际操作冲突的地方？
- 提出的 `CLAUDE.md` 修改建议**仅作为建议输出，不得自动写入**，必须经用户审核确认后由 `/build` 流程执行。

### 5. 归档内容审查

- 本次对话是否产生了值得归档的总结？
- `handoff.md` / `architecture.md` 内容是否准确、简洁、无敏感信息？
- 根据 workflow 类型，归档文件名是否符合命名规则？

### AUDIT 阶段输出

- 将审查发现按「阻塞 / 建议 / 通过」分类。
- 阻塞级问题需用户确认修复后再归档。
- 建议级问题可与归档方案一同展示，由用户决定是否延后处理。

## 改动清单

### 1. `hooks/documentation/archive.sh`

重写归档逻辑：

- **CLI 参数**：`archive.sh [DESCRIPTION] [STATE_DIR]`（保持极简）
- **会话定位**：读取 `CLAUDE_SESSION_ID`，默认 `default`，操作 `.claude/state/sessions/<id>/`。
- **会话总结归档规则**（自动检测非空文件，无需 CLI 开关）：
  - build：`sessions/<id>/handoff.md` → `archive/<timestamp>-<desc>-build-handoff.md`
  - read：`sessions/<id>/handoff.md` → `archive/<timestamp>-<desc>-read-report.md`
  - arch：`sessions/<id>/architecture.md` → `archive/<timestamp>-<desc>-arch-model.md`
  - general：`sessions/<id>/handoff.md` → `archive/<timestamp>-<desc>-general-summary.md`
  - `session.md` 与 `plan.md` **不归档**，避免与总结内容重复
- **workflow 类型推断**：读取 `session.md` frontmatter 的 `current_phase` 与 `task`，映射到 build / read / arch / general。
- **索引维护**：归档成功后，在 `.claude/state/archive/index.md` 追加条目。
- **清理**：归档 handoff 后清空该文件；归档完成后重置 `session.md`。

### 2. `hooks/documentation/pre-summarize.sh`

- 检查 frontmatter 完整性。
- 检查旧路径 `.claude/session.md` 是否存在，输出迁移警告。
- 检查会话隔离：若 `CLAUDE_SESSION_ID` 为 `default` 且存在其他会话目录，或当前会话目录外存在 dirty 状态，输出并发警告。

### 3. `skills/documentation/SKILL.md`

- 在核心阶段中新增 **AUDIT** 阶段，位于 PACKAGE 之后、ARCHIVE_TRIGGER 之前。
- 明确内容分层：中间状态、归档产物、长期记忆。
- 更新 ARCHIVE_TRIGGER：展示 AUDIT 结果、归档方案，询问 handoff 归档确认。
- 更新「与 hooks 的边界」表，加入 index.md 维护、会话隔离、审查逻辑。

### 4. 新增提示模板

- `prompt-templates/documentation/audit.md`：AUDIT 阶段执行模板，覆盖提示词合理性（归纳通用提示）、文档冲突、状态架构、`CLAUDE.md` 优化、归档内容审查。
- 更新 `prompt-templates/documentation/package.md`：
  - 生成交接摘要后输出归档方案
  - 说明 session.md / plan.md 不归档
  - 根据 workflow 类型展示对应的归档命名
  - 询问用户是否归档总结文件

### 5. `CLAUDE.md`

新增/重写「**状态架构与归档规则**」小节：

- 三层内容模型：中间状态、归档产物、长期记忆。
- 规范路径与会话隔离：`sessions/<id>/` 与 `CLAUDE_SESSION_ID`。
- 归档索引 `archive/index.md` 的作用与读取方式。
- 工作流感知命名：build-handoff / read-report / arch-model / general-summary。
- 归档审查要求：每次 `/summarize` 必须审视提示词、文档冲突、状态架构、`CLAUDE.md` 优化。
- `CLAUDE.md` 变更受控：所有增改建议必须经用户审核，不得自动写入。
- handoff 命名规则与确认流程。
- 旧路径 `.claude/session.md` 的处理建议。

### 6. 会话目录初始化

- 在会话开始时（可由 skill 或 hook 负责）确保 `.claude/state/sessions/<id>/` 存在，并创建初始 `session.md`。
- 初始 `session.md` 模板与当前 `.claude/state/session.md` 一致。

## 算法流程

```
用户输入 /summarize
  → pre-summarize hook 检查：frontmatter、旧路径 .claude/session.md、并发冲突
  → REVIEW（回顾本次会话）
  → ALIGN（对照 goal-tracker.md 对齐目标）
  → EVALUATE（回答质量评估）
  → PACKAGE（生成交接摘要 handoff.md / architecture.md）
  → AUDIT（归档审查）
       - 提示词合理性（归纳通用提示）
       - 文档冲突
       - 状态架构
       - CLAUDE.md 优化建议（仅建议，不自动写入）
       - 归档内容审查
  → 展示 AUDIT 结果 + 归档方案
       - build：handoff.md → archive/<timestamp>-<desc>-build-handoff.md
       - read：handoff.md → archive/<timestamp>-<desc>-read-report.md
       - arch：architecture.md → archive/<timestamp>-<desc>-arch-model.md
       - general：handoff.md → archive/<timestamp>-<desc>-general-summary.md
       - session.md / plan.md 不归档
  → 询问用户是否归档总结文件
       - 若否：skill 清空对应中间状态文件
  → 用户确认后调用 archive.sh <desc>
  → archive.sh 迁移产物、更新 index.md、重置状态文件
  → 报告归档结果与待修复的 AUDIT 建议
```

## 接口 / CLI 参数

### archive.sh

```bash
archive.sh [DESCRIPTION] [STATE_DIR]
```

- `DESCRIPTION`：归档文件简短描述，默认 "session"。
- `STATE_DIR`：状态文件目录，默认 `.claude/state`。
- 通过 `CLAUDE_SESSION_ID` 环境变量定位会话子目录。

### 环境变量

| 变量 | 说明 |
|------|------|
| `CLAUDE_SESSION_ID` | 可选。设置后中间状态存放在 `sessions/<id>/`。未设置默认 `default`。 |

### workflow 类型推断

| session.md 线索 | 推断类型 |
|-----------------|----------|
| current_phase 为 UNDERSTANDING/PLANNING/EXECUTING/VERIFYING/REFLECTING | build |
| current_phase 为 SCOPE/HYPOTHESIS/EVIDENCE/REPORT/FIX | read |
| current_phase 为 SCOPE/SURVEY/DRILL/CONNECT/MODEL | arch |
| 其他或无法识别 | general |

`task` 字段含 "build" / "read" / "arch" 关键字时优先按关键字匹配。

## 验证步骤

1. 创建临时会话目录，运行 `archive.sh <desc>`，验证仅归档非空 `handoff.md` / `architecture.md`。
2. 验证 `session.md` / `plan.md` 未被迁移，仅被重置。
3. 验证 `archive/index.md` 正确追加条目与链接。
4. 设置 `CLAUDE_SESSION_ID=test`，验证 `archive.sh` 操作 `sessions/test/` 目录。
5. 运行 `pre-summarize.sh` 验证旧路径警告与并发冲突检测。
6. 检查新增 `audit.md` 模板是否覆盖五类审查问题（含 `CLAUDE.md` 优化）。
7. 验证 AUDIT 阶段提出的 `CLAUDE.md` 建议不会自动写入，仅作为建议输出。
7. 检查 `skills/documentation/SKILL.md`、`CLAUDE.md`、命令入口 frontmatter 完整。
8. 运行 shellcheck 检查 hook 脚本语法。

## 风险与回退方案

| 风险 | 影响 | 回退 |
|------|------|------|
| 会话目录结构变更破坏现有 `.claude/state/session.md` | 当前状态丢失 | 迁移：首次运行时提示用户将旧 `session.md` 移动到 `sessions/default/session.md` |
| AUDIT 阶段输出过长或过于严格 | 归档流程阻塞 | 将 AUDIT 建议分为阻塞/建议两级，仅阻塞项必须修复 |
| 未设置 `CLAUDE_SESSION_ID` 时多会话冲突 | 中间状态被覆盖 | hook 检测并警告；推荐并发会话设置不同 ID |
| 现有 archive/ 文件未进入 index.md | 历史 handoff 不可发现 | 首次部署后手动补充或保留旧文件并仅对新归档追加 |
| AUDIT 阶段误将 `CLAUDE.md` 建议自动写入 | 协作规则被擅自修改 | 在模板与 skill 中明确禁止自动写入，所有建议必须用户确认后由 `/build` 执行 |

