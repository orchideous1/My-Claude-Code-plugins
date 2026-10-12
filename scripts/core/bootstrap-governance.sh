#!/usr/bin/env bash
#
# bootstrap-governance.sh - 非覆盖式初始化层级化项目治理文档。
#
# 用法：
#   scripts/core/bootstrap-governance.sh [PROJECT_ROOT] [INTEGRATION_BRANCH]
#
# 只创建缺失文件；已有治理文档和状态文件绝不会被覆盖。已有工作区
# `.claude/CLAUDE.md` 仅追加带标记的层级化治理入口，原内容保持不变。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_DIR="$PLUGIN_ROOT/prompt-templates/state"

PROJECT_ROOT="${1:-.}"
PROJECT_ROOT="$(realpath -m "$PROJECT_ROOT")"
INTEGRATION_BRANCH="${2:-}"
DATE="$(date +%Y-%m-%d)"

if [[ -z "$INTEGRATION_BRANCH" ]]; then
    INTEGRATION_BRANCH=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || true)
fi
INTEGRATION_BRANCH="${INTEGRATION_BRANCH:-main}"

mkdir -p \
    "$PROJECT_ROOT/.claude/state/sessions" \
    "$PROJECT_ROOT/.claude/state/archive"

render_template() {
    local template="$1"
    sed \
        -e "s/YYYY-MM-DD/$DATE/g" \
        -e "s|^integration_branch: .*|integration_branch: $INTEGRATION_BRANCH|" \
        "$template"
}

render_missing() {
    local template="$1"
    local target="$2"
    if [[ -e "$target" ]]; then
        echo "保留已有文件：${target#$PROJECT_ROOT/}"
        return 0
    fi
    if [[ ! -f "$template" ]]; then
        echo "错误：初始化模板不存在：$template" >&2
        return 1
    fi
    render_template "$template" > "$target"
    echo "已创建：${target#$PROJECT_ROOT/}"
}

append_claude_hierarchy() {
    local target="$1"
    local fragment="$TEMPLATE_DIR/CLAUDE_hierarchy.md"
    local marker="<!-- structured-governance:start -->"

    if [[ ! -f "$fragment" ]]; then
        echo "错误：层级化入口模板不存在：$fragment" >&2
        return 1
    fi
    if grep -Fq "$marker" "$target"; then
        echo "保留已有层级化入口：${target#$PROJECT_ROOT/}"
        return 0
    fi

    if [[ -s "$target" ]]; then
        if [[ -n "$(tail -c 1 "$target")" ]]; then
            printf '\n' >> "$target"
        fi
        printf '\n' >> "$target"
    fi
    render_template "$fragment" >> "$target"
    echo "已补充层级化入口：${target#$PROJECT_ROOT/}"
}

CLAUDE_TARGET="$PROJECT_ROOT/.claude/CLAUDE.md"
if [[ ! -e "$CLAUDE_TARGET" ]]; then
    render_missing "$TEMPLATE_DIR/CLAUDE_example.md" "$CLAUDE_TARGET"
fi
append_claude_hierarchy "$CLAUDE_TARGET"
render_missing "$TEMPLATE_DIR/AGENTS.md" \
    "$PROJECT_ROOT/AGENTS.md"
render_missing "$TEMPLATE_DIR/development-governance.md" \
    "$PROJECT_ROOT/.claude/state/development-governance.md"
render_missing "$TEMPLATE_DIR/git-workflow.md" \
    "$PROJECT_ROOT/.claude/state/git-workflow.md"
render_missing "$TEMPLATE_DIR/session-content-guide.md" \
    "$PROJECT_ROOT/.claude/state/session-content-guide.md"
render_missing "$TEMPLATE_DIR/active-sessions.yaml" \
    "$PROJECT_ROOT/.claude/state/active-sessions.yaml"
render_missing "$TEMPLATE_DIR/goal-tracker_example.md" \
    "$PROJECT_ROOT/.claude/state/goal-tracker.md"
render_missing "$TEMPLATE_DIR/architecture.md" \
    "$PROJECT_ROOT/.claude/state/architecture.md"
render_missing "$TEMPLATE_DIR/CONTRIBUTING.md" \
    "$PROJECT_ROOT/CONTRIBUTING.md"

echo "治理骨架已就绪。下一步在集成分支登记 active session，再调用 ensure-state.sh。"
