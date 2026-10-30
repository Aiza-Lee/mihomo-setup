# 需要管理员权限的高级操作说明 (Sudo / Root)

本目录包含所有**可能需要 root/sudo 权限**的高级操作脚本。
当前基础代理服务（HTTP/SOCKS5 + WebUI + 用户级 systemd 服务）**完全无需 root 权限**即可正常运行。

仅在您有以下特殊需求时，才需要手动执行本目录下的脚本：

---

### 1. 赋予 TUN 虚拟网卡透明代理能力
- **脚本**: [`enable-tun-capability.sh`](file:///privileged/enable-tun-capability.sh)
- **命令**:
  ```bash
  sudo ./privileged/enable-tun-capability.sh
  ```
- **作用**:
  通过 Linux capabilities 为 `bin/mihomo` 添加 `CAP_NET_ADMIN` 和 `CAP_NET_BIND_SERVICE` 权限。
  赋予后，即使以普通用户运行，也能在 `config.yaml` 中开启 `tun:` 虚拟网卡模式（全局接管终端和系统流量，无需额外配置环境变量）。

---

### 2. 将 Mihomo 注册为全局系统级服务 (System-level systemd)
- **脚本**: [`setup-root-service.sh`](file:///privileged/setup-root-service.sh)
- **命令**:
  ```bash
  sudo ./privileged/setup-root-service.sh
  ```
- **作用**:
  将服务动态安装到 `/etc/systemd/system/mihomo.service`，在系统开机且无需用户登录的情况下全局后台运行。
  *(注: 推荐使用默认的用户级服务 `systemctl --user`，且开启 user linger 驻留即可，效果基本相同，通常无需安装系统级服务)*。
