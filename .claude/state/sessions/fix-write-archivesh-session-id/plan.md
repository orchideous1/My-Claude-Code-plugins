---
title: 修复 write-archive.sh 两个阻塞 bug
status: completed
phase: REFLECTING
created: 2026-07-18
updated: 2026-07-18
---

# 计划

## 目标

修复 `write-archive.sh` 两个阻塞 bug（SESSION_ID 来源、SUMMARY 提取），并按 handoff 建议 3、4 改进 CLAUDE.md 与三个 SKILL.md。

## 文件清单

- `scripts/core/write-archive.sh`：SESSION_ID 三段回退；SUMMARY awk 跳过 frontmatter 与 `#` 标题。
- `CLAUDE.md`：pre-summarize.sh 描述修正；「状态脚本」section 加通用约定。
- `skills/build/SKILL.md`、`skills/read/SKILL.md`、`skills/arch/SKILL.md`：删除重复的"显式传 SESSION_ID"约定。

## 验证

- 端到端：构造 sessions/test-e2e，跑 hooks/summarize/archive.sh，tail archive/index.md 核对字段。
- 场景 B：CLAUDE_SESSION_ID=env-override 验证优先级。
- 清理：恢复 index.md，删除测试归档文件与 sessions/test-*。
- 部署：rsync 到 ~/.claude，diff 核对一致。

## 结果

全部通过。
