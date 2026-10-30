#!/usr/bin/env bash
# ==============================================================================
# 配置与更新 Mihomo 订阅
# 用法: ./scripts/update-sub.sh [订阅链接URL]
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${WORKSPACE_DIR}/config/config.yaml"
CONFIG_EXAMPLE="${WORKSPACE_DIR}/config/config.example.yaml"
BACKUP_FILE="${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
PROVIDER_DIR="${WORKSPACE_DIR}/config/providers"
PROVIDER_FILE="${PROVIDER_DIR}/my-subscription.yaml"

SUB_URL="${1:-}"

if [ -z "${SUB_URL}" ]; then
    echo "======================================================================"
    echo "                      Mihomo 订阅更新工具"
    echo "======================================================================"
    if [ -t 0 ]; then
        read -r -p "请输入您的机场/节点订阅链接 (URL): " SUB_URL
    fi
fi

if [ -z "${SUB_URL}" ]; then
    echo "错误: 未输入订阅链接" >&2
    exit 1
fi

echo "正在处理订阅链接: ${SUB_URL}"

# 0. 确保基础配置文件存在
if [ ! -f "${CONFIG_FILE}" ]; then
    if [ -f "${CONFIG_EXAMPLE}" ]; then
        echo "[INFO] 未检测到 config.yaml，正在从模版初始化..."
        cp -f "${CONFIG_EXAMPLE}" "${CONFIG_FILE}"
    else
        echo "错误: 缺少配置文件模版 ${CONFIG_EXAMPLE}" >&2
        exit 1
    fi
fi

# 1. 备份当前配置
cp -f "${CONFIG_FILE}" "${BACKUP_FILE}"
echo "[OK] 已备份当前配置文件至: ${BACKUP_FILE}"

# 2. 下载订阅内容
mkdir -p "${PROVIDER_DIR}"
TEMP_SUB="/tmp/mihomo_sub_download_${RANDOM}.yaml"

echo "正在下载最新订阅配置..."
DOWNLOAD_SUCCESS=false

# 尝试带 User-Agent: clash.meta 下载
if curl -fsSL -A "clash.meta" --connect-timeout 15 -o "${TEMP_SUB}" "${SUB_URL}"; then
    DOWNLOAD_SUCCESS=true
elif curl --noproxy '*' -fsSL -A "clash.meta" --connect-timeout 15 -o "${TEMP_SUB}" "${SUB_URL}"; then
    DOWNLOAD_SUCCESS=true
fi

if [ "${DOWNLOAD_SUCCESS}" != true ]; then
    echo "错误: 订阅下载失败，请检查网络或订阅链接！" >&2
    rm -f "${TEMP_SUB}" 2>/dev/null || true
    exit 1
fi

mv -f "${TEMP_SUB}" "${PROVIDER_FILE}"
echo "[OK] 订阅内容已同步至 ${PROVIDER_FILE}"

# 3. 依赖检查与智能合并配置
if ! python3 -c "import yaml" >/dev/null 2>&1; then
    echo "[WARN] 未检测到 Python PyYAML 模块，尝试快速安装或使用基础订阅..."
    pip3 install pyyaml 2>/dev/null || true
fi

python3 -c "
import yaml

sub_file = '${PROVIDER_FILE}'
cfg_file = '${CONFIG_FILE}'

with open(sub_file, 'r', encoding='utf-8') as f:
    sub = yaml.safe_load(f) or {}

with open(cfg_file, 'r', encoding='utf-8') as f:
    cur = yaml.safe_load(f) or {}

# 同步机场节点、策略组与分流规则
if 'proxies' in sub and sub['proxies']:
    cur['proxies'] = sub['proxies']
if 'proxy-groups' in sub and sub['proxy-groups']:
    cur['proxy-groups'] = sub['proxy-groups']
if 'rules' in sub and sub['rules']:
    cur['rules'] = sub['rules']

# 合并机场专属 DNS 解析策略 (如防污染规则)
if 'dns' in sub and isinstance(sub['dns'], dict) and 'nameserver-policy' in sub['dns']:
    if 'dns' not in cur or not isinstance(cur['dns'], dict):
        cur['dns'] = {}
    if 'nameserver-policy' not in cur['dns']:
        cur['dns']['nameserver-policy'] = {}
    cur['dns']['nameserver-policy'].update(sub['dns']['nameserver-policy'])

# 维护订阅提供商信息
if 'proxy-providers' not in cur or not isinstance(cur['proxy-providers'], dict):
    cur['proxy-providers'] = {}
if 'my-subscription' not in cur['proxy-providers']:
    cur['proxy-providers']['my-subscription'] = {
        'type': 'http',
        'path': './providers/my-subscription.yaml',
        'interval': 86400,
        'health-check': {
            'enable': True,
            'interval': 300,
            'url': 'https://www.gstatic.com/generate_204'
        }
    }
cur['proxy-providers']['my-subscription']['url'] = '''${SUB_URL}'''

with open(cfg_file, 'w', encoding='utf-8') as f:
    yaml.dump(cur, f, allow_unicode=True, sort_keys=False)
"

# 4. 语法校验
echo "正在校验新配置语法完整性..."
if ! "${WORKSPACE_DIR}/bin/mihomo" -t -d "${WORKSPACE_DIR}/config" -f "${CONFIG_FILE}" >/dev/null; then
    echo "错误: 配置合并后语法校验失败，正在自动还原备份..." >&2
    cp -f "${BACKUP_FILE}" "${CONFIG_FILE}"
    exit 1
fi
echo "[OK] 语法校验通过！"

# 5. 重启/重载服务
if systemctl --user is-active --quiet mihomo.service 2>/dev/null; then
    echo "正在重启服务以生效最新节点与策略组..."
    systemctl --user restart mihomo.service
    sleep 1
    echo "[OK] 服务已重启并应用更新"
fi

echo ""
echo "=== 订阅更新完成 ==="
CONTROLLER_ADDR=$(grep -E '^[[:space:]]*external-controller:' "${CONFIG_FILE}" 2>/dev/null | awk '{print $2}' | tr -d "'" | tr -d '"' || echo "127.0.0.1:9090")
echo "控制台地址: http://${CONTROLLER_ADDR}/ui"
