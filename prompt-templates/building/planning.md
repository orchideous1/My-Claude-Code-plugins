# 工作流定位

本阶段属于 `build` 工作流的 **PLANNING**。UNDERSTANDING 已确认用户意图；本阶段输出实现计划，**必须获得用户明确批准后才能进入 EXECUTING**。

**离开本阶段的验收标准**：
- 计划包含方案摘要、文件清单、接口/参数、算法/数据流、验证步骤、风险与回退方案；
- 用户明确批准（如“批准此计划”或“可以执行”）；
- `.claude/state/sessions/<id>/session.md` 中 `context.plan_approved` 已设为 `true`。

## 输出格式与操作

为以下目标输出实现计划：

{{USER_GOAL}}

计划必须包含：

1. **方案摘要** — 一段文字
2. **要创建/修改的文件** — 带用途
3. **接口** — 函数签名或 CLI 参数
4. **算法 / 数据流** — 分步
5. **验证步骤** — 如何证明可用
6. **风险和回退方案**

**停止并等待用户批准后再写代码。**

将完整计划写入 `.claude/state/sessions/<id>/plan.md`。

更新 `.claude/state/sessions/<id>/session.md`：
- `current_phase`: PLANNING
- `context.plan_approved`: false
