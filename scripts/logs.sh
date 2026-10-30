#!/usr/bin/env bash
# ==============================================================================
# 实时查看 Mihomo 运行日志 (按 Ctrl+C 退出)
# 自动兼容 systemd journal 与普通文件日志
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
LOG_FILE="${WORKSPACE_DIR}/logs/mihomo.log"

has_systemd() {
    [ -d /run/systemd/system ] && [ "$(ps -p 1 -o comm= 2>/dev/null)" = "systemd" ]
}

echo "正在跟踪 Mihomo 实时日志 (Ctrl+C 退出)..."

if has_systemd; then
    journalctl --user -u mihomo.service -f -n 50 -o cat
else
    if [ -f "${LOG_FILE}" ]; then
        tail -f -n 50 "${LOG_FILE}"
    else
        echo "提示: 日志文件尚未生成: ${LOG_FILE}"
    fi
fi
