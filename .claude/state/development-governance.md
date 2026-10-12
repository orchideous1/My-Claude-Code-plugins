---
title: 项目开发治理总则
status: current
updated: 2026-10-12
---

# 定位

本文是 `.claude/CLAUDE.md` 之后的唯一开发治理入口，只定义文档层级、权威顺序、
启动门禁和交付门禁。具体 Git 命令、会话内容职责和活跃会话事实分别下沉到对应 L2
文档，不在本文重复。

根目录 `AGENTS.md` 是非 Claude 智能体的项目协作入口，必须转入
`.claude/CLAUDE.md`；它不建立独立的治理层级或状态副本。用户级 skills、hooks 和
运行时安装在 `~/.claude`、`~/.codex` 与 `~/.kimi-code`，不写入项目工具目录。

# 文档层级

```text
L0 协作入口
└─ .claude/CLAUDE.md
   └─ L1 开发治理总则
      └─ .claude/state/development-governance.md
         ├─ L2 Git 操作规范: .claude/state/git-workflow.md
         ├─ L2 贡献检查指南: CONTRIBUTING.md
         ├─ L2 内容编排规范: .claude/state/session-content-guide.md
         └─ L2 活跃会话清单: .claude/state/active-sessions.yaml
            └─ L3 项目与会话状态
               ├─ .claude/state/goal-tracker.md
               ├─ .claude/state/architecture.md
               └─ .claude/state/sessions/<session-id>/
                  └─ L4 代码、测试、配置和运行入口
```

# 权威顺序

1. `.claude/CLAUDE.md` 的稳定协作约束。
2. 本文的治理层级和门禁。
3. `active-sessions.yaml` 的分支、状态和路径归属。
4. 当前会话的 `session.md` 与已批准 `plan.md`。
5. 算法、工程和数据契约文档。
6. 已落地的全局架构、目标追踪和长期参考。
7. 代码、测试和运行产物提供的实现证据。

代码与文档冲突时不得静默选择一方；应在同一行为提交中修正实现、测试和权威文档。

# 启动门禁

1. 阅读 `.claude/CLAUDE.md`、本文和 `active-sessions.yaml`。
2. 阅读 `goal-tracker.md`，确认跨会话依赖。
3. 执行 `git status --short --branch`，不得覆盖现有修改。
4. 进入清单登记的会话分支。
5. 阅读该会话的 `session.md`、`plan.md` 及适用的领域文档。
6. 未完成上述步骤前不得修改生产代码。

# 交付门禁

- 一个行为一个提交，代码、测试和会话状态同步。
- 修改范围不得越过 active session 的 owned/shared paths。
- 退出前记录当前阶段、最后动作、验证结果、阻塞和下一步。
- 长期结论收敛后再关闭会话；运行产物和未提交工作树不是长期记忆。
