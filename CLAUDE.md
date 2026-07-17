# CLAUDE 协作文档

本文档是你与 Claude 协作时必须遵守的规则。所有规则适用于全部项目，除非 workspace 级别的 `.claude/CLAUDE.md` 另有说明。

## 默认语言

1. 所有提示文档、协作文档、状态文件、命令说明均采用中文撰写。
2. 默认响应语言为中文。

## 核心工作流

本系统定义了四个核心工作流技能，会话开始时自动加载 `using-workflows` 技能，强制先根据场景触发对应技能再行动。

| 技能 | 用途 | 触发场景 |
|------|------|----------|
| `read` | 代码阅读 / 故障排查 | 排查 bug、理解代码行为、调查异常 |
| `build` | 代码生成 / 重构 / 修改 | 生成新代码、重构、修改行为 |
| `arch` | 复杂项目架构理解 | 理解项目/模块/数据流架构 |
| `summarize` | 会话收尾 / 目标对齐 / 归档 | 会话结束、切换任务、需要总结归档 |

工作流入口由自然语言场景自动触发，不再维护 `/read`、`/build`、`/arch`、`/summarize` 等 slash 命令。进入一个工作流后，必须按对应技能的阶段推进，不得跳过。

---

## 工作流一：代码阅读 / 故障排查（`read`）

使用 `read` 技能。

启动前若 `CLAUDE_SESSION_ID` 未设置，使用 `scripts/core/derive-session-id.sh` 从调查目标生成会话 ID，并调用 `scripts/core/ensure-state.sh read .claude/state [SESSION_ID]` 初始化状态。

阶段：
1. **SCOPE（范围）** — 定义排查范围，列出可疑位置
2. **HYPOTHESIS（假设）** — 形成 1-3 个根因假设
3. **EVIDENCE（证据）** — 委派子代理阅读具体代码，收集证据
4. **REPORT（报告）** — 输出根因报告和修复计划
5. **FIX（修复）** — 仅在用户批准后执行

强制规则：
- 不要直接阅读大型代码库，先规划再委派子代理。
- 必须能复现问题再进入假设阶段。
- 修复前必须先输出报告并等待用户确认。
- 找不到根因时明确说明，不猜测。

---

## 工作流二：代码生成 / 重构 / 修改（`build`）

使用 `build` 技能。

启动前若 `CLAUDE_SESSION_ID` 未设置，使用 `scripts/core/derive-session-id.sh` 从用户目标生成会话 ID，并调用 `scripts/core/ensure-state.sh build .claude/state [SESSION_ID]` 初始化状态。

阶段：
1. **UNDERSTANDING（理解）** — 澄清意图、约束、成功标准
2. **PLANNING（规划）** — 输出实现计划，等待用户确认
3. **EXECUTING（执行）** — 按计划写最小代码
4. **VERIFYING（验证）** — 运行测试/构建/验证
5. **REFLECTING（反思）** — 总结、更新文档、决定下一步

强制规则：
- 写代码前必须先有计划并获得用户批准。
- 实现计划必须包含：文件清单、接口/参数、算法流程、验证步骤。
- 不添加计划外的功能。
- 脚本命令行参数超过 5 个时，统一改为从配置文件加载。
- 每个生成的脚本开头必须写 docstring，说明用法和概述。
- 验证失败时返回 EXECUTING 阶段，不跳过验证。

---

## 工作流三：架构理解（`arch`）

使用 `arch` 技能。

启动前若 `CLAUDE_SESSION_ID` 未设置，使用 `scripts/core/derive-session-id.sh` 从架构焦点生成会话 ID，并调用 `scripts/core/ensure-state.sh arch .claude/state [SESSION_ID]` 初始化状态。

阶段循环：
1. **SCOPE（范围）** — 定义要理解的架构问题
2. **SURVEY（概览）** — 映射高层结构，不读内部
3. **DRILL（深入）** — 委派子代理深入关键组件
4. **CONNECT（连接）** — 追溯数据流、控制流、依赖关系
5. **MODEL（建模）** — 综合为架构模型文档

循环规则：
- MODEL 后发现缺口，回到 DRILL。
- 关系不清楚，回到 CONNECT。
- 范围错误，回到 SCOPE。
- 模型稳定后标记 DONE。

强制规则：
- 不一次性理解全部代码，分迭代进行。
- 大型项目必须使用子代理分模块调查。
- 必须产出具体产物：组件图、数据流、接口契约。

---

## 文档整理与用户交互

1. 每个工作流阶段结束后更新 `.claude/state/sessions/<id>/session.md`。
2. 每个 `build` 任务必须维护 `.claude/state/sessions/<id>/plan.md`。
3. 长期目标维护在 `.claude/state/goal-tracker.md`。
4. `arch` 产物写入 `.claude/state/sessions/<id>/architecture.md`。
5. 会话结束时触发 `summarize` 技能进行回顾、目标对齐、回答质量评估、归档方案确认与归档执行，归档完成后进入 AUDIT 审查；`CLAUDE.md` 优化建议仅输出，不得自动写入。
6. 实现完成后向用户汇报，并在代码开头写 docstring。

