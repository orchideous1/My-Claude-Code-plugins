---
name: documentation
description: 当会话结束、切换任务或需要总结归档时触发
---

# 文档整理规范

## 用途

保持工作区状态整洁，并让历史上下文易于查找。归档前必须检查状态一致性。

## 何时使用

- 会话结束
- 切换任务前
- 完成目标后
- 用户要求总结

## 职责

1. 用当前阶段和摘要更新 `.claude/state/session.md`
2. 用目标状态更新 `.claude/state/goal-tracker.md`
3. 如会话完成，归档到 `.claude/state/archive/`
4. 确保 `plan.md` 与当前工作一致

## 归档前门控

在移动 `session.md` 到 `archive/` 之前检查：

- `session.md` 的 YAML frontmatter 完整
- `goal-tracker.md` 已更新
- 如会话涉及 `/build`，`plan.md` 状态与实际一致
- 如会话涉及 `/arch`，`architecture.md` 已更新

任何一项不通过，先修复再归档。

## 归档约定

归档文件名：`<时间戳>-<简短描述>.md`

将 `session.md` 内容移动到归档，然后将 `session.md` 重置为初始状态。

## 提示模板

- `~/.claude/prompt-templates/documentation/session-summary.md`
- `~/.claude/prompt-templates/documentation/plan-backup.md`
- `~/.claude/prompt-templates/documentation/goal-tracker.md`
