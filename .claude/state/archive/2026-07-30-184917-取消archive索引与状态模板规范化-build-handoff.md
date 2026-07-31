---
---

# 交接摘要

## 目标与约束

取消 `archive/index.md` 的使用，改用 `prompt-templates/state/` 两个新模板规范状态文件；确保各工作流产出文件可控可预测（用户追加要求）。约束：三层提示结构不显式成文，`~/.claude/CLAUDE.md` 保持原语义；goal-tracker 命名统一连字符；CLAUDE.md 变更受控（归档索引追加为例外，属 PACKAGE 已确认方案）。

## 方案摘要与关键决策

1. **索引迁移**：`write-archive.sh` 摘除摘要提取与 index.md 维护逻辑；归档索引改由 `summarize` ARCHIVE 阶段追加到项目级 CLAUDE.md「已归档内容」区，格式 `- <归档文件名> — <一句话摘要>`。
2. **模板规范化**：`goal_tracker_example.md` 改名 `goal-tracker_example.md`（补 `updated:` 字段供 pre-summarize 校验，删 Megatron 残留行）；`CLAUDE_example.md` 路径明确为 `.claude/state/` 并补归档条目示例。
3. **自动初始化**：`pre-summarize.sh` 在 goal 文件缺失时从模板复制（模板路径相对脚本解析，仓库与 `~/.claude` 部署布局均适用），模板缺失才报错。
4. **输出文件审计**（用户新增）：逐一核对全部技能/脚本/hook 文件产生点；删除 3 个悬空模板（`session-summary.md`、`plan-backup.md`、`goal-tracker.md` 提示模板——无阶段引用，会产生路径未规范文件）；仓库 CLAUDE.md 状态文件管理新增第 7 条收口规则；summarize 危险信号新增对应条目。
5. **本仓落地**：删除 `.claude/state/archive/index.md`（2 条记录迁入 CLAUDE.md，第 2 条"## 目标与约束"缺陷摘要顺手改正）；清理已归档却残留的 `sessions/fix-write-archivesh-session-id/`。
6. **部署**：rsync 四方目录覆盖 `~/.claude/` 顶层过期副本（仍停留在 .current-session-id 时代）；`--delete` 顺带清除三层误嵌套目录（已 diff 验证嵌套==仓库，无内容丢失，等效用户指示的"底层往上提"）。
7. **全局 CLAUDE.md**：仅修正 `goal_tracker.md`→`goal-tracker.md` 一处命名，其余原语义不动（备份 `/tmp/CLAUDE.md.bak`）。

## 文件清单与接口变更

- 修改：`scripts/core/write-archive.sh`、`hooks/summarize/pre-summarize.sh`、`prompt-templates/state/CLAUDE_example.md`、`prompt-templates/summarize/archive.md`、`skills/summarize/SKILL.md`、仓库 `CLAUDE.md`、`~/.claude/CLAUDE.md`（1 处）
- 改名：`prompt-templates/state/goal_tracker_example.md` → `goal-tracker_example.md`（内容增补）
- 删除：`prompt-templates/summarize/{session-summary,plan-backup,goal-tracker}.md`、`.claude/state/archive/index.md`、`sessions/fix-write-archivesh-session-id/`
- 接口：`write-archive.sh` 与 `pre-summarize.sh` 参数不变；行为变化为不再生成 index.md、goal 缺失自动初始化。

## 验证结果

1. 两脚本 `bash -n` 通过。
2. 端到端：构造 `sessions/test-x` 调 `archive.sh`，归档文件命名正确、`test-x` 被清理、**未生成 index.md**（产物已清理）。
3. `pre-summarize.sh` 自动初始化 + 二次运行幂等通过（goal-tracker 已恢复原内容）。
4. 部署后四方目录 `diff -r` 与仓库完全一致；嵌套目录不存在。
5. `grep` 无 `goal_tracker`/`session-summary`/`plan-backup` 残留；`index.md` 仅存于规则文本的否定式表述。

## 待办与风险

- **derive-session-id.sh 截断 bug**：≤30 字符截断按字节切断中文多字节字符，产生乱码会话目录（本次以换短短语绕过）。建议后续改为按字符截断。
- **git 未提交**：仓库改动（含模板改名与删除）待用户决定提交时机。
- **pre-summarize 警告噪音**：未设 `CLAUDE_SESSION_ID` 时会把当前被总结的会话当作"其他 dirty 会话"警告，属误报但无害。
- 新流程首航：本次 ARCHIVE 是「索引写入项目 CLAUDE.md」首次实战，后续会话应观察 summarize 是否正确维护索引区。
