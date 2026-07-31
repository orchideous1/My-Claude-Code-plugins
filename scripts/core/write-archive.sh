#!/usr/bin/env bash
#
# write-archive.sh - 将已确认的 guide 写入 archive。
#
# 说明：不再维护 archive/index.md；归档索引由 summarize 技能
#       在项目级 CLAUDE.md 的「已归档内容」区维护。
#
# 用法：
#   scripts/core/write-archive.sh <SOURCE_FILE> <DESCRIPTION> [WORKFLOW_TYPE] [STATE_DIR]
#
# 参数：
#   SOURCE_FILE   - 已确认的 guide 文件路径
#   DESCRIPTION   - 用于文件名的简短描述
#   WORKFLOW_TYPE - 可选：build | read | arch | general；省略时从 session.md 推断
#   STATE_DIR     - 状态根目录，默认 .claude/state
#
# 环境变量：
#   CLAUDE_SESSION_ID - 会话 ID 来源之一，优先级最高
#
# SESSION_ID 回退顺序：
#   1. CLAUDE_SESSION_ID 环境变量
#   2. 从 SOURCE_FILE 路径推断（要求位于 sessions/<id>/ 下）
#   3. 字面量 default
#
# 退出码：
#   0 - 归档成功
#   1 - 归档失败
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOURCE_FILE="${1:-}"
DESCRIPTION="${2:-}"
WORKFLOW_TYPE="${3:-}"
STATE_DIR="${4:-.claude/state}"

if [[ -z "$SOURCE_FILE" ]] || [[ -z "$DESCRIPTION" ]]; then
    echo "错误：缺少 SOURCE_FILE 或 DESCRIPTION 参数" >&2
    echo "用法：write-archive.sh <SOURCE_FILE> <DESCRIPTION> [WORKFLOW_TYPE] [STATE_DIR]" >&2
    exit 1
fi

if [[ ! -f "$SOURCE_FILE" ]] || [[ ! -s "$SOURCE_FILE" ]]; then
    echo "错误：SOURCE_FILE 不存在或为空：$SOURCE_FILE" >&2
    exit 1
fi

SESSION_ID="${CLAUDE_SESSION_ID:-}"
if [[ -z "$SESSION_ID" ]] && [[ "$SOURCE_FILE" =~ sessions/[^/]+/ ]]; then
    SESSION_ID=$(basename "$(dirname "$SOURCE_FILE")")
fi
SESSION_ID="${SESSION_ID:-default}"

ARCHIVE_DIR="$STATE_DIR/archive"
mkdir -p "$ARCHIVE_DIR"

TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)

# 推断 workflow 类型
if [[ -z "$WORKFLOW_TYPE" ]]; then
    WORKFLOW_TYPE=$("$SCRIPT_DIR/infer-workflow.sh" "$STATE_DIR/sessions/$SESSION_ID/session.md")
fi

# 确定产物后缀
case "$WORKFLOW_TYPE" in
    arch)
        SUFFIX="model"
        ;;
    read)
        SUFFIX="report"
        ;;
    build)
        SUFFIX="handoff"
        ;;
    general|*)
        SUFFIX="summary"
        ;;
esac

# 清理描述
SAFE_DESC=$(echo "$DESCRIPTION" | tr ' ' '-' | tr -cd 'a-zA-Z0-9一-龥_-')
[[ -z "$SAFE_DESC" ]] && SAFE_DESC="session"

ARCHIVE_NAME_BASE="${TIMESTAMP}-${SAFE_DESC}"
ARCHIVE_FILE="$ARCHIVE_DIR/${ARCHIVE_NAME_BASE}-${WORKFLOW_TYPE}-${SUFFIX}.md"

# 命名规范检查
if [[ ! "$ARCHIVE_NAME_BASE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}-[a-zA-Z0-9_一-龥-]+$ ]]; then
    echo "错误：归档名称不符合规范：$ARCHIVE_NAME_BASE" >&2
    exit 1
fi

cp "$SOURCE_FILE" "$ARCHIVE_FILE"
echo "已归档 guide：$ARCHIVE_FILE"
