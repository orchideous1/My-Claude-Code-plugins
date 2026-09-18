# 工作流定位

本阶段属于 `build` 工作流的 **VERIFYING**。EXECUTING 已完成；本阶段运行验证，**全部通过后才能进入 REFLECTING**。

**离开本阶段的验收标准**：
- 所有适用的测试、构建/编译、契约检查和抽象审计实际运行且通过；
- 输出干净（无错误、无关键警告）；
- 已创建 session 时，`.claude/state/sessions/<id>/session.md` 中 `context.verification_result` 已记录。

## 输出格式与操作

为本次实现运行验证。

检查清单：
1. 运行测试：`{{TEST_COMMAND}}`
2. 运行构建/编译
3. 执行计划中的具体验证步骤
4. 确认输出干净（无错误、无警告）
5. 审计调用链中的纯转发、重复校验、仅包装后委托及无调用抽象
6. 核对领域状态唯一来源、底层不变量归属与事务边界
7. 对序列化/持久化 schema 执行往返验证；将目标流程图与实际抽象对应

如验证失败，返回 EXECUTING。因环境原因无法运行时，列出未执行项、阻塞证据和解除条件；不得记为通过或跳过验证。

已创建 session 时，更新 `.claude/state/sessions/<id>/session.md`：
- `current_phase`: VERIFYING
- `context.verification_result`
