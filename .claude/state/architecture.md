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
- `.claude-plugin/` 与 `.codex-plugin/`：分别暴露 Claude Code 和 Codex 插件入口。
- `.claude/CLAUDE.md`、`AGENTS.md`、`.kimi/AGENTS.md`：当前源仓库的轻量协作入口。

运行时数据流为：工具入口加载 skill/hook，hook 读取目标工作区 `.claude/state/`，
再结合 Git 分支和工作树判断读写是否符合当前 active session。长期事实始终只有
`.claude/state/` 一份，工具目录不持有平行状态。

# 开放问题

- Codex Desktop 在当前会话中把项目 `.codex/` 挂载为只读 tmpfs，因此仓库使用根
  `AGENTS.md` 与 `.codex-plugin/` 提供可提交入口，不依赖 `.codex/` 持久化文件。
- Kimi 暂无与 Claude/Codex 等价的项目 hook 接入，本仓库先同步指令与 skills，强制
  阻断能力仍以支持 hook 的运行时为准。
