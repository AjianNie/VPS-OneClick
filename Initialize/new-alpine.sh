#!/bin/sh
LOG_FILE="/var/log/vps_setup.log"
TCP_PORTS="${TCP_PORTS:-}"    # 支持外部传入变量，默认空
UDP_INPUT="${UDP_INPUT:-}"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_command() {
    if [ $? -eq 0 ]; then
        log_message "SUCCESS: $1"
    else
        log_message "FAILED: $1"
        echo "错误：$1 失败。请检查日志文件 $LOG_FILE 或手动解决问题。"
    fi
}

is_installed() {
    apk info -e "$1" >/dev/null 2>&1
    return $?
}

# 安装 iptables
if ! is_installed "iptables"; then
    log_message "iptables 未安装，正在安装..."
    sudo apk add iptables | tee -a "$LOG_FILE"
    check_command "install iptables"
fi

log_message "清空现有 iptables 规则..."
sudo iptables -F
check_command "flush iptables rules"

log_message "设置默认策略为拒绝所有传入..."
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 如果没有预先设置 TCP_PORTS，则执行交互输入
if [ -z "$TCP_PORTS" ]; then
    echo "请在下面输入要开放的 TCP 端口(例如：22 80 443)，留空则不开放:"
    read -r TCP_PORTS
fi

# 如果没有预先设置 UDP_INPUT，则执行交互输入
if [ -z "$UDP_INPUT" ]; then
    echo "请在下面输入要开放的 UDP 端口，输入 '00' 表示等同于 TCP 端口，输入 'no' 表示不开放:"
    read -r UDP_INPUT
fi

if [ "$UDP_INPUT" = "00" ]; then
    UDP_PORTS="$TCP_PORTS"
elif [ "$UDP_INPUT" = "no" ] || [ -z "$UDP_INPUT" ]; then
    UDP_PORTS=""
else
    UDP_PORTS="$UDP_INPUT"
fi

# 开放 TCP 端口
if [ -n "$TCP_PORTS" ]; then
    for port in $TCP_PORTS; do
        log_message "允许 TCP 端口 $port ..."
        sudo iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
    done
else
    log_message "未输入 TCP 端口，跳过 TCP 端口开放。"
fi

# 开放 UDP 端口
if [ -n "$UDP_PORTS" ]; then
    for port in $UDP_PORTS; do
        log_message "允许 UDP 端口 $port ..."
        sudo iptables -A INPUT -p udp --dport "$port" -j ACCEPT
    done
else
    log_message "不开放任何 UDP 端口。"
fi

log_message "保存 iptables 规则..."
# 确保目录存在
sudo mkdir -p /etc/iptables/
sudo iptables-save | sudo tee /etc/iptables/rules-save

check_command "save iptables rules"

echo "防火墙配置完成。"
