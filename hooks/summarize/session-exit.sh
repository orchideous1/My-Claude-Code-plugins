#!/usr/bin/env bash
# shellcheck disable=SC1091
#
# session-exit.sh - 会话退出前检查是否有未归档的 dirty 状态。
#
# 用法：
#   hooks/summarize/session-exit.sh [--json] [STATE_DIR]
#
# 参数：
#   --json      - 以 JSON 格式输出，便于 Claude Code hook 解析
#   STATE_DIR   - 状态文件目录，默认为 .claude/state
#
# 环境变量：
#   CLAUDE_SESSION_ID - 会话标识，未设置时默认为 "default"
#
# 行为：
#   如果当前会话的 session.md 包含本次会话的具体内容（不只是初始模板），
#   则打印提醒，建议用户运行 /summarize 进行归档。
#
# 退出码：
#   0 - 始终返回 0，不阻断会话退出
#

set -euo pipefail

JSON_OUTPUT=false
STATE_DIR=".claude/state"
SESSION_ID="${CLAUDE_SESSION_ID:-default}"

# 解析参数
for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_OUTPUT=true
            ;;
        *)
            STATE_DIR="$arg"
            ;;
    esac
done

SESSION_FILE="$STATE_DIR/sessions/$SESSION_ID/session.md"

if [[ ! -f "$SESSION_FILE" ]]; then
    exit 0
fi

# 读取 session.md 中 ## 已完成 之后的内容
body=$(sed -n '/^## 已完成$/,$p' "$SESSION_FILE" | tail -n +2)

# 如果已完成部分有非空、非注释内容，则认为 dirty
if echo "$body" | grep -v '^\s*$' | grep -v '^## ' | grep -q '.'; then
    msg="【提醒】检测到 session.md 中有未归档的会话内容。建议运行 /summarize 进行回顾、对齐与归档，避免内容被覆盖或丢失。"
    if [[ "$JSON_OUTPUT" == true ]]; then
        echo "{\"systemMessage\": \"$msg\"}"
    else
        echo ""
        echo "$msg"
        echo ""
    fi
fi

exit 0
