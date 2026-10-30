#!/usr/bin/env bash
# ==============================================================================
# 启动 Mihomo 服务
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${WORKSPACE_DIR}/config/config.yaml"
CONFIG_EXAMPLE="${WORKSPACE_DIR}/config/config.example.yaml"
USER_SERVICE_FILE="${HOME}/.config/systemd/user/mihomo.service"

# 1. 确保配置文件存在
if [ ! -f "${CONFIG_FILE}" ]; then
    if [ -f "${CONFIG_EXAMPLE}" ]; then
        echo "[INFO] 首次运行，正在从 config.example.yaml 初始化默认配置文件..."
        cp -f "${CONFIG_EXAMPLE}" "${CONFIG_FILE}"
    else
        echo "错误: 缺少配置文件模版 ${CONFIG_EXAMPLE}" >&2
        exit 1
    fi
fi

# 2. 确保用户服务已注册
if [ ! -f "${USER_SERVICE_FILE}" ]; then
    echo "首次运行，正在自动安装用户服务..."
    "${SCRIPT_DIR}/setup-user-service.sh"
fi

# 3. 验证配置文件语法
echo "正在检查配置文件语法..."
if ! "${WORKSPACE_DIR}/bin/mihomo" -t -d "${WORKSPACE_DIR}/config" -f "${CONFIG_FILE}" >/dev/null; then
    echo "错误: 配置文件语法有误，请先修复 ${CONFIG_FILE}" >&2
    exit 1
fi
echo "[OK] 配置文件语法校验通过"

# 4. 检查端口占用
CONFIG_PORT=$(grep -E '^[[:space:]]*mixed-port:' "${CONFIG_FILE}" | awk '{print $2}' || echo "7890")
if ss -tlpn 2>/dev/null | grep -q ":${CONFIG_PORT} "; then
    # 检查占用进程是否就是当前工作区已有的 mihomo
    CURRENT_RUNNING=$(pgrep -f "${WORKSPACE_DIR}/bin/mihomo" || true)
    if [ -z "${CURRENT_RUNNING}" ]; then
        echo "======================================================================"
        echo "[提示] 检测到代理端口 ${CONFIG_PORT} 当前正被占用"
        echo "您可以选择:"
        echo "  1. 停止占用端口的服务后重新运行: ./scripts/start.sh"
        echo "  2. 或切换至独立端口: ./scripts/switch-port.sh <新端口>"
        echo "======================================================================"
        if [ -t 0 ]; then
            read -r -p "是否仍然尝试启动服务? [y/N]: " choice || choice="n"
            case "$choice" in
                [yY][eE][sS]|[yY])
                    echo "继续尝试启动..."
                    ;;
                *)
                    echo "已取消启动。"
                    exit 0
                    ;;
            esac
        fi
    fi
fi

# 5. 启动用户级 systemd 服务
echo "正在通过 systemctl --user 启动服务..."
systemctl --user start mihomo.service

# 6. 检查启动结果
sleep 1
if systemctl --user is-active --quiet mihomo.service; then
    echo "[OK] Mihomo 服务启动成功！"
    "${SCRIPT_DIR}/status.sh"
else
    echo "[FAIL] 服务启动失败，请检查日志:"
    journalctl --user -u mihomo.service -n 20 --no-pager
    exit 1
fi
