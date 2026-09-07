#!/usr/bin/env bash
# shellcheck disable=SC1091
#
# archive.sh - 在用户确认后执行参考文档归档的 hook 入口。
#
# 用法：
#   hooks/summarize/archive.sh <SOURCE_FILE> <DESCRIPTION> [STATE_DIR]
#
# 参数：
#   SOURCE_FILE   - 已确认的 reference.md 文件路径
#   DESCRIPTION   - 归档文件简短描述
#   STATE_DIR     - 状态根目录，默认 .claude/state
#
# 说明：
#   本 hook 仅为入口，实际归档逻辑委托给 scripts/core/write-archive.sh，
#   归档成功后调用 scripts/core/cleanup-session.sh 删除原会话目录。
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)/scripts/core"

SOURCE_FILE="${1:-}"
DESCRIPTION="${2:-}"
STATE_DIR="${3:-.claude/state}"

if [[ -z "$SOURCE_FILE" ]] || [[ -z "$DESCRIPTION" ]]; then
    echo "错误：缺少 SOURCE_FILE 或 DESCRIPTION 参数" >&2
    echo "用法：archive.sh <SOURCE_FILE> <DESCRIPTION> [STATE_DIR]" >&2
    exit 1
fi

STATE_DIR=$(realpath -m "$STATE_DIR")
SOURCE_FILE=$(realpath -m "$SOURCE_FILE")
case "$SOURCE_FILE" in
    "$STATE_DIR"/sessions/*/reference.md)
        ;;
    *)
        echo "错误：SOURCE_FILE 必须是 sessions/<id>/reference.md：$SOURCE_FILE" >&2
        exit 1
        ;;
esac

if ! grep -Eq '^[[:space:]]*type:[[:space:]]*reference[[:space:]]*$' "$SOURCE_FILE"; then
    echo "错误：SOURCE_FILE 必须在 frontmatter 中声明 type: reference" >&2
    exit 1
fi

SESSION_ID=$(basename "$(dirname "$SOURCE_FILE")")

"$SCRIPTS_DIR/write-archive.sh" "$SOURCE_FILE" "$DESCRIPTION" "$STATE_DIR"

"$SCRIPTS_DIR/cleanup-session.sh" "$STATE_DIR" "$SESSION_ID"
