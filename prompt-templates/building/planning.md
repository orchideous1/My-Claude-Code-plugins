# 构建阶段 2：PLANNING（规划）

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

将完整计划写入 `.claude/state/plan.md`。
更新 `.claude/state/session.md`：
- `current_phase`: PLANNING
- `context.plan_approved`: false
