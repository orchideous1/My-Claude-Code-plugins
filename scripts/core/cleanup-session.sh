#!/usr/bin/env bash
#
# cleanup-session.sh - 归档后删除会话目录。
#
# 用法：
#   scripts/core/cleanup-session.sh [STATE_DIR] [SESSION_ID]
#
# 参数：
#   STATE_DIR  - 状态根目录，默认 .claude/state
#   SESSION_ID - 会话标识；默认读取 CLAUDE_SESSION_ID 环境变量，否则 default
#

set -euo pipefail

STATE_DIR="${1:-.claude/state}"
SESSION_ID="${2:-}"

if [[ -z "$SESSION_ID" ]]; then
    SESSION_ID="${CLAUDE_SESSION_ID:-default}"
fi

SESSION_DIR="$STATE_DIR/sessions/$SESSION_ID"

if [[ ! -d "$SESSION_DIR" ]]; then
    echo "会话目录不存在，无需清理：$SESSION_DIR"
    exit 0
fi

rm -rf "$SESSION_DIR"
echo "已清理会话目录：$SESSION_DIR"
