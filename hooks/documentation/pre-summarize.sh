#!/usr/bin/env bash
# shellcheck disable=SC1091
#
# pre-summarize.sh - 在 /summarize 执行前检查状态文件 frontmatter 完整性。
#
# 用法：
#   hooks/documentation/pre-summarize.sh [STATE_DIR]
#
# 参数：
#   STATE_DIR - 状态文件目录，默认为 .claude/state
#
# 退出码：
#   0 - 检查通过
#   1 - 发现状态文件异常
#

set -euo pipefail

STATE_DIR="${1:-.claude/state}"

SESSION_FILE="$STATE_DIR/session.md"
GOAL_FILE="$STATE_DIR/goal-tracker.md"

# 检查文件是否存在
if [[ ! -f "$SESSION_FILE" ]]; then
    echo "错误：session.md 不存在：$SESSION_FILE" >&2
    exit 1
fi

if [[ ! -f "$GOAL_FILE" ]]; then
    echo "错误：goal-tracker.md 不存在：$GOAL_FILE" >&2
    exit 1
fi

# 检查 YAML frontmatter 是否完整
# frontmatter 必须以 --- 开头和结尾，且包含指定的必填字段
check_frontmatter() {
    local file="$1"
    local required_field="$2"
    local content
    content=$(cat "$file")

    if ! echo "$content" | grep -q '^---$'; then
        echo "错误：$file 缺少 YAML frontmatter" >&2
        return 1
    fi

    # 提取第一个 frontmatter 块（--- 到下一个 --- 之间）
    local frontmatter
    frontmatter=$(echo "$content" | awk '/^---$/{if(++count<=2) p=!p; next} p')

    if [[ -z "$frontmatter" ]]; then
        echo "错误：$file 的 frontmatter 为空" >&2
        return 1
    fi

    if ! echo "$frontmatter" | grep -q "^${required_field}:"; then
        echo "错误：$file 的 frontmatter 缺少 ${required_field} 字段" >&2
        return 1
    fi

    return 0
}

check_frontmatter "$SESSION_FILE" "current_phase"
check_frontmatter "$GOAL_FILE" "updated"

echo "pre-summarize：状态文件 frontmatter 检查通过。"
