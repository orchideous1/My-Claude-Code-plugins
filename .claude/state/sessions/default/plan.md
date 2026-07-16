---
title: 二次迭代：会话 ID 派生、归档流程解耦、AUDIT 上下文隔离
status: draft
phase: PLANNING
created: 2026-07-16
updated: 2026-07-16
---

# 重构方案（第二版）

## 1. 方案摘要

针对以下四点反馈进行改造：

1. **会话 ID 应派生自内容关键词**：`ensure-state.sh` 增加 `SESSION_ID` 命令行参数；新增 `derive-session-id.sh` 从用户目标/焦点生成短 slug；skill 在启动时派生并持久化当前会话 ID。
2. **summarize 不复创建新 id**：summarize 沿用已有会话 ID；归档后删除原 `sessions/<id>/` 目录，而非仅重置文件。
3. **归档与 AUDIT 解耦**：重排 `summarize` 阶段为 REVIEW → ALIGN → EVALUATE → PACKAGE → ARCHIVE → AUDIT；PACKAGE 负责生成 guide 与归档方案并询问用户，ARCHIVE 调用脚本实际归档，只有确认归档后才总结归档内容。
4. **AUDIT 上下文隔离**：采用独立 sub-agent 执行 AUDIT，仅向其暴露 `session.md`、`plan.md`、`handoff.md`/`architecture.md`、相关 diff 与 `CLAUDE.md`，避免主会话上下文污染；同时保留 sub-agent 向用户追问重新对齐目标与架构理解的能力。

同时，为了与 skill 名保持一致，将目录 `skills/documentation/` 与 `prompt-templates/documentation/` 分别重命名为 `skills/summarize/` 与 `prompt-templates/summarize/`。

## 2. 文件清单

### 新增

- `scripts/core/derive-session-id.sh` — 从用户目标/焦点生成会话 ID slug
- `scripts/core/write-archive.sh` — 接收确认后的 guide 与归档名，写入 archive 并更新索引
- `scripts/core/cleanup-session.sh` — 归档后删除 `sessions/<id>/` 目录
- `prompt-templates/summarize/archive.md` — ARCHIVE 阶段模板
- 可选：`scripts/core/run-audit-agent.sh` — 准备上下文并启动 AUDIT sub-agent（若 sub-agent 方案被接受）

### 修改

- `scripts/core/ensure-state.sh` — 增加 `SESSION_ID` 参数与当前会话 ID 持久化
- `scripts/core/infer-workflow.sh` — 支持从 `.claude/state/.current-session-id` 读取 ID
- `scripts/core/reset-session.sh` — 支持从持久化文件读取 ID
- `scripts/core/archive-guide.sh` — 改为包装 `write-archive.sh` + `cleanup-session.sh`，或废弃
- `hooks/documentation/archive.sh`（若 hooks 目录保留）/ `hooks/summarize/archive.sh` — 改为调用 `write-archive.sh`
- `hooks/documentation/pre-summarize.sh` — 支持读取持久化会话 ID
- `skills/build/SKILL.md` — 派生 ID 并传给 ensure-state
- `skills/read/SKILL.md` — 同上
- `skills/arch/SKILL.md` — 同上
- `skills/summarize/SKILL.md` — 重排阶段，说明 ID 复用、归档解耦、AUDIT sub-agent
- `prompt-templates/summarize/package.md` — 生成归档方案并询问用户
- `prompt-templates/summarize/audit.md` — 改为 sub-agent 输入规范
- `prompt-templates/building/*.md`、`prompt-templates/reading/*.md`、`prompt-templates/architecture/*.md` — 更新 ensure-state 调用签名
- `CLAUDE.md` — 更新归档流程、AUDIT 子代理、目录名
- `.claude/settings.local.json` — 同步目录变更

### 重命名

- `skills/documentation/` → `skills/summarize/`
- `prompt-templates/documentation/` → `prompt-templates/summarize/`

### 删除

- 无新增删除（command 层已删除）

## 3. 接口 / CLI 参数

### `scripts/core/derive-session-id.sh <PHRASE>`

- 输入：用户目标或架构焦点短语。
- 输出到 stdout：短 slug（≤30 字符，保留中文/ASCII，空格/标点转连字符）。
- 示例：
  - "重构归档系统" → `重构归档系统`
  - "Fix login bug" → `Fix-login-bug`

### `scripts/core/ensure-state.sh [workflow] [STATE_DIR] [SESSION_ID]`

- `SESSION_ID`：新增可选参数。优先级：参数 > 环境变量 `CLAUDE_SESSION_ID` > `default`。
- 行为：除原功能外，将最终使用的 `SESSION_ID` 写入 `.claude/state/.current-session-id`，供同一会话后续脚本读取。

### `scripts/core/write-archive.sh <SOURCE_FILE> <DESCRIPTION> [WORKFLOW_TYPE] [STATE_DIR]`

- `SOURCE_FILE`：已确认的 guide 文件路径（如 `sessions/<id>/handoff.md`）。
- `DESCRIPTION`：用于文件名的简短描述。
- `WORKFLOW_TYPE`：可选，若省略则从 `session.md` 推断。
- 行为：
  1. 生成目标名：`archive/<timestamp>-<safe-desc>-<workflow>-<handoff|report|model|summary>.md`。
  2. 复制 guide。
  3. 更新 `archive/index.md`。
  4. 调用 `cleanup-session.sh` 删除 `sessions/<id>/`。

### `scripts/core/cleanup-session.sh [STATE_DIR] [SESSION_ID]`

