#!/usr/bin/env bash
#
# derive-session-id.sh - 从用户目标/焦点短语生成会话 ID slug。
#
# 用法：
#   scripts/core/derive-session-id.sh <PHRASE>
#
# 输出到 stdout：短 slug（≤30 字符，保留中文与 ASCII）
#

set -euo pipefail

PHRASE="${1:-}"

if [[ -z "$PHRASE" ]]; then
    echo "session"
    exit 0
fi

slug=$(echo "$PHRASE" | tr ' ' '-')
slug=$(echo "$slug" | tr -cd 'a-zA-Z0-9一-龥_-')
slug=$(echo "$slug" | tr 'A-Z' 'a-z')
slug=$(echo "$slug" | sed 's/-\+/-/g')
slug=$(echo "$slug" | sed 's/^-//;s/-$//')
slug=$(echo "$slug" | cut -c1-30)
slug=$(echo "$slug" | sed 's/-$//')

if [[ -z "$slug" ]]; then
    slug="session"
fi

echo "$slug"
