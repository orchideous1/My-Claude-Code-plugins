#!/usr/bin/env bash
#
# infer-workflow.sh - 从 session.md 推断 workflow 类型。
#
# 用法：
#   scripts/core/infer-workflow.sh [<SESSION_FILE>]
#
# 若未提供 SESSION_FILE，则根据 CLAUDE_SESSION_ID 环境变量（或 default）构造路径。
#
# 输出到 stdout：build | read | arch | general
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SESSION_FILE="${1:-}"

if [[ -z "$SESSION_FILE" ]]; then
    STATE_DIR="${STATE_DIR:-.claude/state}"
    SESSION_ID="${CLAUDE_SESSION_ID:-default}"
    SESSION_FILE="$STATE_DIR/sessions/$SESSION_ID/session.md"
fi

if [[ ! -f "$SESSION_FILE" ]]; then
    echo "general"
    exit 0
fi

# 从第一个 YAML frontmatter 块中提取字段
get_frontmatter_field() {
    local field="$1"
    awk -v field="$field" '/^---$/{if(++count<=2) p=!p; next} p {
        if ($0 ~ "^" field ":") {
            sub("^" field ": *", "")
            print
            exit
        }
    }' "$SESSION_FILE"
}

# 优先按 task 关键字匹配（支持中英文）
task=$(get_frontmatter_field "task")
case "$task" in
    *build*|*BUILD*|*Build*|*构建*|*重构*|*开发*|*实现*|*修改*|*生成代码*|*coding*|*Coding*|*设计*|*改写*|*重写*|*升级*|*改进*|*优化*)
        echo "build"; exit 0 ;;
    *read*|*READ*|*Read*|*阅读*|*排查*|*调试*|*故障*|*调查*|*bugfix*|*Bugfix*|*定位*)
        echo "read"; exit 0 ;;
    *arch*|*ARCH*|*Arch*|*architecture*|*ARCHITECTURE*|*Architecture*|*架构*|*建模*|*结构*|*梳理*)
        echo "arch"; exit 0 ;;
esac

# 其次按 current_phase 匹配
phase=$(get_frontmatter_field "current_phase")
case "$phase" in
    UNDERSTANDING|PLANNING|EXECUTING|VERIFYING|REFLECTING)
        echo "build" ;;
    SCOPE|HYPOTHESIS|EVIDENCE|REPORT|FIX)
        echo "read" ;;
    SURVEY|DRILL|CONNECT|MODEL)
        echo "arch" ;;
    *)
        echo "general" ;;
esac
