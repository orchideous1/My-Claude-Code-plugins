---
name: architecture-understanding
description: 当用户需要理解复杂项目、模块或数据流架构时触发
---

# 架构理解循环

## 用途

通过迭代探索建立复杂代码库的正确心智模型。每个阶段都有门控，防止一次性理解全部代码或跳过关键验证。

## 何时使用

- 加入新项目
- 需要理解大型系统如何组合
- 准备重构或扩展复杂模块
- 为他人记录架构

## 工作流循环

### 阶段 1：SCOPE（范围）

定义要回答的架构问题。

1. 焦点区域是什么？（整个系统、模块、功能、数据流）
2. 为什么要理解它？
3. 入口点在哪里？
4. 什么不在范围内？

**→ SCOPE → SURVEY 门控**：
- 焦点必须具体、可回答
- 如果范围过大或模糊，拆小或重新定义

使用提示模板：`~/.claude/prompt-templates/architecture/scope.md`

### 阶段 2：SURVEY（概览）

在不读内部的情况下映射高层结构。

1. 目录结构和模块边界
2. 构建/包配置
3. 公开 API、CLI 命令、主入口点
4. 关键配置文件
5. 测试结构

如果项目很大，每个模块派一个子代理。

**→ SURVEY → DRILL 门控**：
- 必须有高层地图（目录、模块、入口点）
- 确定最重要的 3-5 个组件作为 DRILL 目标

使用提示模板：`~/.claude/prompt-templates/architecture/survey.md`

### 阶段 3：DRILL（深入）

挑选组件深入理解。

1. 确定焦点区域中最重要的组件
2. 对每个组件理解：
   - 单一职责是什么？
   - 暴露了什么？
   - 依赖什么？
   - 生命周期如何？
3. 每个组件使用一个 `Explore` 子代理

**→ DRILL → CONNECT 门控**：
- 每个关键组件必须有职责、接口、依赖说明
- 如理解不足，继续 DRILL 或调整组件选择

使用提示模板：`~/.claude/prompt-templates/architecture/drill.md`

### 阶段 4：CONNECT（连接）

追溯组件间关系。

1. 数据流：数据如何在系统中移动？
2. 控制流：谁调用谁？
3. 依赖关系：内部和外部
4. 状态归属：状态在哪里创建、变更、消费？

**→ CONNECT → MODEL 门控**：
- 必须有数据流和控制流的描述或图示
- 如关系不清，回到 DRILL 补充

使用提示模板：`~/.claude/prompt-templates/architecture/connect.md`

### 阶段 5：MODEL（建模）

综合为架构模型。

输出到 `.claude/state/architecture.md`：

1. 组件图（文本或 Mermaid）
2. 数据流描述
3. 接口契约
4. 关键决策和权衡
5. 开放问题 / 不确定区域

**→ MODEL 后门控（循环点）**：
- 检查开放问题：是否还有缺口？
- 如有缺口 → 回到 DRILL
- 如关系不清 → 回到 CONNECT
- 如范围错误 → 回到 SCOPE
- 如模型稳固 → 标记 DONE 并归档

使用提示模板：`~/.claude/prompt-templates/architecture/model.md`

## 状态更新

更新 `.claude/state/session.md`：
- `current_phase`: SCOPE | SURVEY | DRILL | CONNECT | MODEL
- `context.architecture_focus`
- `context.components`
- `context.relationships`
- `context.open_questions`

用 `.claude/state/architecture.md` 维护运行中的架构模型。

## 危险信号

- 试图一次性理解所有东西
- 不通过子代理直接读文件
- 不追溯实际代码就画架构图
- 跳过“开放问题”部分
