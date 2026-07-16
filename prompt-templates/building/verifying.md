# 工作流定位

本阶段属于 `build` 工作流的 **VERIFYING**。EXECUTING 已完成；本阶段运行验证，**全部通过后才能进入 REFLECTING**。

**离开本阶段的验收标准**：
- 测试、构建/编译及计划中的验证步骤全部通过；
- 输出干净（无错误、无关键警告）；
- `.claude/state/sessions/<id>/session.md` 中 `context.verification_result` 已记录。

## 输出格式与操作

为本次实现运行验证。

检查清单：
1. 运行测试：`{{TEST_COMMAND}}`
2. 运行构建/编译
3. 执行计划中的具体验证步骤
4. 确认输出干净（无错误、无警告）

如验证失败，返回 EXECUTING。

更新 `.claude/state/sessions/<id>/session.md`：
- `current_phase`: VERIFYING
- `context.verification_result`
