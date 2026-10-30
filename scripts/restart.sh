#!/usr/bin/env bash
# ==============================================================================
# 重启 Mihomo 服务 (支持 systemd 与非 systemd 双引擎自适应)
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
CONFIG_FILE="${WORKSPACE_DIR}/config/config.yaml"

can_use_systemd_user() {
    [ -d /run/systemd/system ] && systemctl --user list-units --type=service >/dev/null 2>&1
}

echo "正在检查配置文件语法..."
if ! "${WORKSPACE_DIR}/bin/mihomo" -t -d "${WORKSPACE_DIR}/config" -f "${CONFIG_FILE}" >/dev/null; then
    echo "错误: 配置文件语法有误，放弃重启以防服务中断！" >&2
    exit 1
fi
echo "[OK] 配置文件校验通过"

if can_use_systemd_user; then
    echo "正在重启 mihomo 用户级 systemd 服务..."
    systemctl --user restart mihomo.service

    sleep 1
    if systemctl --user is-active --quiet mihomo.service; then
        echo "[OK] 服务重启成功！"
        "${SCRIPT_DIR}/status.sh"
    else
        echo "[FAIL] 服务重启失败，请检查日志:"
        journalctl --user -u mihomo.service -n 20 --no-pager
        exit 1
    fi
else
    echo "正在重启独立后台守护进程..."
    "${SCRIPT_DIR}/stop.sh"
    sleep 1
    "${SCRIPT_DIR}/start.sh"
fi
