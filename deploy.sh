#!/usr/bin/env bash
# ==============================================================================
# Mihomo 一键极速部署脚本 (适用于任何无头 Linux 电脑)
# 用法:
#   ./deploy.sh                                   # 使用默认配置部署
#   ./deploy.sh "https://your-subscription-url"   # 自动导入订阅并部署
#   ./deploy.sh "https://your-subscription-url" 7890 # 指定订阅与代理端口
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${SCRIPT_DIR}"
BIN_DIR="${WORKSPACE_DIR}/bin"
CONFIG_DIR="${WORKSPACE_DIR}/config"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
CONFIG_EXAMPLE="${CONFIG_DIR}/config.example.yaml"

SUB_URL="${1:-}"
TARGET_PORT="${2:-}"

MIHOMO_VERSION="v1.19.33"

echo "======================================================================"
echo "          Mihomo 极速自动化部署 (Headless Linux Deployer)"
echo "======================================================================"
echo "部署目录: ${WORKSPACE_DIR}"
echo "当前用户: ${USER} (UID: $(id -u))"

# 1. 检查操作系统与 CPU 架构
OS="$(uname -s)"
if [ "${OS}" != "Linux" ]; then
    echo "错误: 本项目仅支持 Linux 系统，当前为: ${OS}" >&2
    exit 1
fi

ARCH="$(uname -m)"
echo "[OK] 系统架构检测: Linux ${ARCH}"

# 2. 检查或安装 Mihomo 二进制核心
mkdir -p "${BIN_DIR}"
NEED_DOWNLOAD_BIN=false

if [ -f "${BIN_DIR}/mihomo" ]; then
    chmod +x "${BIN_DIR}/mihomo" 2>/dev/null || true
    if "${BIN_DIR}/mihomo" -v >/dev/null 2>&1; then
        echo "[OK] 检测到当前二进制核心兼容且可用: $("${BIN_DIR}/mihomo" -v | head -n 1)"
    else
        echo "[WARN] 检测到本地二进制核心与当前 CPU 架构 (${ARCH}) 不兼容，准备重新下载..."
        NEED_DOWNLOAD_BIN=true
    fi
else
    echo "[INFO] 未检测到核心二进制，准备下载..."
    NEED_DOWNLOAD_BIN=true
fi

if [ "${NEED_DOWNLOAD_BIN}" = true ]; then
    case "${ARCH}" in
        x86_64|amd64)
            PKG_ARCH="linux-amd64-compatible"
            ;;
        aarch64|arm64)
            PKG_ARCH="linux-arm64"
            ;;
        armv7l|armhf)
            PKG_ARCH="linux-armv7"
            ;;
        *)
            echo "错误: 暂不支持的架构: ${ARCH}，请手动放置编译好的 mihomo 核心到 ${BIN_DIR}/mihomo" >&2
            exit 1
            ;;
    esac

    DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-${PKG_ARCH}-${MIHOMO_VERSION}.gz"
    ACCEL_URL="https://ghproxy.net/${DOWNLOAD_URL}"
    TMP_GZ="/tmp/mihomo-${PKG_ARCH}.gz"

    echo "正在下载 Mihomo 核心 (${PKG_ARCH})..."
    DOWNLOAD_SUCCESS=false
    for URL in "${ACCEL_URL}" "${DOWNLOAD_URL}"; do
        echo "尝试下载: ${URL}"
        if curl -fSL --connect-timeout 15 --retry 2 -o "${TMP_GZ}" "${URL}" 2>/dev/null; then
            DOWNLOAD_SUCCESS=true
            break
        fi
    done

    if [ "${DOWNLOAD_SUCCESS}" != true ]; then
        echo "错误: 核心下载失败，请检查网络或手动下载对应核心并解压至 ${BIN_DIR}/mihomo" >&2
        exit 1
    fi

    gzip -dc "${TMP_GZ}" > "${BIN_DIR}/mihomo"
    chmod +x "${BIN_DIR}/mihomo"
    rm -f "${TMP_GZ}"
    echo "[OK] Mihomo 核心下载并解压成功: $("${BIN_DIR}/mihomo" -v | head -n 1)"
fi

# 3. 检查规则数据库文件完整性
mkdir -p "${CONFIG_DIR}/providers"
touch "${CONFIG_DIR}/providers/.gitkeep"

for DB_FILE in "Country.mmdb" "geoip.dat" "geosite.dat"; do
    TARGET_DB="${CONFIG_DIR}/${DB_FILE}"
    if [ ! -s "${TARGET_DB}" ]; then
        echo "[INFO] 正在补全数据库文件: ${DB_FILE}..."
        DB_URL="https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/${DB_FILE}"
        ACCEL_DB="https://ghproxy.net/${DB_URL}"
        curl -fSL --connect-timeout 15 --retry 2 -o "${TARGET_DB}" "${ACCEL_DB}" 2>/dev/null || \
        curl -fSL --connect-timeout 15 --retry 2 -o "${TARGET_DB}" "${DB_URL}" 2>/dev/null || true
    fi
done

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
