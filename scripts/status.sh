#!/usr/bin/env bash
# ==============================================================================
# 查看 Mihomo 运行状态与端口监听
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

echo "======================================================================"
echo "                   Mihomo 服务运行状态"
echo "======================================================================"

# 1. 检查 systemd 服务状态
if systemctl --user is-active --quiet mihomo.service 2>/dev/null; then
    echo "● 服务状态:    [ 运行中 (Active) ]"
else
    echo "○ 服务状态:    [ 未运行 (Inactive) ]"
fi

if systemctl --user is-enabled --quiet mihomo.service 2>/dev/null; then
    echo "● 开机自启:    [ 已启用 (Enabled) ]"
else
    echo "○ 开机自启:    [ 未启用 (Disabled) ]"
fi

# 2. 检查进程
PID=$(pgrep -f "${WORKSPACE_DIR}/bin/mihomo" || true)
if [ -n "${PID}" ]; then
    echo "● 进程 PID:    ${PID}"
    # 内存与运行时间
    PS_INFO=$(ps -o %cpu,%mem,etime,args -p "${PID}" | tail -n 1 || true)
    echo "● 进程资源:    ${PS_INFO}"
else
    echo "○ 进程 PID:    无运行中进程"
fi

# 3. 检查端口监听
if [ -f "${CONFIG_FILE}" ]; then
    CONFIG_PORT=$(grep -E '^[[:space:]]*mixed-port:' "${CONFIG_FILE}" 2>/dev/null | awk '{print $2}' || echo "7890")
    CONTROLLER_ADDR=$(grep -E '^[[:space:]]*external-controller:' "${CONFIG_FILE}" 2>/dev/null | awk '{print $2}' | tr -d "'" | tr -d '"' || echo "127.0.0.1:9090")
else
    CONFIG_PORT="7890"
    CONTROLLER_ADDR="127.0.0.1:9090"
fi
CONTROLLER_PORT="${CONTROLLER_ADDR##*:}"

echo "----------------------------------------------------------------------"
echo "端口监听状态:"
if ss -tlpn 2>/dev/null | grep -q ":${CONFIG_PORT} "; then
    LISTEN_PROC=$(ss -tlpn 2>/dev/null | grep ":${CONFIG_PORT} " | awk '{print $4, $NF}' || true)
    echo "  [已监听] 代理端口 ${CONFIG_PORT}: ${LISTEN_PROC}"
else
    echo "  [未监听] 代理端口 ${CONFIG_PORT}"
fi

if ss -tlpn 2>/dev/null | grep -q ":${CONTROLLER_PORT} "; then
    LISTEN_CTRL=$(ss -tlpn 2>/dev/null | grep ":${CONTROLLER_PORT} " | awk '{print $4, $NF}' || true)
    echo "  [已监听] 控制端口 ${CONTROLLER_ADDR}: ${LISTEN_CTRL}"
else
    echo "  [未监听] 控制端口 ${CONTROLLER_ADDR}"
fi

# 4. 控制台入口
echo "----------------------------------------------------------------------"
echo "Web 管理控制台 (Metacubexd):"
echo "  URL:  http://${CONTROLLER_ADDR}/ui"
echo "  密钥: (默认留空)"

# 5. 终端代理变量
echo "----------------------------------------------------------------------"
echo "当前终端代理变量:"
echo "  http_proxy:  ${http_proxy:-<未设置>}"
echo "  https_proxy: ${https_proxy:-<未设置>}"
echo "  all_proxy:   ${all_proxy:-<未设置>}"
echo "======================================================================"
