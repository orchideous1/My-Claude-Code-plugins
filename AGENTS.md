# 工作区协作入口

本仓库的跨智能体长期事实统一存放在 `.claude/state/`。开始任务时先阅读
`.claude/CLAUDE.md`，再按其中顺序读取治理文档和当前会话状态。

## 必须遵守

- 默认使用中文沟通和维护协作文档。
- 先检查 Git 分支、active session 和未提交修改，不覆盖其他会话的工作。
- 计划获批后再修改生产文件，只写当前会话拥有或共享的路径。
- 同步维护测试、契约和 `session.md`；结束前记录验证结果、阻塞和下一步。
- 根目录 `CLAUDE.md` 是插件实现说明，不是工作区状态文件。
- `.codex`、`.kimi` 仅提供工具入口；不得复制 `.claude/state` 中的长期事实。

插件的 Codex skills 由 `.codex-plugin/plugin.json` 暴露；会话治理以
`.claude/state/active-sessions.yaml` 为机器可读事实源。