---

## 阶段门控与审计

本系统不设置独立的 `/guard` 命令。防护和审计思想嵌入在每个工作流 skill 中。

### 软门控（skill 内）

每个 skill 在阶段转换处定义门控条件：

- `read`：REPORT → FIX 必须获得用户批准
- `build`：PLANNING → EXECUTING 必须获得用户批准
- `arch`：MODEL 后必须自审，有缺口则回退
- `summarize`：REVIEW → ALIGN → EVALUATE → PACKAGE → ARCHIVE → AUDIT；PACKAGE 生成归档内容方案并提前询问用户是否归档，用户确认后调用归档 hook 写入 archive 并清理原会话目录，随后进入 AUDIT；AUDIT 结果只向用户展示，不写入文件，也不进入 archive；用户不确认则不归档。

### 状态脚本

可固化的状态操作收敛到 `scripts/core/*.sh`，各 skill 在启动和收尾时直接调用：

- `derive-session-id.sh <PHRASE>`：从用户目标/焦点短语生成短会话 ID slug（≤30 字符，保留中文与 ASCII）。
- `ensure-state.sh [workflow] [STATE_DIR] [SESSION_ID]`：初始化/校验 `.claude/state/sessions/<id>/` 及 `session.md`、`plan.md`、`architecture.md`、`handoff.md`。SESSION_ID 由调用方显式传入或取自 `CLAUDE_SESSION_ID` 环境变量，不再落盘到共享文件。
- `infer-workflow.sh [<SESSION_FILE>]`：从 `session.md` 推断 workflow 类型；未提供文件时根据 `CLAUDE_SESSION_ID`（或 `default`）构造路径。
- `reset-session.sh [<SESSION_FILE>]`：将 `session.md` 重置为 IDLE 模板。
- `write-archive.sh <SOURCE_FILE> <DESCRIPTION> [WORKFLOW_TYPE] [STATE_DIR]`：将已确认的 guide 复制到 `archive/`，按类型命名并更新 `archive/index.md`。
- `cleanup-session.sh [STATE_DIR] [SESSION_ID]`：归档后删除原 `sessions/<id>/` 目录。SESSION_ID 由调用方显式传入；`hooks/summarize/archive.sh` 会从 `SOURCE_FILE` 路径推断并显式传递。

### 归档 hooks

`summarize` 技能对应的归档操作由以下 hooks 执行，`summarize` 本身不直接搬运文件：

- `pre-summarize.sh`：在 `summarize` 执行前检查：
  - `sessions/<id>/session.md` 与 `goal-tracker.md` 的 YAML frontmatter 完整性
  - 旧路径 `.claude/session.md` 是否存在并提示迁移
  - 是否存在其他 dirty 会话状态并提示并发冲突
  - 调用 `ensure-state.sh` 时使用持久化的会话 ID 补全当前会话状态
  - 异常时阻断
- `archive.sh`：在用户确认归档后执行归档。负责：
  - 接收已确认的 guide 来源文件、归档描述、workflow 类型
  - 调用 `scripts/core/write-archive.sh` 将 guide 复制到归档目录
  - 调用 `scripts/core/cleanup-session.sh` 删除原 `sessions/<id>/` 目录
  - 按 workflow 类型迁移 guide 到归档目录：
    - build：`handoff.md` → `archive/<timestamp>-<desc>-build-handoff.md`
    - read：`handoff.md` → `archive/<timestamp>-<desc>-read-report.md`
    - arch：`architecture.md` → `archive/<timestamp>-<desc>-arch-model.md`
    - general：`handoff.md` → `archive/<timestamp>-<desc>-general-summary.md`
  - **只归档 guide，`session.md` 与 `plan.md` 等中间状态不归档**，归档后随 `sessions/<id>/` 一起删除
- `session-exit.sh`：会话退出前检测当前会话未归档的 dirty 状态，提示用户是否需要触发 `summarize`。

这些 hooks 存放在本项目的 `hooks/summarize/` 目录下，使用时需在 Claude Code 配置中按需挂载。

为避免上下文冗余，本系统采用以下分工：

1. **Skill 是单一真相源**：所有工作流阶段、门控、模板路径、状态字段只存在于 skill 中。
2. **Description 只写触发条件**：遵循 CSO（Claude Search Optimization）原则，不在 description 中总结流程。
3. **Skill 之间交叉引用**：skill A 需要 skill B 的流程时，显式调用，不内联复制。
4. **可固化操作写入脚本**：状态初始化、workflow 推断、归档等重复操作由 `scripts/core/*.sh` 提供，skill 直接调用。

---

## 状态文件管理

1. 状态文件统一存放在当前 workspace 的 `.claude/state/` 目录。
2. 中间状态按会话隔离，存放在 `.claude/state/sessions/<CLAUDE_SESSION_ID>/`。
3. 长期记忆文件（`goal-tracker.md`、`archive/index.md`）存放在 `.claude/state/` 根目录。
4. 所有状态文件使用 YAML frontmatter + Markdown body 格式。
5. 不得破坏状态文件的 YAML frontmatter。
6. 归档产物存放在 `.claude/state/archive/`，按工作流类型命名。

