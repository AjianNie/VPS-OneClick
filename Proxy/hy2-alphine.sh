#!/bin/bash

# ==================================================================
# 脚本将在 BASH 环境下执行。
# 请确保通过以下方式运行，以使用正确的解释器：
# 1. chmod +x hy2-alphine.sh
# 2. ./hy2-alphine.sh
# ==================================================================

# hy2一键脚本 for Alpine Linux, 改编自: https://github.com/seagullz4/hysteria2

# 检测当前用户是否为 root 用户
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 用户执行此脚本！"
  exit 1
fi

random_color() {
  colors=("31" "32" "33" "34" "35" "36")
  echo -e "\e[${colors[$((RANDOM % ${#colors[@]}))]}m$1\e[0m"
}

# Alpine Linux 所需的命令和依赖包
packages=("bash" "wget" "sed" "openssl" "net-tools" "psmisc" "procps-ng" "iptables" "iproute2" "curl" "libcap" "ufw")

# 安装缺失的依赖
install_missing_commands() {
  echo "正在检查并安装依赖..."
  apk update > /dev/null 2>&1
  for pkg in "${packages[@]}"; do
    if ! apk info -e "$pkg" >/dev/null 2>&1; then
      echo "正在安装 $pkg..."
      apk add --no-cache "$pkg"
    fi
  done
}

set_architecture() {
  case "$(uname -m)" in
    'i386' | 'i686') arch='386' ;;
    'amd64' | 'x86_64') arch='amd64' ;;
    'armv5tel' | 'armv6l' | 'armv7' | 'armv7l') arch='arm' ;;
    'armv8' | 'aarch64') arch='arm64' ;;
    'mips' | 'mipsle' | 'mips64' | 'mips64le') arch='mipsle' ;;
    's390x') arch='s390x' ;;
    *)
      echo "暂时不支持你的系统哦，可能是因为不在已知架构范围内。"
      exit 1
      ;;
  esac
}

get_installed_version() {
    if [ -x "/root/hy3/hysteria-linux-$arch" ]; then
        version="$("/root/hy3/hysteria-linux-$arch" version 2>/dev/null | grep Version | grep -o 'v[0-9.]*')"
    else
        version="你还没有安装"
    fi
}

checkact() {
  pid=$(pgrep -f "hysteria-linux-$arch server")
  if [ -n "$pid" ]; then
    hy2zt="运行中"
  else
    hy2zt="未运行"
  fi
}

# 新增：检查UFW状态
check_ufw() {
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        UFW_ACTIVE=true
        echo "$(random_color '检测到 UFW 防火墙正在运行，将自动配置规则。')"
    else
        UFW_ACTIVE=false
    fi
}

welcome() {
echo -e "$(random_color '
░██  ░██                                                              
░██  ░██       ░████        ░█         ░█        ░█░█░█  
░██  ░██     ░█      █      ░█         ░█        ░█    ░█ 
░██████     ░██████         ░█         ░█        ░█    ░█ 
░██  ░██     ░█             ░█ ░█      ░█  ░█     ░█░█░█ 
░██  ░██      ░██  █         ░█         ░█                   ')"
}

# 主程序开始
echo -e "$(random_color '安装必要依赖中......')"
sleep 1
install_missing_commands > /dev/null 2>&1
echo -e "$(random_color '依赖安装完成')"

set_architecture
get_installed_version
checkact
check_ufw # 检查UFW状态
welcome

#这些就行提示你输入的😇
echo "$(random_color '选择一个操作:')"
echo "1. 安装HY2"
echo "2. 卸载HY2"
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "3. 查看配置"
echo "4. 退出脚本"
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "5. 在线更新hy2内核(您当前的hy2版本:$version)"
echo "$(random_color 'hy2究极版本v24.01.01')"
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "hysteria2状态: $hy2zt"

read -p "输入操作编号 (1/2/3/4/5): " choice

case $choice in
   1)
     #啥也没有
     ;;

   2)
