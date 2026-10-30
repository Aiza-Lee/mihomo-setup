#!/usr/bin/env bash
# ==============================================================================
# 实时查看 Mihomo 运行日志 (按 Ctrl+C 退出)
# ==============================================================================
set -euo pipefail

# 自动补全无头/SSH 环境下的用户级 systemd bus 环境变量
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "${XDG_RUNTIME_DIR}/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
fi

echo "正在跟踪 Mihomo 实时日志 (Ctrl+C 退出)..."
journalctl --user -u mihomo.service -f -n 50 -o cat
