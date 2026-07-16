# 工作流定位

本阶段属于 `arch` 工作流的 **SCOPE**。`arch` 工作流用于理解复杂项目、模块或数据流架构，共分为 SCOPE → SURVEY → DRILL → CONNECT → MODEL 五个阶段。

**进入本阶段的前提**：用户已表达需要理解某部分架构的意图。

**离开本阶段的验收标准**：
- 焦点区域具体、可回答；
- 理解了该架构的动机、入口点、范围边界；
- 范围已写入 `.claude/state/sessions/<id>/session.md` 的 `context.architecture_focus`。

## 输出格式与操作

定义要回答的架构问题。

焦点：{{ARCHITECTURE_FOCUS}}

填写：

- 要理解代码库的哪个部分？
- 为什么要理解它？（最终文档开篇价值定位的素材）
- 这个理解将支持什么决策？
- 入口点：
- 不在范围内：
- 期望输出：（例如：一篇带代码片段的 walkthrough、一张数据流图、一份接口使用指南）

**操作**：
- 调用 `~/.claude/scripts/core/ensure-state.sh arch` 初始化状态。
- 更新 `.claude/state/sessions/<id>/session.md`：
  - `current_phase`: SCOPE
  - `context.architecture_focus`
