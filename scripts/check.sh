#!/usr/bin/env bash
# ==============================================================================
# Mihomo 运行环境与网络代理健康诊断脚本
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
echo "                   Mihomo 全面健康诊断"
echo "======================================================================"

PASSED=0
WARNINGS=0
FAILED=0

pass() {
    echo "  [PASS] $1"
    PASSED=$((PASSED + 1))
}

warn() {
    echo "  [WARN] $1"
    WARNINGS=$((WARNINGS + 1))
}

fail() {
    echo "  [FAIL] $1"
    FAILED=$((FAILED + 1))
}

# 0. 架构信息
echo "0. 系统环境与 CPU 架构:"
ARCH=$(uname -m)
pass "系统架构: $(uname -s) (${ARCH})"

# 1. 检查核心二进制
echo "1. 核心二进制文件:"
if [ -x "${WORKSPACE_DIR}/bin/mihomo" ]; then
    if VERSION_STR=$("${WORKSPACE_DIR}/bin/mihomo" -v 2>/dev/null | head -n 1); then
        pass "Mihomo 核心已装配且可用: ${VERSION_STR}"
    else
        fail "Mihomo 二进制与当前系统架构 (${ARCH}) 不兼容或无法执行！请运行 ./deploy.sh 重新装配"
    fi
elif [ -d "${WORKSPACE_DIR}/bin/arch" ]; then
    pass "检测到本地多架构核心库完整 (待运行 ./deploy.sh 自动装配到 bin/mihomo)"
else
    fail "缺少 Mihomo 核心或架构库: ${WORKSPACE_DIR}/bin"
fi

# 2. 检查规则与数据库文件
echo "2. GeoIP 与 Geosite 数据库:"
for f in "Country.mmdb" "geoip.dat" "geosite.dat"; do
    if [ -f "${WORKSPACE_DIR}/config/${f}" ] && [ -s "${WORKSPACE_DIR}/config/${f}" ]; then
        pass "数据库文件存在且非空: ${f}"
    else
        fail "缺少数据库文件: ${WORKSPACE_DIR}/config/${f}"
    fi
done

# 3. 检查 WebUI 静态资源
echo "3. WebUI 控制台资源:"
if [ -f "${WORKSPACE_DIR}/ui/index.html" ]; then
    pass "Metacubexd 控制台静态文件完好"
else
    fail "缺少 WebUI 静态文件: ${WORKSPACE_DIR}/ui/index.html"
fi

# 4. 检查配置文件语法
echo "4. 配置文件完整性校验:"
if [ -f "${CONFIG_FILE}" ]; then
    if "${WORKSPACE_DIR}/bin/mihomo" -t -d "${WORKSPACE_DIR}/config" -f "${CONFIG_FILE}" >/dev/null 2>&1; then
        pass "配置文件语法校验通过"
    else
        fail "配置文件校验失败，请检查 ${CONFIG_FILE}"
    fi
else
    warn "未检测到 config.yaml，请运行 ./scripts/update-sub.sh 导入订阅或从模版生成"
fi

# 5. 检查系统服务与端口
echo "5. 服务与端口状态:"
if [ -f "${CONFIG_FILE}" ]; then
    CONFIG_PORT=$(grep -E '^[[:space:]]*mixed-port:' "${CONFIG_FILE}" 2>/dev/null | awk '{print $2}' || echo "7890")
    CONTROLLER_ADDR=$(grep -E '^[[:space:]]*external-controller:' "${CONFIG_FILE}" 2>/dev/null | awk '{print $2}' | tr -d "'" | tr -d '"' || echo "127.0.0.1:9090")
else
    CONFIG_PORT="7890"
    CONTROLLER_ADDR="127.0.0.1:9090"
fi
CONTROLLER_PORT="${CONTROLLER_ADDR##*:}"

if systemctl --user is-active --quiet mihomo.service 2>/dev/null; then
    pass "用户级 systemd 服务正在运行 (mihomo.service)"
else
    warn "用户级 systemd 服务当前未激活"
fi

# 端口检查
if ss -tlpn 2>/dev/null | grep -q ":${CONFIG_PORT} "; then
    pass "代理端口 ${CONFIG_PORT} 处于 LISTEN 状态"
else
    warn "代理端口 ${CONFIG_PORT} 未处于监听状态"
fi

if ss -tlpn 2>/dev/null | grep -q ":${CONTROLLER_PORT} "; then
    pass "外部控制端口 ${CONTROLLER_ADDR} 处于 LISTEN 状态"
    # 测试 WebUI HTTP 访问
    HTTP_CODE=$(curl --noproxy '*' -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "http://${CONTROLLER_ADDR}/ui/" || true)
    if [ "${HTTP_CODE}" = "200" ]; then
        pass "WebUI 控制台访问测试正常 (HTTP 200: http://${CONTROLLER_ADDR}/ui)"
    else
        warn "WebUI HTTP 响应状态码为: ${HTTP_CODE}"
    fi
else
    warn "外部控制端口 ${CONTROLLER_ADDR} 未监听"
fi

# 6. 测试代理连通性
echo "6. 代理网络连通性 (若服务运行中):"
if systemctl --user is-active --quiet mihomo.service 2>/dev/null && ss -tlpn 2>/dev/null | grep -q ":${CONFIG_PORT} "; then
    # 测试直连国内
    if curl -x "http://127.0.0.1:${CONFIG_PORT}" -fsSL --connect-timeout 5 -o /dev/null "https://www.baidu.com" 2>/dev/null; then
        pass "国内网络分流连通 (Baidu)"
    else
        warn "国内分流连通测试超时"
    fi

    # 测试海外代理
    if curl -x "http://127.0.0.1:${CONFIG_PORT}" -fsSL --connect-timeout 5 -o /dev/null "https://www.gstatic.com/generate_204" 2>/dev/null; then
        pass "海外代理节点连通 (Google 204)"
    else
        warn "海外节点测试连接超时 (可能未导入有效订阅或当前节点离线)"
    fi
else
    warn "服务未运行，跳过连通性测试"
fi

echo "======================================================================"
echo "诊断结果: 通过 ${PASSED} 项, 警告 ${WARNINGS} 项, 失败 ${FAILED} 项"
echo "======================================================================"

if [ "${FAILED}" -gt 0 ]; then
    exit 1
fi
