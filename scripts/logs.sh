#!/usr/bin/env bash
# ==============================================================================
# 查看 Mihomo 实时运行日志
# ==============================================================================
set -euo pipefail

LINES="${1:-50}"

echo "正在查看 Mihomo 用户服务最近 ${LINES} 行日志 (按 Ctrl+C 退出跟随)..."
journalctl --user -u mihomo.service -n "${LINES}" -f --no-pager
