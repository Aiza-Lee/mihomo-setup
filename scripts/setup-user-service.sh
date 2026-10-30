#!/usr/bin/env bash
# ==============================================================================
# 安装并配置 Mihomo 用户级系统服务 (无需 root 权限)
# 自动根据当前目录和当前用户动态渲染服务单元 (自动检测 systemd 支持)
# ==============================================================================
set -euo pipefail

# 自动补全无头/SSH 环境下的用户级 systemd bus 环境变量
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "${XDG_RUNTIME_DIR}/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
fi

can_use_systemd_user() {
    [ -d /run/systemd/system ] && systemctl --user list-units --type=service >/dev/null 2>&1
}

if ! can_use_systemd_user; then
    echo "=== 系统服务检查 ==="
    echo "[INFO] 检测到当前环境用户级 systemd 不可用 (如 WSL / Docker / 容器 / 无 D-Bus 会话)。"
    echo "[INFO] 本套件已自动启用「独立后台守护进程」模式，直接运行 ./scripts/start.sh 即可，无需配置 systemd。"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SERVICE_TEMPLATE="${WORKSPACE_DIR}/systemd/mihomo.service.template"
USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
SERVICE_DEST="${USER_SYSTEMD_DIR}/mihomo.service"
CONFIG_FILE="${WORKSPACE_DIR}/config/config.yaml"
CONFIG_EXAMPLE="${WORKSPACE_DIR}/config/config.example.yaml"
BIN_FILE="${WORKSPACE_DIR}/bin/mihomo"
ARCH_DIR="${WORKSPACE_DIR}/bin/arch"

echo "=== 正在配置 Mihomo 用户级 systemd 服务 ==="
echo "工作目录: ${WORKSPACE_DIR}"
echo "当前用户: ${USER} (UID: $(id -u))"

# 1. 尝试提前开启 Linger 驻留
loginctl enable-linger "${USER}" 2>/dev/null || true

# 确保用户服务目录存在
mkdir -p "${USER_SYSTEMD_DIR}"

# 2. 确保配置文件存在
if [ ! -f "${CONFIG_FILE}" ]; then
    if [ -f "${CONFIG_EXAMPLE}" ]; then
        echo "[INFO] 未检测到 config.yaml，正在从 config.example.yaml 初始化默认配置..."
        cp -f "${CONFIG_EXAMPLE}" "${CONFIG_FILE}"
    else
        echo "错误: 缺少配置文件模版 ${CONFIG_EXAMPLE}" >&2
        exit 1
    fi
fi

# 3. 确保核心二进制存在
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

echo "正在校验配置有效性..."
"${BIN_FILE}" -t -d "${WORKSPACE_DIR}/config" -f "${CONFIG_FILE}" >/dev/null
echo "[OK] 配置校验通过"

# 4. 动态替换模板生成用户级服务文件
if [ ! -f "${SERVICE_TEMPLATE}" ]; then
    echo "错误: 缺少服务模板 ${SERVICE_TEMPLATE}" >&2
    exit 1
fi

sed "s|__WORKSPACE_DIR__|${WORKSPACE_DIR}|g" "${SERVICE_TEMPLATE}" > "${SERVICE_DEST}"
echo "[OK] 服务单元已动态生成并部署到: ${SERVICE_DEST}"

# 5. 重载用户服务配置
systemctl --user daemon-reload
echo "[OK] systemctl --user daemon-reload 执行成功"

# 6. 启用开机自启
systemctl --user enable mihomo.service
echo "[OK] 已启用 mihomo.service 开机自启"

# 7. 检查当前用户 linger 状态
LINGER_STATUS=$(loginctl show-user "${USER}" 2>/dev/null | grep -i "Linger=yes" || true)
if [ -n "${LINGER_STATUS}" ]; then
    echo "[OK] 用户驻留 (Linger) 已开启，注销或关闭 SSH 后服务将持续在后台常驻运行"
else
    echo "[WARN] 当前用户未成功开启 Linger，若需要关闭 SSH 会话后服务依然常驻，请执行: sudo loginctl enable-linger ${USER}"
fi

echo ""
echo "=== 配置完成 ==="
echo "您现在可以使用以下命令管理服务:"
echo "  启动服务: ${WORKSPACE_DIR}/scripts/start.sh"
echo "  停止服务: ${WORKSPACE_DIR}/scripts/stop.sh"
echo "  查看状态: ${WORKSPACE_DIR}/scripts/status.sh"
echo "  查看日志: ${WORKSPACE_DIR}/scripts/logs.sh"
