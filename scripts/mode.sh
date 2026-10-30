#!/usr/bin/env bash
# ==============================================================================
# 查看与切换 Mihomo 代理模式 (rule / global / direct)
# 用法:
#   ./scripts/mode.sh           # 查看当前运行模式
#   ./scripts/mode.sh rule      # 切换为规则分流模式 (国内直连，海外走代理)
#   ./scripts/mode.sh global    # 切换为全局代理模式 (所有流量走代理)
#   ./scripts/mode.sh direct    # 切换为全直连模式 (不走代理)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${WORKSPACE_DIR}/config/config.yaml"

TARGET_MODE="${1:-}"

# 1. 获取控制器地址与密钥
if [ -f "${CONFIG_FILE}" ]; then
    CONTROLLER_ADDR=$(grep -E '^[[:space:]]*external-controller:' "${CONFIG_FILE}" 2>/dev/null | awk '{print $2}' | tr -d "'" | tr -d '"' || echo "127.0.0.1:9090")
    SECRET=$(grep -E '^[[:space:]]*secret:' "${CONFIG_FILE}" 2>/dev/null | awk '{print $2}' | tr -d "'" | tr -d '"' || echo "")
else
    CONTROLLER_ADDR="127.0.0.1:9090"
    SECRET=""
fi

AUTH_HEADER=()
if [ -n "${SECRET}" ]; then
    AUTH_HEADER=(-H "Authorization: Bearer ${SECRET}")
fi

# 2. 如果无参数，查询当前模式
if [ -z "${TARGET_MODE}" ]; then
    echo "=== 查询 Mihomo 当前运行模式 ==="
    RES=$(curl --noproxy '*' -s "${AUTH_HEADER[@]}" "http://${CONTROLLER_ADDR}/configs" 2>/dev/null || true)
    if [ -z "${RES}" ]; then
        echo "错误: 无法连接至控制器 (http://${CONTROLLER_ADDR})，请确保服务已启动。" >&2
        exit 1
    fi
    CURRENT_MODE=$(echo "${RES}" | grep -o '"mode":"[^"]*"' | cut -d'"' -f4 || echo "未知")
    echo "当前运行模式: [ ${CURRENT_MODE} ]"
    echo ""
    echo "切换命令示例:"
    echo "  $0 rule    # 规则模式 (推荐，国内直连、海外代理)"
    echo "  $0 global  # 全局模式 (所有连接强制走代理)"
    echo "  $0 direct  # 直连模式 (全部直连)"
    exit 0
fi

# 3. 规范化参数
TARGET_MODE="$(echo "${TARGET_MODE}" | tr '[:upper:]' '[:lower:]')"

case "${TARGET_MODE}" in
    rule|global|direct)
        ;;
    *)
        echo "错误: 无效的模式 '${TARGET_MODE}'！仅支持: rule, global, direct" >&2
        exit 1
        ;;
esac

# 4. 通过 REST API 热切换模式 (0秒延迟，无需重启服务)
HTTP_CODE=$(curl --noproxy '*' -s -o /dev/null -w "%{http_code}" -X PATCH "${AUTH_HEADER[@]}" \
    -H "Content-Type: application/json" \
    -d "{\"mode\": \"${TARGET_MODE}\"}" \
    "http://${CONTROLLER_ADDR}/configs" 2>/dev/null || echo "000")

if [ "${HTTP_CODE}" = "204" ] || [ "${HTTP_CODE}" = "200" ]; then
    echo "[OK] 代理模式已成功热切换为: [ ${TARGET_MODE} ]"
    # 同步更新本地 config.yaml 中的默认 mode 设置 (持久化)
    if [ -f "${CONFIG_FILE}" ]; then
        sed -i -E "s/^[[:space:]]*mode:[[:space:]]*[a-zA-Z]+/mode: ${TARGET_MODE}/" "${CONFIG_FILE}" 2>/dev/null || true
    fi
else
    echo "错误: 模式切换失败 (HTTP 状态码: ${HTTP_CODE})，请检查服务是否运行及控制器地址 http://${CONTROLLER_ADDR}" >&2
    exit 1
fi
