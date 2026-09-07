#!/usr/bin/env bash
#
# write-archive.sh - 将已确认的长期参考文档写入 archive。
#
# 说明：不再维护 archive/index.md；归档索引由 summarize 技能
#       在项目级 CLAUDE.md 的「已归档内容」区维护。
#
# 用法：
#   scripts/core/write-archive.sh <SOURCE_FILE> <DESCRIPTION> [STATE_DIR]
#
# 参数：
#   SOURCE_FILE   - 已确认的 reference.md 文件路径
#   DESCRIPTION   - 用于文件名的简短描述
#   STATE_DIR     - 可选：状态根目录，默认 .claude/state
#
# 退出码：
#   0 - 归档成功
#   1 - 归档失败
#

set -euo pipefail

SOURCE_FILE="${1:-}"
DESCRIPTION="${2:-}"
STATE_DIR="${3:-.claude/state}"

if [[ -z "$SOURCE_FILE" ]] || [[ -z "$DESCRIPTION" ]]; then
    echo "错误：缺少 SOURCE_FILE 或 DESCRIPTION 参数" >&2
    echo "用法：write-archive.sh <SOURCE_FILE> <DESCRIPTION> [STATE_DIR]" >&2
    exit 1
fi

if [[ ! -f "$SOURCE_FILE" ]] || [[ ! -s "$SOURCE_FILE" ]]; then
    echo "错误：SOURCE_FILE 不存在或为空：$SOURCE_FILE" >&2
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

ARCHIVE_DIR="$STATE_DIR/archive"
mkdir -p "$ARCHIVE_DIR"

TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)

# 清理描述
SAFE_DESC=$(echo "$DESCRIPTION" | tr ' ' '-' | tr -cd 'a-zA-Z0-9一-龥_-')
[[ -z "$SAFE_DESC" ]] && SAFE_DESC="session"

ARCHIVE_NAME_BASE="${TIMESTAMP}-${SAFE_DESC}"
ARCHIVE_FILE="$ARCHIVE_DIR/${ARCHIVE_NAME_BASE}-reference.md"

# 命名规范检查
if [[ ! "$ARCHIVE_NAME_BASE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}-[a-zA-Z0-9_一-龥-]+$ ]]; then
    echo "错误：归档名称不符合规范：$ARCHIVE_NAME_BASE" >&2
    exit 1
fi

cp "$SOURCE_FILE" "$ARCHIVE_FILE"
echo "已归档参考文档：$ARCHIVE_FILE"
