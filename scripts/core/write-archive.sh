#!/usr/bin/env bash
#
# write-archive.sh - 将已确认的 guide 写入 archive 并更新索引。
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
#   CLAUDE_SESSION_ID - 若未提供且 .current-session-id 不存在，则使用 default
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

SESSION_ID=""
if [[ -f "$STATE_DIR/.current-session-id" ]]; then
    SESSION_ID=$(cat "$STATE_DIR/.current-session-id")
else
    SESSION_ID="${CLAUDE_SESSION_ID:-default}"
fi

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

# 提取摘要
SUMMARY=$(sed -n '/^# /,$p' "$SOURCE_FILE" | tail -n +2 | grep -v '^\s*$' | head -n 1)
[[ -z "$SUMMARY" ]] && SUMMARY="无摘要"

# 更新 archive/index.md
INDEX_FILE="$ARCHIVE_DIR/index.md"
if [[ ! -f "$INDEX_FILE" ]]; then
    cat > "$INDEX_FILE" <<'EOF'
---
updated:
---

# 归档索引

本文件由 `archive.sh` 自动维护，记录所有已归档的会话总结。新会话开始时应优先读取本文件以了解历史进展。

## 归档记录

EOF
fi

REL_LINK="archive/$(basename "$ARCHIVE_FILE")"

{
    echo ""
    echo "### $ARCHIVE_NAME_BASE"
    echo ""
    echo "- **类型**: $WORKFLOW_TYPE"
    echo "- **时间**: $TIMESTAMP"
    echo "- **会话**: $SESSION_ID"
    echo "- **摘要**: $SUMMARY"
    echo "- $SUFFIX: [$REL_LINK]($REL_LINK)"
} >> "$INDEX_FILE"

sed -i "s/^updated:.*/updated: $(date +%Y-%m-%d)/" "$INDEX_FILE"

echo "已更新归档索引：$INDEX_FILE"
