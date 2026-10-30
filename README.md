# Mihomo (Clash Meta) 无头 Linux 便携式极速部署套件

本项目是一套专为 **Linux 无头服务器 (Headless VPS / 开发板 / 工作站)** 设计的 Mihomo (Clash Meta) 代理自动化部署套件。

支持在任何新安装的 Linux 机器上实现 **Git Clone 即一键部署**，零特权免 root 运行，开机自启并支持 SSH 关闭后后台常驻。

---

## 🚀 极速上手 (Clone 即部署)

在任何新的 Linux 机器上，只需执行以下命令：

```bash
# 1. 克隆您的个人仓库
git clone <您的仓库URL> ~/mihomo-setup
cd ~/mihomo-setup

# 2. 一键自动化部署 (直接带上机场订阅链接)
./deploy.sh "https://your-subscription-url.com/api/..."
```

> [!TIP]
> 如果暂时没有订阅链接，也可以直接执行 `./deploy.sh`，脚本会使用内置的标准脱敏模版完成基础初始化，后续随时可通过 `./scripts/update-sub.sh` 导入订阅。

---

## ✨ 核心特性

- **全离线多架构自包含 (零网络依赖)**:
  内置 `x86_64` (AMD64)、`aarch64` (ARM64)、`armv7l` (ARMv7) 三大主流架构官方静态编译核心（统一版本 `v1.19.33`）。克隆即具备全套文件，彻底消除新电脑未配置代理时无法从 GitHub 下载核心的“鸡生蛋”悖论。
- **智能架构匹配装配**:
  部署脚本自动识别宿主机 CPU 架构，0.1 秒内从本地多架构核心库完成精确装配。
- **免 root 零特权运行**:
  默认采用 `systemctl --user` 用户级 systemd 架构，完全无需 root / sudo 权限即可注册开机自启。
- **无头常驻保障 (User Linger)**:
  自动配置 `loginctl enable-linger`，确保关闭所有 SSH 连接或注销后，代理进程仍会在后台 24 小时稳定运行。
- **零路径硬编码**:
  所有脚本、服务单元模板均动态计算路径与用户，支持克隆到任意目录（如 `~/tools`、`/opt`、`~/.local`）。
- **隐私脱敏与安全隔离**:
  严格通过 `.gitignore` 过滤实际订阅、节点密码、运行缓存，确保个人 Git 仓库即使推送到远程也绝对安全。
- **自包含 Web 控制台**:
  自带 Metacubexd 前端面板静态资源，克隆后立即可视化查看节点延迟与测速。

---

## 📁 目录结构

```
mihomo-setup/
├── deploy.sh                    # ⭐ 一键极速部署总入口 (自动装配/架构探测/初始化)
├── env.sh                       # 终端代理环境变量配置 (source env.sh)
├── bin/
│   ├── arch/                    # 📦 本地内置多架构官方核心库 (amd64, arm64, armv7)
│   │   ├── mihomo-linux-amd64.gz
│   │   ├── mihomo-linux-arm64.gz
│   │   └── mihomo-linux-armv7.gz
│   └── mihomo                   # 本机装配的核心二进制 (deploy.sh 自动装配，不入Git)
├── config/
│   ├── config.example.yaml      # 带详细中文注释的标准参考配置模版
│   ├── config.yaml              # 运行主配置 (deploy/update-sub 自动生成，不入Git)
│   ├── Country.mmdb             # MaxMind GeoIP 离线地理数据库
│   ├── geoip.dat                # V2Ray 格式 GeoIP 数据库
│   ├── geosite.dat              # V2Ray 格式 Geosite 域名分流数据库
│   ├── providers/               # 订阅节点 yaml 缓存目录 (不入Git)
│   └── ui -> ../ui              # 指向 WebUI 的符号链接 (供 Mihomo 挂载)
├── ui/                          # Metacubexd Web 控制台前端静态资源
├── systemd/
│   ├── mihomo.service.template        # 用户级服务动态模版 (免 root)
│   └── mihomo-system.service.template # 系统级全局服务动态模版 (可选)
├── scripts/
│   ├── setup-user-service.sh    # 用户级 systemd 服务动态渲染与开机自启注册
│   ├── start.sh                 # 启动服务
│   ├── stop.sh                  # 停止服务
│   ├── restart.sh               # 安全重启 (自动校验语法)
│   ├── status.sh                # 查看运行状态、端口监听与 WebUI 入口
│   ├── logs.sh                  # 实时查看运行日志 (journalctl)
│   ├── check.sh                 # 架构/核心/数据库/端口/网络连通性健康诊断
│   ├── update-sub.sh            # 一键导入/更新机场订阅链接
│   ├── switch-port.sh           # 快速切换监听端口 (例如 7890 与 7893)
│   └── mode.sh                  # 切换代理模式 (rule / global / direct)
├── privileged/                  # 需要 root 权限的高级操作 (备用)
│   ├── enable-tun-capability.sh # 为二进制赋予 TUN 虚拟网卡能力
│   ├── setup-root-service.sh    # 安装系统级全局服务
│   └── README.md                # 特权操作说明
├── PRIVILEGED_INSTRUCTIONS.md   # 特权命令备忘录
└── README.md                    # 本文档
```

