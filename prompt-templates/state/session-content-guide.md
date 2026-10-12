---
title: 会话内容编排与文档职责
status: current
updated: YYYY-MM-DD
---

# 内容职责

| 载体 | 唯一职责 |
|---|---|
| `active-sessions.yaml` | 活跃会话、分支、路径归属和验证命令 |
| `goal-tracker.md` | 项目级目标、跨会话依赖和阻塞 |
| `architecture.md` | 已落地的跨模块架构和当前契约 |
| `session.md` | 当前阶段、最后动作、验证、阻塞和下一步 |
| `plan.md` | 已批准目标、范围、里程碑和验收条件 |
| `algorithm.md` | 决策流程、规则/模型边界和算法不变量 |
| `engineering.md` | 模块、接口、状态归属、并发、外部边界和测试对象 |
| `data-dict.md` / `data-contracts.md` | schema、字段、生产者、消费者、版本和持久化边界 |

# 最小与重大会话

最小会话只创建 `session.md` 和 `plan.md`。跨模块、改变 schema、状态归属、持久化或
主控制流的重大任务，再增加 `algorithm.md`、`engineering.md` 和数据契约文档。

# 更新矩阵

| 修改类型 | 必须同步更新 |
|---|---|
| 当前步骤、验证、阻塞或下一步 | `session.md` |
| 目标、范围、里程碑或验收 | `plan.md`，必要时 `goal-tracker.md` |
| 决策规则或模型/规则边界 | `algorithm.md` |
| 模块、接口、状态源、并发或外部依赖 | `engineering.md` |
| schema、字段、版本或持久化 | 数据契约文档及生产者/消费者测试 |
| 已落地的跨会话架构 | 全局 `architecture.md` |
| 分支、会话状态或路径归属 | `active-sessions.yaml` |

每项事实只保留一个权威定义；其他文档使用链接，不复制全文。文档保存决策与可复现
状态，不保存逐轮聊天转录、一次性日志或无证据统计。

# 可执行同步规则

对领域边界明确的项目，可在 `active-sessions.yaml` 的单个 session 下增加：

```yaml
document_rules:
  - paths: ["src/prompts/**"]
    require: ["algorithm.md"]
  - paths: ["src/core/**", "config/**"]
    require_any: ["engineering.md", "data-dict.md"]
```

Stop hook 会在命中代码路径但缺少对应文档变更时阻止结束。规则只表达文件同步关系；
内容是否正确仍由计划批准、评审和测试负责。

默认代码门控读取 `session.md` 的 `context.plan_approved`；调查修复的 `FIX` 阶段读取
`context.fix_approved`。若会话使用独立里程碑批准字段，可在对应 session 清单项声明：

```yaml
approval_field: milestone_2_approved
```
