<!-- structured-development-workflows:start -->
## 结构化开发工作流

- 用户级 skills：`~/.claude/skills/{read,build,arch,summarize}/`
- 状态与初始化脚本：`~/.claude/scripts/core/`
- 会话治理 hook：`~/.claude/hooks/session-governance.py`
- 项目存在 `.claude/state/active-sessions.yaml` 时，按 Git 分支、路径归属、阶段和批准状态执行治理。
- 项目长期事实仍存放在项目自己的 `.claude/state/`，不得写入用户级配置目录。
<!-- structured-development-workflows:end -->