uninstall_hysteria() {
  echo "正在停止并移除 Hysteria 服务..."
  if [ -f "/etc/init.d/hysteria" ]; then
    service hysteria stop >/dev/null 2>&1
    rc-update del hysteria default >/dev/null 2>&1
    rm -f "/etc/init.d/hysteria"
  fi

  echo "正在停止并移除端口跳跃服务..."
  if [ -f "/etc/init.d/ipppp" ]; then
    service ipppp stop >/dev/null 2>&1
    rc-update del ipppp default >/dev/null 2>&1
    rm -f "/etc/init.d/ipppp"
  fi

  echo "正在杀死相关进程..."
  pkill -f "hysteria-linux-$arch"

  # 新增：清理UFW规则
  if [ "$UFW_ACTIVE" = true ] && [ -f "/root/hy3/ufw_rules.log" ]; then
      echo "正在清理 UFW 防火墙规则..."
      while read -r rule; do
          ufw delete $rule >/dev/null 2>&1
      done < "/root/hy3/ufw_rules.log"
      echo "UFW 规则已清理。"
  fi

  echo "正在删除文件..."
  if [ -d "/root/hy3" ]; then
    rm -rf /root/hy3
  fi

  echo "正在清理 iptables 规则..."
  iptables -t nat -F PREROUTING
  ip6tables -t nat -F PREROUTING
  
  echo "$(random_color '卸载完成')"
}

uninstall_hysteria
exit
     ;;

   4)
     exit
     ;;
   3)
echo "$(random_color '下面是你的nekobox节点信息')" 
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
if [ -f "/root/hy3/neko.txt" ]; then cat /root/hy3/neko.txt; else echo "配置文件不存在。"; fi
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "$(random_color '下面是你的clashmate配置')"
if [ -f "/root/hy3/clash-mate.yaml" ]; then cat /root/hy3/clash-mate.yaml; else echo "配置文件不存在。"; fi
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
    exit
    ;;
    
   5)
updatehy2 () {
  echo "正在停止 Hysteria 服务..."
  service hysteria stop
  echo "正在下载最新内核..."
  cd /root/hy3
  rm -f hysteria-linux-$arch
  if wget -O hysteria-linux-$arch https://download.hysteria.network/app/latest/hysteria-linux-$arch; then
    chmod +x hysteria-linux-$arch
  else
    if wget -O hysteria-linux-$arch https://github.com/apernet/hysteria/releases/download/app/v2.2.2/hysteria-linux-$arch; then
      chmod +x hysteria-linux-$arch
    else
      echo "无法从任何网站下载文件"
      exit 1
    fi
  fi
  echo "正在重启 Hysteria 服务..."
  service hysteria start
  echo "更新完成"
}
echo "$(random_color '更新中...')"
sleep 1
updatehy2
echo "$(random_color '更新完成')"
    exit
    ;;
   *)
     echo "$(random_color '无效的选择，退出脚本。')"
     exit
     ;;
esac

echo "$(random_color '等待中...')"
sleep 1

if [ "$hy2zt" = "运行中" ]; then
  echo "Hysteria 正在运行，请先卸载再安装。"
  exit 1
else
  echo "HY2启动"
fi

installhy2 () {
cd /root
mkdir -p ~/hy3
cd ~/hy3
if wget -O hysteria-linux-$arch https://download.hysteria.network/app/latest/hysteria-linux-$arch; then
  chmod +x hysteria-linux-$arch
else
  if wget -O hysteria-linux-$arch https://github.com/apernet/hysteria/releases/download/app/v2.2.2/hysteria-linux-$arch; then
    chmod +x hysteria-linux-$arch
  else
    echo "无法从任何网站下载文件"
    exit 1
  fi
fi
}
echo "$(random_color '下载中...')"
sleep 1
installhy2 > /dev/null 2>&1

cat <<EOL > config.yaml
listen: :443
auth:
  type: password
  password: Se7RAuFZ8Lzg
masquerade:
  type: proxy
  proxy:
    url: https://news.ycombinator.com/
    rewriteHost: true 
