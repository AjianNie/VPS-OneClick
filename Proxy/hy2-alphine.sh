#!/bin/bash

# hy2一键脚本 for Alpine Linux, 改编自: https://github.com/seagullz4/hysteria2

# 检测当前用户是否为 root 用户
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 用户执行此脚本！"
  exit 1
fi

random_color() {
  colors=("31" "32" "33" "34" "35" "36" "37")
  echo -e "\e[${colors[$((RANDOM % 7))]}m$1\e[0m"
}

# Alpine Linux 所需的命令和依赖包
commands=("wget" "sed" "openssl" "netstat" "fuser" "pgrep" "iptables" "ip")
packages=("bash" "wget" "sed" "openssl" "net-tools" "psmisc" "procps-ng" "iptables" "iproute2" "curl" "libcap")

# 安装缺失的依赖
install_missing_commands() {
  apk update
  for pkg in "${packages[@]}"; do
    if ! apk info -e "$pkg" >/dev/null 2>&1; then
      echo "Installing $pkg..."
      apk add --no-cache "$pkg"
      if [ $? -eq 0 ]; then
        echo "$pkg installed successfully."
      else
        echo "Failed to install $pkg."
      fi
    else
      echo "$pkg is already installed."
    fi
  done
}

set_architecture() {
  case "$(uname -m)" in
    'i386' | 'i686')
      arch='386'
      ;;
    'amd64' | 'x86_64')
      arch='amd64'
      ;;
    'armv5tel' | 'armv6l' | 'armv7' | 'armv7l')
      arch='arm'
      ;;
    'armv8' | 'aarch64')
      arch='arm64'
      ;;
    'mips' | 'mipsle' | 'mips64' | 'mips64le')
      arch='mipsle'
      ;;
    's390x')
      arch='s390x'
      ;;
    *)
      echo "暂时不支持你的系统哦，可能是因为不在已知架构范围内。"
      exit 1
      ;;
  esac
}

get_installed_version() {
    if [ -x "/root/hy3/hysteria-linux-$arch" ]; then
        version="$("/root/hy3/hysteria-linux-$arch" version | grep Version | grep -o 'v[.0-9]*')"
    else
        version="你还没有安装"
    fi
}

checkact() {
pid=$(pgrep -f "hysteria-linux-$arch")

if [ -n "$pid" ]; then
  hy2zt="运行中"
else
  hy2zt="未运行"
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

echo -e "$(random_color '安装必要依赖中......')"
sleep 1
install_missing_commands > /dev/null 2>&1
echo -e "$(random_color '依赖安装完成')"

set_architecture
get_installed_version
checkact
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
  # 停止并移除 Hysteria 服务
  if [ -f "/etc/init.d/hysteria" ]; then
    service hysteria stop
    rc-update del hysteria default
    rm "/etc/init.d/hysteria"
    echo "Hysteria 服务已移除。"
  else
    echo "Hysteria 服务文件不存在。"
  fi

  # 停止并移除端口跳跃服务
  if [ -f "/etc/init.d/ipppp" ]; then
    service ipppp stop
    rc-update del ipppp default
    rm "/etc/init.d/ipppp"
    echo "端口跳跃服务已移除。"
  fi

  # 杀死进程
  process_name="hysteria-linux-$arch"
  pid=$(pgrep -f "$process_name")
  if [ -n "$pid" ]; then
    echo "找到 $process_name 进程 (PID: $pid)，正在杀死..."
    kill "$pid"
    echo "$process_name 进程已被杀死。"
  else
    echo "未找到 $process_name 进程。"
  fi

  # 删除文件
  if [ -d "/root/hy3" ]; then
    rm -rf /root/hy3
    echo "Hysteria 配置目录 /root/hy3 已删除。"
  fi

  # 清理防火墙规则
  iptables -t nat -F PREROUTING
  echo "防火墙规则已清理。"
  echo "卸载完成"
}

echo -e "$(random_color '卸载中......')"
uninstall_hysteria > /dev/null 2>&1
sleep 1
echo -e "$(random_color '卸载完成')"
exit
     ;;

   4)
     # Exit script
     exit
     ;;
   3)
echo "$(random_color '下面是你的nekobox节点信息')" 
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"   
if [ -f "/root/hy3/neko.txt" ]; then
    cat /root/hy3/neko.txt
else
    echo "配置文件不存在。"
fi

echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "$(random_color '下面是你的clashmate配置')"

if [ -f "/root/hy3/clash-mate.yaml" ]; then
    cat /root/hy3/clash-mate.yaml
else
    echo "配置文件不存在。"
fi

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
updatehy2 > /dev/null 2>&1
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

# 就是写一个配置文件，你可以自己修改，别乱搞就行，安装hysteria2文档修改
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
    echo "$(random_color '请输入端口号（留空默认443，输入0随机2000-60000，你可以输入1-65630指定端口号）: ')" 
    read -p "" port 
  
    if [ -z "$port" ]; then 
      port=443 
    elif [ "$port" -eq 0 ]; then 
      port=$((RANDOM % 58001 + 2000)) 
    elif ! [[ "$port" =~ ^[0-9]+$ ]]; then 
      echo "$(random_color '请输入数字，请重新输入端口号：')" 
      continue 
    fi 
  
    while netstat -tuln | grep -q ":$port "; do 
      echo "$(random_color '端口已被占用，请重新输入端口号：')" 
      read -p "" port 
    done 
  
    if sed -i "s/:443/:$port/" config.yaml; then 
      echo "$(random_color '端口号已设置为：')" "$port" 
    else 
      echo "$(random_color '替换端口号失败，退出脚本。')" 
      exit 1 
    fi 
  

generate_certificate() {
    read -p "请输入要用于自签名证书的域名（默认为 bing.com）: " user_domain
    domain_name=${user_domain:-"bing.com"}
    if curl --output /dev/null --silent --head --fail "$domain_name"; then
        mkdir -p /etc/ssl/private
        openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout "/etc/ssl/private/$domain_name.key" -out "/etc/ssl/private/$domain_name.crt" -subj "/CN=$domain_name" -days 36500
        chmod 600 "/etc/ssl/private/$domain_name.key" "/etc/ssl/private/$domain_name.crt"
        echo -e "自签名证书和私钥已生成！"
    else
        echo -e "无效的域名或域名不可用，请输入有效的域名！"
        generate_certificate
    fi
}

read -p "请选择证书类型（输入 1 使用ACME证书,输入 2 使用自签名证书,回车默认acme证书申请,自签证书最简单）: " cert_choice

if [ "$cert_choice" == "2" ]; then
    generate_certificate

    certificate_path="/etc/ssl/private/$domain_name.crt"
    private_key_path="/etc/ssl/private/$domain_name.key"

    echo -e "证书文件已保存到 /etc/ssl/private/$domain_name.crt"
    echo -e "私钥文件已保存到 /etc/ssl/private/$domain_name.key"

    temp_file=$(mktemp)
    echo -e "temp_file: $temp_file"
    sed '3i\tls:\n  cert: '"/etc/ssl/private/$domain_name.crt"'\n  key: '"/etc/ssl/private/$domain_name.key"'' /root/hy3/config.yaml > "$temp_file"
    mv "$temp_file" /root/hy3/config.yaml
    touch /root/hy3/ca
   #这里加了一个小的变量
    ovokk="insecure=1&"
    choice1="true"
    echo -e "已将证书和密钥信息写入 /root/hy3/config.yaml 文件。"
    