- 删除指定会话目录（含 session.md、plan.md、handoff.md、architecture.md）。
- 若未提供 SESSION_ID，读取 `.claude/state/.current-session-id` 或环境变量。

## 4. 算法 / 数据流

### 4.1 工作流启动（build / read / arch）

1. skill 被触发。
2. 如果环境变量 `CLAUDE_SESSION_ID` 未设置，调用 `derive-session-id.sh "<user_goal/focus>"` 生成 ID。
3. 调用 `ensure-state.sh <workflow> .claude/state <SESSION_ID>`。
4. `ensure-state.sh` 将会话 ID 持久化到 `.claude/state/.current-session-id`。
5. 后续阶段操作均使用 `sessions/<id>/`。

### 4.2 summarize 流程

1. skill 被触发。
2. 读取 `.claude/state/.current-session-id` 或环境变量，**不生成新 ID**。
3. 调用 `ensure-state.sh general .claude/state <id>`（仅确保目录存在）。
4. REVIEW → ALIGN → EVALUATE：读取 `session.md` 与 `goal-tracker.md`，输出到对话。
5. PACKAGE：
   - 根据 `session.md` 生成/完善 guide 文件（handoff.md 或 architecture.md）。
   - 生成归档方案（来源文件、目标文件名、摘要）。
   - **询问用户是否归档**。
   - 若用户选择不归档：
     - 询问是“需要继续修改 guide”还是“本次改进较小无需归档”。
     - 若继续修改 → 返回 PACKAGE 或 REVIEW。
     - 若无需归档 → 清空 guide 文件，结束 summarize。
6. ARCHIVE（用户确认归档后）：
   - 调用 `write-archive.sh <source> <description> [workflow_type]`。
   - 向用户总结归档内容（文件名、位置、摘要）。
7. AUDIT（独立阶段，可在 ARCHIVE 之后）：
   - 启动独立 sub-agent，传入 `session.md`、`plan.md`、guide 文件、相关 diff、`CLAUDE.md`。
   - sub-agent 输出审查结果；如有需要，可直接向用户提出重新对齐目标或架构理解的问题。
   - 主代理展示 sub-agent 报告。

## 5. AUDIT 上下文隔离方案

推荐采用 **独立 sub-agent** 而非新 OS 进程：

- **原因**：
  - 不需要依赖 `claude` CLI 是否支持非交互式 prompt，避免跨进程状态同步问题。
  - sub-agent 可以精确控制输入上下文，只读取审计所需文件。
  - sub-agent 返回的审查报告和问题可以由主代理展示，用户回复后由主代理继续流程，形成闭环。
- **输入给 sub-agent 的资料**：
  - `.claude/state/sessions/<id>/session.md`
  - `.claude/state/sessions/<id>/plan.md`
  - `.claude/state/sessions/<id>/handoff.md` 或 `architecture.md`
  - 本次会话涉及的代码 diff（`git diff`）
  - `CLAUDE.md`
- **sub-agent 任务**：
  - 审查提示词合理性、文档冲突、状态架构、`CLAUDE.md` 优化建议、归档内容。
  - 如发现目标偏差或架构理解问题，向用户提出澄清问题。
  - 输出分类结果：阻塞 / 建议 / 通过。

若用户坚持要用新进程，可再实现 `run-audit-agent.sh`，但其可靠性取决于 `claude` CLI 的具体行为。

## 6. 验证步骤

1. `bash -n` 检查所有新增/修改脚本。
2. 测试 `derive-session-id.sh`：中英文混合短语生成合法 slug。
3. 测试 `ensure-state.sh`：传入 `SESSION_ID` 参数，确认 `.claude/state/.current-session-id` 被写入。
4. 模拟完整 workflow：
   - 启动 `build` workflow，派生 ID；写入 session.md、plan.md、handoff.md。
   - 触发 `summarize`；确认使用相同 ID。
   - 选择不归档：确认 guide 被清空，会话目录保留。
   - 选择归档：确认 archive 生成 guide，原 `sessions/<id>/` 被删除，index.md 更新。
5. 检查无 `documentation` 目录残留引用。
6. 检查 `summarize` skill 阶段顺序与 AUDIT 子代理说明正确。

## 7. 风险与回退方案

| 风险 | 影响 | 回退方案 |
|------|------|----------|
| 持久化 `.current-session-id` 被意外覆盖 | 后续脚本使用错误会话 | 所有脚本优先使用显式参数；如文件不存在则回退到 `default` 并提示。 |
| 派生 ID 冲突 | 不同会话目录覆盖 | 若目录已存在且非空，ensure-state 提示冲突并附加短随机后缀。 |
| summarize 直接触发但无当前会话 | 无法归档 | skill 检测到无 `.current-session-id` 且无 dirty 会话目录时，按 general workflow 创建空 handoff 并提示。 |
| 用户拒绝 sub-agent 方案 | AUDIT 仍需在 main 上下文 | 保留 `audit.md` 模板作为 fallback，由主代理执行。 |

## 8. 预期变更总结

- 新增 3-4 个核心脚本，1 个 ARCHIVE 模板。
- 重命名 2 个目录（skills/documentation → summarize，prompt-templates/documentation → summarize）。
- 修改 5 个 skill、若干 prompt templates、hooks、CLAUDE.md。
- `summarize` 阶段明确为 REVIEW → ALIGN → EVALUATE → PACKAGE → ARCHIVE → AUDIT。
- 归档流程由 skill 控制，脚本只负责写入；归档后删除 `sessions/<id>/`。
- AUDIT 通过独立 sub-agent 实现上下文隔离。
