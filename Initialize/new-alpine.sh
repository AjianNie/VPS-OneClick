#!/bin/sh

# --- 变量定义 ---
LOG_FILE="/var/log/vps_setup.log"
NON_ROOT_USER=""
NON_ROOT_PASSWORD=""
TCP_PORTS=""
UDP_PORTS=""
DEFAULT_TIMEZONE="Asia/Shanghai" # 默认时区为Asia/Shanghai
IPTABLES_CMD="/usr/sbin/iptables"

# --- 函数定义 ---

# 记录日志
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 检查命令是否成功
check_command() {
    if [ $? -eq 0 ]; then
        log_message "SUCCESS: $1"
    else
        log_message "FAILED: $1"
        echo "错误：$1 失败。请检查日志文件 $LOG_FILE 或手动解决问题。"
        exit 1
    fi
}

# 检查软件包是否已安装 (Alpine中查看apk info安装包)
is_installed() {
    apk info | grep -qw "$1"
    return $?
}

# --- 脚本开始 ---
log_message "--- VPS 基础配置脚本开始 (Alpine Linux) ---"
echo "所有操作将记录在 $LOG_FILE。"
echo "请注意：本脚本尽量避免断开终端连接，推荐在控制台操作。"
echo ""

# 1. 更新系统
echo "--- [1/6] 更新软件包列表并升级系统 ---"
log_message "正在更新软件包索引..."
sudo apk update | tee -a "$LOG_FILE"
check_command "apk update"

log_message "升级系统软件包..."
sudo apk upgrade | tee -a "$LOG_FILE"
check_command "apk upgrade"

echo "系统更新完成。"
echo ""

# 2. 安装并配置防火墙 (iptables)
echo "--- [2/6] 安装并配置防火墙 (iptables) ---"

if is_installed "iptables" && is_installed "iptables-openrc"; then
    log_message "iptables 和 iptables-openrc 已安装。"
else
    log_message "iptables 或 iptables-openrc 未安装，正在安装..."
    sudo apk add iptables iptables-openrc | tee -a "$LOG_FILE"
    check_command "apk add iptables iptables-openrc"
fi

# 检查iptables命令是否存在
if [ ! -x "$IPTABLES_CMD" ]; then
    log_message "错误：$IPTABLES_CMD 命令未找到或不可执行，安装失败。脚本终止。"
    echo "错误：$IPTABLES_CMD 命令未找到或不可执行，安装失败。"
    exit 1
fi

log_message "启用 iptables 服务..."
sudo rc-update add iptables default

log_message "设置默认防火墙规则：默认拒绝所有传入，允许所有传出..."
sudo $IPTABLES_CMD -F
sudo $IPTABLES_CMD -X
sudo $IPTABLES_CMD -P INPUT DROP
sudo $IPTABLES_CMD -P FORWARD DROP
sudo $IPTABLES_CMD -P OUTPUT ACCEPT
sudo $IPTABLES_CMD -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo $IPTABLES_CMD -A INPUT -i lo -j ACCEPT
check_command "iptables 默认规则设置"

# 询问 TCP 端口
read -p "请输入需要开放的 TCP 端口 (多个端口用空格隔开，例如：22 80 443)：" TCP_PORTS
if [ -n "$TCP_PORTS" ]; then
    for port in $TCP_PORTS; do
        log_message "允许 TCP 端口 $port..."
        sudo $IPTABLES_CMD -A INPUT -p tcp --dport "$port" -j ACCEPT
        check_command "iptables 允许 tcp 端口 $port"
    done
else
    log_message "未输入 TCP 端口，跳过 TCP 端口开放。"
fi

# 询问 UDP 端口
read -p "请输入需要开放的 UDP 端口 (多个端口用空格隔开，输入 '00' 则使用与 TCP 相同的端口，输入 'no' 则不开放任何 UDP 端口)：" UDP_INPUT
if [ "$UDP_INPUT" = "00" ]; then
    UDP_PORTS="$TCP_PORTS"
    log_message "UDP 端口设置为与 TCP 端口相同：$UDP_PORTS"
elif [ "$UDP_INPUT" = "no" ]; then
    UDP_PORTS=""
    log_message "不开放任何 UDP 端口。"