bandwidth:
  up: 99 gbps
  down: 99 gbps
udpIdleTimeout: 90s
ignoreClientBandwidth: false
quic:
  initStreamReceiveWindow: 8388608 
  maxStreamReceiveWindow: 8388608 
  initConnReceiveWindow: 20971520 
  maxConnReceiveWindow: 20971520 
  maxIdleTimeout: 90s 
  maxIncomingStreams: 1800 
  disablePathMTUDiscovery: false 
EOL

while true; do 
    read -p "$(random_color '请输入端口号（留空默认443，输入0随机2000-60000）: ')" port 
    if [ -z "$port" ]; then port=443; fi
    if [ "$port" -eq 0 ]; then port=$((RANDOM % 58001 + 2000)); fi
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then 
      echo "$(random_color '请输入一个 1-65535 之间的数字。')" 
      continue 
    fi 
    if netstat -tuln | grep -q ":$port "; then 
      echo "$(random_color "端口 $port 已被占用，请重新输入。")" 
      continue
    fi
    sed -i "s/:443/:$port/" config.yaml
    echo "$(random_color '端口号已设置为：')" "$port" 
    break
done

# 新增：UFW放行主端口
if [ "$UFW_ACTIVE" = true ]; then
    echo "allow $port/udp" >> /root/hy3/ufw_rules.log
    ufw allow "$port/udp"
fi

generate_certificate() {
    read -p "请输入要用于自签名证书的域名（默认为 bing.com）: " user_domain
    domain_name=${user_domain:-"bing.com"}
    if curl --output /dev/null --silent --head --fail "https://$domain_name"; then
        mkdir -p /etc/ssl/private
        openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout "/etc/ssl/private/$domain_name.key" -out "/etc/ssl/private/$domain_name.crt" -subj "/CN=$domain_name" -days 36500
        chmod 600 "/etc/ssl/private/$domain_name.key" "/etc/ssl/private/$domain_name.crt"
        echo -e "自签名证书和私钥已生成！"
    else
        echo -e "无效的域名或域名不可用，请输入有效的域名！"
        generate_certificate
    fi
}

read -p "请选择证书类型（1. ACME证书 | 2. 自签名证书。回车默认ACME）: " cert_choice

