#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#=================================================
#	System Required: Debian/Ubuntu
#	Description: ocserv AnyConnect
#	Version: 1.4.2
#	Author: SheepKeeperS
#	Blog: blog.kqsdw.com
#=================================================
sh_ver="1.4.2"
file="/usr/local/sbin/ocserv"
conf_file="/etc/ocserv"
conf="/etc/ocserv/ocserv.conf"
passwd_file="/etc/ocserv/ocpasswd"
log_file="/tmp/ocserv.log"
ocserv_ver="1.4.2"
PID_FILE="/var/run/ocserv.pid"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}
#检查系统
check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
    fi
	#bit=`uname -m`
}
check_installed_status(){
	[[ ! -e ${file} ]] && echo -e "${Error} ocserv 没有安装，请检查 !" && exit 1
	[[ ! -e ${conf} ]] && echo -e "${Error} ocserv 配置文件不存在，请检查 !" && [[ $1 != "un" ]] && exit 1
}
check_pid(){
	if [[ ! -e ${PID_FILE} ]]; then
		PID=""
	else
		PID=$(cat ${PID_FILE})
	fi
}
Get_ip(){
	ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ip}" ]]; then
		ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ip}" ]]; then
			ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ip}" ]]; then
				ip="VPS_IP"
			fi
		fi
	fi
}
Download_ocserv(){
	local build_dir
	build_dir=$(mktemp -d)
	cd "${build_dir}"
	wget "https://www.infradead.org/ocserv/download/ocserv-${ocserv_ver}.tar.xz"
	[[ ! -s "ocserv-${ocserv_ver}.tar.xz" ]] && echo -e "${Error} ocserv 源码文件下载失败 !" && rm -rf "${build_dir}" && exit 1
	tar -xJf "ocserv-${ocserv_ver}.tar.xz" && cd "ocserv-${ocserv_ver}"
	meson setup build --prefix=/usr/local
	[[ $? -ne 0 ]] && echo -e "${Error} meson 配置失败，请检查依赖！" && rm -rf "${build_dir}" && exit 1
	ninja -C build
	[[ $? -ne 0 ]] && echo -e "${Error} 编译失败，请检查日志！" && rm -rf "${build_dir}" && exit 1
	ninja -C build install
	[[ $? -ne 0 ]] && echo -e "${Error} 安装失败，请检查！" && rm -rf "${build_dir}" && exit 1
	cd / && rm -rf "${build_dir}"

	if [[ -e ${file} ]]; then
		mkdir -p "${conf_file}"
		# 添加时间戳绕过 GitHub 的 CDN 缓存
		wget --no-check-certificate -O "${conf}" "https://raw.githubusercontent.com/lgdglgc/ocserv/master/other/ocserv.conf?t=$(date +%s)"
		[[ ! -s "${conf}" ]] && echo -e "${Error} ocserv 配置文件下载失败 !" && rm -rf "${conf_file}" && exit 1
	else
		echo -e "${Error} ocserv 编译安装失败，请检查！" && exit 1
	fi
}
Service_ocserv(){
	# 检测 systemd 或 SysV init
	if command -v systemctl &>/dev/null && systemctl --version &>/dev/null; then
		# 写入 systemd unit 文件
		cat > /etc/systemd/system/ocserv.service << 'EOF'
[Unit]
Description=OpenConnect SSL VPN server
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/var/run/ocserv.pid
ExecStart=/usr/local/sbin/ocserv -c /etc/ocserv/ocserv.conf
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=51200

[Install]
WantedBy=multi-user.target
EOF
		systemctl daemon-reload
		systemctl enable ocserv
		echo -e "${Info} ocserv systemd 服务已配置并设置开机自启 !"
	else
		# 降级使用 SysV init
		if ! wget --no-check-certificate "https://raw.githubusercontent.com/lgdglgc/ocserv/master/service/ocserv_debian?t=$(date +%s)" -O /etc/init.d/ocserv; then
			echo -e "${Error} ocserv 服务 管理脚本下载失败 !" && over
		fi
		chmod +x /etc/init.d/ocserv
		update-rc.d -f ocserv defaults
		echo -e "${Info} ocserv SysV init 服务脚本下载完成 !"
	fi
}
rand(){
	min=10000
	max=$((60000-$min+1))
	num=$(date +%s%N)
	echo $(($num%$max+$min))
}
Generate_SSL(){
	echo -e "${Tip} 是否拥有已经解析到本服务器IP的域名？"
	echo -e "${Tip} 使用域名可以申请 Let's Encrypt 受信任证书，客户端连接时不再报“不安全”警告。"
	read -e -p "(有域名输入 Y, 没有直接回车使用自签证书):" has_domain
	[[ -z "${has_domain}" ]] && has_domain="n"

	if [[ ${has_domain} == [Yy] ]]; then
		read -e -p "请输入你的域名 (例如 vpn.example.com):" domain
		if [[ ! -z "${domain}" ]]; then
			echo -e "${Info} 开始配置安装 acme.sh..."
			curl https://get.acme.sh | sh
			~/.acme.sh/acme.sh --upgrade --auto-upgrade
			~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
			echo -e "${Info} 正在申请证书，请确保 80 端口未被占用且域名已正确解析到本服..."
			~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256
			local acme_status=$?
			if [[ ${acme_status} -eq 0 ]] || [[ ${acme_status} -eq 2 ]]; then
				echo -e "${Info} 证书申请成功（或已存在有效证书）！开始部署到 ocserv..."
				mkdir -p /etc/ocserv/ssl
				~/.acme.sh/acme.sh --installcert -d ${domain} --fullchainpath /etc/ocserv/ssl/server-cert.pem --keypath /etc/ocserv/ssl/server-key.pem --ecc
				# 对于真实的公网证书，直接注释掉 ocserv.conf 里的 ca-cert 限制
				sed -i 's/^ca-cert =/#ca-cert =/g' ${conf}
				echo -e "${Info} 受信任证书配置完成！"
				return 0
			else
				echo -e "${Error} 证书申请失败！自动回退到自签证书模式！"
			fi
		else
			echo -e "${Error} 未输入域名，回退到自签证书模式！"
		fi
	fi

	echo -e "${Info} 开始生成本地自签证书..."
	lalala=$(rand)
	rm -rf /tmp/ssl && mkdir -p /tmp/ssl && cd /tmp/ssl
	echo -e 'cn = "'${lalala}'"
organization = "'${lalala}'"
serial = 1
expiration_days = 3650
ca
signing_key
cert_signing_key
crl_signing_key' > ca.tmpl
	[[ $? != 0 ]] && echo -e "${Error} 写入SSL证书签名模板失败(ca.tmpl) !" && over
	certtool --generate-privkey --outfile ca-key.pem
	[[ $? != 0 ]] && echo -e "${Error} 生成SSL证书密匙文件失败(ca-key.pem) !" && over
	certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca-cert.pem
	[[ $? != 0 ]] && echo -e "${Error} 生成SSL证书文件失败(ca-cert.pem) !" && over
	
	Get_ip
	if [[ -z "$ip" ]]; then
		echo -e "${Error} 检测外网IP失败 !"
		read -e -p "请手动输入你的服务器外网IP:" ip
		[[ -z "${ip}" ]] && echo "取消..." && over
	fi
	echo -e 'cn = "'${ip}'"
organization = "'${lalala}'"
expiration_days = 3650
signing_key
encryption_key
tls_www_server' > server.tmpl
	[[ $? != 0 ]] && echo -e "${Error} 写入SSL证书签名模板失败(server.tmpl) !" && over
	certtool --generate-privkey --outfile server-key.pem
	[[ $? != 0 ]] && echo -e "${Error} 生成SSL证书密匙文件失败(server-key.pem) !" && over
	certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca-cert.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem
	[[ $? != 0 ]] && echo -e "${Error} 生成SSL证书文件失败(server-cert.pem) !" && over
	
	mkdir -p /etc/ocserv/ssl
	mv ca-cert.pem /etc/ocserv/ssl/ca-cert.pem
	mv ca-key.pem /etc/ocserv/ssl/ca-key.pem
	mv server-cert.pem /etc/ocserv/ssl/server-cert.pem
	mv server-key.pem /etc/ocserv/ssl/server-key.pem
	cd .. && rm -rf /tmp/ssl/
}
# 统一依赖包列表（Debian/Ubuntu 通用）
DEPS="wget curl tar xz-utils socat openssl vim net-tools pkg-config build-essential cron \
	libgnutls28-dev libwrap0-dev liblz4-dev libseccomp-dev libreadline-dev \
	libnl-nf-3-dev libnl-route-3-dev libev-dev gnutls-bin \
	libpam0g-dev libsystemd-dev meson ninja-build \
	gperf protobuf-c-compiler libprotobuf-c-dev libtalloc-dev \
	ipcalc libtasn1-bin libjansson-dev liboath-dev libcurl4-gnutls-dev iptables"