else
    UDP_PORTS="$UDP_INPUT"
    log_message "UDP 端口设置为：$UDP_PORTS"
fi

if [ -n "$UDP_PORTS" ]; then
    for port in $UDP_PORTS; do
        log_message "允许 UDP 端口 $port..."
        sudo $IPTABLES_CMD -A INPUT -p udp --dport "$port" -j ACCEPT
        check_command "iptables 允许 udp 端口 $port"
    done
fi

log_message "保存防火墙规则..."
sudo /etc/init.d/iptables save
check_command "iptables 规则保存"

log_message "启动 iptables 服务..."
sudo rc-service iptables start
check_command "启动 iptables 服务"

echo "防火墙配置完成。"
echo ""

# 3. 安装常用工具和实用程序
echo "--- [3/6] 安装常用工具和实用程序 ---"
echo "htop (进程查看器); curl 和 wget (下载工具); git (版本控制); unzip 和 zip (解压压缩工具); fail2ban (防暴力破解)"
read -p "是否安装常用工具和实用程序？(y/n): " install_common_tools
if echo "$install_common_tools" | grep -iq "^y"; then
    COMMON_TOOLS="htop curl wget git unzip zip fail2ban"
    for tool in $COMMON_TOOLS; do
        if is_installed "$tool"; then
            log_message "$tool 已安装，跳过安装。"
        else
            log_message "正在安装 $tool..."
            sudo apk add "$tool" | tee -a "$LOG_FILE"
            check_command "安装 $tool"
        fi
    done
    echo "常用工具安装完成。"
else
    echo "跳过安装常用工具。"
fi
echo ""

# 4. 配置时区和时间同步
echo "--- [4/6] 配置时区和时间同步 ---"
log_message "设置时区为 $DEFAULT_TIMEZONE..."
sudo apk add tzdata | tee -a "$LOG_FILE"
check_command "安装 tzdata"
sudo cp "/usr/share/zoneinfo/$DEFAULT_TIMEZONE" /etc/localtime
check_command "设置时区文件"
echo "$DEFAULT_TIMEZONE" | sudo tee /etc/timezone | tee -a "$LOG_FILE"

log_message "启用 NTP 时间同步..."
sudo apk add openntpd | tee -a "$LOG_FILE"
check_command "安装 openntpd"

sudo rc-update add openntpd default
sudo rc-service openntpd start
check_command "启动 openntpd 服务"

log_message "当前时间状态："
date | tee -a "$LOG_FILE"
echo "时区和时间同步配置完成。"
echo ""

# 5. 配置 SWAP (可选)
echo "--- [5/6] 配置 SWAP (交换空间) ---"
read -p "是否配置 SWAP 交换空间？(y/n，小内存 VPS 推荐 y)：" CONFIGURE_SWAP
if echo "$CONFIGURE_SWAP" | grep -iq "^y"; then
    if swapon --show | grep -q '/swapfile'; then
        log_message "SWAP 文件已配置，跳过 SWAP 配置。"
        echo "SWAP 已配置。当前 SWAP 状态："
        free -h | tee -a "$LOG_FILE"
    else
        read -p "请输入 SWAP 大小 (例如：2G，默认为 2G)：" SWAP_SIZE
        SWAP_SIZE=${SWAP_SIZE:-2G}
        COUNT=$(echo "$SWAP_SIZE" | tr -d 'Gg')
        COUNT=$((COUNT * 1024))
        log_message "正在创建 $SWAP_SIZE 的 SWAP 文件..."
        sudo dd if=/dev/zero of=/swapfile bs=1M count="$COUNT" status=progress | tee -a "$LOG_FILE"
        check_command "创建 swapfile"

        sudo chmod 600 /swapfile
        check_command "设置 swapfile 权限"

        sudo mkswap /swapfile | tee -a "$LOG_FILE"
        check_command "格式化 swapfile"

        sudo swapon /swapfile | tee -a "$LOG_FILE"
        check_command "启用 swapfile"

        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab | tee -a "$LOG_FILE"
        check_command "添加 swap 到 fstab"

        sudo sysctl -w vm.swappiness=10 | tee -a "$LOG_FILE"
        sudo sysctl -w vm.vfs_cache_pressure=50 | tee -a "$LOG_FILE"
        echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf | tee -a "$LOG_FILE"
        echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf | tee -a "$LOG_FILE"
        check_command "调整内核参数"

        log_message "当前 SWAP 状态："
        free -h | tee -a "$LOG_FILE"
        echo "SWAP 配置完成。"
    fi