---

## 状态架构与归档规则

### 三层内容模型

| 类型 | 位置 | 代表文件 | 说明 |
|------|------|----------|------|
| 中间状态 | `.claude/state/sessions/<id>/` | `session.md`、`plan.md`、待归档的 `handoff.md` / `architecture.md` | 单会话工作草稿，会话结束后重置 |
| 归档产物 | `.claude/state/archive/` | `<timestamp>-<desc>-<type>-<artifact>.md` | 经审查的 guide 快照，保留足够过程信息 |
| 长期记忆 | `.claude/state/` 根目录 + `CLAUDE.md` | `goal-tracker.md`、`archive/index.md`、`CLAUDE.md` | 跨会话共享，协作规则与目标 |

### 归档索引

`.claude/state/archive/index.md` 由 `archive.sh` 自动维护，记录所有已归档的会话总结。新会话开始时应优先读取本文件以了解历史进展与关键 handoff。

### 工作流感知的归档命名

| workflow | 来源文件 | 归档文件名 |
|----------|----------|------------|
| build | `sessions/<id>/handoff.md` | `<timestamp>-<desc>-build-handoff.md` |
| read | `sessions/<id>/handoff.md` | `<timestamp>-<desc>-read-report.md` |
| arch | `sessions/<id>/architecture.md` | `<timestamp>-<desc>-arch-model.md` |
| general | `sessions/<id>/handoff.md` | `<timestamp>-<desc>-general-summary.md` |

### 归档 guide 内容标准

归档产物是 guide，不是 `session.md` 的原始轨迹。guide 必须保留足够的过程信息，避免过度简化，使新会话能继续推进：

- **build handoff**：目标与约束、方案摘要与关键决策、文件清单与接口变更、验证结果、待办与风险。
- **read report**：问题与范围、假设及证实/证伪证据、被排除假设的理由、根因、修复计划、风险。
- **arch model**：焦点与价值、高层结构、组件职责与代码片段、数据/控制流、关键决策与开放问题。
- **general summary**：核心成果、关键决策、待办、下次入口与风险。

### 归档审查

归档完成后，进入 AUDIT 阶段。AUDIT 必须通过**独立 sub-agent** 执行，与主代理的回顾/对齐/评估上下文解耦。sub-agent 仅可见以下材料：

- 本次会话的 `session.md`、`plan.md`、guide 文件（如已归档则使用 archive 副本）
- 本次会话涉及的代码变更（`git diff`）
- 项目级 `CLAUDE.md`

sub-agent 的审查范围：

- 提示词合理性（能否归纳通用提示）
- 文档冲突（`CLAUDE.md`、skill、模板之间是否一致）
- 状态架构（文件位置、frontmatter、分层边界）
- `CLAUDE.md` 优化（仅输出建议，**不得自动写入**）
- 归档内容审查（guide 是否准确、完整、命名是否符合规则）

AUDIT 结果按「阻塞 / 建议 / 通过」分类，只向用户展示，不写入文件，也不进入 archive。如发现目标偏差或架构理解问题，sub-agent 可向用户提出重新对齐的问题。

### CLAUDE.md 变更受控

`CLAUDE.md` 是项目级协作规则的核心载体，**所有内容增改必须经用户审核**。AUDIT 阶段可提出优化建议，但绝不能自动写入。审核通过后，应通过 `build` 流程执行修改。

### 并发会话隔离

- 通过环境变量 `CLAUDE_SESSION_ID` 隔离不同会话的中间状态。
- 未设置时默认使用 `default`。
- 推荐并发会话启动方式：`CLAUDE_SESSION_ID=feature-a claude`
- 若未设置 ID 且存在其他会话目录，`pre-summarize.sh` 会发出警告。

### 旧路径处理

旧路径 `.claude/session.md` 已不再使用。如发现该文件，应手动迁移到 `.claude/state/sessions/default/session.md` 或删除，以避免冗余。

---

## 命令行接口规范

1. 本系统不再维护 `/read`、`/build`、`/arch`、`/summarize` 等 slash 命令入口，工作流由 skill 根据场景自动触发。
2. 脚本/工具命令行参数超过 5 个时，必须改为从配置文件读取。
3. 配置文件结构必须在文档中详细说明。
4. 配置统一存放在 `.claude/` 或项目约定的配置目录。

---

## 子代理使用规范

1. 大型代码库排查和理解必须通过子代理完成。
2. 每个子代理只负责一个聚焦的问题。
3. 子代理只报告事实，由你进行综合分析。
4. 复杂代码阅读理解任务交给 `Explore` 子代理。

---

## 禁止事项

- 未形成排查计划就直接读大段代码。
- 未获用户批准就修复代码。
- 未获用户批准就生成代码。
- 添加计划外功能。
- 跳过验证阶段。
- 破坏状态文件 frontmatter。
- 用英文撰写协作文档和提示文档。
- 将 AUDIT 结果写入文件或归档。
- 归档 `session.md` 原始轨迹。
