#!/usr/bin/env bash
# ==============================================================================
# Mihomo 终端环境变量配置脚本
# 用法:
#   source env.sh        # 开启终端代理
#   source env.sh off    # 关闭终端代理
# ==============================================================================

_ENV_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CONFIG_FILE="${_ENV_SCRIPT_DIR}/config/config.yaml"

_PROXY_PORT=$(grep -E '^[[:space:]]*mixed-port:' "${_CONFIG_FILE}" 2>/dev/null | awk '{print $2}' || echo "7890")

if [ "${1:-}" = "off" ] || [ "${1:-}" = "unset" ] || [ "${1:-}" = "stop" ]; then
    unset http_proxy https_proxy all_proxy
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
    unset no_proxy NO_PROXY
    echo "[OK] 已清除当前终端的所有代理环境变量"
else
    export http_proxy="http://127.0.0.1:${_PROXY_PORT}"
    export https_proxy="http://127.0.0.1:${_PROXY_PORT}"
    export all_proxy="socks5://127.0.0.1:${_PROXY_PORT}"

    export HTTP_PROXY="http://127.0.0.1:${_PROXY_PORT}"
    export HTTPS_PROXY="http://127.0.0.1:${_PROXY_PORT}"
    export ALL_PROXY="socks5://127.0.0.1:${_PROXY_PORT}"

    export no_proxy="localhost,127.0.0.1,::1,*.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
    export NO_PROXY="${no_proxy}"

    echo "[OK] 已配置当前终端代理环境变量 (指向 127.0.0.1:${_PROXY_PORT}):"
    echo "  http_proxy  = ${http_proxy}"
    echo "  all_proxy   = ${all_proxy}"
    echo "  no_proxy    = ${no_proxy}"
fi
