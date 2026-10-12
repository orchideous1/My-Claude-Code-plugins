# 工作区协作入口

本文件只定义在当前仓库协作时必须执行的最小流程。插件自身的技能、脚本、hook、
状态模型和归档实现说明维护在根目录 `CLAUDE.md`，不得复制到这里。

## 协作顺序

1. 默认使用中文沟通和维护协作文档。
2. 开始长期任务前，依次阅读 `development-governance.md`、
   `active-sessions.yaml`、`goal-tracker.md` 和当前会话目录。
3. 先检查 Git 分支与未提交修改；不得覆盖其他会话或用户已有工作。
4. 计划获批后再修改生产文件，范围以 active session 的 owned/shared paths 为准。
5. 实现、测试、契约文档和 `session.md` 同步更新；退出前记录验证结果与下一步。

## 事实源

- 开发治理：`.claude/state/development-governance.md`
- 活跃会话：`.claude/state/active-sessions.yaml`
- 项目目标：`.claude/state/goal-tracker.md`
- 已落地架构：`.claude/state/architecture.md`
- 内容职责：`.claude/state/session-content-guide.md`
- 插件实现规范：`CLAUDE.md`

工具专属目录只保存入口、配置或 skill 适配；长期项目事实统一维护在
`.claude/state/`，不得在 `.codex/`、`.kimi/` 或其他目录建立平行副本。

<!-- structured-governance:start -->
## 层级化开发治理

```text
L0 .claude/CLAUDE.md
└─ L1 .claude/state/development-governance.md
   ├─ L2 git-workflow.md / CONTRIBUTING.md
   ├─ L2 session-content-guide.md
   └─ L2 active-sessions.yaml
      └─ L3 goal-tracker.md / architecture.md / sessions/<session-id>/
```

`active-sessions.yaml` 是分支、会话和路径归属的机器可读事实源。会话中的长期跟踪
文件按内容职责增量维护，禁止整文件覆盖或用临时日志替代权威状态。
<!-- structured-governance:end -->
