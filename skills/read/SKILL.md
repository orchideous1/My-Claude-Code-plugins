---
name: read
description: 当用户需要排查 bug、理解代码行为或调查意外行为时触发
---

# 系统化代码阅读 / 故障排查

## 用途

在不猜测的情况下理解代码或找到根因。本技能在每个阶段转换处设置门控，确保不跳过关键步骤。

## 何时使用

- 用户报告 bug
- 用户问“这段代码是做什么的？”
- 任何组件出现意外行为
- 测试失败

## 启动前必须执行

仅在调查需要跨会话跟进，或用户明确要求记录 session 时，在 SCOPE 阶段开始读写状态前：

1. 如果环境变量 `CLAUDE_SESSION_ID` 未设置，根据调查目标生成会话 ID。**会话 ID 避免使用中文**：先将调查目标提炼为英文（ASCII）短语，再传入脚本。
   ```bash
   SESSION_ID=$(~/.claude/scripts/core/derive-session-id.sh "{{INVESTIGATION_TARGET}}")
   ```
2. 调用 `ensure-state.sh` 初始化状态：
   ```bash
   ~/.claude/scripts/core/ensure-state.sh read .claude/state "${SESSION_ID:-${CLAUDE_SESSION_ID:-default}}"
   ```

短小、一次性的调查不创建 session，调查结论直接在报告中呈现。创建 session 时，脚本会创建 `.claude/state/sessions/<id>/` 并确保 `session.md` 的 frontmatter 完整；派生的 SESSION_ID 必须写入 `session.md` 的 `context.session_id` 字段。

## 工作流

### 阶段 1：SCOPE（范围）

定义调查边界。

1. 重述症状或问题
2. 确定入口点（URL、CLI 命令、函数调用）
3. 确定涉及的组件
4. 列出可疑文件或模块（只列不读）
5. 已创建 session 时，将范围写入 `.claude/state/sessions/<id>/session.md`

**→ SCOPE → HYPOTHESIS 门控**：
- `context.scope` 必须包含入口点、预期/实际行为、可疑位置
- 如果范围模糊，停留在 SCOPE，继续澄清

使用提示模板：`~/.claude/prompt-templates/reading/phase1-scope.md`

### 阶段 2：HYPOTHESIS（假设）

形成根因理论。

1. 仔细阅读错误信息和堆栈
2. 检查近期变更（git diff、提交）
3. 形成 1-3 个具体假设
4. 为每个假设说明可证实或证伪的证据

**→ HYPOTHESIS → EVIDENCE 门控**：
- 每个假设必须有“证实证据”和“证伪证据”
- 如果没有明确假设，停留在 HYPOTHESIS

使用提示模板：`~/.claude/prompt-templates/reading/phase2-hypothesis.md`

### 阶段 3：EVIDENCE（证据）

委派子代理阅读代码。

1. 为每个假设确定要检查的确切文件/函数
2. 每个调查目标派一个 `Explore` 子代理
3. 子代理报告：代码做什么、数据如何流动、哪里可能失败
4. 综合发现

**→ EVIDENCE → REPORT 门控**：
- 每个假设都必须被证据支持或反驳
- 如证据不足，返回 EVIDENCE 补充，或回到 HYPOTHESIS 修正假设

规则：
- 不要自己读大文件
- 一个子代理对应一个聚焦问题
- 将发现与假设对比

使用提示模板：`~/.claude/prompt-templates/reading/phase3-evidence.md`

### 阶段 4：REPORT（报告）

输出根因报告。

报告必须包含：
1. 确认的根因
2. 支持证据
3. 其他假设为何被排除
4. 修复计划
5. 风险

**→ REPORT → FIX 门控**：
- 必须获得用户明确批准（如“批准修复”）
- 在批准前，任何对生产代码的 Write/Edit 都被 hook 拦截

使用提示模板：`~/.claude/prompt-templates/reading/phase4-report.md`

## 状态更新

已创建 session 时，每个阶段后更新 `.claude/state/sessions/<id>/session.md`：
- `current_phase`: SCOPE | HYPOTHESIS | EVIDENCE | REPORT | FIX
- `context.investigation_target`
- `context.hypotheses`
- `context.evidence_summary`
- `context.root_cause`
- `context.proposed_fix`

## 危险信号

- 在报告根因前提出修复
- 不通过子代理直接阅读文件
- 跳过证据收集
- “我觉得可能是 X”
- 已决定创建 session 却不先调用 `ensure-state.sh`
