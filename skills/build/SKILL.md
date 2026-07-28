---
name: build
description: 当用户需要生成新代码、重构或修改行为时触发
---

# 结构化代码生成

## 用途

通过一个受控的五阶段循环来构建、重构或修改代码。每个阶段转换都经过门控检查，尤其是执行与审计的分割。

## 何时使用

- 新功能
- Bug 修复（在 `read` 产出已批准的修复计划后）
- 重构
- 行为变更

## 启动前必须执行

在 UNDERSTANDING 阶段开始读写状态前：

1. 如果环境变量 `CLAUDE_SESSION_ID` 未设置，根据用户目标生成会话 ID：
   ```bash
   SESSION_ID=$(~/.claude/scripts/core/derive-session-id.sh "{{USER_GOAL}}")
   ```
2. 调用 `ensure-state.sh` 初始化状态：
   ```bash
   ~/.claude/scripts/core/ensure-state.sh build .claude/state "${SESSION_ID:-${CLAUDE_SESSION_ID:-default}}"
   ```

该脚本会创建 `.claude/state/sessions/<id>/` 并确保 `session.md` 与 `plan.md` 的 frontmatter 完整。派生的 SESSION_ID 必须写入 `session.md` 的 `context.session_id` 字段。

## 工作流

### 阶段 1：UNDERSTANDING（理解）

规划前先澄清：

1. 目标是什么？
2. 硬约束有哪些？
3. 成功标准是什么？
4. 有哪些已有代码或模式可复用？
5. 公开接口是什么（函数、CLI、API）？

**→ UNDERSTANDING → PLANNING 门控**：
- 用户意图和成功标准必须清晰
- 如不清楚，停留在 UNDERSTANDING 继续询问

使用提示模板：`~/.claude/prompt-templates/building/understanding.md`

### 阶段 2：PLANNING（规划）

输出实现计划。

计划必须包含：
1. 方案摘要
2. 要创建或修改的文件及用途
3. 接口 / CLI 参数
4. 算法或数据流
5. 验证步骤
6. 风险和回退方案

**→ PLANNING → EXECUTING 门控（最关键）**：
- 必须获得用户明确批准
- `.claude/state/sessions/<id>/session.md` 中 `context.plan_approved` 必须设为 `true`
- 在批准前，hook 会拦截所有生产代码的 Write/Edit

使用提示模板：`~/.claude/prompt-templates/building/planning.md`

### 阶段 3：EXECUTING（执行）

按批准的计划实现。

规则：
- 只写计划规定的内容
- 不添加计划外功能
- 遵循现有代码模式
- 保持 CLI 简单；参数超过 5 个时用配置文件
- 脚本开头写用法 docstring

**→ EXECUTING → VERIFYING 门控**：
- 检查修改的文件是否超出 `.claude/state/sessions/<id>/plan.md` 中的文件清单
- 如发现计划外文件，返回 PLANNING 补充或删除多余修改

使用提示模板：`~/.claude/prompt-templates/building/executing.md`

### 阶段 4：VERIFYING（验证）

运行验证。

1. 运行测试
2. 运行构建/编译
3. 执行计划中的具体验证步骤
4. 确认输出干净（无错误、无警告）

**→ VERIFYING → REFLECTING 门控**：
- 所有验证必须通过
- 如失败，返回 EXECUTING 修复，而不是跳过验证

使用提示模板：`~/.claude/prompt-templates/building/verifying.md`

### 阶段 5：REFLECTING（反思）

收尾。

1. 总结变更内容
2. 更新相关文档
3. 更新 `.claude/state/goal-tracker.md`
4. 决定：完成、还是下一轮？

使用提示模板：`~/.claude/prompt-templates/building/reflecting.md`

## 状态更新

在 `.claude/state/sessions/<id>/session.md` 中跟踪进度：
- `current_phase`: UNDERSTANDING | PLANNING | EXECUTING | VERIFYING | REFLECTING
- `context.user_goal`
- `context.plan`
- `context.plan_approved`
- `context.last_action`
- `context.verification_result`
- `context.reflection`

计划在 `.claude/state/sessions/<id>/plan.md` 中维护。

## 危险信号

- 计划未批准就写代码
- 添加计划外功能
- 跳过验证
- 不更新状态文件
- 不先调用 `ensure-state.sh`
