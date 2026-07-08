#!/usr/bin/env bash
# shellcheck disable=SC1091
#
# archive.sh - 在用户确认后执行会话归档。
#
# 用法：
#   hooks/documentation/archive.sh [DESCRIPTION] [STATE_DIR]
#
# 参数：
#   DESCRIPTION - 归档文件简短描述，默认为 "session"
#   STATE_DIR   - 状态文件目录，默认为 .claude/state
#
# 退出码：
#   0 - 归档成功
#   1 - 归档失败
#
# 归档规则：
#   1. 生成文件名：<时间戳>-<简短描述>.md
#   2. 将 session.md 内容迁移到归档文件
#   3. 如 architecture.md 存在，复制一份到归档目录并附带原时间戳
#   4. 重置 session.md 为初始状态
#   5. 校验命名规范：文件名只包含时间戳、连字符、中文、字母、数字
#

set -euo pipefail

DESCRIPTION="${1:-session}"
STATE_DIR="${2:-.claude/state}"
ARCHIVE_DIR="$STATE_DIR/archive"

TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
# 将描述中的空格替换为连字符，限制长度
SAFE_DESC=$(echo "$DESCRIPTION" | tr ' ' '-' | tr -cd 'a-zA-Z0-9一-龥_-')
if [[ -z "$SAFE_DESC" ]]; then
    SAFE_DESC="session"
fi

ARCHIVE_NAME="${TIMESTAMP}-${SAFE_DESC}.md"
ARCHIVE_PATH="$ARCHIVE_DIR/$ARCHIVE_NAME"
SESSION_FILE="$STATE_DIR/session.md"
GOAL_FILE="$STATE_DIR/goal-tracker.md"
ARCH_FILE="$STATE_DIR/architecture.md"

# 命名规范检查：文件名格式为 <timestamp>-<desc>.md
if [[ ! "$ARCHIVE_NAME" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}-[a-zA-Z0-9_一-龥-]+\.md$ ]]; then
    echo "错误：归档文件名不符合规范：$ARCHIVE_NAME" >&2
    exit 1
fi

# 确保归档目录存在
mkdir -p "$ARCHIVE_DIR"

# 检查 session.md 是否存在
if [[ ! -f "$SESSION_FILE" ]]; then
    echo "错误：session.md 不存在" >&2
    exit 1
fi

# 迁移 architecture.md（如果存在且有内容）
if [[ -f "$ARCH_FILE" ]] && [[ -s "$ARCH_FILE" ]]; then
    ARCHIVE_ARCH_NAME="${TIMESTAMP}-${SAFE_DESC}-architecture.md"
    ARCHIVE_ARCH_PATH="$ARCHIVE_DIR/$ARCHIVE_ARCH_NAME"
    cp "$ARCH_FILE" "$ARCHIVE_ARCH_PATH"
    echo "已迁移 architecture.md 到：$ARCHIVE_ARCH_PATH"
fi

# 将 session.md 内容迁移到归档文件
cp "$SESSION_FILE" "$ARCHIVE_PATH"
echo "已归档 session.md 到：$ARCHIVE_PATH"

# 重置 session.md 为初始状态
cat > "$SESSION_FILE" <<'EOF'
---
current_phase: IDLE
task:
started:
updated:
---

# 当前会话

## 已完成

## 下一步建议

EOF

echo "已重置 session.md"
