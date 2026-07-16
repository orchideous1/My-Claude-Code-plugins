---
current_phase: EXECUTING
context:
  user_goal: 二次迭代重构：会话 ID 按内容关键词派生并传给 ensure-state；summarize 不复创建新 id，归档后删除原 sessions/<id>；归档与 AUDIT 解耦，PACKAGE 生成归档方案、ARCHIVE 调用脚本实际归档，提前询问是否归档；AUDIT 通过独立 sub-agent 与主会话上下文隔离。
  task: plugin-refactor-v3
  plan_approved: true
  clarifications:
    - ensure-state.sh 增加 SESSION_ID 参数；新增 derive-session-id.sh 生成短 slug。
    - 当前会话 ID 持久化到 .claude/state/.current-session-id，供后续脚本读取。
    - summarize 使用已有会话 ID，归档后删除 sessions/<id> 目录。
    - summarize 阶段改为 REVIEW → ALIGN → EVALUATE → PACKAGE → ARCHIVE → AUDIT。
    - PACKAGE 生成 guide 与归档方案，提前询问用户；不归档则区分“继续修改”或“无需归档”。
    - 只有确认归档后，才调用 write-archive.sh 并总结归档内容。
    - AUDIT 采用独立 sub-agent，仅暴露必要 state 文件与 diff。
    - 目录 skills/documentation 与 prompt-templates/documentation 重命名为 summarize，与 skill 名一致。
  plan_summary: |
    1. 新增 derive-session-id.sh、write-archive.sh、cleanup-session.sh。
    2. 改造 ensure-state.sh、infer-workflow.sh、reset-session.sh、archive-guide.sh，支持 SESSION_ID 参数与 .current-session-id 持久化。
    3. 重命名 skills/documentation 与 prompt-templates/documentation 为 summarize。
    4. 更新 build/read/arch/summarize skill 与所有模板。
    5. 更新 hooks 与 CLAUDE.md。
    6. 验证派生 ID、归档流程、目录删除、sub-agent AUDIT。
  last_action: 用户批准第二版计划，进入 EXECUTING
started: 2026-07-16
updated: 2026-07-16
---

# 当前会话

## 已完成

- 用户确认第二版计划，采用独立 sub-agent 方案执行 AUDIT。
- 进入 EXECUTING 阶段。

## 下一步建议

- 创建/修改 scripts/core 脚本。
- 重命名目录。
- 更新 skills、templates、hooks、CLAUDE.md。
- 验证。
