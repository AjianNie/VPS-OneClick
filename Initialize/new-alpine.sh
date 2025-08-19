#!/bin/sh

# --- 变量定义 ---
LOG_FILE="/var/log/vps_setup.log"
NON_ROOT_USER=""
NON_ROOT_PASSWORD=""
TCP_PORTS=""
UDP_PORTS=""
DEFAULT_TIMEZONE="Asia/Shanghai"

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

# --- 脚本开始 ---
log_message "--- VPS 基础配置脚本开始 ---"
echo "所有操作将记录在 $LOG_FILE。"
echo "请注意：本脚本尽量避免断开终端连接，但某些操作仍有风险，建议在 VNC 控制台运行。"
echo ""

# 1. 更新系统
echo "--- [1/6] 更新软件包索引并升级系统 ---"
log_message "apk update..."
sudo apk update | tee -a "$LOG_FILE"
check_command "apk update"

log_message "apk upgrade..."
sudo apk upgrade | tee -a "$LOG_FILE"
check_command "apk upgrade"

echo "系统更新完成。"
echo ""

# 2. 安装并配置防火墙 (使用 iptables 简单配置)
echo "--- [2/6] 配置基础防火墙（iptables）---"

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

# 允许回环接口通信和已建立连接
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

read -p "请输入需要开放的 TCP 端口 (多个端口用空格隔开，例如：22 80 443)：" TCP_INPUT
TCP_PORTS="$TCP_INPUT"

read -p "请输入需要开放的 UDP 端口 (多个端口用空格隔开，输入 '00' 则使用与 TCP 相同端口，输入 'no' 则不开放任何 UDP 端口)：" UDP_INPUT

if [ "$UDP_INPUT" = "00" ]; then
    UDP_PORTS="$TCP_PORTS"
elif [ "$UDP_INPUT" = "no" ]; then
    UDP_PORTS=""
else
    UDP_PORTS="$UDP_INPUT"
fi

# 开放 TCP 端口
if [ -n "$TCP_PORTS" ]; then
    for port in $TCP_PORTS; do
        log_message "允许 TCP 端口 $port"
        sudo iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
    done
else
    log_message "未输入 TCP 端口，未开放任何 TCP 端口"
fi

# 开放 UDP 端口
if [ -n "$UDP_PORTS" ]; then
    for port in $UDP_PORTS; do
        log_message "允许 UDP 端口 $port"
        sudo iptables -A INPUT -p udp --dport "$port" -j ACCEPT
    done
else
    log_message "未输入 UDP 端口，未开放任何 UDP 端口"
fi

log_message "保存 iptables 规则..."
if [ -x /etc/init.d/iptables ]; then
    sudo /etc/init.d/iptables save
    check_command "save iptables rules"
else
    log_message "警告：未检测到 iptables 保存脚本，规则不会开机自动恢复。"
fi

echo "防火墙配置完成。"
echo ""

# 3. 安装常用工具
echo "--- [3/6] 安装常用工具和实用程序 ---"
echo "htop, curl, wget, git, unzip, zip, fail2ban"
read -p "是否安装常用工具和实用程序？(y/n): " install_common_tools
if echo "$install_common_tools" | grep -iq '^y'; then
    COMMON_TOOLS="htop curl wget git unzip zip fail2ban"
    for tool in $COMMON_TOOLS; do
        if is_installed "$tool"; then
            log_message "$tool 已安装，跳过。"
        else
            log_message "安装 $tool..."
            sudo apk add "$tool" | tee -a "$LOG_FILE"
            check_command "install $tool"
        fi
    done
    echo "常用工具安装完成。"
else
    echo "跳过安装常用工具。"
fi
echo ""

# 4. 配置时区和时间同步
echo "--- [4/6] 配置时区和时间同步 ---"
log_message "配置时区为 $DEFAULT_TIMEZONE ..."
sudo apk add tzdata | tee -a "$LOG_FILE"
check_command "install tzdata"

sudo cp /usr/share/zoneinfo/$DEFAULT_TIMEZONE /etc/localtime
check_command "set timezone"

sudo rc-update add ntpd default
sudo service ntpd start
check_command "start ntpd"

log_message "当前时间状态："
date | tee -a "$LOG_FILE"
echo "时区和时间同步配置完成。"
echo ""

