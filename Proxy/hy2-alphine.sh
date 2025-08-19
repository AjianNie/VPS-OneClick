#!/bin/bash

# 来源: https://github.com/zrlhk/alpine-hysteria2

apk add wget curl git openssh openssl openrc

generate_random_password() {
  dd if=/dev/random bs=18 count=1 status=none | base64
}

# 用户输入端口
while true; do
  read -p "请输入监听端口(1024-65535): " PORT
  if [[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1024 ] && [ "$PORT" -le 65535 ]; then
    break
  else
    echo "端口号无效，请输入范围在1024到65535之间的数字。"
  fi
done

GENPASS="$(generate_random_password)"

echo_hysteria_config_yaml() {
  cat << EOF
listen: :$PORT

#有域名，使用CA证书
#acme:
#  domains:
#    - test.heybro.bid #你的域名，需要先解析到服务器ip
#  email: xxx@gmail.com

#使用自签名证书
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: $GENPASS

masquerade:
  type: proxy
  proxy:
    url: https://bing.com/
    rewriteHost: true
EOF
}

echo_hysteria_autoStart(){
  cat << EOF
#!/sbin/openrc-run

name="hysteria"

command="/usr/local/bin/hysteria"
command_args="server --config /etc/hysteria/config.yaml"

pidfile="/var/run/\${name}.pid"

command_background="yes"

depend() {
        need networking
}
EOF
}

wget -O /usr/local/bin/hysteria https://download.hysteria.network/app/latest/hysteria-linux-amd64 --no-check-certificate
chmod +x /usr/local/bin/hysteria

mkdir -p /etc/hysteria/

openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=bing.com" -days 36500

# 写配置文件
echo_hysteria_config_yaml > "/etc/hysteria/config.yaml"

# 写自启动脚本
echo_hysteria_autoStart > "/etc/init.d/hysteria"
chmod +x /etc/init.d/hysteria

rc-update add hysteria

service hysteria start

echo "------------------------------------------------------------------------"
echo "hysteria2已经安装完成"
echo "监听端口： $PORT"
echo "密码为： $GENPASS"
echo "工具中配置：tls，SNI为： bing.com"
echo "配置文件路径：/etc/hysteria/config.yaml"
echo "已配置为开机自启"
echo "查看服务状态: service hysteria status"
echo "重启服务: service hysteria restart"
echo "----------------- 配置文件内容 -----------------"
cat /etc/hysteria/config.yaml
echo "------------------------------------------------------------------------"
