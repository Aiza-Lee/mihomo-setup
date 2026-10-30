#!/usr/bin/env bash
# ==============================================================================
# 重启 Mihomo 服务
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${WORKSPACE_DIR}/config/config.yaml"

echo "正在检查配置文件语法..."
if ! "${WORKSPACE_DIR}/bin/mihomo" -t -d "${WORKSPACE_DIR}/config" -f "${CONFIG_FILE}" >/dev/null; then
    echo "错误: 配置文件语法有误，放弃重启以防服务中断！" >&2
    exit 1
fi
echo "[OK] 配置文件校验通过"

echo "正在重启 mihomo 服务..."
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
