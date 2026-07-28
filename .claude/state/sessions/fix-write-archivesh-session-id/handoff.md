---
---

# 交接摘要：修复 write-archive.sh 的两个阻塞 bug

## 背景

上一会话完成了"移除 `.current-session-id` 持久化机制"的改造（commit `6686d8e`），随后在归档过程中暴露并修复了 `write-archive.sh` 的 SIGPIPE bug（commit `0ca7d4b`）。AUDIT 阶段由独立 sub-agent 审查后发现 **2 个阻塞 bug**、3 个建议项、1 个重新对齐问题，均需在 `write-archive.sh` 与 `CLAUDE.md` 中继续修复。

参考材料：

- 上一会话的归档 guide：`.claude/state/archive/2026-07-18-003428-移除current-session-id持久化-build-handoff.md`
- 相关 commit：`6686d8e`（移除持久化机制）、`0ca7d4b`（修复 SIGPIPE）
- 目标文件：`scripts/core/write-archive.sh`、`CLAUDE.md`

## 阻塞 1：SESSION_ID 来源错误

**位置**：`scripts/core/write-archive.sh:42`

**现状**：

```bash
SESSION_ID="${CLAUDE_SESSION_ID:-default}"
```

**问题**：仅从环境变量读取，未从 `SOURCE_FILE` 路径推断。`hooks/summarize/archive.sh` 已从路径推断 SESSION_ID 并显式传给 `cleanup-session.sh`，但未传给 `write-archive.sh`。导致 `archive/index.md` 的"会话"字段错记为 `default`（真实 ID 是上一会话的 `remove-current-session-id-pers`）。

**修复方向**：在 `write-archive.sh` 内部同样从 `SOURCE_FILE` 推断 SESSION_ID（正则 `sessions/[^/]+/`），环境变量仅作回退。示例：

```bash
SESSION_ID="${CLAUDE_SESSION_ID:-}"
if [[ -z "$SESSION_ID" ]] && [[ "$SOURCE_FILE" =~ sessions/[^/]+/ ]]; then
    SESSION_ID=$(basename "$(dirname "$SOURCE_FILE")")
fi
SESSION_ID="${SESSION_ID:-default}"
```

**验证**：构造测试会话 `sessions/test-x/{session.md,handoff.md}`，调用 `archive.sh`，`tail .claude/state/archive/index.md` 确认"会话"字段为 `test-x` 而非 `default`。

## 阻塞 2：SUMMARY 提取语义 bug

**位置**：`scripts/core/write-archive.sh:87`

**现状**：

```bash
SUMMARY=$(awk '/^# /{p=1; next} p && NF {print; exit}' "$SOURCE_FILE")
```

**问题**：只跳过一级标题 `# `，不跳过 `## `、`### ` 等。上一会话 handoff 的结构是 `# 交接摘要` → 空行 → `## 目标与约束`，导致 `index.md` 的"摘要"字段被错抓为 `## 目标与约束` 而非真正的一句话摘要。

**修复方向**：跳过所有标题行（以 `#` 开头）后取首个非空正文行：

```bash
SUMMARY=$(awk '/^#/{next} NF {print; exit}' "$SOURCE_FILE")
```

**验证**：同上构造测试会话，`tail .claude/state/archive/index.md` 确认"摘要"字段是正文而非任何 `#` 开头的标题。

## 建议 3：CLAUDE.md 对 pre-summarize.sh 的描述漂移

**位置**：`CLAUDE.md` 第 134-140 行附近（"归档 hooks" section）

**现状**：仍写"使用持久化的会话 ID 补全当前会话状态"。该描述在移除 `.current-session-id` 改造前已不准确（脚本实际用 `CLAUDE_SESSION_ID` 环境变量），改造后"持久化"一词更误导（暗示已删除的 `.current-session-id`）。

**修复方向**：改为"使用 `CLAUDE_SESSION_ID` 环境变量（未设置时回退 `default`）补全当前会话状态"。

## 建议 4：归纳通用提示

**位置**：`CLAUDE.md`「状态脚本」section 开头

**现状**：build/read/arch/summarize 四个 SKILL.md 各自重复"显式传 SESSION_ID"约定。

**修复方向**：在「状态脚本」section 开头加一条总规则："所有 `scripts/core/*.sh` 调用必须显式传 SESSION_ID 参数或 `CLAUDE_SESSION_ID` 环境变量；脚本不再读共享文件。"然后精简四处 skill 描述。

## 建议 5（可选）：ensure-state.sh 自动注入 context.session_id

**位置**：`scripts/core/ensure-state.sh`

**现状**：build/read/arch skill 要求主代理把派生的 SESSION_ID 写入 `session.md` 的 `context.session_id`，但 `ensure-state.sh` 不会自动写。属主代理责任，可执行，但 handoff 中"主代理丢失上下文"风险正来源于此。

**修复方向（可选）**：给 `ensure-state.sh` 加 `--write-context` 选项，自动把 SESSION_ID 注入 `session.md` 的 `context.session_id` 字段。

## 重新对齐问题（留待用户决策）

上一会话 handoff 的"验证结果"表声称"端到端归档成功"，但未发现 `index.md` 元数据错配（即上述阻塞 1 与 2）。

**问题**：是否需要在 build 流程的 VERIFYING 阶段加一条强制门："归档后必须 `tail .claude/state/archive/index.md` 人工核对最新条目的'会话'与'摘要'字段"？

**决策权**：用户。若接受，需更新 `skills/build/SKILL.md` 的 VERIFYING 阶段门控条件。

## 执行建议

1. 按 build 流程走：UNDERSTANDING → PLANNING → EXECUTING → VERIFYING → REFLECTING。
2. 阻塞 1 与 2 必须修复；建议 3 与 4 强烈推荐；建议 5 可选；重新对齐问题先问用户。
3. 修复后**务必**通过端到端归档路径验证 `index.md` 字段正确。
4. 同步 `~/.claude/scripts/core/write-archive.sh` 部署副本。
5. 按 CLAUDE.md 规则，CLAUDE.md 的所有增改需经用户审核。

## 相关文件

- `scripts/core/write-archive.sh`（主修）
- `CLAUDE.md`（建议 3、4）
- `skills/build/SKILL.md`（重新对齐问题若接受）
- `hooks/summarize/archive.sh`（参考：如何正确从 SOURCE_FILE 推断 SESSION_ID）