Installation_dependency(){
	[[ ! -e "/dev/net/tun" ]] && echo -e "${Error} 你的VPS没有开启TUN，请联系IDC或通过VPS控制面板打开TUN/TAP开关 !" && exit 1
	if [[ ${release} = "centos" ]]; then
		echo -e "${Error} 本脚本不支持 CentOS 系统 !" && exit 1
	fi

	echo -e "${Info} 正在检测系统缺失的必要依赖..."
	local missing_deps=""
	for dep in ${DEPS}; do
		if ! dpkg -s "${dep}" >/dev/null 2>&1; then
			missing_deps="${missing_deps} ${dep}"
		fi
	done

	if [[ -n "${missing_deps}" ]]; then
		echo -e "${Info} 发现缺失的依赖: ${missing_deps}"
		echo -e "${Info} 正在更新软件包列表..."
		apt-get update -y
		echo -e "${Info} 正在安装缺失依赖（可能需要几分钟）..."
		apt-get install -y ${missing_deps}
		if [[ $? -ne 0 ]]; then
			echo -e "${Error} 依赖安装失败，请检查网络或 apt 源配置！" && exit 1
		fi
	else
		echo -e "${Info} 所有系统必要依赖均已安装，跳过下载阶段。"
	fi

	echo -e "${Info} 正在配置并启动 cron 定时任务服务（用于证书自动续期）..."
	systemctl start cron 2>/dev/null || /etc/init.d/cron start 2>/dev/null
	systemctl enable cron 2>/dev/null || update-rc.d cron defaults 2>/dev/null
}
Install_ocserv(){
	check_root
	[[ -e ${file} ]] && echo -e "${Error} ocserv 已安装，请检查 !" && exit 1
	echo -e "${Info} 开始安装/配置 依赖..."
	Installation_dependency
	echo -e "${Info} 开始下载/安装 配置文件..."
	Download_ocserv
	echo -e "${Info} 开始下载/安装 服务脚本(init)..."
	Service_ocserv
	echo -e "${Info} 开始自签SSL证书..."
	Generate_SSL
	echo -e "${Info} 开始设置账号配置..."
	Read_config
	Set_Config
	echo -e "${Info} 开始设置 iptables防火墙..."
	Set_iptables
	echo -e "${Info} 开始添加 iptables防火墙规则..."
	Add_iptables
	echo -e "${Info} 开始保存 iptables防火墙规则..."
	Save_iptables
	echo -e "${Info} 所有步骤 安装完毕，开始启动..."
	Start_ocserv
}
Start_ocserv(){
	check_installed_status
	if [[ -f /etc/systemd/system/ocserv.service ]]; then
		systemctl is-active --quiet ocserv && echo -e "${Error} ocserv 正在运行，请检查 !" && exit 1
		systemctl start ocserv
		sleep 2s
		systemctl is-active --quiet ocserv && View_Config || echo -e "${Error} ocserv 启动失败，请运行: journalctl -u ocserv -n 30"
	else
		check_pid
		[[ ! -z ${PID} ]] && echo -e "${Error} ocserv 正在运行，请检查 !" && exit 1
		/etc/init.d/ocserv start
		sleep 2s
		check_pid
		[[ ! -z ${PID} ]] && View_Config
	fi
}
Stop_ocserv(){
	check_installed_status
	if [[ -f /etc/systemd/system/ocserv.service ]]; then
		systemctl is-active --quiet ocserv || { echo -e "${Error} ocserv 没有运行，请检查 !"; exit 1; }
		systemctl stop ocserv
	else
		check_pid
		[[ -z ${PID} ]] && echo -e "${Error} ocserv 没有运行，请检查 !" && exit 1
		/etc/init.d/ocserv stop
	fi
}
Restart_ocserv(){
	check_installed_status
	if [[ -f /etc/systemd/system/ocserv.service ]]; then
		systemctl restart ocserv
		sleep 2s
		systemctl is-active --quiet ocserv && View_Config || echo -e "${Error} ocserv 重启失败，请运行: journalctl -u ocserv -n 30"
	else
		check_pid
		[[ ! -z ${PID} ]] && /etc/init.d/ocserv stop
		/etc/init.d/ocserv start
		sleep 2s
		check_pid
		[[ ! -z ${PID} ]] && View_Config
	fi
}
Set_ocserv(){
	[[ ! -e ${conf} ]] && echo -e "${Error} ocserv 配置文件不存在 !" && exit 1
	tcp_port=$(cat ${conf}|grep "tcp-port ="|awk -F ' = ' '{print $NF}')
	udp_port=$(cat ${conf}|grep "udp-port ="|awk -F ' = ' '{print $NF}')
	vim ${conf}
	set_tcp_port=$(cat ${conf}|grep "tcp-port ="|awk -F ' = ' '{print $NF}')
	set_udp_port=$(cat ${conf}|grep "udp-port ="|awk -F ' = ' '{print $NF}')
	Del_iptables
	Add_iptables
	Save_iptables
	echo "是否重启 ocserv ? (Y/n)"
	read -e -p "(默认: Y):" yn
	[[ -z ${yn} ]] && yn="y"
	if [[ ${yn} == [Yy] ]]; then
		Restart_ocserv
	fi
}
Set_username(){
	echo "请输入 要添加的VPN账号 用户名"
	read -e -p "(默认: admin):" username
	[[ -z "${username}" ]] && username="admin"
	echo && echo -e "	用户名 : ${Red_font_prefix}${username}${Font_color_suffix}" && echo
}
Set_passwd(){
	local default_pass
	default_pass=$(tr -dc 'A-Za-z0-9!@#' < /dev/urandom 2>/dev/null | head -c 12)
	[[ -z "${default_pass}" ]] && default_pass="Oc$(date +%s%N | md5sum | head -c 8)"
	echo "请输入 要添加的VPN账号 密码"
	read -e -p "(默认: 随机密码 ${default_pass}):" userpass
	[[ -z "${userpass}" ]] && userpass="${default_pass}"
	echo && echo -e "\t密码 : ${Red_font_prefix}${userpass}${Font_color_suffix}" && echo
}
Set_tcp_port(){
	while true
	do
	echo -e "请输入VPN服务端的TCP端口"
	read -e -p "(默认: 443):" set_tcp_port
	[[ -z "$set_tcp_port" ]] && set_tcp_port="443"
	echo $((${set_tcp_port}+0)) &>/dev/null
	if [[ $? -eq 0 ]]; then
		if [[ ${set_tcp_port} -ge 1 ]] && [[ ${set_tcp_port} -le 65535 ]]; then
			echo && echo -e "	TCP端口 : ${Red_font_prefix}${set_tcp_port}${Font_color_suffix}" && echo
			break
		else
			echo -e "${Error} 请输入正确的数字！"
		fi
	else
		echo -e "${Error} 请输入正确的数字！"
	fi
	done
}
Set_udp_port(){
	while true
	do
	echo -e "请输入VPN服务端的UDP端口"
	read -e -p "(默认: ${set_tcp_port}):" set_udp_port
	[[ -z "$set_udp_port" ]] && set_udp_port="${set_tcp_port}"
	echo $((${set_udp_port}+0)) &>/dev/null
	if [[ $? -eq 0 ]]; then
		if [[ ${set_udp_port} -ge 1 ]] && [[ ${set_udp_port} -le 65535 ]]; then
			echo && echo -e "	UDP端口 : ${Red_font_prefix}${set_udp_port}${Font_color_suffix}" && echo
			break
		else
			echo -e "${Error} 请输入正确的数字！"
		fi
	else
		echo -e "${Error} 请输入正确的数字！"
	fi
	done
}
Set_Config(){
	Set_username
	Set_passwd
	printf "%s\n%s\n" "${userpass}" "${userpass}" | ocpasswd -c ${passwd_file} ${username}
	Set_tcp_port
	Set_udp_port
	sed -i 's/tcp-port = '"$(echo ${tcp_port})"'/tcp-port = '"$(echo ${set_tcp_port})"'/g' ${conf}
	sed -i 's/udp-port = '"$(echo ${udp_port})"'/udp-port = '"$(echo ${set_udp_port})"'/g' ${conf}

	# 自动生成下发给客户端的服务器列表 (profile.xml)
	local server_addr="${ip}"
	# 如果申请了域名证书，尝试从证书提取域名作为下发地址
	if [[ -f /etc/ocserv/ssl/server-cert.pem ]]; then
		local maybe_domain=$(openssl x509 -in /etc/ocserv/ssl/server-cert.pem -noout -text 2>/dev/null | grep DNS: | sed -n 's/.*DNS:\([^,]*\).*/\1/p' | head -1)
		[[ ! -z "${maybe_domain}" ]] && server_addr="${maybe_domain}"
	fi
	
	cat > /etc/ocserv/profile.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<AnyConnectProfile xmlns="http://schemas.xmlsoap.org/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.xmlsoap.org/encoding/ AnyConnectProfile.xsd">
    <ServerList>
        <HostEntry>
            <HostName>${server_addr}</HostName>
            <HostAddress>\${server_addr}:\${set_tcp_port}</HostAddress>
        </HostEntry>
    </ServerList>
</AnyConnectProfile>
EOF
}
Read_config(){
	[[ ! -e ${conf} ]] && echo -e "${Error} ocserv 配置文件不存在 !" && exit 1
	conf_text=$(cat ${conf}|grep -v '#')
	tcp_port=$(echo -e "${conf_text}"|grep "tcp-port ="|awk -F ' = ' '{print $NF}')
	udp_port=$(echo -e "${conf_text}"|grep "udp-port ="|awk -F ' = ' '{print $NF}')
	max_same_clients=$(echo -e "${conf_text}"|grep "max-same-clients ="|awk -F ' = ' '{print $NF}')
	max_clients=$(echo -e "${conf_text}"|grep "max-clients ="|awk -F ' = ' '{print $NF}')
}
List_User(){
	[[ ! -e ${passwd_file} ]] && echo -e "${Error} ocserv 账号配置文件不存在 !" && exit 1
	User_text=$(cat ${passwd_file})
	if [[ ! -z ${User_text} ]]; then
		User_num=$(echo -e "${User_text}"|wc -l)
		user_list_all=""
		for((integer = 1; integer <= ${User_num}; integer++))
		do
			user_name=$(echo -e "${User_text}" | awk -F ':*:' '{print $1}' | sed -n "${integer}p")
			user_status=$(echo -e "${User_text}" | awk -F ':*:' '{print $NF}' | sed -n "${integer}p"|cut -c 1)
			if [[ ${user_status} == '!' ]]; then
				user_status="禁用"
			else
				user_status="启用"
			fi
			user_list_all=${user_list_all}"用户名: "${user_name}" 账号状态: "${user_status}"\n"
		done
		echo && echo -e "用户总数 ${Green_font_prefix}"${User_num}"${Font_color_suffix}"
		echo -e ${user_list_all}
	fi
}
Add_User(){
	Set_username
	Set_passwd
	user_status=$(grep "^${username}:" "${passwd_file}")
	[[ ! -z ${user_status} ]] && echo -e "${Error} 用户名已存在 ![ ${username} ]" && exit 1
	printf "%s\n%s\n" "${userpass}" "${userpass}" | ocpasswd -c ${passwd_file} ${username}
	user_status=$(grep "^${username}:" "${passwd_file}")
	if [[ ! -z ${user_status} ]]; then
		echo -e "${Info} 账号添加成功 ![ ${username} ]"
	else
		echo -e "${Error} 账号添加失败 ![ ${username} ]" && exit 1
	fi
}
Del_User(){
	List_User
	[[ ${User_num} == 1 ]] && echo -e "${Error} 当前仅剩一个账号配置，无法删除 !" && exit 1
	echo -e "请输入要删除的VPN账号的用户名"
	read -e -p "(默认取消):" Del_username
	[[ -z "${Del_username}" ]] && echo "已取消..." && exit 1
	user_status=$(grep "^${Del_username}:" "${passwd_file}")
	[[ -z ${user_status} ]] && echo -e "${Error} 用户名不存在 ! [${Del_username}]" && exit 1
	ocpasswd -c ${passwd_file} -d ${Del_username}
	user_status=$(grep "^${Del_username}:" "${passwd_file}")
	if [[ -z ${user_status} ]]; then
		echo -e "${Info} 删除成功 ! [${Del_username}]"
	else
		echo -e "${Error} 删除失败 ! [${Del_username}]" && exit 1
	fi
}
Modify_User_disabled(){
	List_User
	echo -e "请输入要启用/禁用的VPN账号的用户名"
	read -e -p "(默认取消):" Modify_username
	[[ -z "${Modify_username}" ]] && echo "已取消..." && exit 1
	user_status=$(grep "^${Modify_username}:" "${passwd_file}")
	[[ -z ${user_status} ]] && echo -e "${Error} 用户名不存在 ! [${Modify_username}]" && exit 1
	user_status=$(grep "^${Modify_username}:" "${passwd_file}" | awk -F ':*:' '{print $NF}' | cut -c 1)
	if [[ ${user_status} == '!' ]]; then
			ocpasswd -c ${passwd_file} -u ${Modify_username}
			user_status=$(cat "${passwd_file}" | grep "${Modify_username}"':*:' | awk -F ':*:' '{print $NF}' |cut -c 1)
			if [[ ${user_status} != '!' ]]; then
				echo -e "${Info} 启用成功 ! [${Modify_username}]"
			else
				echo -e "${Error} 启用失败 ! [${Modify_username}]" && exit 1
			fi
		else
			ocpasswd -c ${passwd_file} -l ${Modify_username}
			user_status=$(cat "${passwd_file}" | grep "${Modify_username}"':*:' | awk -F ':*:' '{print $NF}' |cut -c 1)
			if [[ ${user_status} == '!' ]]; then
				echo -e "${Info} 禁用成功 ! [${Modify_username}]"
			else
				echo -e "${Error} 禁用失败 ! [${Modify_username}]" && exit 1
			fi
		fi
}
Set_Pass(){
	check_installed_status
	echo && echo -e " 你要做什么？
	
 ${Green_font_prefix} 0.${Font_color_suffix} 列出 账号配置
————————
 ${Green_font_prefix} 1.${Font_color_suffix} 添加 账号配置
 ${Green_font_prefix} 2.${Font_color_suffix} 删除 账号配置
————————
 ${Green_font_prefix} 3.${Font_color_suffix} 启用/禁用 账号配置
 
 注意：添加/修改/删除 账号配置后，VPN服务端会实时读取，无需重启服务端 !" && echo
	read -e -p "(默认: 取消):" set_num
	[[ -z "${set_num}" ]] && echo "已取消..." && exit 1
	if [[ ${set_num} == "0" ]]; then
		List_User
	elif [[ ${set_num} == "1" ]]; then
		Add_User
	elif [[ ${set_num} == "2" ]]; then
		Del_User
	elif [[ ${set_num} == "3" ]]; then
		Modify_User_disabled
	else
		echo -e "${Error} 请输入正确的数字[1-3]" && exit 1
	fi
}
View_Config(){
	Get_ip
	Read_config
	clear && echo "===================================================" && echo
	echo -e " AnyConnect 配置信息：" && echo
	echo -e " I  P\t\t  : ${Green_font_prefix}${ip}${Font_color_suffix}"
	echo -e " TCP端口\t  : ${Green_font_prefix}${tcp_port}${Font_color_suffix}"
	echo -e " UDP端口\t  : ${Green_font_prefix}${udp_port}${Font_color_suffix}"
	echo -e " 单用户设备数限制 : ${Green_font_prefix}${max_same_clients}${Font_color_suffix}"
	echo -e " 总用户设备数限制 : ${Green_font_prefix}${max_clients}${Font_color_suffix}"
	if [[ "${tcp_port}" == "443" ]]; then
		echo -e "\n 客户端链接请填写 : ${Green_font_prefix}你的域名${Font_color_suffix} (使用域名可防弹窗，如未绑定域名请填 ${ip})"
	else
		echo -e "\n 客户端链接请填写 : ${Green_font_prefix}你的域名:${tcp_port}${Font_color_suffix} (或 ${ip}:${tcp_port})"
	fi
	echo && echo "==================================================="
}
View_Log(){
	if [[ -f /etc/systemd/system/ocserv.service ]]; then
		echo && echo -e "${Tip} 按 ${Red_font_prefix}Ctrl+C${Font_color_suffix} 终止查看日志" && echo
		journalctl -u ocserv -f
	else
		[[ ! -e ${log_file} ]] && echo -e "${Error} ocserv 日志文件不存在 !" && exit 1
		echo && echo -e "${Tip} 按 ${Red_font_prefix}Ctrl+C${Font_color_suffix} 终止查看日志" && echo
		tail -f ${log_file}
	fi
}
Uninstall_ocserv(){
	check_installed_status "un"
	echo "确定要彻底卸载 ocserv 吗 ? (y/N)"
	echo
	read -e -p "(默认: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		check_pid
		if [[ ! -z $PID ]]; then
			if [[ -f /etc/systemd/system/ocserv.service ]]; then systemctl stop ocserv 2>/dev/null; else /etc/init.d/ocserv stop 2>/dev/null; fi
			rm -f ${PID_FILE}
		fi
		
		# 清理防火墙端口放行规则 (兼容配置文件丢失的容错)
		if [[ -e ${conf} ]]; then
			tcp_port=$(cat ${conf}|grep "tcp-port ="|awk -F ' = ' '{print $NF}')
			udp_port=$(cat ${conf}|grep "udp-port ="|awk -F ' = ' '{print $NF}')
			[[ -n "${tcp_port}" ]] && iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${tcp_port} -j ACCEPT 2>/dev/null
			[[ -n "${udp_port}" ]] && iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${udp_port} -j ACCEPT 2>/dev/null
			Save_iptables
		fi

		if [[ -f /etc/systemd/system/ocserv.service ]]; then
			systemctl disable ocserv 2>/dev/null
			rm -f /etc/systemd/system/ocserv.service
			systemctl daemon-reload
		else
			update-rc.d -f ocserv remove 2>/dev/null
			rm -rf /etc/init.d/ocserv
		fi
		
		# 彻底清理所有文件和配置
		rm -rf /etc/ocserv
		rm -rf /tmp/ocserv.log
		rm -f /usr/local/bin/occtl
		rm -f /usr/local/bin/ocpasswd
		rm -f /usr/local/bin/ocserv-fw
		rm -f /usr/local/sbin/ocserv
		rm -f /usr/local/share/man/man8/ocserv.8
		rm -f /usr/local/share/man/man8/ocpasswd.8
		rm -f /usr/local/share/man/man8/occtl.8
		
		# 清理系统级网络优化脚本和配置
		rm -f /etc/sysctl.d/99-vpn-optimize.conf
		rm -f /etc/network/if-pre-up.d/iptables
		sysctl --system >/dev/null 2>&1
		
		echo && echo "ocserv 及其所有配置残留已彻底清理完成 !" && echo
	else
		echo && echo "卸载已取消..." && echo
	fi
}
over(){
	if [[ -f /etc/systemd/system/ocserv.service ]]; then
		systemctl disable ocserv 2>/dev/null
		rm -f /etc/systemd/system/ocserv.service
		systemctl daemon-reload
	else
		update-rc.d -f ocserv remove 2>/dev/null
		rm -rf /etc/init.d/ocserv
	fi
	
	rm -rf /etc/ocserv
	rm -rf /tmp/ocserv.log
	rm -f /usr/local/bin/occtl
	rm -f /usr/local/bin/ocpasswd
	rm -f /usr/local/bin/ocserv-fw
	rm -f /usr/local/sbin/ocserv
	rm -f /usr/local/share/man/man8/ocserv.8
	rm -f /usr/local/share/man/man8/ocpasswd.8
	rm -f /usr/local/share/man/man8/occtl.8
	
	rm -f /etc/sysctl.d/99-vpn-optimize.conf
	rm -f /etc/network/if-pre-up.d/iptables
	sysctl --system >/dev/null 2>&1
	
	echo && echo "安装过程错误，已回滚并完全清理残留 !" && echo
	exit 1
}
Add_iptables(){
	iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${set_tcp_port} -j ACCEPT
	iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${set_udp_port} -j ACCEPT
}
Del_iptables(){
	iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${tcp_port} -j ACCEPT 2>/dev/null
	iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${udp_port} -j ACCEPT 2>/dev/null
}
Save_iptables(){
	iptables-save > /etc/iptables.up.rules
}
Set_iptables(){
	# 系统网络极限优化与 BBR 拥塞控制
	echo -e "${Info} 正在写入内核网络极致优化参数..."
	mkdir -p /etc/sysctl.d
	cat > /etc/sysctl.d/99-vpn-optimize.conf << EOF
# ==== VPN Network Optimization ====
net.ipv4.ip_forward = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_rmem = 16384 262144 8388608
net.ipv4.tcp_wmem = 32768 524288 16777216
net.core.somaxconn = 8192
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.wmem_default = 2097152
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_max_syn_backlog = 10240
net.core.netdev_max_backlog = 10240
net.ipv4.tcp_slow_start_after_idle = 0
# ==================================
EOF
	sysctl --system >/dev/null 2>&1
	# 使用 ip route 自动获取默认出口网卡，兼容所有云服务器
	Network_card=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
	if [[ -z "${Network_card}" ]]; then
		echo -e "${Error} 无法自动识别网卡，请手动输入网卡名:"
		ip link show
		read -e -p "网卡名 (如 eth0 / ens3 / ens4 / enp1s0):" Network_card
		[[ -z "${Network_card}" ]] && echo "取消..." && exit 1
	else
		echo -e "${Info} 自动识别到出口网卡: ${Green_font_prefix}${Network_card}${Font_color_suffix}"
	fi
	iptables -t nat -A POSTROUTING -o ${Network_card} -j MASQUERADE
	iptables-save > /etc/iptables.up.rules
	mkdir -p /etc/network/if-pre-up.d
	printf '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules\n' > /etc/network/if-pre-up.d/iptables
	chmod +x /etc/network/if-pre-up.d/iptables
}
Update_Shell(){
	sh_new_ver=$(wget --no-check-certificate -qO- -t1 -T3 "https://raw.githubusercontent.com/lgdglgc/ocserv/master/ocserv.sh?t=$(date +%s)"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1)
	[[ -z ${sh_new_ver} ]] && echo -e "${Error} 无法链接到 Github !" && exit 0
	if [[ "${sh_new_ver}" == "${sh_ver}" ]]; then
		echo -e "${Info} 当前已是最新版本 [v${sh_ver}]，无需更新。" && exit 0
	fi
	echo -e "${Info} 发现新版本 [v${sh_new_ver}]，当前版本 [v${sh_ver}]，开始更新..."
	if [[ -e "/etc/init.d/ocserv" ]]; then
		rm -rf /etc/init.d/ocserv
		Service_ocserv
	fi
	wget -O ocserv.sh --no-check-certificate "https://raw.githubusercontent.com/lgdglgc/ocserv/master/ocserv.sh?t=$(date +%s)" && chmod +x ocserv.sh
	echo -e "脚本已更新为最新版本 [v${sh_new_ver}]！" && exit 0
}
check_sys
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && echo -e "${Error} 本脚本不支持当前系统 ${release} !" && exit 1
echo && echo -e " ocserv 一键安装管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  -- Update by SheepKeeperS --
  
 ${Green_font_prefix}0.${Font_color_suffix} 升级脚本
