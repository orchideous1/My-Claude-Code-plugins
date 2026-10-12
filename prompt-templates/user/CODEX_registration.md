<!-- structured-development-workflows:start -->
## 结构化开发工作流

- 用户级 skills：`~/.codex/skills/{read,build,arch,summarize}/`
- 运行时：`~/.codex/structured-development-workflows/`
- 会话治理 hook：`~/.codex/hooks.json`
- 项目存在 `.claude/state/active-sessions.yaml` 时，按 Git 分支、路径归属、阶段和批准状态执行治理。
- 项目长期事实统一使用项目自己的 `.claude/state/`。
<!-- structured-development-workflows:end -->