# 5. 配置 SWAP
echo "--- [5/6] 配置 SWAP (交换空间) ---"
read -p "是否配置 SWAP 交换空间？(y/n，小内存 VPS 推荐 y)：" CONFIGURE_SWAP
if echo "$CONFIGURE_SWAP" | grep -iq '^y'; then
    if grep -q "/swapfile" /etc/fstab 2>/dev/null; then
        log_message "SWAP 已配置，跳过。"
        free -h | tee -a "$LOG_FILE"
    else
        read -p "请输入 SWAP 大小 (例如：2G，默认 2G)：" SWAP_SIZE
        SWAP_SIZE=${SWAP_SIZE:-2G}
        log_message "创建 $SWAP_SIZE 的 SWAP 文件..."
        sudo fallocate -l "$SWAP_SIZE" /swapfile
        check_command "fallocate swapfile"
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        check_command "配置 swapfile"
        sudo sysctl vm.swappiness=10 vm.vfs_cache_pressure=50
        echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
        echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
        free -h | tee -a "$LOG_FILE"
        echo "SWAP 配置完成。"
    fi
else
    log_message "跳过 SWAP 配置。"
fi
echo ""

# 6. SSH 安全加固
echo "--- [6/6] SSH 安全加固 ---"

if ! is_installed "openssh"; then
    log_message "安装 openssh..."
    sudo apk add openssh | tee -a "$LOG_FILE"
    check_command "install openssh"
fi

if ! pgrep sshd > /dev/null; then
    log_message "启用并启动 sshd 服务..."
    sudo rc-update add sshd
    sudo service sshd start
    check_command "start sshd"
fi

read -p "是否创建非 Root 用户并禁用 Root 登录？(y/n，强烈推荐 y)：" CREATE_USER_AND_DISABLE_ROOT
if echo "$CREATE_USER_AND_DISABLE_ROOT" | grep -iq '^y'; then
    read -p "请输入非 Root 用户名和密码 (例如: youruser yourpassword): " USER_INPUT
    NON_ROOT_USER=$(echo "$USER_INPUT" | awk '{print $1}')
    NON_ROOT_PASSWORD=$(echo "$USER_INPUT" | awk '{print $2}')

    if [ -z "$NON_ROOT_USER" ] || [ -z "$NON_ROOT_PASSWORD" ]; then
        log_message "用户名或密码为空，跳过用户创建。"
        echo "用户名或密码为空，无法创建用户。"
    else
        if id "$NON_ROOT_USER" >/dev/null 2>&1; then
            log_message "用户 $NON_ROOT_USER 已存在。"
            echo "用户 $NON_ROOT_USER 已存在。"
        else
            log_message "创建用户 $NON_ROOT_USER..."
            sudo adduser -D -s /bin/sh "$NON_ROOT_USER"
            echo "$NON_ROOT_USER:$NON_ROOT_PASSWORD" | sudo chpasswd
            check_command "create user $NON_ROOT_USER"
        fi
        log_message "添加 $NON_ROOT_USER 到 wheel 组..."
        sudo addgroup "$NON_ROOT_USER" wheel
        # 允许wheel组 sudo 权限
        if ! is_installed "sudo"; then
            sudo apk add sudo | tee -a "$LOG_FILE"
            check_command "install sudo"
        fi
        sudo sed -i '/^# %wheel ALL=(ALL) ALL/s/^# //' /etc/sudoers
        echo "用户 $NON_ROOT_USER 创建并配置完成，请牢记密码。"
        echo ""

        log_message "禁用 root SSH 登录..."
        sudo sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        sudo sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
        check_command "禁用 root SSH 登录"

        echo "警告：重启 sshd 可能导致连接中断，建议通过控制台操作。"
        read -p "是否立即重启 sshd 服务？(y/n): " RESTART_SSH_FINAL
        if echo "$RESTART_SSH_FINAL" | grep -iq '^y'; then
            sudo service sshd restart
            check_command "restart sshd"
            echo "sshd 服务已重启，root 用户 SSH 登录已禁用。"
        else
            echo "sshd 未重启，配置将在下次启动时生效。"
        fi
    fi
else
    log_message "不创建非 Root 用户，保持 root 登录。"
fi

echo ""
log_message "--- VPS 基础配置脚本执行完毕 ---"
