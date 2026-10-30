#!/usr/bin/env bash
# ==============================================================================
# 安装并配置 Mihomo 用户级系统服务 (无需 root 权限)
# 自动根据当前目录和当前用户动态渲染服务单元
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SERVICE_TEMPLATE="${WORKSPACE_DIR}/systemd/mihomo.service.template"
USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
SERVICE_DEST="${USER_SYSTEMD_DIR}/mihomo.service"
CONFIG_FILE="${WORKSPACE_DIR}/config/config.yaml"
CONFIG_EXAMPLE="${WORKSPACE_DIR}/config/config.example.yaml"

echo "=== 正在配置 Mihomo 用户级 systemd 服务 ==="
echo "工作目录: ${WORKSPACE_DIR}"
echo "当前用户: ${USER}"

# 确保目录存在
mkdir -p "${USER_SYSTEMD_DIR}"

# 确保配置文件存在
if [ ! -f "${CONFIG_FILE}" ]; then
    if [ -f "${CONFIG_EXAMPLE}" ]; then
        echo "[INFO] 未检测到 config.yaml，正在从 config.example.yaml 初始化默认配置..."
        cp -f "${CONFIG_EXAMPLE}" "${CONFIG_FILE}"
    else
        echo "错误: 缺少配置文件模版 ${CONFIG_EXAMPLE}" >&2
        exit 1
    fi
fi

# 验证核心文件存在与语法
if [ ! -x "${WORKSPACE_DIR}/bin/mihomo" ]; then
    echo "错误: 缺少可执行的核心二进制 ${WORKSPACE_DIR}/bin/mihomo" >&2
    exit 1
fi

echo "正在校验配置有效性..."
"${WORKSPACE_DIR}/bin/mihomo" -t -d "${WORKSPACE_DIR}/config" -f "${CONFIG_FILE}" >/dev/null
echo "[OK] 配置校验通过"

# 动态替换模板生成用户级服务文件
if [ ! -f "${SERVICE_TEMPLATE}" ]; then
    echo "错误: 缺少服务模板 ${SERVICE_TEMPLATE}" >&2
    exit 1
fi

sed "s|__WORKSPACE_DIR__|${WORKSPACE_DIR}|g" "${SERVICE_TEMPLATE}" > "${SERVICE_DEST}"
echo "[OK] 服务单元已动态生成并部署到: ${SERVICE_DEST}"

# 重载用户服务配置
systemctl --user daemon-reload
echo "[OK] systemctl --user daemon-reload 执行成功"

# 启用开机自启
systemctl --user enable mihomo.service
echo "[OK] 已启用 mihomo.service 开机自启"

# 尝试自动开启并检查当前用户 linger 状态 (无头环境关闭 SSH 后持续常驻)
loginctl enable-linger "${USER}" 2>/dev/null || true
LINGER_STATUS=$(loginctl show-user "${USER}" 2>/dev/null | grep -i "Linger=yes" || true)
if [ -n "${LINGER_STATUS}" ]; then
    echo "[OK] 用户驻留 (Linger) 已开启，注销或关闭 SSH 后服务将持续在后台常驻运行"
else
    echo "[WARN] 当前用户未开启 Linger，若需要关闭 SSH 会话后服务依然常驻，请执行: sudo loginctl enable-linger ${USER}"
fi

echo ""
echo "=== 配置完成 ==="
echo "您现在可以使用以下命令管理服务:"
echo "  启动服务: ${WORKSPACE_DIR}/scripts/start.sh"
echo "  停止服务: ${WORKSPACE_DIR}/scripts/stop.sh"
echo "  查看状态: ${WORKSPACE_DIR}/scripts/status.sh"
echo "  查看日志: ${WORKSPACE_DIR}/scripts/logs.sh"
