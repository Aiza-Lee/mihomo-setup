#!/usr/bin/env bash
# ==============================================================================
# Mihomo 一键极速部署脚本 (全离线、多架构自适应、版本统一)
# 用法:
#   ./deploy.sh                                   # 使用默认配置部署
#   ./deploy.sh "https://your-subscription-url"   # 自动导入订阅并部署
#   ./deploy.sh "https://your-subscription-url" 7890 # 指定订阅与代理端口
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${SCRIPT_DIR}"
BIN_DIR="${WORKSPACE_DIR}/bin"
ARCH_DIR="${BIN_DIR}/arch"
CONFIG_DIR="${WORKSPACE_DIR}/config"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
CONFIG_EXAMPLE="${CONFIG_DIR}/config.example.yaml"

SUB_URL="${1:-}"
TARGET_PORT="${2:-}"

MIHOMO_VERSION="v1.19.33"

echo "======================================================================"
echo "          Mihomo 极速自动化部署 (全离线多架构版本)"
echo "======================================================================"
echo "部署目录: ${WORKSPACE_DIR}"
echo "当前用户: ${USER} (UID: $(id -u))"
echo "预设内核: Mihomo Meta ${MIHOMO_VERSION}"

# 1. 检查操作系统
OS="$(uname -s)"
if [ "${OS}" != "Linux" ]; then
    echo "错误: 本项目仅支持 Linux 系统，当前为: ${OS}" >&2
    exit 1
fi

# 2. 识别 CPU 架构并从本地核心库装配
ARCH="$(uname -m)"
case "${ARCH}" in
    x86_64|amd64)
        ARCH_TAG="amd64"
        ;;
    aarch64|arm64)
        ARCH_TAG="arm64"
        ;;
    armv7l|armhf|arm)
        ARCH_TAG="armv7"
        ;;
    *)
        echo "错误: 暂不支持的架构: ${ARCH}。当前支持: amd64 (x86_64), arm64 (aarch64), armv7 (armv7l)" >&2
        exit 1
        ;;
esac

echo "[OK] 系统架构检测: Linux ${ARCH} (匹配架构包: ${ARCH_TAG})"

ARCH_GZ="${ARCH_DIR}/mihomo-linux-${ARCH_TAG}.gz"
if [ ! -f "${ARCH_GZ}" ]; then
    echo "错误: 缺少本地内置架构核心包: ${ARCH_GZ}" >&2
    exit 1
fi

# 检查是否需要重新解压装配核心
NEED_EXTRACT=true
if [ -f "${BIN_DIR}/mihomo" ] && [ -x "${BIN_DIR}/mihomo" ]; then
    if "${BIN_DIR}/mihomo" -v >/dev/null 2>&1; then
        CURRENT_BIN_ARCH=$(file -b "${BIN_DIR}/mihomo" || true)
        if { [ "${ARCH_TAG}" = "amd64" ] && [[ "${CURRENT_BIN_ARCH}" =~ x86-64 ]]; } || \
           { [ "${ARCH_TAG}" = "arm64" ] && [[ "${CURRENT_BIN_ARCH}" =~ aarch64 ]]; } || \
           { [ "${ARCH_TAG}" = "armv7" ] && [[ "${CURRENT_BIN_ARCH}" =~ ARM ]]; }; then
            echo "[OK] 本地 Mihomo 核心可用且与架构 (${ARCH}) 完全匹配: $("${BIN_DIR}/mihomo" -v | head -n 1)"
            NEED_EXTRACT=false
        fi
    fi
fi

if [ "${NEED_EXTRACT}" = true ]; then
    echo "正在从本地架构包离线装配核心 (${ARCH_TAG})..."
    gzip -dc "${ARCH_GZ}" > "${BIN_DIR}/mihomo"
    chmod +x "${BIN_DIR}/mihomo"
    echo "[OK] 核心装配完成: $("${BIN_DIR}/mihomo" -v | head -n 1)"
fi

# 3. 检查离线规则数据库文件完整性
mkdir -p "${CONFIG_DIR}/providers"
touch "${CONFIG_DIR}/providers/.gitkeep"

for DB_FILE in "Country.mmdb" "geoip.dat" "geosite.dat"; do
    TARGET_DB="${CONFIG_DIR}/${DB_FILE}"
    if [ ! -s "${TARGET_DB}" ]; then
        echo "错误: 缺少本地离线数据库文件: ${TARGET_DB}" >&2
        exit 1
    fi
done
echo "[OK] GeoIP 与 Geosite 离线规则数据库完整"

# 4. 初始化配置文件
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "[INFO] 初始化默认主配置文件 (config.yaml)..."
    cp -f "${CONFIG_EXAMPLE}" "${CONFIG_FILE}"
fi

# 5. 如果提供了订阅链接，调用 update-sub.sh 导入
if [ -n "${SUB_URL}" ]; then
    echo ""
    echo "=== 正在导入机场订阅链接 ==="
    "${WORKSPACE_DIR}/scripts/update-sub.sh" "${SUB_URL}"
fi

# 6. 如果指定了端口，修改端口
if [ -n "${TARGET_PORT}" ]; then
    "${WORKSPACE_DIR}/scripts/switch-port.sh" "${TARGET_PORT}"
fi

# 7. 注册并配置用户级 systemd 服务单元
echo ""
"${WORKSPACE_DIR}/scripts/setup-user-service.sh"

# 8. 启动服务
echo ""
"${WORKSPACE_DIR}/scripts/start.sh"

echo ""
echo "======================================================================"
echo "                   🎉 Mihomo 部署成功！"
echo "======================================================================"
echo "常用操作提示:"
echo "  1. 当前终端开启代理: source ${WORKSPACE_DIR}/env.sh"
echo "  2. 当前终端关闭代理: source ${WORKSPACE_DIR}/env.sh off"
echo "  3. 导入/更新订阅链接: ${WORKSPACE_DIR}/scripts/update-sub.sh \"<订阅URL>\""
echo "  4. 查看运行状态:     ${WORKSPACE_DIR}/scripts/status.sh"
echo "  5. 实时查看运行日志: ${WORKSPACE_DIR}/scripts/logs.sh"
echo "  6. 全面健康体检:     ${WORKSPACE_DIR}/scripts/check.sh"
echo "======================================================================"
