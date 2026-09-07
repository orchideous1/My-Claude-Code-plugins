#!/usr/bin/env bash
#
# reset-session.sh - 将 session.md 重置为 IDLE 模板。
#
# 用法：
#   scripts/core/reset-session.sh [<SESSION_FILE>]
#
# 若未提供 SESSION_FILE，根据 CLAUDE_SESSION_ID 环境变量（或 default）构造路径。
#

set -euo pipefail

SESSION_FILE="${1:-}"

if [[ -z "$SESSION_FILE" ]]; then
    STATE_DIR="${STATE_DIR:-.claude/state}"
    SESSION_ID="${CLAUDE_SESSION_ID:-default}"
    SESSION_FILE="$STATE_DIR/sessions/$SESSION_ID/session.md"
fi

DATE="$(date +%Y-%m-%d)"

if [[ ! -f "$SESSION_FILE" ]]; then
    echo "错误：会话文件不存在，拒绝隐式创建：$SESSION_FILE" >&2
    exit 1
fi

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
