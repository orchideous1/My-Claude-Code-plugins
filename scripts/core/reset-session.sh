#!/usr/bin/env bash
#
# reset-session.sh - 将 session.md 重置为 IDLE 模板。
#
# 用法：
#   scripts/core/reset-session.sh [<SESSION_FILE>]
#
# 若未提供 SESSION_FILE，根据 .current-session-id 或 CLAUDE_SESSION_ID 构造路径。
#

set -euo pipefail

SESSION_FILE="${1:-}"

if [[ -z "$SESSION_FILE" ]]; then
    STATE_DIR="${STATE_DIR:-.claude/state}"
    SESSION_ID=""

    if [[ -f "$STATE_DIR/.current-session-id" ]]; then
        SESSION_ID=$(cat "$STATE_DIR/.current-session-id")
    else
        SESSION_ID="${CLAUDE_SESSION_ID:-default}"
    fi

    SESSION_FILE="$STATE_DIR/sessions/$SESSION_ID/session.md"
fi

DATE="$(date +%Y-%m-%d)"
mkdir -p "$(dirname "$SESSION_FILE")"

cat > "$SESSION_FILE" <<EOF
---
current_phase: IDLE
task:
started: ${DATE}
updated: ${DATE}
---

# 当前会话

## 已完成

## 下一步建议

EOF
