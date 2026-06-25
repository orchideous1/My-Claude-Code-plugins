---
name: using-workflows
description: 在每次会话开始时加载，强制先检查工作流技能
---

# 工作流使用规范

在每次会话开始时，本技能自动加载。

## 核心纪律

如果你认为当前任务可能适用于以下任一工作流技能，**必须**先调用对应技能：

| 场景 | 调用技能 |
|------|----------|
| 排查 bug、理解代码、调查异常 | `systematic-reading` |
| 生成代码、重构、修改行为 | `structured-building` |
| 理解项目/模块/数据流架构 | `architecture-understanding` |
| 收尾会话、更新文档、归档 | `documentation` |

## 命令入口

用户可以通过以下命令触发工作流：

- `/read [目标]`
- `/build [目标]`
- `/arch [焦点]`
- `/summarize`

## 禁止事项

- 不检查技能就直接开始复杂任务
- 用普通对话绕过 `/read`、`/build`、`/arch`
- 在命令中重复 skill 已经定义的工作流细节
