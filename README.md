# Structured Development Workflows

面向 Claude Code 的分阶段开发与会话治理插件。仓库包含 `read`、`build`、`arch`、
`summarize` 技能，以及用于 Git 会话绑定、状态文档保护和停止前一致性检查的 hooks。

## 启用插件

开发时可直接从本仓库加载：

```bash
claude --plugin-dir /home/linyiwu/My-Claude-Code-plugins
```

hooks 在 Claude Code 会话启动时加载；修改 `hooks/hooks.json` 后必须重启会话。
hook 使用 Python 3 和 PyYAML 读取 `active-sessions.yaml`。

Codex 使用 `.codex-plugin/plugin.json` 暴露同一组 skills，并从仓库根 `AGENTS.md`
读取工作区协作约束。Kimi 使用 `.kimi/AGENTS.md`；`.kimi-code/AGENTS.md` 作为旧目录
兼容入口。三类工具共用 `.claude/state/`，不得分别维护长期状态副本。

本源仓库自身还包含 `.claude/settings.json`，因此直接在仓库内使用 Claude Code 时会
加载治理 hook；外部项目仍推荐通过插件方式加载。

## 初始化项目治理

在项目根目录执行：

```bash
/home/linyiwu/My-Claude-Code-plugins/scripts/core/bootstrap-governance.sh \
  . codex/integration
```

脚本只创建缺失文件，不覆盖已有项目文档。它初始化 L0-L3 文档骨架：

```text
AGENTS.md / .kimi/AGENTS.md  (工具适配入口)
└─ .claude/CLAUDE.md
   └─ .claude/state/development-governance.md
      ├─ git-workflow.md
      ├─ session-content-guide.md
      ├─ active-sessions.yaml
      ├─ goal-tracker.md
      ├─ architecture.md
      └─ sessions/<session-id>/
```

注册 active session 后，创建最小会话状态：

```bash
scripts/core/ensure-state.sh build .claude/state <session-id> minimal
```

跨模块、改变 schema/状态/持久化/主控制流的重大 build 使用 `major`，额外创建
`algorithm.md`、`engineering.md` 和 `data-dict.md`：

```bash
scripts/core/ensure-state.sh build .claude/state <session-id> major
```

## Governance hooks

- `SessionStart` / `PreCompact`：绑定当前 Git 分支与 active session，并重新注入阅读入口。
- `PreToolUse`：阻止错分支、跨会话、路径越权、未批准代码写入和长期文档整文件覆盖。
- `PostToolUse`：校验 YAML frontmatter 和必填状态字段。
- `Stop`：检查路径归属、跨会话污染、全局文档分支边界、`session.md` 同步和可选
  `document_rules`。
- `SessionEnd`：提醒将未提交工作树收敛为可运行检查点。

没有 `.claude/state/active-sessions.yaml` 的项目不会启用严格治理。hooks 只强制可确定的
结构、阶段和归属；算法内容是否正确仍需计划批准、代码评审和测试。

## 验证

```bash
python3 -m unittest discover -s tests -v
python3 -m py_compile hooks/session-governance.py
bash -n scripts/core/*.sh hooks/summarize/*.sh
jq empty .claude-plugin/plugin.json hooks/hooks.json
```
