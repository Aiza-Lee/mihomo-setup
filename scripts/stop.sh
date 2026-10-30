#!/usr/bin/env bash
# ==============================================================================
# 停止 Mihomo 服务 (支持 systemd 与非 systemd 双引擎自适应)
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
BIN_FILE="${WORKSPACE_DIR}/bin/mihomo"
PID_FILE="${WORKSPACE_DIR}/bin/mihomo.pid"

echo "正在停止 Mihomo 服务..."

# 1. 如果有 systemd，尝试停止 systemd 服务
if [ -d /run/systemd/system ] && [ "$(ps -p 1 -o comm= 2>/dev/null)" = "systemd" ]; then
    if systemctl --user is-active --quiet mihomo.service 2>/dev/null; then
        systemctl --user stop mihomo.service 2>/dev/null || true
    fi
fi

# 2. 检查并停止独立进程 (或 PID 文件记录的进程)
if [ -f "${PID_FILE}" ]; then
    RECORDED_PID=$(cat "${PID_FILE}" 2>/dev/null || true)
    if [ -n "${RECORDED_PID}" ] && kill -0 "${RECORDED_PID}" 2>/dev/null; then
        echo "正在停止后台进程 (PID: ${RECORDED_PID})..."
        kill "${RECORDED_PID}" 2>/dev/null || true
    fi
    rm -f "${PID_FILE}" 2>/dev/null || true
fi

# 3. 检查是否有残留的 mihomo 进程
REMAINING=$(pgrep -f "${BIN_FILE}" || true)
if [ -n "${REMAINING}" ]; then
    echo "正在终止残留的 mihomo 进程 (PID: ${REMAINING})..."
    kill ${REMAINING} 2>/dev/null || true
    sleep 1
fi

echo "[OK] Mihomo 服务已完全停止"
