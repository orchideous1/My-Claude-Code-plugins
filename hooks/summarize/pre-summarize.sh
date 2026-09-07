#!/usr/bin/env bash
# shellcheck disable=SC1091
#
# pre-summarize.sh - 在 /summarize 执行前检查状态文件 frontmatter 完整性、
#                    旧路径冗余与并发会话冲突。
#                    goal-tracker.md 缺失时从标准模板自动初始化。
#                    仅在会话目录已存在时补全会话状态，避免凭空创建残留目录。
#
# 用法：
#   hooks/summarize/pre-summarize.sh [STATE_DIR]
#
# 参数：
#   STATE_DIR - 状态文件目录，默认为 .claude/state
#
# 环境变量：
#   CLAUDE_SESSION_ID - 会话标识，未设置时默认为 "default"
#
# 退出码：
#   0 - 检查通过
#   1 - 发现状态文件异常
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)/scripts/core"

STATE_DIR="${1:-.claude/state}"
SESSION_ID="${CLAUDE_SESSION_ID:-default}"
SESSION_FILE="$STATE_DIR/sessions/$SESSION_ID/session.md"
GOAL_FILE="$STATE_DIR/goal-tracker.md"
OLD_SESSION_FILE="$STATE_DIR/../session.md"
SESSIONS_DIR="$STATE_DIR/sessions"

# goal-tracker.md 缺失时从标准模板自动初始化；模板缺失才报错
# 模板路径相对于本脚本解析，仓库布局与 ~/.claude 部署布局均适用
GOAL_TEMPLATE="$SCRIPT_DIR/../../prompt-templates/state/goal-tracker_example.md"
if [[ ! -f "$GOAL_FILE" ]]; then
    if [[ -f "$GOAL_TEMPLATE" ]]; then
        cp "$GOAL_TEMPLATE" "$GOAL_FILE"
        echo "已从模板初始化 goal-tracker.md：$GOAL_FILE"
    else
        echo "错误：goal-tracker.md 不存在且初始化模板缺失：$GOAL_TEMPLATE" >&2
        exit 1
    fi
fi

# 检查 YAML frontmatter 是否完整
# frontmatter 必须以 --- 开头和结尾，且包含指定的必填字段
check_frontmatter() {
    local file="$1"
    local required_field="$2"
    local frontmatter
    frontmatter=$(awk '/^---$/{if(++count<=2) p=!p; next} p' "$file")

    if [[ -z "$frontmatter" ]]; then
        echo "错误：$file 缺少或 frontmatter 为空" >&2
        return 1
    fi

    if ! echo "$frontmatter" | grep -q "^${required_field}:"; then
        echo "错误：$file 的 frontmatter 缺少 ${required_field} 字段" >&2
        return 1
    fi

    return 0
}

# 使用 ensure-state.sh 补全已存在的当前会话状态（抑制 stdout）。
if [[ -d "$STATE_DIR/sessions/$SESSION_ID" ]]; then
    if ! "$SCRIPTS_DIR/ensure-state.sh" general "$STATE_DIR" "$SESSION_ID" > /dev/null; then
        echo "错误：无法初始化当前会话状态" >&2
        exit 1
    fi
    check_frontmatter "$SESSION_FILE" "current_phase"
fi

check_frontmatter "$GOAL_FILE" "updated"

# 检查旧路径 .claude/session.md 是否存在
if [[ -f "$OLD_SESSION_FILE" ]]; then
    echo "【警告】发现旧路径 $OLD_SESSION_FILE。" >&2
    echo "        规范路径为 $SESSION_FILE，请手动迁移或删除旧文件以避免冗余。" >&2
fi

# 并发会话冲突检测
# 若当前为 default 会话且存在其他非 default 会话目录，或存在其他 dirty 的 default 会话，则警告
detect_concurrent_dirty() {
    if [[ ! -d "$SESSIONS_DIR" ]]; then
        return 0
    fi

    local other_sessions=false
    local dirty_other=false

    for dir in "$SESSIONS_DIR"/*; do
        [[ -d "$dir" ]] || continue
        local id
        id=$(basename "$dir")
        [[ "$id" == "$SESSION_ID" ]] && continue

        other_sessions=true
        local other_session="$dir/session.md"
        if [[ -f "$other_session" ]]; then
            local body
            body=$(sed -n '/^## 已完成$/,$p' "$other_session" | tail -n +2)
            if echo "$body" | grep -v '^\s*$' | grep -v '^## ' | grep -q '.'; then
                dirty_other=true
            fi
        fi
    done

    if [[ "$other_sessions" == true ]] && [[ "$SESSION_ID" == "default" ]]; then
        echo "【警告】检测到非 default 会话目录，当前未设置 CLAUDE_SESSION_ID。" >&2
        echo "        建议为当前会话设置唯一的 CLAUDE_SESSION_ID 以避免状态冲突。" >&2
    fi

    if [[ "$dirty_other" == true ]]; then
        echo "【警告】检测到其他会话存在未归档的 dirty 状态。" >&2
        echo "        请在归档前确认不会覆盖其他会话的中间状态。" >&2
    fi
}

detect_concurrent_dirty

echo "pre-summarize：状态文件 frontmatter 检查通过。"
