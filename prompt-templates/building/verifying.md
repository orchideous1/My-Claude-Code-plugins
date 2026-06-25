# 构建阶段 4：VERIFYING（验证）

为本次实现运行验证。

检查清单：
1. 运行测试：`{{TEST_COMMAND}}`
2. 运行构建/编译
3. 执行计划中的具体验证步骤
4. 确认输出干净（无错误、无警告）

如验证失败，返回 EXECUTING。

更新 `.claude/state/session.md`：
- `current_phase`: VERIFYING
- `context.verification_result`