get_ipv4_info() {
  ip_address=$(wget -4 -qO- --no-check-certificate --user-agent=Mozilla --tries=2 --timeout=3 http://ip-api.com/json/) &&
  
  ispck=$(echo "$ip_address" | sed -n 's/.*"isp"[ ]*:[ ]*"\([^"]*\).*/\1/p')

  if echo "$ispck" | grep -qi "cloudflare"; then
    echo "检测到Warp，请输入正确的服务器 IP："
    read new_ip
    ipwan="$new_ip"
  else
    ipwan="$(echo "$ip_address" | sed -n 's/.*"query"[ ]*:[ ]*"\([^"]*\).*/\1/p')"
  fi
}

get_ipv6_info() {
  ip_address=$(wget -6 -qO- --no-check-certificate --user-agent=Mozilla --tries=2 --timeout=3 https://api.ip.sb/geoip) &&
  
  ispck=$(echo "$ip_address" | sed -n 's/.*"isp"[ ]*:[ ]*"\([^"]*\).*/\1/p')

  if echo "$ispck" | grep -qi "cloudflare"; then
    echo "检测到Warp，请输入正确的服务器 IP："
    read new_ip
    ipwan="[$new_ip]"
  else
    ipwan="[$(echo "$ip_address" | sed -n 's/.*"ip"[ ]*:[ ]*"\([^"]*\).*/\1/p')]"
  fi
}

while true; do
  echo "1. IPv4 模式"
  echo "2. IPv6 模式"
  echo "按回车键选择默认的 IPv4 模式."

  read -p "请选择: " choice

  case $choice in
    1)
      get_ipv4_info
      echo "你的IP 地址为：$ipwan"
      ipta="iptables"
      break
      ;;
    2)
      get_ipv6_info
      echo "老登你的IP 地址为：$ipwan"
      ipta="ip6tables"
      break
      ;;
    "")
      echo "使用默认的 IPv4 模式。"
      get_ipv4_info
      echo "你的IP 地址为：$ipwan"
      ipta="iptables"
      break
      ;;
    *)
      echo "输入无效。请输入1或2，或者按回车键使用默认的 IPv4 模式。"
      ;;
  esac
done

fi

if [ -f "/root/hy3/ca" ]; then
  echo "$(random_color '/root/hy3/ 文件夹中已存在名为 ca 的文件。跳过添加操作。')"
else

  echo "$(random_color '请输入你的域名（必须是解析好的域名哦）: ')"
  read -p "" domain

  while [ -z "$domain" ]; do
    echo "$(random_color '域名不能为空，请重新输入: ')"
    read -p "" domain
  done


  echo "$(random_color '请输入你的邮箱（默认随机邮箱）: ')"
  read -p "" email

  if [ -z "$email" ]; then
    random_part=$(head /dev/urandom | LC_ALL=C tr -dc A-Za-z0-9 | head -c 4 ; echo '')
    email="${random_part}@gmail.com"
  fi

  yaml_content="acme:\n  domains:\n    - $domain\n  email: $email"

  if [ -f "config.yaml" ]; then
    echo -e "\nAppending to config.yaml..."
    # 使用 sed 在 listen: :port 之后插入 acme 配置
    sed -i "/listen: :$port/a\\$yaml_content" config.yaml
    echo "$(random_color '域名和邮箱已添加到 config.yaml 文件。')"
    ipta="iptables"
    choice2="false"
  else
    echo "$(random_color 'config.yaml 文件不存在，无法添加。')"
    exit 1
  fi
fi

echo "$(random_color '请输入你的密码（留空将生成随机密码，不超过20个字符）: ')"
read -p "" password

if [ -z "$password" ]; then
  password=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9')
fi

if sed -i "s/Se7RAuFZ8Lzg/$password/" config.yaml; then
  echo "$(random_color '密码已设置为：')" $password
else
  echo "$(random_color '替换密码失败，退出脚本。')"
  exit 1
fi

echo "$(random_color '请输入伪装网址（默认https://news.ycombinator.com/）: ')"
read -p "" masquerade_url

if [ -z "$masquerade_url" ]; then
  masquerade_url="https://news.ycombinator.com/"
fi

if sed -i "s|https://news.ycombinator.com/|$masquerade_url|" config.yaml; then
  echo "$(random_color '伪装域名已设置为：')" $masquerade_url
else
  echo "$(random_color '替换伪装域名失败，退出脚本。')"
  exit 1
fi
   
    echo "$(random_color '是否要开启端口跳跃功能？回车默认不开启，输入1开启: ')" 
    read -p "" port_jump 
  
    if [ -z "$port_jump" ]; then 
      break 
    elif [ "$port_jump" -eq 1 ]; then 
      echo "$(random_color '请输入起始端口号(起始端口必须小于末尾端口): ')" 
      read -p "" start_port 
  
      echo "$(random_color '请输入末尾端口号(末尾端口必须大于起始端口): ')" 
      read -p "" end_port 
  
      if [ "$start_port" -lt "$end_port" ]; then 
        "$ipta" -t nat -A PREROUTING -i eth0 -p udp --dport "$start_port":"$end_port" -j DNAT --to-destination :"$port" 
        echo "$(random_color '端口跳跃功能已开启，将范围重定向到主端口：')" "$port" 
        break 
      else 
        echo "$(random_color '末尾端口必须大于起始端口，请重新输入。')" 
      fi 
    else 
      echo "$(random_color '输入无效，请输入1开启端口跳跃功能，或直接按回车跳过。')" 
    fi 
done 


if [ -n "$port_jump" ] && [ "$port_jump" -eq 1 ]; then
  # 创建防火墙规则脚本
  echo "#!/bin/sh" > /root/hy3/ipppp.sh 
  echo "$ipta -t nat -A PREROUTING -i eth0 -p udp --dport $start_port:$end_port -j DNAT --to-destination :$port" >> /root/hy3/ipppp.sh 
  chmod +x /root/hy3/ipppp.sh 
  
  # 创建 OpenRC 服务文件
  cat > /etc/init.d/ipppp << EOF
#!/sbin/openrc-run
name="Hysteria Port Jumping"
command="/root/hy3/ipppp.sh"

depend() {
    need net
    after firewall
}

start() {
    ebegin "Applying Hysteria port jumping rules"
    \${command}
    eend \$?
}

stop() {
    ebegin "Flushing NAT table to remove port jumping rules"
    $ipta -t nat -F PREROUTING
    eend 0
}
EOF
  chmod +x /etc/init.d/ipppp
  rc-update add ipppp default
  service ipppp start
  echo "$(random_color '已创建端口跳跃服务并设置开机自启动。')"
fi

fuser -k -n tcp $port
fuser -k -n udp $port

if setcap cap_net_bind_service=+ep /root/hy3/hysteria-linux-$arch; then
  echo "$(random_color '授予权限成功。')"
else
  echo "$(random_color '授予权限失败，退出脚本。')"
  exit 1
fi

#优化一些系统参数
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216

cat <<EOL > clash-mate.yaml
system-port: 7890
external-controller: 127.0.0.1:9090
allow-lan: false
mode: rule
log-level: info
ipv6: true
unified-delay: true
profile:
  store-selected: true
  store-fake-ip: true
tun:
  enable: true
  stack: system
  auto-route: true
  auto-detect-interface: true
dns:
  enable: true
  prefer-h3: true
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  nameserver:
    - 223.5.5.5
    - 8.8.8.8
proxies:
  - name: Hysteria2
    type: hysteria2
    server: $domain$ipwan
    port: $port
    password: $password
    sni: $domain$domain_name
    skip-cert-verify: $choice1$choice2
proxy-groups:
  - name: auto
    type: select
    proxies:
      - Hysteria2
rules:
  - MATCH,auto
EOL
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "
clash-mate.yaml 已保存到当前文件夹
"
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"

# 创建 Hysteria 的 OpenRC 服务文件
cat > /etc/init.d/hysteria << EOF
#!/sbin/openrc-run
name="hysteria"
command="/root/hy3/hysteria-linux-$arch"
command_args="server --config /root/hy3/config.yaml"
command_background="yes"
pidfile="/var/run/\${name}.pid"
directory="/root/hy3"

depend() {
    need net
    after firewall
}

start() {
    ebegin "Starting \$name"
    start-stop-daemon --start --quiet --background \
        --make-pidfile --pidfile \$pidfile \
        --chdir \$directory \
        --exec \$command -- \$command_args
    eend \$?
}

stop() {
    ebegin "Stopping \$name"
    start-stop-daemon --stop --quiet --pidfile \$pidfile
    eend \$?
}
EOF

chmod +x /etc/init.d/hysteria
rc-update add hysteria default
service hysteria start

echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "
完成。
"
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"

echo "$(random_color '
这是你的clash配置:')"
cat /root/hy3/clash-mate.yaml

if [ -n "$start_port" ] && [ -n "$end_port" ]; then
  echo -e "$(random_color '这是你的Hysteria2节点链接信息，请注意保存: ')\nhysteria2://$password@$ipwan$domain:$port/?${ovokk}mport=$port,$start_port-$end_port&sni=$domain$domain_name#Hysteria2"
  echo "hysteria2://$password@$ipwan$domain:$port/?${ovokk}mport=$port,$start_port-$end_port&sni=$domain$domain_name#Hysteria2" > /root/hy3/neko.txt
else
  echo -e "$(random_color '这是你的Hysteria2节点链接信息，请注意保存: ')\nhysteria2://$password@$ipwan$domain:$port/?${ovokk}sni=$domain$domain_name#Hysteria2"
  echo "hysteria2://$password@$ipwan$domain:$port/?${ovokk}sni=$domain$domain_name#Hysteria2" > /root/hy3/neko.txt
fi

echo -e "$(random_color '

Hysteria2安装成功')"