---

## 🛠️ 常用管理命令

在仓库根目录下，您可以使用以下内置脚本管理代理：

| 操作 | 命令 | 说明 |
| :--- | :--- | :--- |
| **一键部署** | `./deploy.sh [订阅URL] [端口]` | 新机器初始化与一键启动 |
| **查看状态** | `./scripts/status.sh` | 显示运行状态、PID、内存占用及端口监听 |
| **健康体检** | `./scripts/check.sh` | 自动化诊断二进制、数据库、WebUI 与连通性 |
| **启动服务** | `./scripts/start.sh` | 校验语法与端口后通过 systemctl --user 启动 |
| **停止服务** | `./scripts/stop.sh` | 停止服务并清理残留进程 |
| **重启服务** | `./scripts/restart.sh` | 校验语法后重新加载并重启 |
| **查看日志** | `./scripts/logs.sh` | 实时查看运行日志 (`Ctrl+C` 退出) |
| **更新订阅** | `./scripts/update-sub.sh <订阅URL>` | 一键拉取最新节点并合并规则 |
| **切换端口** | `./scripts/switch-port.sh <port>` | 动态切换代理监听端口 (如 7890 / 7893) |
| **切换模式** | `./scripts/mode.sh [rule/global/direct]` | 热切换分流模式 (规则/全局/直连，无需重启) |

---

## 💻 终端与命令行中使用代理

在当前终端中执行以下命令，即可让当前 Shell 会话的所有请求走代理（包括 `curl`、`wget`、`git`、`pip` 等）：

```bash
# 开启当前终端代理
source ./env.sh

# 关闭当前终端代理
source ./env.sh off
```

> [!TIP]
> 如果您希望每次登录 SSH 时默认开启代理，可将以下代码加入您的 `~/.bashrc` 或 `~/.zshrc`：
> ```bash
> [ -f ~/mihomo-setup/env.sh ] && source ~/mihomo-setup/env.sh
> ```

---

## 🌐 Web 管理控制台 (Metacubexd)

服务启动后，打开浏览器访问：
**`http://<您的服务器IP>:9090/ui`**

- **API 地址**: `http://<您的服务器IP>:9090`
- **Secret 密钥**: 默认为空，直接点击连接即可进入。
- 在控制台中可直观测试所有节点延迟、切换自动优选线路或指定代理节点。

---

## 🔒 隐私与安全性保障

1. **订阅不入库**: 机场订阅地址只保存在本地生成的 `config/config.yaml` 中，已被 `.gitignore` 彻底忽略。
2. **本地绑定安全**: 默认端口绑定在 `127.0.0.1`，仅本机终端与进程可访问，默认不对公网开放。
3. **特权完全隔离**: 绝不擅自修改系统全局文件 `/etc`，高级 TUN 特性单独放在 `privileged/` 目录供按需审阅。
