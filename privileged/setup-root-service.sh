#!/usr/bin/env bash
# ==============================================================================
# [需要 sudo 权限] 将 Mihomo 配置为系统级全局系统服务 (/etc/systemd/system)
# ==============================================================================
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "错误: 本脚本需要管理员权限，请使用 sudo 执行: sudo $0" >&2
    exit 1
fi

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEM_SERVICE_TEMPLATE="${WORKSPACE_DIR}/systemd/mihomo-system.service.template"
SYSTEM_SERVICE_DEST="/etc/systemd/system/mihomo.service"

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_GROUP="$(id -gn "${TARGET_USER}")"

echo "=== 正在配置系统级 Mihomo 服务 ==="
echo "服务所属用户: ${TARGET_USER}:${TARGET_GROUP}"
echo "工作目录: ${WORKSPACE_DIR}"

# 赋予二进制文件网络管理能力 (便于以后开启 TUN 模式)
setcap 'cap_net_admin,cap_net_bind_service=+ep' "${WORKSPACE_DIR}/bin/mihomo" || true

# 根据模板动态渲染 systemd 服务
sed -e "s|__WORKSPACE_DIR__|${WORKSPACE_DIR}|g" \
    -e "s|__USER__|${TARGET_USER}|g" \
    -e "s|__GROUP__|${TARGET_GROUP}|g" \
    "${SYSTEM_SERVICE_TEMPLATE}" > "${SYSTEM_SERVICE_DEST}"

systemctl daemon-reload
systemctl enable mihomo.service

echo "[OK] 系统级服务已动态渲染安装并启用自启"
echo "启动命令: sudo systemctl start mihomo"
echo "停止命令: sudo systemctl stop mihomo"
echo "状态命令: sudo systemctl status mihomo"
