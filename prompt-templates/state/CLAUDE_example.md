# 工作区协作入口

本文件只定义当前项目的最小协作规则；项目进度、会话状态和长期架构由
`.claude/state/` 下的权威文档维护，不在这里复制。

## 协作顺序

1. 阅读 `development-governance.md`、`active-sessions.yaml`、`goal-tracker.md` 和当前会话目录。
2. 检查 Git 分支与未提交修改，不覆盖其他会话或用户已有工作。
3. 计划获批后再修改生产文件，范围以 active session 的 owned/shared paths 为准。
4. 实现、测试、契约文档和 `session.md` 同步更新；退出前记录验证结果与下一步。

## 项目约束

- 在此补充运行环境、构建命令、测试约定和必要领域不变量。
- 不记录单次会话进度、运行日志或临时实验数字。
- 工具专属目录只保存入口和配置，不建立长期状态副本。

## 事实源

- 开发治理：`.claude/state/development-governance.md`
- 活跃会话：`.claude/state/active-sessions.yaml`
- 项目目标：`.claude/state/goal-tracker.md`
- 已落地架构：`.claude/state/architecture.md`
- 内容职责：`.claude/state/session-content-guide.md`
