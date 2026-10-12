# Contributing

本仓库使用“长期会话 + Git 提交”共同维护项目记忆。开始修改前先阅读
`.claude/CLAUDE.md`、开发治理总则、活跃会话清单、Git 工作流、内容编排规范以及
当前会话文档。

## 必须遵守

- 生产代码只在 `active-sessions.yaml` 登记的会话分支修改。
- 只修改当前会话声明的 owned/shared paths。
- 代码、测试、契约和 `session.md` 在同一行为提交中保持一致。
- 算法、接口或 schema 变化同步更新对应权威文档。
- 退出前运行项目验证、`git diff --check`，并记录验证结果和下一步。
- 数据、日志、缓存、模型文件、凭据和本地环境配置不得提交。