if [[ "$cert_choice" == "2" ]]; then
    generate_certificate
    certificate_path="/etc/ssl/private/$domain_name.crt"
    private_key_path="/etc/ssl/private/$domain_name.key"
    echo -e "证书文件已保存到 $certificate_path"
    echo -e "私钥文件已保存到 $private_key_path"
    sed -i "/listen: :$port/a \
tls:\n  cert: $certificate_path\n  key: $private_key_path" /root/hy3/config.yaml
    touch /root/hy3/ca
    ovokk="insecure=1&"
    choice1="true"
    echo -e "已将证书和密钥信息写入 /root/hy3/config.yaml 文件。"
    get_ipv4_info() {
      ip_address=$(wget -4 -qO- --no-check-certificate http://ip-api.com/json/)
      ispck=$(echo "$ip_address" | sed -n 's/.*"isp"[ ]*:[ ]*"\([^"]*\).*/\1/p')
      if echo "$ispck" | grep -qi "cloudflare"; then
        read -p "检测到Warp，请输入正确的服务器 IP：" ipwan
      else
        ipwan=$(echo "$ip_address" | sed -n 's/.*"query"[ ]*:[ ]*"\([^"]*\).*/\1/p')
      fi
    }
    get_ipv6_info() {
      ip_address=$(wget -6 -qO- --no-check-certificate https://api.ip.sb/geoip)
      ispck=$(echo "$ip_address" | sed -n 's/.*"isp"[ ]*:[ ]*"\([^"]*\).*/\1/p')
      if echo "$ispck" | grep -qi "cloudflare"; then
        read -p "检测到Warp，请输入正确的服务器 IP：" new_ip
        ipwan="[$new_ip]"
      else
        ipwan="[$(echo "$ip_address" | sed -n 's/.*"ip"[ ]*:[ ]*"\([^"]*\).*/\1/p')]"
      fi
    }
    while true; do
      read -p "请选择IP模式 (1. IPv4 | 2. IPv6, 回车默认IPv4): " ip_choice
      case $ip_choice in
        1|"") get_ipv4_info; ipta="iptables"; break ;;
        2) get_ipv6_info; ipta="ip6tables"; break ;;
        *) echo "输入无效。" ;;
      esac
    done
    echo "你的IP 地址为：$ipwan"
fi

if [ ! -f "/root/hy3/ca" ]; then
  read -p "$(random_color '请输入你的域名（必须是解析好的域名哦）: ')" domain
  while [ -z "$domain" ]; do read -p "$(random_color '域名不能为空，请重新输入: ')" domain; done
  read -p "$(random_color '请输入你的邮箱（默认随机邮箱）: ')" email
  if [ -z "$email" ]; then
    random_part=$(head /dev/urandom | LC_ALL=C tr -dc A-Za-z0-9 | head -c 4)
    email="${random_part}@gmail.com"
  fi
  sed -i "/listen: :$port/a \
acme:\n  domains:\n    - $domain\n  email: $email" config.yaml
  echo "$(random_color '域名和邮箱已添加到 config.yaml 文件。')"
  ipta="iptables"
  choice2="false"
fi

read -p "$(random_color '请输入你的密码（留空将生成随机密码）: ')" password
if [ -z "$password" ]; then password=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9'); fi
sed -i "s/Se7RAuFZ8Lzg/$password/" config.yaml
echo "$(random_color '密码已设置为：')" $password

read -p "$(random_color '请输入伪装网址（默认https://news.ycombinator.com/）: ')" masquerade_url
if [ -z "$masquerade_url" ]; then masquerade_url="https://news.ycombinator.com/"; fi
sed -i "s|https://news.ycombinator.com/|$masquerade_url|" config.yaml
echo "$(random_color '伪装域名已设置为：')" $masquerade_url

read -p "$(random_color '是否要开启端口跳跃功能？(1. 开启 | 回车默认不开启): ')" port_jump 
if [[ "$port_jump" == "1" ]]; then
    read -p "$(random_color '请选择跳跃端口模式 (1. 连续范围 | 2. 手动输入, 回车默认1): ')" hop_mode
    if [[ "$hop_mode" == "2" ]]; then
        while true; do
            read -p "$(random_color '请输入要跳跃的端口，用空格隔开: ')" manual_ports
            valid_ports=true
            if [ -z "$manual_ports" ]; then echo "$(random_color '输入不能为空。')"; valid_ports=false; else
                for p in $manual_ports; do
                    if ! [[ "$p" =~ ^[0-9]+$ ]] || [ "$p" -lt 1 ] || [ "$p" -gt 65535 ]; then
                        echo "$(random_color "错误: '$p' 不是有效端口。")"; valid_ports=false; break
                    fi
                done
            fi
            [ "$valid_ports" = true ] && break
        done
        comma_separated_ports=$(echo "$manual_ports" | tr ' ' ',')
        iptables_rule="$ipta -t nat -A PREROUTING -i eth0 -p udp -m multiport --dports $comma_separated_ports -j DNAT --to-destination :$port"
        hop_ports_for_link="$comma_separated_ports"
        # 新增：UFW放行手动端口
        if [ "$UFW_ACTIVE" = true ]; then
            for p in $manual_ports; do
                echo "allow $p/udp" >> /root/hy3/ufw_rules.log
                ufw allow "$p/udp"
            done
        fi
        echo "$(random_color '手动端口跳跃已开启。')"
    else
        while true; do
            read -p "$(random_color '请输入起始端口号: ')" start_port 
            read -p "$(random_color '请输入末尾端口号: ')" end_port 
            if [[ "$start_port" =~ ^[0-9]+$ ]] && [[ "$end_port" =~ ^[0-9]+$ ]] && [ "$start_port" -lt "$end_port" ]; then break; else 
                echo "$(random_color '输入无效，起始需小于末尾。')"
            fi
        done
        iptables_rule="$ipta -t nat -A PREROUTING -i eth0 -p udp --dport $start_port:$end_port -j DNAT --to-destination :$port"
        hop_ports_for_link="$start_port-$end_port"
        # 新增：UFW放行连续端口
        if [ "$UFW_ACTIVE" = true ]; then
            echo "allow $start_port:$end_port/udp" >> /root/hy3/ufw_rules.log
            ufw allow "$start_port:$end_port/udp"
        fi
        echo "$(random_color '连续端口跳跃已开启。')"
    fi
    eval "$iptables_rule"
    echo "#!/sbin/openrc-run" > /etc/init.d/ipppp
    echo "name=\"Hysteria Port Jumping\"" >> /etc/init.d/ipppp
    echo 'depend() { need net; after firewall; }' >> /etc/init.d/ipppp
    echo "command_args=\"$iptables_rule\"" >> /etc/init.d/ipppp
    echo 'start() { ebegin "Applying Hysteria port jumping rules"; eval $command_args; eend $?; }' >> /etc/init.d/ipppp
    echo "stop() { ebegin \"Flushing NAT table\"; /sbin/$ipta -t nat -F PREROUTING; eend 0; }" >> /etc/init.d/ipppp
    chmod +x /etc/init.d/ipppp
    rc-update add ipppp default
    service ipppp start
    echo "$(random_color '已创建端口跳跃服务并设置开机自启动。')"
fi

fuser -k -n tcp "$port" >/dev/null 2>&1
fuser -k -n udp "$port" >/dev/null 2>&1
if setcap cap_net_bind_service=+ep /root/hy3/hysteria-linux-$arch; then
  echo "$(random_color '授予权限成功。')"
else
  echo "$(random_color '授予权限失败，退出脚本。')"; exit 1
fi
sysctl -w net.core.rmem_max=26214400 >/dev/null 2>&1
sysctl -w net.core.wmem_max=26214400 >/dev/null 2>&1

cat <<EOL > clash-mate.yaml
proxies:
  - name: Hysteria2
    type: hysteria2
    server: ${domain:-$ipwan}
    port: $port
    password: $password
    sni: ${domain:-$domain_name}
    skip-cert-verify: ${choice1:-$choice2}
proxy-groups:
  - name: auto
    type: select
    proxies:
      - Hysteria2
rules:
  - MATCH,auto
EOL
echo "$(random_color 'clash-mate.yaml 已保存到当前文件夹')"

cat > /etc/init.d/hysteria << EOF
#!/sbin/openrc-run
name="hysteria"
command="/root/hy3/hysteria-linux-$arch"
command_args="server --config /root/hy3/config.yaml"
command_background="yes"
pidfile="/var/run/\${name}.pid"
directory="/root/hy3"
depend() { need net; after firewall; }
start() { ebegin "Starting \$name"; start-stop-daemon --start --quiet --background --make-pidfile --pidfile \$pidfile --chdir \$directory --exec \$command -- \$command_args; eend \$?; }
stop() { ebegin "Stopping \$name"; start-stop-daemon --stop --quiet --pidfile \$pidfile; eend \$?; }
EOF

chmod +x /etc/init.d/hysteria
rc-update add hysteria default
service hysteria start

echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "完成。"
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "$(random_color '这是你的clash配置:')"
cat /root/hy3/clash-mate.yaml

if [[ "$port_jump" == "1" ]]; then
  share_link="hysteria2://$password@${domain:-$ipwan}:$port/?${ovokk}mport=$port,$hop_ports_for_link&sni=${domain:-$domain_name}#Hysteria2"
else
  share_link="hysteria2://$password@${domain:-$ipwan}:$port/?${ovokk}sni=${domain:-$domain_name}#Hysteria2"
fi
echo -e "\n$(random_color '这是你的Hysteria2节点链接信息，请注意保存: ')\n$share_link"
echo "$share_link" > /root/hy3/neko.txt

echo -e "$(random_color '\nHysteria2安装成功')"