————————————
 ${Green_font_prefix}1.${Font_color_suffix} 安装 ocserv
 ${Green_font_prefix}2.${Font_color_suffix} 卸载 ocserv
————————————
 ${Green_font_prefix}3.${Font_color_suffix} 启动 ocserv
 ${Green_font_prefix}4.${Font_color_suffix} 停止 ocserv
 ${Green_font_prefix}5.${Font_color_suffix} 重启 ocserv
————————————
 ${Green_font_prefix}6.${Font_color_suffix} 设置 账号配置
 ${Green_font_prefix}7.${Font_color_suffix} 查看 配置信息
 ${Green_font_prefix}8.${Font_color_suffix} 修改 配置文件
 ${Green_font_prefix}9.${Font_color_suffix} 查看 日志信息
————————————" && echo
if [[ -e ${file} ]]; then
	check_pid
	if [[ ! -z "${PID}" ]]; then
		echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
	else
		echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
	fi
else
	echo -e " 当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
fi
echo
read -e -p " 请输入数字 [0-9]:" num
case "$num" in
	0)
	Update_Shell
	;;
	1)
	Install_ocserv
	;;
	2)
	Uninstall_ocserv
	;;
	3)
	Start_ocserv
	;;
	4)
	Stop_ocserv
	;;
	5)
	Restart_ocserv
	;;
	6)
	Set_Pass
	;;
	7)
	View_Config
	;;
	8)
	Set_ocserv
	;;
	9)
	View_Log
	;;
	*)
	echo "请输入正确数字 [0-9]"
	;;
esac 
