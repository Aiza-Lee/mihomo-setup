#!/usr/bin/env bash
# ==============================================================================
# 启动 Mihomo 服务 (支持 systemd 与非 systemd 双引擎自适应)
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
ARCH_DIR="${WORKSPACE_DIR}/bin/arch"
CONFIG_FILE="${WORKSPACE_DIR}/config/config.yaml"
CONFIG_EXAMPLE="${WORKSPACE_DIR}/config/config.example.yaml"
USER_SERVICE_FILE="${HOME}/.config/systemd/user/mihomo.service"
PID_FILE="${WORKSPACE_DIR}/bin/mihomo.pid"
LOG_DIR="${WORKSPACE_DIR}/logs"
LOG_FILE="${LOG_DIR}/mihomo.log"

# 检测系统是否以 systemd 为 PID 1
has_systemd() {
    [ -d /run/systemd/system ] && [ "$(ps -p 1 -o comm= 2>/dev/null)" = "systemd" ]
}

# 0. 确保核心二进制存在
if [ ! -x "${BIN_FILE}" ]; then
    ARCH="$(uname -m)"
    case "${ARCH}" in
        x86_64|amd64)   ARCH_TAG="amd64" ;;
        aarch64|arm64)  ARCH_TAG="arm64" ;;
        armv7l|armhf)   ARCH_TAG="armv7" ;;
        *) ARCH_TAG="" ;;
    esac
    if [ -n "${ARCH_TAG}" ] && [ -f "${ARCH_DIR}/mihomo-linux-${ARCH_TAG}.gz" ]; then
        echo "[INFO] 正在从本地核心库装配 ${ARCH_TAG} 核心..."
        gzip -dc "${ARCH_DIR}/mihomo-linux-${ARCH_TAG}.gz" > "${BIN_FILE}"
        chmod +x "${BIN_FILE}"
    else
        echo "错误: 缺少可执行的核心二进制 ${BIN_FILE}" >&2
        exit 1
    fi
fi

# 1. 确保配置文件存在
if [ ! -f "${CONFIG_FILE}" ]; then
    if [ -f "${CONFIG_EXAMPLE}" ]; then
        echo "[INFO] 首次运行，正在从 config.example.yaml 初始化默认配置文件..."
        cp -f "${CONFIG_EXAMPLE}" "${CONFIG_FILE}"
    else
        echo "错误: 缺少配置文件模版 ${CONFIG_EXAMPLE}" >&2
        exit 1
    fi
fi

# 2. 验证配置文件语法
echo "正在检查配置文件语法..."
if ! "${BIN_FILE}" -t -d "${WORKSPACE_DIR}/config" -f "${CONFIG_FILE}" >/dev/null; then
    echo "错误: 配置文件语法有误，请先修复 ${CONFIG_FILE}" >&2
    exit 1
fi
echo "[OK] 配置文件语法校验通过"

# 3. 检查端口占用
CONFIG_PORT=$(grep -E '^[[:space:]]*mixed-port:' "${CONFIG_FILE}" | awk '{print $2}' || echo "7890")
if ss -tlpn 2>/dev/null | grep -q ":${CONFIG_PORT} "; then
    # 检查占用进程是否就是当前工作区已有的 mihomo
    CURRENT_RUNNING=$(pgrep -f "${BIN_FILE}" || true)
    if [ -z "${CURRENT_RUNNING}" ]; then
        echo "======================================================================"
        echo "[提示] 检测到代理端口 ${CONFIG_PORT} 当前正被占用"
        echo "您可以选择:"
        echo "  1. 停止占用端口的服务后重新运行: ./scripts/start.sh"
        echo "  2. 或切换至独立端口: ./scripts/switch-port.sh <新端口>"
        echo "======================================================================"
        if [ -t 0 ]; then
            read -r -p "是否仍然尝试启动服务? [y/N]: " choice || choice="n"
            case "$choice" in
                [yY][eE][sS]|[yY])
                    echo "继续尝试启动..."
                    ;;
                *)
                    echo "已取消启动。"
                    exit 0
                    ;;
            esac
        fi
    fi
fi

# 4. 启动服务 (systemd / 独立进程自适应)
if has_systemd; then
    # 确保用户服务已注册
    if [ ! -f "${USER_SERVICE_FILE}" ]; then
        echo "首次运行，正在自动安装用户服务..."
        "${SCRIPT_DIR}/setup-user-service.sh"
    fi

    echo "正在通过 systemctl --user 启动服务..."
    systemctl --user start mihomo.service

    sleep 1
    if systemctl --user is-active --quiet mihomo.service; then
        echo "[OK] Mihomo 服务 (systemd) 启动成功！"
        "${SCRIPT_DIR}/status.sh"
    else
        echo "[FAIL] 服务启动失败，请检查日志:"
        journalctl --user -u mihomo.service -n 20 --no-pager
        exit 1
    fi
else
    echo "检测到系统未运行 systemd (如 WSL / Docker / 容器环境)，已启用独立后台守护进程模式..."
    mkdir -p "${LOG_DIR}"

    # 检查是否已在运行
    ALREADY_RUNNING=$(pgrep -f "${BIN_FILE}" || true)
    if [ -n "${ALREADY_RUNNING}" ]; then
        echo "[OK] Mihomo 进程已经在后台运行中 (PID: ${ALREADY_RUNNING})"
        "${SCRIPT_DIR}/status.sh"
        exit 0
    fi

    nohup "${BIN_FILE}" -d "${WORKSPACE_DIR}/config" -f "${CONFIG_FILE}" > "${LOG_FILE}" 2>&1 &
    NEW_PID=$!
    echo "${NEW_PID}" > "${PID_FILE}"
    sleep 1

    if kill -0 "${NEW_PID}" 2>/dev/null; then
        echo "[OK] Mihomo 独立后台守护进程启动成功！(PID: ${NEW_PID})"
        echo "日志路径: ${LOG_FILE}"
        "${SCRIPT_DIR}/status.sh"
    else
        echo "[FAIL] 启动失败，请检查运行日志: ${LOG_FILE}"
        tail -n 20 "${LOG_FILE}" 2>/dev/null || true
        exit 1
    fi
fi
