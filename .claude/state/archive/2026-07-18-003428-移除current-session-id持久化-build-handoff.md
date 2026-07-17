---
---

# 交接摘要

## 目标与约束

移除 `.claude/state/.current-session-id` 持久化机制，消除多会话并发场景下的文件互相覆盖问题。

**约束**：

- 所有脚本 CLI 签名保持不变，仅内部行为收敛
- 只改源仓库（`/home/linyiwu/My-Claude-Code-plugins/`），部署副本由用户同步
- 旧 `default` 会话（2026-07-16 二次迭代重构残留）直接清理不归档

## 问题分析

### 设计缺陷

`.current-session-id` 是工作区级单文件，多会话共享时互相覆盖：

```
会话 A 启动 arch → 写入 "feature-a"
会话 B 同时启动 build → 覆盖为 "fix-bug"
会话 A 调用 cleanup-session.sh（无参） → 读到 "fix-bug"，误删会话 B 目录
```

### 实际价值有限

代码审查发现：真正读取 `.current-session-id` 的脚本（`infer-workflow.sh`、`write-archive.sh`、`cleanup-session.sh`、`reset-session.sh`）都把它当**回退路径**——只在"未显式传参 + 环境变量未设"时才读。而 `pre-summarize.sh` 和 `session-exit.sh` 根本不读它，直接用 `CLAUDE_SESSION_ID:-default`。

因此该文件只在"主代理派生 ID 但忘记传递"的粗心场景下有用，却引入并发 bug 和状态管理复杂度。

## 方案摘要与关键决策

**核心思路**：移除文件持久化，SESSION_ID 在调用链上通过显式参数传递；未收到时回退 `${CLAUDE_SESSION_ID:-default}`。

**关键决策**：

1. **修复 `archive.sh` 隐式依赖**：旧代码调 `cleanup-session.sh` 不传 ID，靠 `.current-session-id` 兜底。改造后从 `SOURCE_FILE` 路径推断 SESSION_ID（`sessions/<id>/` 目录名即 ID），显式传递，避免新增 CLI 参数。
2. **skill 层兜底**：build/read/arch 派生 ID 后写入 `session.md` 的 `context.session_id` 字段；summarize 主代理上下文丢失时从最近一次 `sessions/*/session.md` 读取。该逻辑由 skill 层（主代理）实现，脚本不感知。
3. **路径校验**：`archive.sh` 在推断前校验 `SOURCE_FILE` 必须匹配 `sessions/[^/]+/` 模式，不匹配则报错退出，防止误清理。

## 文件清单与接口变更

### 修改（11 个文件，无新增、无删除）

| 文件 | 关键改动 |
|------|----------|
| `scripts/core/ensure-state.sh` | 删除第 110-111 行 `echo "$SESSION_ID" > .current-session-id`；删除对应头部注释 |
| `scripts/core/infer-workflow.sh` | 第 19-30 行简化为 `SESSION_ID="${CLAUDE_SESSION_ID:-default}"`；删除读文件分支 |
| `scripts/core/write-archive.sh` | 第 42-47 行同上简化 |
| `scripts/core/cleanup-session.sh` | 第 18-24 行同上简化；删除第 36-42 行清理 `.current-session-id` 的代码块 |
| `scripts/core/reset-session.sh` | 第 15-26 行同上简化 |
| `hooks/summarize/archive.sh` | 新增：路径模式校验 + `SESSION_ID=$(basename "$(dirname "$SOURCE_FILE")")` + 显式传给 `cleanup-session.sh` |
| `skills/build/SKILL.md` | 约定派生 ID 写入 `context.session_id` 并显式传递 |
| `skills/read/SKILL.md` | 同上 |
| `skills/arch/SKILL.md` | 同上 |
| `skills/summarize/SKILL.md` | 启动流程改为"复用上下文 ID → 读最近 session.md → 回退环境变量或 default" |
| `CLAUDE.md` | 同步删除两处 `.current-session-id` 描述；补充 `archive.sh` 路径推断说明 |

### CLI 签名

**全部不变**。仅行为变化：不再读/写 `.current-session-id`。

## 验证结果

| 验证项 | 结果 |
|--------|------|
| `bash -n` 语法检查（6 个可执行文件） | 通过 |
| `grep -rn "current-session-id"` 源仓库残留 | 零残留 |
| `ensure-state.sh build .claude/state test-a` 后检查文件 | 未生成 `.current-session-id` |
| `infer-workflow.sh` 无参调用（环境变量未设） | 输出 `general`（回退 default） |
| `CLAUDE_SESSION_ID=test-a infer-workflow.sh` | 输出 `general`（IDLE 阶段） |
| `cleanup-session.sh .claude/state test-a` | 正确删除，不依赖 `.current-session-id` |
| 并发：`cone-a` + `cone-b` 同时 `ensure-state.sh` | 两个 `sessions/<id>/` 并存，无共享文件 |
| 端到端归档：构造 `sessions/test-b/` → `archive.sh` | 归档成功，`test-b` 被正确清理 |

**附带清理**：

- 旧 `default` 会话目录（4 个文件）
- 历史 `.current-session-id` 残留（19:22 由改造前脚本写入）
- 测试产物 `cone-a`、`cone-b`、`test-b` 与对应归档条目

## 提交与部署

- Commit：`6686d8e` — "remove .current-session-id persistence mechanism"
- 部署：`rsync` 同步到 `~/.claude/scripts/core/`、`~/.claude/skills/{arch,build,read,summarize}/`、`~/.claude/hooks/summarize/`
- 验证：`~/.claude/` 副本 grep 零残留

## 待办与风险

### 已知风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| 主代理在 workflow 中途丢失 SESSION_ID 上下文 | summarize 回退到 default | skill 约定派生后立即写入 `session.md` 的 `context.session_id`；summarize 从最近修改的 `sessions/*/session.md` 读取 |
| 已部署的 `~/.claude` 副本仍是旧版本 | 行为分裂 | 已通过 rsync 同步 |
| `archive.sh` 推断 SESSION_ID 失败 | 清理错目录 | 路径模式校验，不匹配则报错退出 |

### 遗留问题（未纳入本次范围）

1. **CLAUDE.md 文档漂移**：`pre-summarize.sh` 的描述写"使用持久化的会话 ID 补全当前会话状态"，但该脚本实际使用 `CLAUDE_SESSION_ID` 环境变量，与 `.current-session-id` 无关。改造前已存在，留给 AUDIT 阶段提出。
2. **用户全局 `~/.claude/CLAUDE.md`**：包含与项目级 CLAUDE.md 类似的 `ensure-state.sh` 描述，按"只改源仓库"决策未动。用户需自行评估是否同步。

### 下次入口

无遗留代码任务。如未来发现 SESSION_ID 上下文丢失导致 summarize 回退 default 频繁发生，可考虑在 skill 层增加"自动从 `sessions/` 扫描最新 dirty 目录"的兜底（当前由 summarize skill 文档描述，主代理实现）。
