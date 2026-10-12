#!/usr/bin/env bash
#
# ensure-state.sh - 初始化并校验已获准创建的单会话状态目录。
#
# 用法：
#   scripts/core/ensure-state.sh [workflow] [STATE_DIR] [SESSION_ID] [PROFILE]
#
# 参数：
#   workflow   - build | read | arch | general，默认 general
#   STATE_DIR  - 状态根目录，默认 .claude/state
#   SESSION_ID - 会话标识；默认读取 CLAUDE_SESSION_ID 环境变量，否则 default
#   PROFILE    - minimal | major；major 为重大 build 创建算法/工程/数据字典
#
# 退出码：
#   0 - 状态目录已就绪
#   1 - 初始化失败
#

set -euo pipefail

WORKFLOW="${1:-general}"
STATE_DIR="${2:-.claude/state}"
SESSION_ID="${3:-${CLAUDE_SESSION_ID:-default}}"
PROFILE="${4:-minimal}"
DATE="$(date +%Y-%m-%d)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_DIR="$PLUGIN_ROOT/prompt-templates/state"

SESSIONS_DIR="$STATE_DIR/sessions"
SESSION_DIR="$SESSIONS_DIR/$SESSION_ID"

SESSION_FILE="$SESSION_DIR/session.md"
PLAN_FILE="$SESSION_DIR/plan.md"
ARCH_FILE="$SESSION_DIR/architecture.md"
ALGORITHM_FILE="$SESSION_DIR/algorithm.md"
ENGINEERING_FILE="$SESSION_DIR/engineering.md"
DATA_DICT_FILE="$SESSION_DIR/data-dict.md"
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
    local initial_phase="IDLE"
    case "$WORKFLOW" in
        build) initial_phase="UNDERSTANDING" ;;
        read|arch) initial_phase="SCOPE" ;;
    esac
    sed \
        -e "s/YYYY-MM-DD/${DATE}/g" \
        -e "s/SESSION_ID/${SESSION_ID}/g" \
        -e "s/^current_phase:.*/current_phase: ${initial_phase}/" \
        "$TEMPLATE_DIR/session.md" > "$SESSION_FILE"
}

write_plan_template() {
    sed -e "s/YYYY-MM-DD/${DATE}/g" \
        "$TEMPLATE_DIR/plan.md" > "$PLAN_FILE"
}

write_arch_template() {
    cat > "$ARCH_FILE" <<EOF
---
title: 架构模型
status: draft
updated: ${DATE}
---

# 架构模型

EOF
}

write_template() {
    local template="$1"
    local target="$2"
    sed -e "s/YYYY-MM-DD/${DATE}/g" "$template" > "$target"
}

case "$PROFILE" in
    minimal|major)
        ;;
    *)
        echo "错误：未知 PROFILE：$PROFILE（允许 minimal | major）" >&2
        exit 1
        ;;
esac

# 1. session.md 缺失时创建；已有文件异常时拒绝覆盖
if [[ ! -f "$SESSION_FILE" ]]; then
    write_session_template
elif ! validate_frontmatter "$SESSION_FILE" "current_phase"; then
    echo "错误：已有 session.md frontmatter 异常，拒绝自动覆盖：$SESSION_FILE" >&2
    exit 1
fi

# 2. 仅创建 workflow 需要的中间产物。reference.md 仅在 summarize
#    判定会话具有长期参考价值后生成，不能作为默认模板。
case "$WORKFLOW" in
    build)
        if [[ ! -f "$PLAN_FILE" ]]; then
            write_plan_template
        elif ! validate_frontmatter "$PLAN_FILE" "status"; then
            echo "错误：已有 plan.md frontmatter 异常，拒绝自动覆盖：$PLAN_FILE" >&2
            exit 1
        fi
        if [[ "$PROFILE" == "major" ]]; then
            [[ -f "$ALGORITHM_FILE" ]] || \
                write_template "$TEMPLATE_DIR/algorithm.md" "$ALGORITHM_FILE"
            [[ -f "$ENGINEERING_FILE" ]] || \
                write_template "$TEMPLATE_DIR/engineering.md" "$ENGINEERING_FILE"
            [[ -f "$DATA_DICT_FILE" ]] || \
                write_template "$TEMPLATE_DIR/data-dict.md" "$DATA_DICT_FILE"
        fi
        ;;
    arch)
        if [[ ! -f "$ARCH_FILE" ]]; then
            write_arch_template
        elif ! validate_frontmatter "$ARCH_FILE" "status"; then
            echo "错误：已有 architecture.md frontmatter 异常，拒绝自动覆盖：$ARCH_FILE" >&2
            exit 1
        fi
        ;;
    read|general)
        ;;
    *)
        echo "错误：未知 workflow：$WORKFLOW" >&2
        exit 1
        ;;
esac

# 更新 updated 字段（如果 frontmatter 中存在）
if grep -q "^updated:" "$SESSION_FILE"; then
    sed -i "s/^updated:.*/updated: ${DATE}/" "$SESSION_FILE"
fi

echo "$SESSION_ID"
exit 0
