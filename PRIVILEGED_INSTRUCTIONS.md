# 特权操作备忘录 (Privileged Operations)

本项目默认设计为**零特权、普通用户级服务** (`systemctl --user`)，完全不需要 root 权限即可开机自启并后台常驻。

仅当您需要系统全局接管、TUN 虚拟网卡模式或全局服务时，才需要使用管理员权限：

---

### 操作一：为核心开启 TUN 虚拟网卡权限 (免 root 运行 TUN)

```bash
# 进入工作区目录
cd /path/to/mihomo-setup

# 赋予 CAP_NET_ADMIN 能力
sudo ./privileged/enable-tun-capability.sh
```

---

### 操作二：注册为系统级全局守护进程 (可选)

```bash
# 进入工作区目录
cd /path/to/mihomo-setup

# 动态安装系统级服务到 /etc/systemd/system/
sudo ./privileged/setup-root-service.sh
```
安装后管理命令：
- 启动: `sudo systemctl start mihomo`
- 停止: `sudo systemctl stop mihomo`
- 重启: `sudo systemctl restart mihomo`
- 状态: `sudo systemctl status mihomo`
- 日志: `journalctl -u mihomo -f`

---

### 操作三：开启用户注销后持续常驻 (Linger)

如果普通用户登录注销后希望用户级服务不被 systemd 杀掉，请执行：
```bash
sudo loginctl enable-linger $USER
```
