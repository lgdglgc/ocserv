# Ocserv (AnyConnect) 一键安装管理脚本

基于逗比大神的原始脚本进行二次重构与现代化升级，专为现代 Linux 发行版优化，旨在提供一键式、高稳定性的 Cisco AnyConnect VPN 服务端部署方案。

怀念大神！！！

## 🌟 核心特性升级
- **现代化服务管理**：智能识别系统环境，完美兼容 `systemd`，支持开机自启与进程守护（同时向下兼容老旧的 SysV init）。
- **自动化安全机制**：自动生成高强度随机密码、自动签发 SSL 证书。
- **智能网络配置**：自动获取服务器公网 IP，自动识别出口网卡并配置 iptables 转发规则。
- **交互式管理菜单**：支持一键安装、卸载、启动、停止、添加/删除/禁用用户等快捷操作。

## 🚀 快速安装 / 管理

支持系统：**Debian 9+ / Ubuntu 18.04+** （暂不支持 CentOS）

在终端中以 `root` 用户运行以下命令：

```bash
wget -N --no-check-certificate https://raw.githubusercontent.com/lgdglgc/ocserv88/master/ocserv.sh && chmod +x ocserv.sh && bash ocserv.sh
```

> **提示**：安装完成后，以后只需在终端输入 `bash ocserv.sh` 或 `./ocserv.sh` 即可再次唤出管理菜单。

---

## ⚠️ 避坑指南（安装后必读！）

### 1. 为什么连接时提示 `DTLS handshake failed`？
这是因为你的云服务器提供商（如阿里云、腾讯云、AWS等）默认屏蔽了外部端口。
**解决办法**：请务必登录你的云服务器控制台，在**【安全组 / 防火墙】**设置中，**放行你安装时配置的端口（例如 443 或 8443）的 TCP 和 UDP 协议**。打游戏必须通 UDP！

### 2. 连接成功但无法上网？
如果确保端口已开但无法上网，可能是因为配置文件中屏蔽了国内 IP 的路由，或者服务器所在的网络无法访问 8.8.8.8。请在管理菜单选择修改配置，调整 DNS 或检查服务器网卡转发状态。

---

## 📱 客户端推荐

- **Windows / macOS**：搜索下载 `Cisco AnyConnect Secure Mobility Client` 或开源的 `OpenConnect GUI`。
- **Android / iOS**：在应用商店搜索安装 `AnyConnect`。

---

## 🛠 高级玩法：向客户端下发服务器列表

你可以通过修改 `profile.xml` 文件，让客户端连接后自动在列表中保存多个服务器地址，省去手动输入的麻烦。

修改文件：
```bash
vi /var/lib/ocserv/profile.xml
```

在文件中添加或修改如下 XML 节点：
```xml
<ServerList>
    <HostEntry>
        <HostName>我的美国节点</HostName>
        <HostAddress>us.yourdomain.com:443</HostAddress>
    </HostEntry>
    <HostEntry>
        <HostName>我的日本节点</HostName>
        <HostAddress>198.51.100.1:8443</HostAddress>
    </HostEntry>
</ServerList>
```
*(注：如果该文件不存在，你需要先检查 ocserv 是否配置了自动下发 xml 文件的参数。)*
