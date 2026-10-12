---
title: 项目架构
status: current
updated: 2026-10-12
---

# 系统边界

本仓库提供结构化开发 skills、状态模板、状态脚本和 Git 会话治理 hook。它既是插件
源仓库，也是多类智能体在当前工作区中的协作入口；业务项目状态不属于本仓库。

# 组件与数据流

- `skills/`：read、build、arch、summarize 的阶段与门禁真相源。
- `scripts/core/`：状态初始化、会话 ID、归档和治理骨架等确定性操作。
- `hooks/session-governance.py`：读取目标项目的 `active-sessions.yaml`，执行分支、路径、
  阶段、批准和长期文档保护。
- `prompt-templates/state/`：L0-L3 治理与会话文档模板。
- `.claude-plugin/` 与 `.codex-plugin/`：分别暴露 Claude Code 和 Codex 源插件入口。
- `scripts/core/sync-user-runtimes.py`：把运行时注册到 `~/.claude`、`~/.codex` 和
  `~/.kimi-code`。
- `.claude/CLAUDE.md` 与 `AGENTS.md`：当前源仓库的项目协作入口，不承载插件安装。

运行时数据流为：工具入口加载 skill/hook，hook 读取目标工作区 `.claude/state/`，
再结合 Git 分支和工作树判断读写是否符合当前 active session。长期事实始终只有
`.claude/state/` 一份，工具目录不持有平行状态。

# 开放问题

- Kimi 暂无与 Claude/Codex 等价的 hook 注册，因此同步 skills 和运行时，但强制
  阻断能力仍以支持 hook 的运行时为准。
