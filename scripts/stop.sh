#!/usr/bin/env bash
# ==============================================================================
# 停止 Mihomo 服务
# ==============================================================================
set -euo pipefail

# 自动补全无头/SSH 环境下的用户级 systemd bus 环境变量
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "${XDG_RUNTIME_DIR}/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "正在停止 Mihomo 服务..."
if systemctl --user is-active --quiet mihomo.service 2>/dev/null; then
    systemctl --user stop mihomo.service
fi

# 检查是否有残留独立进程
REMAINING=$(pgrep -f "${WORKSPACE_DIR}/bin/mihomo" || true)
if [ -n "${REMAINING}" ]; then
    echo "正在终止残留的 mihomo 进程 (PID: ${REMAINING})..."
    kill ${REMAINING} 2>/dev/null || true
    sleep 1
fi

echo "[OK] Mihomo 服务已停止"