else
    log_message "跳过 SWAP 配置。"
fi
echo ""

# --- 最终 SSH 安全加固 (创建非 Root 用户并禁用 Root 登录) ---
echo "--- [最终步骤] SSH 安全加固：创建非 Root 用户并禁用 Root 登录 ---"

if ! is_installed "openssh"; then
    log_message "OpenSSH Server 未安装，尝试安装..."
    sudo apk add openssh | tee -a "$LOG_FILE"
    check_command "安装 openssh"
fi

sudo rc-update add sshd default
sudo rc-service sshd start
check_command "启动 sshd"

read -p "是否创建非 Root 用户并禁用 Root 登录？(y/n，强烈推荐 y)：" CREATE_USER_AND_DISABLE_ROOT
if echo "$CREATE_USER_AND_DISABLE_ROOT" | grep -iq "^y"; then
    read -p "请输入非 Root 用户的用户名和密码 (例如：youruser yourpassword，用空格隔开)：" USER_INPUT
    NON_ROOT_USER=$(echo "$USER_INPUT" | awk '{print $1}')
    NON_ROOT_PASSWORD=$(echo "$USER_INPUT" | awk '{print $2}')

    if [ -z "$NON_ROOT_USER" ] || [ -z "$NON_ROOT_PASSWORD" ]; then
        log_message "用户名或密码为空，跳过创建用户和禁用 Root 登录。"
        echo "警告：用户名或密码为空，无法创建用户。Root 登录未禁用。"
    else
        if id "$NON_ROOT_USER" >/dev/null 2>&1; then
            log_message "用户 $NON_ROOT_USER 已存在，跳过创建。"
            echo "用户 '$NON_ROOT_USER' 已存在。请确保您知道其密码。"
        else
            log_message "正在创建用户 $NON_ROOT_USER..."
            sudo adduser -D "$NON_ROOT_USER"
            echo "$NON_ROOT_USER:$NON_ROOT_PASSWORD" | sudo chpasswd
            check_command "创建用户 $NON_ROOT_USER"
        fi

        if ! is_installed "sudo"; then
            log_message "sudo 未安装，正在安装..."
            sudo apk add sudo | tee -a "$LOG_FILE"
            check_command "安装 sudo"
        fi

        log_message "将用户 $NON_ROOT_USER 添加到 wheel 组以授予 sudo 权限..."
        sudo addgroup "$NON_ROOT_USER" wheel
        check_command "添加 $NON_ROOT_USER 到 wheel 组"

        if ! grep -q '^%wheel ALL=(ALL) ALL' /etc/sudoers; then
            echo '%wheel ALL=(ALL) ALL' | sudo tee -a /etc/sudoers
            log_message "已添加 wheel 组 sudo 权限配置。"
        fi

        log_message "禁用 Root 用户 SSH 登录..."
        sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        check_command "禁用 Root SSH 登录"

        log_message "重启 SSH 服务以使 Root 登录禁用生效..."
        echo "警告：重启 SSH 服务可能会导致当前连接中断，建议在控制台操作。"
        read -p "是否立即重启 SSH 服务？(y/n，推荐 y)：" RESTART_SSH_FINAL
        if echo "$RESTART_SSH_FINAL" | grep -iq "^y"; then
            sudo rc-service sshd restart
            check_command "重启 sshd"
            echo "SSH 服务已重启。Root 用户登录已禁用。"
            echo "请使用非 Root 用户 '$NON_ROOT_USER' 登录。"
        else
            echo "SSH 服务未重启。Root 登录禁用将在下次 SSH 服务重启时生效。"
        fi
    fi
else
    log_message "用户选择不创建非 Root 用户和禁用 Root 登录。"
    echo "未创建非 Root 用户，Root 登录未禁用。"
fi
echo ""

log_message "--- VPS 基础配置脚本结束 ---"
echo "脚本执行完成。详细信息请查看日志文件 $LOG_FILE。"
