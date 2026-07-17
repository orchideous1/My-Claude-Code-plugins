#!/usr/bin/env bash
# shellcheck disable=SC1091
#
# archive.sh - 在用户确认后执行 guide 归档的 hook 入口。
#
# 用法：
#   hooks/summarize/archive.sh <SOURCE_FILE> <DESCRIPTION> [WORKFLOW_TYPE] [STATE_DIR]
#
# 参数：
#   SOURCE_FILE   - 已确认的 guide 文件路径
#   DESCRIPTION   - 归档文件简短描述
#   WORKFLOW_TYPE - 可选：build | read | arch | general
#   STATE_DIR     - 状态根目录，默认 .claude/state
#
# 说明：
#   本 hook 仅为入口，实际归档逻辑委托给 scripts/core/write-archive.sh，
#   归档成功后调用 scripts/core/cleanup-session.sh 删除原会话目录。
#   会话 ID 从 SOURCE_FILE 路径推断（假定其位于 sessions/<id>/ 下）。
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)/scripts/core"

SOURCE_FILE="${1:-}"
DESCRIPTION="${2:-}"
WORKFLOW_TYPE="${3:-}"
STATE_DIR="${4:-.claude/state}"

if [[ -z "$SOURCE_FILE" ]] || [[ -z "$DESCRIPTION" ]]; then
    echo "错误：缺少 SOURCE_FILE 或 DESCRIPTION 参数" >&2
    echo "用法：archive.sh <SOURCE_FILE> <DESCRIPTION> [WORKFLOW_TYPE] [STATE_DIR]" >&2
    exit 1
fi

"$SCRIPTS_DIR/write-archive.sh" "$SOURCE_FILE" "$DESCRIPTION" "$WORKFLOW_TYPE" "$STATE_DIR"

# 从 SOURCE_FILE 推断 SESSION_ID（SOURCE_FILE 必须位于 sessions/<id>/ 下）
if [[ ! "$SOURCE_FILE" =~ sessions/[^/]+/ ]]; then
    echo "错误：SOURCE_FILE 必须位于 sessions/<id>/ 目录下：$SOURCE_FILE" >&2
    exit 1
fi
SESSION_ID=$(basename "$(dirname "$SOURCE_FILE")")

"$SCRIPTS_DIR/cleanup-session.sh" "$STATE_DIR" "$SESSION_ID"
