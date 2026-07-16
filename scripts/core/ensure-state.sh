#!/usr/bin/env bash
#
# ensure-state.sh - 初始化并校验单会话状态目录与文件。
#
# 用法：
#   scripts/core/ensure-state.sh [workflow] [STATE_DIR] [SESSION_ID]
#
# 参数：
#   workflow   - build | read | arch | general，默认 general
#   STATE_DIR  - 状态根目录，默认 .claude/state
#   SESSION_ID - 会话标识；默认读取 CLAUDE_SESSION_ID 环境变量，否则 default
#
# 说明：
#   最终使用的 SESSION_ID 会写入 .claude/state/.current-session-id，
#   供同一会话内的其他脚本在环境变量未显式设置时读取。
#
# 退出码：
#   0 - 状态目录已就绪
#   1 - 初始化失败
#

set -euo pipefail

WORKFLOW="${1:-general}"
STATE_DIR="${2:-.claude/state}"
SESSION_ID="${3:-${CLAUDE_SESSION_ID:-default}}"
DATE="$(date +%Y-%m-%d)"

SESSIONS_DIR="$STATE_DIR/sessions"
SESSION_DIR="$SESSIONS_DIR/$SESSION_ID"

SESSION_FILE="$SESSION_DIR/session.md"
PLAN_FILE="$SESSION_DIR/plan.md"
ARCH_FILE="$SESSION_DIR/architecture.md"
HANDOFF_FILE="$SESSION_DIR/handoff.md"

mkdir -p "$SESSION_DIR"

# 校验文件是否包含 YAML frontmatter 且包含指定字段
validate_frontmatter() {
    local file="$1"
    local field="$2"

    [[ -f "$file" ]] || return 1

    local frontmatter
    frontmatter=$(awk '/^---$/{if(++count<=2) p=!p; next} p' "$file")
    [[ -n "$frontmatter" ]] || return 1

    echo "$frontmatter" | grep -q "^${field}:" || return 1
    return 0
}

write_session_template() {
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
}

write_plan_template() {
    cat > "$PLAN_FILE" <<'EOF'
---
title:
status: draft
phase:
created:
updated:
---

# 计划

EOF
}

write_arch_template() {
    cat > "$ARCH_FILE" <<'EOF'
---
title:
status: draft
updated:
---

# 架构模型

EOF
}

write_handoff_template() {
    cat > "$HANDOFF_FILE" <<'EOF'
---
---

# 交接摘要

EOF
}

# 持久化当前会话 ID
echo "$SESSION_ID" > "$STATE_DIR/.current-session-id"

# 1. session.md 必须存在且 frontmatter 完整
if ! validate_frontmatter "$SESSION_FILE" "current_phase"; then
    write_session_template
fi

# 2. 确保各中间产物模板存在
if [[ ! -f "$PLAN_FILE" ]]; then
    write_plan_template
fi

if [[ ! -f "$ARCH_FILE" ]]; then
    write_arch_template
fi

if [[ ! -f "$HANDOFF_FILE" ]]; then
    write_handoff_template
fi

# 更新 updated 字段（如果 frontmatter 中存在）
if grep -q "^updated:" "$SESSION_FILE"; then
    sed -i "s/^updated:.*/updated: ${DATE}/" "$SESSION_FILE"
fi

echo "$SESSION_ID"
exit 0
