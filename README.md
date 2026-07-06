# ocserv-master (AnyConnect 一键极速部署脚本)

本仓库提供 Cisco AnyConnect (ocserv) 的一键自动编译部署与全自动优化脚本，基于开源的 **ocserv 1.5.0** 最新版构建，完美支持高并发，并自带极为强大的路由分流系统。

> ⚠️ **版本架构提示**：1.5.0 版是专注于极致性能与严苛安全协议的纯血 AnyConnect 版本，**不再支持兼容 OpenVPN 客户端**。如果您有极强的 OpenVPN 客户端兼容需求，请使用我们的 **[ocserv88-main (1.2.4 稳定增强版)](https://github.com/lgdglgc/ocserv88)**。

---

## 🔄 v1.5.0 版本新特性与安全修复

基于最新的官方 **ocserv 1.5.0** (2026年6月发布) 版本构建，引入了多项关键的安全修复与配置增强：

1. **核心安全漏洞修复 (强烈建议升级)**
   - **缓冲区溢出修复**：修复了在非特权工作进程中由超长 `webvpncontext=` Cookie 引起的安全堆溢出漏洞 (Unauthenticated heap buffer overflow)。
   - **MTU 协商修复**：修复了在 DTLS MTU 协商过程中，由于客户端广播超出范围的值可能引发的无符号整数下溢漏洞 (Unsigned integer underflow)。

2. **配置与协议功能升级**
   - **多 DNS/NBNS 服务器支持**：`ocserv.conf` 现在原生支持配置多个 DNS/NBNS 服务器以实现更好的解析备份。
   - **全新配置项**：新增了 `split-dns` (分流 DNS 域名解析) 和 `custom-header` (自定义 HTTP 响应头) 配置支持。
   - **可配置 Rekey 时间**：对会话重密钥 (Rekey) 时间提供了更弹性的可配置化支持。
   - **已废弃特性清理**：不再支持旧版的 `local` 认证关键字。

3. **系统健壮性与报错改进**
   - **严格配置文件审计**：当指定的 `default-user-conf` 或 `default-group-conf` 文件无法打开时，服务端将主动拒绝会话 (Session Rejection) 以避免静默忽略带来的隐患。
   - **Seccomp 沙箱容错**：在启用 `seccomp` 容器安全沙箱时，被禁止的系统调用现在会温和地返回错误码，而不再直接强制杀死 (Kill) 工作进程。

---

## ✨ 核心亮点与优化 (v1.5.0)

1. **全新路由模式无缝切换内核**
   - 彻底摆脱手动修改路由规则的痛苦，脚本通过外科手术式精准替换内核，支持**一键在「全局代理」和「国内直连分流」之间无缝切换**。
   - 分流规则采用独立的 `cn_routes.txt`（包含 200+ 高精准度国内 IP 段），配置无损不干扰自定义端口。

2. **内核网络极限优化与 BBR 拥塞控制**
   - 独家集成 `99-vpn-optimize.conf` 内核级参数注入。
   - 原生强制开启 BBR 拥塞控制。
   - 解除并发连接数限制（提升 fs.file-max, net.core.somaxconn 等至百万级），保证多用户满载状态下依然如丝般顺滑。

3. **定制化专属品牌 UI 接入**
   - 客户端连接成功后展示独特的定制化欢迎横幅 (Banner)：  
     `🌟 欢迎使用 Cisco AnyConnect 🌟 | 微信客服：lgdglgc89 | 淘宝店铺：喀秋莎电玩`

4. **原生功能全覆盖**
   - 自动拉取源码编译、部署。
   - 一键配置 Let's Encrypt 受信任域名 SSL 证书（亦可本地自签）。
   - 用户账号的可视化管理界面。

---

## 🚀 安装与使用教程

### 1. 极速部署
连接到您的 Linux 服务器（建议使用 Debian 11/12/13 或 Ubuntu 20.04+），执行以下命令直接拉取并运行最新版一键脚本：

```bash
wget -N --no-check-certificate https://raw.githubusercontent.com/lgdglgc/ocserv/master/ocserv.sh && chmod +x ocserv.sh && bash ocserv.sh
```

### 2. 图形化交互菜单
运行脚本后，您将看到如下直观的控制台交互面板。只需输入对应数字即可实现全自动化管理：

```text
 ocserv 一键安装管理脚本 [v1.5.0]
  -- Update by SheepKeeperS --
  
 0. 升级脚本
————————————
 1. 安装 ocserv
 2. 卸载 ocserv
————————————
 3. 启动 ocserv
 4. 停止 ocserv
 5. 重启 ocserv
————————————
 6. 设置 账号配置
 7. 查看 配置信息
 8. 修改 配置文件
 9. 查看 日志信息
 10. 切换 路由模式
————————————
```

### 3. 详细功能说明

*   **[1] 安装 ocserv**: 执行全自动环境检测、依赖安装、源码编译。期间会提示您是否使用域名申请免费的受信任 SSL 证书，如果无域名，会自动生成本地自签证书。接着会提示您设置默认后台账号、密码及 TCP/UDP 监听端口。
*   **[6] 设置 账号配置**: 进入极其强大的多用户管理子菜单：
    ```text
     0. 列出 账号配置
    ————————————
     1. 添加 账号配置
     2. 删除 账号配置
    ————————————
     3. 启用/禁用 账号配置
    ```
    > *注意：所有的账号添加、修改、删除操作都是热生效的，**无需重启服务端**！*
*   **[7] 查看 配置信息**: 一键打印出当前服务器的公网 IP、端口信息，以及用于直接填入 AnyConnect 客户端的链接地址。
*   **[10] 切换 路由模式**: 本脚本的杀手锏功能。您可以随时执行此选项：
    *   **选择 1（全局代理）**：所有流量通过 VPN 转发（适合需要全局翻墙的场景）。
    *   **选择 2（国内直连）**：访问国内 IP 不走 VPN（全自动下发几百条国内 IP 直连分流路由表，节省服务器流量，同时保证国内软件满速运行）。

---

## 📱 客户端下载与连接指南

此版本 (1.5.0) 专为 **Cisco AnyConnect** 及 **OpenConnect** 协议设计，拥有最为成熟的跨平台客户端生态。

### 推荐客户端列表

*   **🍏 苹果生态 (iOS / iPadOS)**
    *   请在非国区 App Store 搜索并下载 **Cisco Secure Client**（原名 AnyConnect）。
    *   或搜索下载第三方开源客户端 **OpenConnect**。
*   **🤖 安卓生态 (Android)**
    *   请在 Google Play 商店或通过 APK 下载 **Cisco Secure Client-AnyConnect**。
    *   第三方强力推荐：**OpenConnect**（针对 Android 定制的开源客户端，非常稳定）。
*   **💻 桌面端 (Windows / macOS)**
    *   官方客户端：**Cisco AnyConnect Secure Mobility Client**。
    *   开源客户端：**OpenConnect-GUI**。

### 连接步骤详解

1.  **获取地址**：在服务器脚本主菜单输入 `7` 查看配置信息，获取您的**服务器地址**（如 `vpn.example.com:443` 或 `1.2.3.4:443`）。
2.  **添加连接**：打开您的 AnyConnect 或 OpenConnect 客户端，点击“添加新连接 (Add New VPN Connection)”。
3.  **输入地址**：在服务器地址栏填入刚才获取的地址。
4.  **证书信任（核心体验优势）**：如果您在安装时绑定了**域名**，本脚本会自动为您申请并续签全球受信任的 Let's Encrypt 证书！客户端连接时**绝对不会弹出任何刺眼的红色不可信警告，实现企业级丝滑秒连**！*(注：仅当您无域名被迫生成自签证书时，才需手动点击 Details -> Import 信任警告)*。
5.  **输入密码**：随后客户端会自动拉取定制的 `Banner` 横幅。此时输入您在脚本中设置的**账号**和**密码**。
6.  **连接成功**：成功后即可看到专属的商家欢迎语，尽情享受百万级并发引擎带来的极致网络体验！

### 💡 避坑排错指南

**1. 连接时依然弹窗提示“证书不可信” / “证书与服务器名称不符”？**
*   **原因 A**：你可能在客户端输入的地址是纯数字 IP。**解决**：请务必一字不差地输入你的域名。
*   **原因 B**：安装时 80 端口没开或解析没生效，导致 Let's Encrypt 申请失败，降级生成了自签假证书。**解决**：去网页防火墙端开放 80 端口，然后重新运行一遍本脚本选择申请证书。
*   **原因 C**：手机端存留了以前旧域名/旧IP的缓存配置文件。**解决**：在手机 AnyConnect 里将历史连接记录左滑删除，在设置中点击“清除配置信息”，再手动输入新域名重新连接。

**2. 连接时提示 `DTLS handshake failed` 并且网速很慢？**
*   **原因**：这说明 UDP 隧道建立失败，VPN 被迫降级使用缓慢的 TCP 传输，严重影响视频和游戏体验。
*   **解决**：99% 是因为你的云服务器控制台（如阿里云、腾讯云的安全组）只放行了 TCP 的端口，漏放了同等数字的 **UDP** 端口（默认443）。请务必前往服务器网页控制台手动双向放行 UDP。

## 🛠️ 高级进阶：如何启用客户端节点列表下发 (profile.xml)

默认情况下，本脚本移除了 `profile.xml` 自动下发功能，客户端连接后需手动添加服务器地址。如果您有多台 VPN 服务器，并希望客户端在首次连接后能**自动拉取并保存所有服务器的节点列表**，可以按照以下步骤手动配置：

### 1. 创建节点列表配置文件
在您的各台 VPN 服务器上创建并编辑 `/etc/ocserv/profile.xml`：
```bash
nano /etc/ocserv/profile.xml
```
填入以下模板内容（可根据需要添加多个 `<HostEntry>` 节点，将您**所有的服务器均添加进去**）：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<AnyConnectProfile xmlns="http://schemas.xmlsoap.org/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.xmlsoap.org/encoding/ AnyConnectProfile.xsd">
    <ServerList>
        <HostEntry>
            <HostName>香港主服务器</HostName>
            <HostAddress>hk.example.com:443</HostAddress>
        </HostEntry>
        <HostEntry>
            <HostName>日本备用服务器</HostName>
            <HostAddress>jp.example.com:443</HostAddress>
        </HostEntry>
        <HostEntry>
            <HostName>美国中转服务器</HostName>
            <HostAddress>us.example.com:443</HostAddress>
        </HostEntry>
    </ServerList>
</AnyConnectProfile>
```

### 2. 在 ocserv 配置文件中启用下发
编辑您的 `/etc/ocserv/ocserv.conf` 配置文件：
```bash
nano /etc/ocserv/ocserv.conf
```
在文件末尾或合适位置添加以下一行配置项：
```text
user-profile = /etc/ocserv/profile.xml
```

### 3. 重启 ocserv 服务
运行以下命令使配置在您的服务器上生效：
```bash
systemctl restart ocserv
```
此时，客户端只要首次成功连接其中任意一台服务器，就会自动下载并保存包含所有服务器节点的 `profile.xml`。下次打开 AnyConnect 时，下拉菜单中将自动显示所有已配置的服务器节点列表，实现无缝切换。

---
*Developed & Optimized by SheepKeeperS & lgdglgc*
