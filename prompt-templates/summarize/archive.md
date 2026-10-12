# 工作流定位

本阶段属于 `summarize` 工作流的 **ARCHIVE**。PACKAGE 已生成 `reference.md` 与归档
方案，且用户已确认归档；本阶段调用脚本实际写入 archive，并清理原会话目录。

**进入本阶段的前提**：用户在 PACKAGE 阶段明确同意归档。

**离开本阶段的验收标准**：
- 已调用 `write-archive.sh` 或 `hooks/summarize/archive.sh` 完成归档；
- 未启用 active-session 治理时，项目级归档索引已按确认方案更新；启用治理时，
  索引更新留待 integration 分支收敛；
- 原 `sessions/<id>/` 目录已被删除；
- 已向用户总结归档内容（文件名、位置、摘要）。

## 输出格式与操作

确认归档方案：

- reference 来源文件：`<SOURCE_FILE>`
- 归档描述：`<DESCRIPTION>`
- 预期目标文件名：`<timestamp>-<desc>-reference.md`

执行归档（二选一）：

```bash
# 直接调用脚本
~/.claude/scripts/core/write-archive.sh <SOURCE_FILE> <DESCRIPTION> .claude/state

# 或调用 hook 入口
~/.claude/hooks/summarize/archive.sh <SOURCE_FILE> <DESCRIPTION> .claude/state
```

归档成功后，将 PACKAGE 阶段用户已确认的归档条目追加到项目级 `CLAUDE.md` 的「已归档内容」区（该区条目属于已确认归档方案的一部分，不视为未受控的 CLAUDE.md 变更）。条目格式：

```markdown
- <timestamp>-<desc>-reference.md — <一句话摘要>
```

启用 active-session 治理时，不得从会话分支直接修改项目级 `CLAUDE.md`；记录待收敛
索引条目，在 integration 分支处理。

最后向用户输出：

1. **已归档文件名**：`archive/<timestamp>-<desc>-reference.md`
2. **摘要**：reference 的适用范围与核心长期事实
3. **下一步**：是否继续 AUDIT，或直接结束 summarize
