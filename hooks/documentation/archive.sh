#!/usr/bin/env bash
# shellcheck disable=SC1091
#
# archive.sh - 在用户确认后执行会话总结归档。
#
# 用法：
#   hooks/documentation/archive.sh [DESCRIPTION] [STATE_DIR]
#
# 参数：
#   DESCRIPTION - 归档文件简短描述，默认为 "session"
#   STATE_DIR   - 状态文件目录，默认为 .claude/state
#
# 环境变量：
#   CLAUDE_SESSION_ID - 会话标识，未设置时默认为 "default"
#
# 退出码：
#   0 - 归档成功
#   1 - 归档失败
#
# 归档规则：
#   1. 读取 CLAUDE_SESSION_ID 定位会话目录：STATE_DIR/sessions/<id>/
#   2. 根据 session.md 推断 workflow 类型：build / read / arch / general
#   3. 按工作流类型迁移总结产物到 archive/：
#      - build: handoff.md  -> <timestamp>-<desc>-build-handoff.md
#      - read:  handoff.md  -> <timestamp>-<desc>-read-report.md
#      - arch:  architecture.md -> <timestamp>-<desc>-arch-model.md
#      - general: handoff.md -> <timestamp>-<desc>-general-summary.md
#   4. 更新 archive/index.md
#   5. 不归档 session.md 与 plan.md，仅重置 session.md
#

set -euo pipefail

DESCRIPTION="${1:-session}"
STATE_DIR="${2:-.claude/state}"
SESSION_ID="${CLAUDE_SESSION_ID:-default}"
ARCHIVE_DIR="$STATE_DIR/archive"
SESSION_DIR="$STATE_DIR/sessions/$SESSION_ID"

TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)

# 将描述中的空格替换为连字符，限制字符范围
SAFE_DESC=$(echo "$DESCRIPTION" | tr ' ' '-' | tr -cd 'a-zA-Z0-9一-龥_-')
if [[ -z "$SAFE_DESC" ]]; then
    SAFE_DESC="session"
fi

ARCHIVE_NAME_BASE="${TIMESTAMP}-${SAFE_DESC}"
SESSION_FILE="$SESSION_DIR/session.md"
PLAN_FILE="$SESSION_DIR/plan.md"
HANDOFF_FILE="$SESSION_DIR/handoff.md"
ARCH_FILE="$SESSION_DIR/architecture.md"

# 命名规范检查：基础名称为 <timestamp>-<desc>
if [[ ! "$ARCHIVE_NAME_BASE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}-[a-zA-Z0-9_一-龥-]+$ ]]; then
    echo "错误：归档名称不符合规范：$ARCHIVE_NAME_BASE" >&2
    exit 1
fi

# 确保归档目录存在
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$SESSION_DIR"

# 检查 session.md 是否存在
if [[ ! -f "$SESSION_FILE" ]]; then
    echo "错误：session.md 不存在：$SESSION_FILE" >&2
    exit 1
fi

# 推断 workflow 类型
infer_workflow_type() {
    local file="$1"
    local phase task
    phase=$(awk '/^current_phase:/{print $2; exit}' "$file" 2>/dev/null || true)
    task=$(awk '/^task:/{sub(/^task: */,""); print; exit}' "$file" 2>/dev/null || true)

    # 优先按 task 关键字匹配（支持中英文）
    case "$task" in
        *build*|*BUILD*|*Build*|*构建*|*重构*|*开发*|*实现*|*修改*|*生成代码*|*coding*|*Coding*|*设计*|*改写*|*重写*|*升级*|*改进*|*优化*)
            echo "build"; return ;;
        *read*|*READ*|*Read*|*阅读*|*排查*|*调试*|*故障*|*调查*|*bugfix*|*Bugfix*|*定位*)
            echo "read"; return ;;
        *arch*|*ARCH*|*Arch*|*architecture*|*ARCHITECTURE*|*Architecture*|*架构*|*建模*|*结构*|*梳理*)
            echo "arch"; return ;;
    esac

    # 按 current_phase 匹配
    case "$phase" in
        UNDERSTANDING|PLANNING|EXECUTING|VERIFYING|REFLECTING)
            echo "build"
            ;;
        SCOPE)
            # SCOPE 在 read 与 arch 中都有，默认 read
            echo "read"
            ;;
        HYPOTHESIS|EVIDENCE|REPORT|FIX)
            echo "read"
            ;;
        SURVEY|DRILL|CONNECT|MODEL)
            echo "arch"
            ;;
        *)
            echo "general"
            ;;
    esac
}

