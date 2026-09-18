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

仅在任务需要跨会话状态，或用户明确要求记录 session 时，在 UNDERSTANDING 阶段开始读写状态前执行：

1. 如果环境变量 `CLAUDE_SESSION_ID` 未设置，根据用户目标生成会话 ID。**会话 ID 避免使用中文**：先将用户目标提炼为英文（ASCII）短语，再传入脚本。
   ```bash
   SESSION_ID=$(~/.claude/scripts/core/derive-session-id.sh "{{USER_GOAL}}")
   ```
2. 调用 `ensure-state.sh` 初始化状态：
   ```bash
   ~/.claude/scripts/core/ensure-state.sh build .claude/state "${SESSION_ID:-${CLAUDE_SESSION_ID:-default}}"
   ```

短小、可在当前回合完成的改动不创建 session，仍需完成理解、计划、实现和验证。创建 session 时，脚本会创建 `.claude/state/sessions/<id>/` 并确保 `session.md` 与 `plan.md` 的 frontmatter 完整；派生的 SESSION_ID 必须写入 `session.md` 的 `context.session_id` 字段。

## 工作流

### 阶段 1：UNDERSTANDING（理解）

规划前先澄清：

1. 目标是什么？
2. 硬约束有哪些？
3. 成功标准是什么？
4. 有哪些已有代码或模式可复用？
5. 公开接口是什么（函数、CLI、API）？
6. 算法主流程是什么？按实际执行顺序列出关键步骤，区分主流程与辅助机制。
7. 每项领域状态的唯一来源是什么？谁创建、持有、修改和读取该状态？
8. 边界在哪里？明确领域逻辑与 Tool、Store、外部 API、文件系统、数据库、消息和序列化之间的边界。

**→ UNDERSTANDING → PLANNING 门控**：
- 用户意图和成功标准必须清晰
- 已识别算法主流程、领域状态唯一来源和外部边界；未知项必须显式列为待确认问题
- 如不清楚，停留在 UNDERSTANDING 继续询问

使用提示模板：`~/.claude/prompt-templates/building/understanding.md`

### 阶段 2：PLANNING（规划）

输出实现计划。

计划必须包含：
1. 方案摘要
2. 要创建或修改的文件及用途
3. 明确的接口与数据 schema：逐项写明输入、输出、状态归属、不变量、错误边界、序列化 / 持久化边界；不适用的项必须注明“不适用”及原因
4. 算法或数据流，标明领域状态的唯一来源以及 Tool、Store、外部 API 等边界
5. 每个新增或保留抽象的必要性表，至少包含以下列：名称、类型（算法步骤 / 领域状态 / 外部边界 / 独立横切机制）、调用者、被调用者、必要性、为何不能内联或下沉
6. substantial 修改的当前流程图与目标流程图；图中每个节点必须映射到必要性表中的抽象，必要性表中的每个抽象也必须能在流程图或边界说明中定位
7. 验证步骤，覆盖功能行为、接口契约、状态归属、schema 往返和抽象审计
8. 风险和回退方案

以下任一情况视为 substantial 修改：改变算法主流程、领域状态归属、持久化或序列化 schema、事务边界、外部接口，或任何新增、删除或合并抽象。纯局部且不改变这些内容的修改可不提供流程图，但必须说明为何不属于 substantial 修改。

**→ PLANNING → EXECUTING 门控（最关键）**：
- 必须获得用户明确批准
- `.claude/state/sessions/<id>/session.md` 中 `context.plan_approved` 必须设为 `true`
- 在批准前，hook 会拦截所有生产代码的 Write/Edit
- 计划中的 schema、抽象必要性表以及 substantial 修改所需的当前 / 目标流程图必须完整

使用提示模板：`~/.claude/prompt-templates/building/planning.md`

### 阶段 3：EXECUTING（执行）

按批准的计划实现。

