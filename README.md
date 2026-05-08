##基于逗比大神的ocserv一键脚本,怀念大神！！！

##升级最新版本ocserv 1.2.4

##自用一键脚本

``` bash
wget -N --no-check-certificate https://raw.githubusercontent.com/lgdglgc/ocserv88/master/ocserv.sh && chmod +x ocserv.sh && bash ocserv.sh
```


################################################################

 ＃＃Debian/Ubuntu:依赖文件：

# Basic build tools
``` bash 
apt-get install -y build-essential pkg-config
```
# Required
``` bash 
apt-get install -y libgnutls28-dev libev-dev
```
# Optional functionality and testing
``` bash
 apt-get install -y libpam0g-dev liblz4-dev libseccomp-dev \
	libreadline-dev libnl-route-3-dev libkrb5-dev libradcli-dev \
	libcurl4-gnutls-dev libcjose-dev libjansson-dev liboath-dev \
	libprotobuf-c-dev libtalloc-dev libllhttp-dev protobuf-c-compiler \
	gperf iperf3 lcov libuid-wrapper libpam-wrapper libnss-wrapper \
	libsocket-wrapper gss-ntlmssp haproxy iputils-ping freeradius \
	gawk gnutls-bin iproute2 yajl-tools tcpdump
```
# For manpages
``` bash 
apt-get install -y ronn
```
#########################################################################

## 修改 /var/lib/ocserv/profile.xml 文件中的内容可以将服务器的配置推送给客户端 ###

```bash
vi /var/lib/ocserv/profile.xml
```

```xml
<ServerList>
                <HostEntry>
                    <HostName>服务器描述1</HostName>
                    <HostAddress>server1_ipaddress:port</HostAddress>
                </HostEntry>
                <HostEntry>
                    <HostName>服务器描述2</HostName>
                    <HostAddress>server2_ipaddress:port</HostAddress>
                </HostEntry>
</ServerList>
```

