# 工作流定位

本阶段属于 `summarize` 工作流的 **PACKAGE**。REVIEW、ALIGN、EVALUATE 已完成；本阶段负责判断会话是否有长期参考价值，并生成删除或参考文档归档方案。

**离开本阶段的验收标准**：
- 已判断会话是否包含未被现行资料覆盖、可供未来复用的稳定知识；
- 有长期价值时，`reference.md` 只保留现行契约、边界、风险和代码位置；
- 已生成删除或参考文档归档方案，并询问用户确认。

## 输出格式与操作

### 1. 筛选长期知识

判断以下内容是否尚未被现行代码或项目文档覆盖，且会在未来任务中复用：稳定接口契约、数据布局、重建条件、运维风险、设计边界。

不要将过程日志、历史测试数、一次性统计、试点样本、已过时的计划或原始交接内容归档。

### 2. 生成处置方案

没有长期知识时，方案是直接删除 `sessions/<id>/`。有长期知识时，在该目录创建 `reference.md`，frontmatter 必须有 `type: reference`，并确定目标文件名 `archive/<timestamp>-<desc>-reference.md`。

### 3. 询问用户确认

先向用户展示处置理由与方案，并明确询问：

> 是否同意执行上述删除或参考文档归档方案？

#### 用户选择参考文档归档

- 将精炼内容写入 `sessions/<id>/reference.md`；
- 进入 **ARCHIVE** 阶段，调用归档脚本：
  ```bash
  ~/.claude/hooks/summarize/archive.sh <SOURCE_FILE> <DESCRIPTION> .claude/state
  ```
  或：
  ```bash
  ~/.claude/scripts/core/write-archive.sh <SOURCE_FILE> <DESCRIPTION> .claude/state
  ~/.claude/scripts/core/cleanup-session.sh .claude/state <SESSION_ID>
  ```

#### 用户选择直接删除

- 调用 `~/.claude/scripts/core/cleanup-session.sh .claude/state <SESSION_ID>`；
- 不写入 archive，不追加项目 `CLAUDE.md` 归档索引。

### 4. 输出要求

- 向用户清晰展示长期知识判断和处置方案；
- 等待用户明确确认后再写入 reference 或调用清理脚本；
- 不得将会话过程当作 archive 内容。