规则：
- 只写计划规定的内容
- 不添加计划外功能
- 遵循现有代码模式
- 保持 CLI 简单；参数超过 5 个时用配置文件
- 脚本开头写用法 docstring
- 删除纯转发、重复检查以及仅包装后立即委托的层；除非该层是计划中论证过的外部边界或独立横切机制
- 检查若属于底层操作的固有语义，必须下沉到拥有该语义的最低合理层，避免调用者重复维护同一不变量
- 横切 wrapper 仅在与算法主流程无关，且独立保障原子性、锁、资源清理、审计或安全契约时保留；其边界和失败语义必须与计划一致
- 禁止从展示文本、消息内容或序列化 payload 反推系统中已经存在的领域状态；直接读取该状态的唯一来源
- 事务实现必须隐藏在 Tool、Store 等外部边界内；算法主流程只依赖边界契约，不拼装提交、回滚或锁细节
- 禁止为“统一形式”引入无具体收益的泛型、基类或框架；每个抽象必须对应已批准必要性表中的具体收益
- 不添加针对假想旧调用者、旧 schema、旧行为或未知外部消费者的兼容代码；只有已确认的持久化数据、已发布契约或明确用户要求才能构成兼容需求

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
5. 执行抽象审计：逐条检查实际调用链是否与计划一致，是否存在纯转发或仅 wrap 后委托的层
6. 检查每项领域状态是否仍有且仅有一个权威来源，未从展示、消息或序列化 payload 反推已有状态
7. 对所有序列化 / 持久化 schema 执行往返验证，并检查输入、输出、不变量和错误边界
8. substantial 修改需对照当前 / 目标流程图，确认目标节点、边界和抽象映射与实现一致
9. 检查无死代码、无调用抽象、重复检查和失去调用者的兼容分支

验证结果必须区分：
- **验证失败**：测试、构建、契约检查或抽象审计已运行但未通过；返回 EXECUTING 修复
- **环境阻塞**：因缺少依赖、权限、服务或硬件而无法运行；记录未执行项、阻塞证据和解除条件，不得记为通过
- **验证通过**：所有适用验证均已实际运行且通过；“未运行测试”不得声称为通过

**→ VERIFYING → REFLECTING 门控**：
- 所有适用验证必须实际运行并通过
- 如失败，返回 EXECUTING 修复，而不是跳过验证
- 如环境阻塞，保持在 VERIFYING，明确报告阻塞；除非用户接受未验证风险，否则不得进入完成状态

使用提示模板：`~/.claude/prompt-templates/building/verifying.md`

### 阶段 5：REFLECTING（反思）

收尾。

1. 总结变更内容
2. 更新相关文档
3. 更新 `.claude/state/goal-tracker.md`
4. 记录实际保留、新增、内联、下沉或删除的抽象，并逐项对照计划中的必要性表
5. 记录实际接口 / schema、状态归属、流程图与批准计划的偏差、偏差原因及用户是否重新批准；无偏差也要明确记录
6. 决定：完成、还是下一轮？

使用提示模板：`~/.claude/prompt-templates/building/reflecting.md`

## 状态更新

已创建 session 时，在 `.claude/state/sessions/<id>/session.md` 中跟踪进度：
- `current_phase`: UNDERSTANDING | PLANNING | EXECUTING | VERIFYING | REFLECTING
- `context.user_goal`
- `context.plan`
- `context.plan_approved`
- `context.last_action`
- `context.verification_result`
- `context.reflection`

已创建 session 时，计划在 `.claude/state/sessions/<id>/plan.md` 中维护；否则在用户确认的对话计划中维护。

## 危险信号

- 计划未批准就写代码
- 添加计划外功能
- 跳过验证
- 未识别算法主流程、领域状态唯一来源或外部边界就开始规划
- 接口 / schema 未说明输入、输出、状态归属、不变量、错误边界或序列化 / 持久化边界，且未解释不适用项
- 新增或保留抽象没有必要性表，或 substantial 修改没有当前 / 目标流程图及节点映射
- 保留纯转发、重复检查、仅 wrap 后委托的层，或把底层语义检查堆在上层
- 横切 wrapper 混入算法主流程，或不能独立保障原子性、锁、资源清理、审计或安全契约
- 从展示、消息或序列化 payload 反推已有领域状态，形成多个状态来源
- 事务提交、回滚或锁细节泄漏出 Tool、Store 等边界
- 为形式统一引入无具体收益的泛型、基类或框架
- 为未确认的旧调用者、旧 schema 或旧行为添加假想兼容
- 验证未审计调用链、状态唯一来源、schema 往返、流程图一致性、死代码或无调用抽象
- 将环境阻塞或未运行测试报告为验证通过
- 反思阶段未记录实际抽象与批准计划的偏差
- 已创建 session 却不更新状态文件
- 已决定创建 session 却不先调用 `ensure-state.sh`