WORKFLOW_TYPE=$(infer_workflow_type "$SESSION_FILE")

# 根据 workflow 类型确定归档产物与目标名
declare -a ARCHIVED_ARTIFACTS=()
archive_artifact() {
    local src="$1"
    local dest_name="$2"
    local label="$3"

    if [[ -f "$src" ]] && [[ -s "$src" ]]; then
        local dest="$ARCHIVE_DIR/${dest_name}"
        cp "$src" "$dest"
        echo "已归档 $label：$dest"
        ARCHIVED_ARTIFACTS+=("$label:$dest")
        return 0
    fi
    return 1
}

HANDOFF_ARCHIVED=false
ARCH_ARCHIVED=false

case "$WORKFLOW_TYPE" in
    build)
        if archive_artifact "$HANDOFF_FILE" "${ARCHIVE_NAME_BASE}-build-handoff.md" "handoff"; then
            HANDOFF_ARCHIVED=true
        fi
        ;;
    read)
        if archive_artifact "$HANDOFF_FILE" "${ARCHIVE_NAME_BASE}-read-report.md" "report"; then
            HANDOFF_ARCHIVED=true
        fi
        ;;
    arch)
        if archive_artifact "$ARCH_FILE" "${ARCHIVE_NAME_BASE}-arch-model.md" "architecture"; then
            ARCH_ARCHIVED=true
        fi
        ;;
    general)
        if archive_artifact "$HANDOFF_FILE" "${ARCHIVE_NAME_BASE}-general-summary.md" "summary"; then
            HANDOFF_ARCHIVED=true
        fi
        ;;
esac

# 若当前工作流未归档任何产物，但存在其他可归档文件，则兜底处理
if [[ "$HANDOFF_ARCHIVED" == false ]] && [[ "$ARCH_ARCHIVED" == false ]]; then
    if archive_artifact "$HANDOFF_FILE" "${ARCHIVE_NAME_BASE}-general-summary.md" "summary"; then
        HANDOFF_ARCHIVED=true
    elif archive_artifact "$ARCH_FILE" "${ARCHIVE_NAME_BASE}-arch-model.md" "architecture"; then
        ARCH_ARCHIVED=true
    fi
fi

if [[ "$HANDOFF_ARCHIVED" == false ]] && [[ "$ARCH_ARCHIVED" == false ]]; then
    echo "警告：未找到可归档的 handoff.md 或 architecture.md" >&2
fi

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

# 提取摘要（取 handoff 或 architecture 的第一段非空内容）
extract_summary() {
    local file="$1"
    if [[ -f "$file" ]]; then
        sed -n '/^# /,$p' "$file" | tail -n +2 | grep -v '^\s*$' | head -n 1
    fi
}

SUMMARY=""
if [[ "$HANDOFF_ARCHIVED" == true ]]; then
    SUMMARY=$(extract_summary "$HANDOFF_FILE")
elif [[ "$ARCH_ARCHIVED" == true ]]; then
    SUMMARY=$(extract_summary "$ARCH_FILE")
fi
[[ -z "$SUMMARY" ]] && SUMMARY="无摘要"

# 构建相对链接
RELATIVE_LINKS=()
for item in "${ARCHIVED_ARTIFACTS[@]}"; do
    label="${item%%:*}"
    path="${item#*:}"
    rel="archive/$(basename "$path")"
    RELATIVE_LINKS+=("- $label: [$rel]($rel)")
done

# 追加到 index.md
{
    echo ""
    echo "### $ARCHIVE_NAME_BASE"
    echo ""
    echo "- **类型**: $WORKFLOW_TYPE"
    echo "- **时间**: $TIMESTAMP"
    echo "- **会话**: $SESSION_ID"
    echo "- **摘要**: $SUMMARY"
    for link in "${RELATIVE_LINKS[@]}"; do
        echo "$link"
    done
} >> "$INDEX_FILE"

# 更新 index.md 的 updated 字段
sed -i "s/^updated:.*/updated: $(date +%Y-%m-%d)/" "$INDEX_FILE"

# 清理已归档的中间状态文件
if [[ "$HANDOFF_ARCHIVED" == true ]]; then
    cat > "$HANDOFF_FILE" <<'EOF'
---
---

# 交接摘要

EOF
fi

if [[ "$ARCH_ARCHIVED" == true ]]; then
    cat > "$ARCH_FILE" <<'EOF'
---
---

# 架构模型

EOF
fi

# 重置 session.md 为初始模板
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

echo "已归档 workflow 类型：$WORKFLOW_TYPE"
echo "已更新归档索引：$INDEX_FILE"
echo "已重置 session.md"
