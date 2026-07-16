#!/usr/bin/env bash
#
# cleanup-session.sh - 归档后删除会话目录。
#
# 用法：
#   scripts/core/cleanup-session.sh [STATE_DIR] [SESSION_ID]
#
# 参数：
#   STATE_DIR  - 状态根目录，默认 .claude/state
#   SESSION_ID - 会话标识；默认读取 .current-session-id 或 CLAUDE_SESSION_ID
#

set -euo pipefail

STATE_DIR="${1:-.claude/state}"
SESSION_ID="${2:-}"

if [[ -z "$SESSION_ID" ]]; then
    if [[ -f "$STATE_DIR/.current-session-id" ]]; then
        SESSION_ID=$(cat "$STATE_DIR/.current-session-id")
    else
        SESSION_ID="${CLAUDE_SESSION_ID:-default}"
    fi
fi

SESSION_DIR="$STATE_DIR/sessions/$SESSION_ID"

if [[ ! -d "$SESSION_DIR" ]]; then
    echo "会话目录不存在，无需清理：$SESSION_DIR"
    exit 0
fi

rm -rf "$SESSION_DIR"
echo "已清理会话目录：$SESSION_DIR"

# 可选：清理当前会话 ID 持久化文件（如果它指向被删除的会话）
if [[ -f "$STATE_DIR/.current-session-id" ]]; then
    CURRENT=$(cat "$STATE_DIR/.current-session-id")
    if [[ "$CURRENT" == "$SESSION_ID" ]]; then
        rm -f "$STATE_DIR/.current-session-id"
    fi
fi
