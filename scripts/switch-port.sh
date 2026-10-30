#!/usr/bin/env bash
# ==============================================================================
# 切换 Mihomo 代理监听端口 (例如 7890 与 7893 之间切换)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${WORKSPACE_DIR}/config/config.yaml"

TARGET_PORT="${1:-}"

if [ -z "${TARGET_PORT}" ]; then
    CURRENT_PORT=$(grep -E '^[[:space:]]*mixed-port:' "${CONFIG_FILE}" | awk '{print $2}' || echo "未知")
    echo "用法: $0 <端口号>"
    echo "当前配置端口为: ${CURRENT_PORT}"
    echo "常见使用场景:"
    echo "  $0 7893   # 临时使用 7893 端口进行测试（当别的电脑开机且正占用 7890 时）"
    echo "  $0 7890   # 恢复默认 7890 端口（当别的电脑关机断开后）"
    exit 1
fi

if ! [[ "${TARGET_PORT}" =~ ^[0-9]+$ ]] || [ "${TARGET_PORT}" -lt 1024 ] || [ "${TARGET_PORT}" -gt 65535 ]; then
    echo "错误: 端口必须在 1024 到 65535 之间" >&2
    exit 1
fi

# 检查目标端口是否被其他进程占用
OCCUPIED=$(ss -tulpn 2>/dev/null | grep ":${TARGET_PORT} " || true)
if [ -n "${OCCUPIED}" ]; then
    echo "[WARN] 警告: 目标端口 ${TARGET_PORT} 当前已被占用:"
    echo "${OCCUPIED}"
    echo "如果该端口被当前运行的 mihomo 占用，稍后重启将自动释放并重新绑定。"
fi

# 修改配置文件
sed -i -E "s/^[[:space:]]*mixed-port:[[:space:]]*[0-9]+/mixed-port: ${TARGET_PORT}/" "${CONFIG_FILE}"

# 验证配置
"${WORKSPACE_DIR}/bin/mihomo" -t -d "${WORKSPACE_DIR}/config" -f "${CONFIG_FILE}" >/dev/null

echo "[OK] 已成功将 config.yaml 的 mixed-port 修改为: ${TARGET_PORT}"

# 如果服务正在运行，则重启
if systemctl --user is-active --quiet mihomo 2>/dev/null; then
    echo "正在重启 mihomo 服务以生效新端口..."
    systemctl --user restart mihomo
    echo "[OK] 服务已重启"
fi
