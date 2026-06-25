# CLAUDE 协作文档

本文档是你与 Claude 协作时必须遵守的规则。所有规则适用于全部项目，除非 workspace 级别的 `.claude/CLAUDE.md` 另有说明。

## 默认语言

1. 所有提示文档、协作文档、状态文件、命令说明均采用中文撰写。
2. 默认响应语言为中文。

## 核心工作流

本系统定义了四个核心工作流命令：

| 命令 | 用途 | 后端技能 |
|------|------|----------|
| `/read [目标]` | 代码阅读 / 故障排查 | `systematic-reading` |
| `/build [目标]` | 代码生成 / 重构 / 修改 | `structured-building` |
| `/arch [焦点]` | 复杂项目架构理解 | `architecture-understanding` |
| `/summarize` | 会话收尾 / 文档整理 | `documentation` |

命令是薄壳入口，所有流程细节、门控、模板引用收敛到对应 skill 中。会话开始时自动加载 `using-workflows` 技能，强制先检查工作流技能再行动。

进入一个工作流后，必须按对应技能的阶段推进，不得跳过。

---

## 工作流一：代码阅读 / 故障排查（`/read`）

使用 `systematic-reading` 技能。

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

## 工作流二：代码生成 / 重构 / 修改（`/build`）

使用 `structured-building` 技能。

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

## 工作流三：架构理解（`/arch`）

使用 `architecture-understanding` 技能。

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

1. 每个工作流阶段结束后更新 `.claude/state/session.md`。
2. 每个 `/build` 任务必须维护 `.claude/state/plan.md`。
3. 长期目标维护在 `.claude/state/goal-tracker.md`。
4. `/arch` 产物写入 `.claude/state/architecture.md`。
5. 会话结束时使用 `/summarize` 归档。
6. 实现完成后向用户汇报，并在代码开头写 docstring。

---

## 阶段门控与审计

本系统不设置独立的 `/guard` 命令。防护和审计思想嵌入在每个工作流 skill 中。

### 软门控（skill 内）

每个 skill 在阶段转换处定义门控条件：

- `/read`：REPORT → FIX 必须获得用户批准
- `/build`：PLANNING → EXECUTING 必须获得用户批准
- `/arch`：MODEL 后必须自审，有缺口则回退
- `/summarize`：归档前必须检查状态一致性

### 状态文件保护

`.claude/state/*.md` 文件由 `PostToolUse` hook `protect-state.sh` 保护：

- 在每次 Write/Edit 后检查 YAML frontmatter 是否完整
- 如 frontmatter 被破坏，阻断操作并提示恢复模板

---

## 命令与技能的分工

为避免上下文冗余，本系统采用以下分工：

1. **Skill 是单一真相源**：所有工作流阶段、门控、模板路径、状态字段只存在于 skill 中。
2. **Command 是薄壳入口**：只负责参数解析和调用对应 skill，禁止重复 workflow 细节。
3. **Description 只写触发条件**：遵循 CSO（Claude Search Optimization）原则，不在 description 中总结流程。
4. **无对应 skill 的 command 禁止存在**：每个 command 必须有且仅有一个 skill 作为后端。
5. **Skill 之间交叉引用**：skill A 需要 skill B 的流程时，显式调用，不内联复制。

---

## 状态文件管理

1. 状态文件统一存放在当前 workspace 的 `.claude/state/` 目录。
2. 所有状态文件使用 YAML frontmatter + Markdown body 格式。
3. 不得破坏状态文件的 YAML frontmatter。
4. 旧的 `session.md` 完成后归档到 `.claude/state/archive/`。

---

## 命令行接口规范

1. Slash 命令最多接受 2 个参数。
2. 脚本命令行参数超过 5 个时，必须改为从配置文件读取。
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

---

## 技能与命令对应关系

| 场景 | 命令 | 技能 |
|------|------|------|
| 故障排查 | `/read` | `systematic-reading` |
| 代码生成/重构 | `/build` | `structured-building` |
| 架构理解 | `/arch` | `architecture-understanding` |
| 收尾归档 | `/summarize` | `documentation` |
