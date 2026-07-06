---
title: 改写 architecture-understanding 技能说明
status: completed
created: 2026-07-06
updated: 2026-07-06
---

# 改写 architecture-understanding 技能说明

## 目标

让 `architecture-understanding` 技能产出的 `.claude/state/architecture.md` 更贴近人类偏好的“code walkthrough”风格，而不是中性参考手册。

## 约束

- 保留 SCOPE → SURVEY → DRILL → CONNECT → MODEL 的上下文渐进式批量原则。
- 不新增工作流阶段，只在现有阶段内增加风格要求和信息收集项。
- 所有提示文档使用中文撰写。

## 改动清单

1. `skills/architecture-understanding/SKILL.md`
   - 在“用途”中明确产物定位为“工程师带读式的架构 walkthrough”。
   - 重写 MODEL 阶段说明，规定必须包含：开篇价值定位、鸟瞰结构、核心组件逐一解读、数据流与控制流、关键决策与权衡、接口契约（使用方式）、开放问题。
   - 增加文风要求：有观点、有代码片段、有具体参数示例。
   - 增加危险信号：写成参考手册、没有落地代码。

2. `prompt-templates/architecture/model.md`
   - 重写为 walkthrough 风格的具体执行模板。
   - 规定代码片段放在 `<details>` 可折叠块中。
   - 要求“作者点评”和具体运行示例。

3. `prompt-templates/architecture/drill.md`
   - 增加收集“核心代码片段”和“设计亮点/潜在坑点”的字段。
   - 明确子代理只报告事实，主观评价在 MODEL 阶段统一撰写。

4. `prompt-templates/architecture/connect.md`
   - 增加“典型运行示例”字段，为 MODEL 阶段的具体参数示例提供素材。

5. `prompt-templates/architecture/scope.md`
   - 把“为什么理解它”明确标注为“最终文档开篇价值定位的素材”。
   - 期望输出增加 walkthrough 等选项。

6. `prompt-templates/architecture/survey.md`
   - 增加收集“可绘制的整体结构图素材”和“最值得深入解读的 3-5 个核心组件”。

## 验证

- 已读取更新后的 `SKILL.md` 和 `model.md`，格式完整、frontmatter 未被破坏。
- 下一阶段可在 slime 框架上重新跑一次 `/arch`，检验产物是否更接近 `slime概述.md` 的风格。
