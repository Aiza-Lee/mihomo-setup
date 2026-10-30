#!/usr/bin/env bash
# ==============================================================================
# [需要 sudo 权限] 赋予 Mihomo 核心 TUN 虚拟网卡能力
# ==============================================================================
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "错误: 本脚本需要管理员权限，请使用 sudo 执行: sudo $0" >&2
    exit 1
fi

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_PATH="${WORKSPACE_DIR}/bin/mihomo"

echo "正在向 ${BIN_PATH} 赋予 cap_net_admin,cap_net_bind_service 权限..."
setcap 'cap_net_admin,cap_net_bind_service=+ep' "${BIN_PATH}"

echo "[OK] 权限赋予成功！当前能力状态:"
getcap "${BIN_PATH}"
echo "现在您可以在 config.yaml 中启用 tun 模式 (例如 tun: enable: true) 而无需使用 root 运行。"
