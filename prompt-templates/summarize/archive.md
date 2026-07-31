# 工作流定位

本阶段属于 `summarize` 工作流的 **ARCHIVE**。PACKAGE 已生成 guide 与归档方案，且用户已确认归档；本阶段调用脚本实际写入 archive，并清理原会话目录。

**进入本阶段的前提**：用户在 PACKAGE 阶段明确同意归档。

**离开本阶段的验收标准**：
- 已调用 `write-archive.sh` 或 `hooks/summarize/archive.sh` 完成归档；
- 项目级 `CLAUDE.md` 的「已归档内容」区已追加归档条目；
- 原 `sessions/<id>/` 目录已被删除；
- 已向用户总结归档内容（文件名、位置、摘要）。

## 输出格式与操作

确认归档方案：

- guide 来源文件：`<SOURCE_FILE>`
- 归档描述：`<DESCRIPTION>`
- workflow 类型：`<WORKFLOW_TYPE>`（build / read / arch / general）
- 预期目标文件名：`<timestamp>-<desc>-<workflow>-<handoff|report|model|summary>.md`

执行归档（二选一）：

```bash
# 直接调用脚本
~/.claude/scripts/core/write-archive.sh <SOURCE_FILE> <DESCRIPTION> <WORKFLOW_TYPE> .claude/state

# 或调用 hook 入口
~/.claude/hooks/summarize/archive.sh <SOURCE_FILE> <DESCRIPTION> <WORKFLOW_TYPE> .claude/state
```

归档成功后，将 PACKAGE 阶段用户已确认的归档条目追加到项目级 `CLAUDE.md` 的「已归档内容」区（该区条目属于已确认归档方案的一部分，不视为未受控的 CLAUDE.md 变更）。条目格式：

```markdown
- <timestamp>-<desc>-<workflow>-<artifact>.md — <一句话摘要>
```

若项目级 `CLAUDE.md` 尚无「已归档内容」区，参照 `~/.claude/prompt-templates/state/CLAUDE_example.md` 补建该区后再追加。

最后向用户输出：

1. **已归档文件名**：`archive/<timestamp>-<desc>-<workflow>-<artifact>.md`
2. **摘要**：guide 的第一段核心内容
3. **下一步**：是否继续 AUDIT，或直接结束 summarize
