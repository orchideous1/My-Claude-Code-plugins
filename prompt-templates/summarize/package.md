# 工作流定位

本阶段属于 `summarize` 工作流的 **PACKAGE**。REVIEW、ALIGN、EVALUATE 已完成；本阶段负责根据 `.claude/state/sessions/<id>/session.md` 的完整轨迹，生成交接 guide 的**归档内容方案**，并提前询问用户是否归档。

**离开本阶段的验收标准**：
- 已根据 workflow 类型确定 guide 文件：
  - `build` / `read` / `general` → `.claude/state/sessions/<id>/handoff.md`
  - `arch` → `.claude/state/sessions/<id>/architecture.md`
- guide 内容准确、完整，保留了关键决策理由、证据、代码位置、验证结果、待办与风险，避免过度简化；
- 已生成归档方案（来源文件、workflow 类型、描述、预期归档文件名）；
- 已询问用户是否归档，并根据用户选择进入对应分支。

## 输出格式与操作

### 1. 生成交接 guide 草稿

基于 `.claude/state/sessions/<id>/session.md` 的完整轨迹，整理为一份可归档的 guide 草稿。草稿应包含：

- **摘要标题**：一句话概括本次会话的核心成果。
- **关键产物清单**：产物名称、位置、一句话价值说明。
- **决策与待办**：已确认决策（附理由）、待办事项（按优先级，标注入口/负责人）。
- **过程要点**：关键思路、证据、验证步骤、代码位置，以及为什么排除其他方案。
- **风险提示**：下次会话需特别注意的地方、可能被推翻的假设。

### 2. 生成归档方案

根据 workflow 类型，确定归档来源文件与目标文件名：

| workflow 类型 | guide 来源文件 | 归档目标文件名 |
|---------------|----------------|----------------|
| build | `sessions/<id>/handoff.md` | `archive/<timestamp>-<desc>-build-handoff.md` |
| read | `sessions/<id>/handoff.md` | `archive/<timestamp>-<desc>-read-report.md` |
| arch | `sessions/<id>/architecture.md` | `archive/<timestamp>-<desc>-arch-model.md` |
| general | `sessions/<id>/handoff.md` | `archive/<timestamp>-<desc>-general-summary.md` |

归档方案必须包括：

- guide 来源文件：`<SOURCE_FILE>`
- 归档描述：`<DESCRIPTION>`（用于文件名中的 `<desc>` 部分）
- workflow 类型：`<WORKFLOW_TYPE>`（build / read / arch / general）
- 预期目标文件名：`<timestamp>-<desc>-<workflow>-<artifact>.md`

### 3. 询问用户是否归档

在将 guide 写入文件之前，先向用户展示 guide 草稿与归档方案，并明确询问：

> 是否同意将上述 guide 归档到 `archive/<timestamp>-<desc>-<workflow>-<artifact>.md`？

#### 用户选择归档

- 将 guide 写入/更新到 `sessions/<id>/handoff.md` 或 `architecture.md`；
- 进入 **ARCHIVE** 阶段，调用归档脚本：
  ```bash
  ~/.claude/hooks/summarize/archive.sh <SOURCE_FILE> <DESCRIPTION> <WORKFLOW_TYPE> .claude/state
  ```
  或：
  ```bash
  ~/.claude/scripts/core/write-archive.sh <SOURCE_FILE> <DESCRIPTION> <WORKFLOW_TYPE> .claude/state
  ~/.claude/scripts/core/cleanup-session.sh .claude/state
  ```

#### 用户选择不归档

询问用户属于哪种情况：

1. **需要继续修改 guide**
   - 收集用户反馈；
   - 返回 **REVIEW** 或 **PACKAGE** 重新完善 guide。

2. **本次改进较小，无需归档**
   - 清空对应的 guide 文件（`handoff.md` 或 `architecture.md`）；
   - 结束 `summarize`，不进入 ARCHIVE 与 AUDIT。

### 4. 输出要求

- 向用户清晰展示 guide 草稿与归档方案；
- 等待用户明确确认后再写入 guide 文件或调用归档脚本；
- 不归档时必须先确认用户的具体意图，不得直接丢弃内容或强制归档。
