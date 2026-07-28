---
current_phase: REFLECTING
task: fix-write-archive-bugs
context:
  user_goal: 修复 write-archive.sh 的 SESSION_ID 来源与 SUMMARY 提取两个阻塞 bug；可选处理 CLAUDE.md 描述漂移与通用提示归纳
  session_id: fix-write-archivesh-session-id
  plan_approved: true
  source: 由上一会话 AUDIT 阶段产出，预创建供新会话使用
started: 2026-07-18
updated: 2026-07-18
---

# 当前会话

## 已完成

- 修复 `scripts/core/write-archive.sh`：
  - 阻塞 1：SESSION_ID 三段回退（环境变量 → SOURCE_FILE 路径推断 → default）。
  - 阻塞 2：SUMMARY 提取跳过 frontmatter 块（`---` 到 `---`）与所有 `#` 标题行，取首个非空正文行。frontmatter 跳过是在端到端验证中暴露的边界情况（原方案抓到了 `---` 分隔线）。
  - 更新 docstring 说明 SESSION_ID 回退顺序。
- 更新 `CLAUDE.md`：
  - 修正「归档 hooks → pre-summarize.sh」描述："持久化的会话 ID" → "CLAUDE_SESSION_ID 环境变量（未设置时回退 default）"。
  - 在「状态脚本」section 开头加通用约定：所有 scripts/core/*.sh 调用必须显式传 SESSION_ID 参数或 CLAUDE_SESSION_ID 环境变量。
- 精简 `skills/build/SKILL.md`、`skills/read/SKILL.md`、`skills/arch/SKILL.md`：删除各自重复的"显式传 SESSION_ID"约定，由 CLAUDE.md 通用规则承载。
- 端到端验证通过：
  - 场景 A（无环境变量，路径推断）：会话=test-e2e、摘要=正文首行。
  - 场景 B（CLAUDE_SESSION_ID=env-override）：会话=env-override（环境变量优先）。
  - 测试产物已完全清理，archive/index.md 恢复到验证前状态。
- 部署副本同步：`write-archive.sh` 与三个 SKILL.md 已 rsync 到 `~/.claude/`，diff 一致。

## 用户决策

- 拒绝在 build 的 VERIFYING 阶段加"归档后必须 tail index.md 人工核对"的强制门。
- 拒绝给 ensure-state.sh 加 --write-context 选项。

## 未做事项

- 未清洗 archive/index.md 中两条历史错配条目（会话=default、摘要=## 目标与约束），属审计痕迹保留。

## 下一步建议

- 可触发 summarize 归档本会话。
