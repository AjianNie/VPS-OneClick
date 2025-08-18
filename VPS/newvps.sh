#!/bin/bash

# --- 变量定义 ---
LOG_FILE="/var/log/vps_setup.log"
NON_ROOT_USER=""
NON_ROOT_PASSWORD=""
TCP_PORTS=""
UDP_PORTS=""
DEFAULT_TIMEZONE="Asia/Shanghai" # 默认时区为china/shanghai

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
        # 考虑到避免断开连接，这里不直接退出，而是继续尝试
    fi
}

# 检查软件包是否已安装
is_installed() {
    dpkg -s "$1" &> /dev/null
    return $?
}

# --- 脚本开始 ---
log_message "--- VPS 基础配置脚本开始 ---"
echo "所有操作将记录在 $LOG_FILE。"
echo "请注意：本脚本尽量避免断开终端连接，但某些操作仍有风险，建议在 VNC 控制台运行。"
echo ""

# 1. 更新系统
echo "--- [1/6] 更新软件包列表并升级系统 ---"
log_message "正在更新软件包列表..."
sudo apt update | tee -a "$LOG_FILE"
check_command "apt update"

log_message "正在升级系统软件包..."
sudo apt upgrade -y | tee -a "$LOG_FILE"
check_command "apt upgrade"

log_message "正在处理依赖关系升级..."
sudo apt dist-upgrade -y | tee -a "$LOG_FILE"
check_command "apt dist-upgrade"

log_message "正在移除不再需要的软件包..."
sudo apt autoremove -y | tee -a "$LOG_FILE"
check_command "apt autoremove"

echo "系统更新完成。"
echo ""

# 2. 安装并配置防火墙 (UFW)
echo "--- [2/6] 安装并配置防火墙 (UFW) ---"
if is_installed "ufw"; then
    log_message "UFW 已安装。"
    echo "当前 UFW 状态："
    sudo ufw status verbose | tee -a "$LOG_FILE"
    read -p "UFW 已安装。是否继续进行 UFW 配置？(y/n，推荐 y)：" CONTINUE_UFW_CONFIG
    if [[ ! "$CONTINUE_UFW_CONFIG" =~ ^[Yy]$ ]]; then
        log_message "用户选择跳过 UFW 配置。"
        echo "跳过 UFW 配置。"
        echo ""
    else
        log_message "用户选择继续进行 UFW 配置。"
        log_message "设置 UFW 默认规则：拒绝所有传入，允许所有传出..."
        sudo ufw default deny incoming | tee -a "$LOG_FILE"
        check_command "ufw default deny incoming"
        sudo ufw default allow outgoing | tee -a "$LOG_FILE"
        check_command "ufw default allow outgoing"

        # 询问 TCP 端口
        read -p "请输入需要开放的 TCP 端口 (多个端口用空格隔开，例如：22 80 443)：" TCP_PORTS
        if [ -n "$TCP_PORTS" ]; then
            for port in $TCP_PORTS; do
                log_message "允许 TCP 端口 $port..."
                sudo ufw allow "$port"/tcp | tee -a "$LOG_FILE"
                check_command "ufw allow $port/tcp"
            done
        else
            log_message "未输入 TCP 端口，跳过 TCP 端口开放。"
        fi

        # 询问 UDP 端口
        read -p "请输入需要开放的 UDP 端口 (多个端口用空格隔开，输入 '00' 则使用与 TCP 相同的端口，输入 'no' 则不开放任何 UDP 端口)：" UDP_INPUT
        if [ "$UDP_INPUT" == "00" ]; then
            UDP_PORTS="$TCP_PORTS"
            log_message "UDP 端口设置为与 TCP 端口相同：$UDP_PORTS"
        elif [ "$UDP_INPUT" == "no" ]; then
            UDP_PORTS=""
            log_message "不开放任何 UDP 端口。"
        else
            UDP_PORTS="$UDP_INPUT"
            log_message "UDP 端口设置为：$UDP_PORTS"
        fi

        if [ -n "$UDP_PORTS" ]; then
            for port in $UDP_PORTS; do
                log_message "允许 UDP 端口 $port..."
                sudo ufw allow "$port"/udp | tee -a "$LOG_FILE"
                check_command "ufw allow $port/udp"
            done
        fi

        log_message "正在启用 UFW 防火墙..."
        echo "y" | sudo ufw enable | tee -a "$LOG_FILE"
        check_command "ufw enable"
        if [ $? -ne 0 ]; then
            echo "警告：UFW 启用可能需要手动确认。如果脚本卡住，请尝试手动输入 'y' 并回车。"
        fi

        log_message "当前 UFW 状态："
        sudo ufw status verbose | tee -a "$LOG_FILE"
        echo "防火墙配置完成。"
        echo ""
    fi
else
    log_message "UFW 未安装，正在安装..."
    sudo apt install ufw -y | tee -a "$LOG_FILE"
    check_command "ufw install"

    log_message "设置 UFW 默认规则：拒绝所有传入，允许所有传出..."
    sudo ufw default deny incoming | tee -a "$LOG_FILE"
    check_command "ufw default deny incoming"
    sudo ufw default allow outgoing | tee -a "$LOG_FILE"
    check_command "ufw default allow outgoing"

    # 询问 TCP 端口
    read -p "请输入需要开放的 TCP 端口 (多个端口用空格隔开，例如：22 80 443)：" TCP_PORTS
    if [ -n "$TCP_PORTS" ]; then
        for port in $TCP_PORTS; do
            log_message "允许 TCP 端口 $port..."
            sudo ufw allow "$port"/tcp | tee -a "$LOG_FILE"
            check_command "ufw allow $port/tcp"
        done
    else
        log_message "未输入 TCP 端口，跳过 TCP 端口开放。"
    fi

    # 询问 UDP 端口
    read -p "请输入需要开放的 UDP 端口 (多个端口用空格隔开，输入 '00' 则使用与 TCP 相同的端口，输入 'no' 则不开放任何 UDP 端口)：" UDP_INPUT
    if [ "$UDP_INPUT" == "00" ]; then
        UDP_PORTS="$TCP_PORTS"
        log_message "UDP 端口设置为与 TCP 端口相同：$UDP_PORTS"
    elif [ "$UDP_INPUT" == "no" ]; then
        UDP_PORTS=""
        log_message "不开放任何 UDP 端口。"
    else
        UDP_PORTS="$UDP_INPUT"
        log_message "UDP 端口设置为：$UDP_PORTS"
    fi

    if [ -n "$UDP_PORTS" ]; then
        for port in $UDP_PORTS; do
            log_message "允许 UDP 端口 $port..."
            sudo ufw allow "$port"/udp | tee -a "$LOG_FILE"
            check_command "ufw allow $port/udp"
        done
    fi

    log_message "正在启用 UFW 防火墙..."
    echo "y" | sudo ufw enable | tee -a "$LOG_FILE"
    check_command "ufw enable"
    if [ $? -ne 0 ]; then
        echo "警告：UFW 启用可能需要手动确认。如果脚本卡住，请尝试手动输入 'y' 并回车。"
    fi

    log_message "当前 UFW 状态："
    sudo ufw status verbose | tee -a "$LOG_FILE"
    echo "防火墙配置完成。"
    echo ""
fi

# 3. 安装常用工具和实用程序
echo "--- [3/6] 安装常用工具和实用程序 ---"
echo "htop (更友好的进程查看器);curl 和 wget (命令行下载工具);git (版本控制工具);unzip 和 zip (文件压缩/解压缩工具);fail2ban (入侵防御系统，防止暴力破解)"
COMMON_TOOLS="htop curl wget git unzip zip fail2ban"
for tool in $COMMON_TOOLS; do
    if is_installed "$tool"; then
        log_message "$tool 已安装，跳过安装。"
    else
        log_message "正在安装 $tool..."
        sudo apt install "$tool" -y | tee -a "$LOG_FILE"
        check_command "install $tool"
    fi
done
echo "常用工具安装完成。"
echo ""

# 4. 配置时区和时间同步
echo "--- [4/6] 配置时区和时间同步 ---"
log_message "设置时区为 $DEFAULT_TIMEZONE..."
sudo timedatectl set-timezone "$DEFAULT_TIMEZONE" | tee -a "$LOG_FILE"
check_command "set timezone to $DEFAULT_TIMEZONE"

log_message "启用 NTP 时间同步..."
sudo timedatectl set-ntp true | tee -a "$LOG_FILE"
check_command "enable ntp"

log_message "当前时间状态："
timedatectl status | tee -a "$LOG_FILE"
echo "时区和时间同步配置完成。"
echo ""

# 5. 配置 SWAP (可选)
echo "--- [5/6] 配置 SWAP (交换空间) ---"
read -p "是否配置 SWAP 交换空间？(y/n，小内存 VPS 推荐 y)：" CONFIGURE_SWAP
if [[ "$CONFIGURE_SWAP" =~ ^[Yy]$ ]]; then
    # 检查是否已存在 swapfile
    if grep -q "/swapfile" /etc/fstab; then
        log_message "SWAP 文件已配置在 /etc/fstab 中，跳过 SWAP 配置。"
        echo "SWAP 似乎已配置。当前 SWAP 状态："
        free -h | tee -a "$LOG_FILE"
    else
        read -p "请输入 SWAP 大小 (例如：2G，默认为 2G)：" SWAP_SIZE
        SWAP_SIZE=${SWAP_SIZE:-2G}
        log_message "正在创建 $SWAP_SIZE 的 SWAP 文件..."
        sudo fallocate -l "$SWAP_SIZE" /swapfile | tee -a "$LOG_FILE"
        check_command "fallocate swapfile"

        log_message "设置 SWAP 文件权限..."
        sudo chmod 600 /swapfile | tee -a "$LOG_FILE"
        check_command "chmod swapfile"

        log_message "格式化 SWAP 文件..."
        sudo mkswap /swapfile | tee -a "$LOG_FILE"
        check_command "mkswap swapfile"

        log_message "启用 SWAP..."
        sudo swapon /swapfile | tee -a "$LOG_FILE"
        check_command "swapon swapfile"

        log_message "添加到 fstab 使开机自动挂载..."
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab | tee -a "$LOG_FILE"
        check_command "add swap to fstab"

        log_message "调整 swappiness 和 vfs_cache_pressure..."
        sudo sysctl vm.swappiness=10 | tee -a "$LOG_FILE"
        sudo sysctl vm.vfs_cache_pressure=50 | tee -a "$LOG_FILE"
        echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf | tee -a "$LOG_FILE"
        echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf | tee -a "$LOG_FILE"
        check_command "adjust swappiness"

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

# 检查 SSH 服务是否已运行
if ! is_installed "openssh-server"; then
    log_message "OpenSSH Server 未安装，尝试安装..."
    sudo apt install openssh-server -y | tee -a "$LOG_FILE"
    check_command "install openssh-server"
fi

if ! systemctl is-active sshd &> /dev/null; then
    log_message "SSH 服务未运行，尝试启动..."
    sudo systemctl enable sshd | tee -a "$LOG_FILE"
    sudo systemctl start sshd | tee -a "$LOG_FILE"
    check_command "start sshd"
fi

# 询问创建非 Root 用户
read -p "是否创建非 Root 用户并禁用 Root 登录？(y/n，强烈推荐 y)：" CREATE_USER_AND_DISABLE_ROOT
if [[ "$CREATE_USER_AND_DISABLE_ROOT" =~ ^[Yy]$ ]]; then
    read -p "请输入非 Root 用户的用户名和密码 (例如：youruser yourpassword，用空格隔开)：" USER_INPUT
    NON_ROOT_USER=$(echo "$USER_INPUT" | awk '{print $1}')
    NON_ROOT_PASSWORD=$(echo "$USER_INPUT" | awk '{print $2}')

    if [ -z "$NON_ROOT_USER" ] || [ -z "$NON_ROOT_PASSWORD" ]; then
        log_message "用户名或密码为空，跳过创建用户和禁用 Root 登录。"
        echo "警告：用户名或密码为空，无法创建用户。Root 登录未禁用。"
    else
        if id "$NON_ROOT_USER" &> /dev/null; then
            log_message "用户 $NON_ROOT_USER 已存在，跳过创建。"
            echo "用户 '$NON_ROOT_USER' 已存在。请确保您知道其密码。"
        else
            log_message "正在创建用户 $NON_ROOT_USER..."
            # 使用 useradd 和 echo 管道设置密码，避免交互式
            sudo useradd -m -s /bin/bash "$NON_ROOT_USER" | tee -a "$LOG_FILE"
            echo "$NON_ROOT_USER:$NON_ROOT_PASSWORD" | sudo chpasswd | tee -a "$LOG_FILE"
            check_command "create user $NON_ROOT_USER"
        fi

        log_message "将用户 $NON_ROOT_USER 添加到 sudo 组..."
        sudo usermod -aG sudo "$NON_ROOT_USER" | tee -a "$LOG_FILE"
        check_command "add $NON_ROOT_USER to sudo group"
        echo "用户 '$NON_ROOT_USER' 创建并配置 sudo 权限完成。请牢记其密码！"
        echo ""

        # 禁用 Root 用户 SSH 登录
        log_message "禁用 Root 用户 SSH 登录..."
        sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config | tee -a "$LOG_FILE"
        check_command "PermitRootLogin no"

        log_message "重启 SSH 服务以使 Root 登录禁用生效..."
        echo "警告：重启 SSH 服务可能会导致当前连接中断，最好在 VNC 控制台操作。"
        read -p "是否立即重启 SSH 服务？(y/n，推荐 y)：" RESTART_SSH_FINAL
        if [[ "$RESTART_SSH_FINAL" =~ ^[Yy]$ ]]; then
            sudo systemctl restart sshd | tee -a "$LOG_FILE"
            check_command "systemctl restart sshd"
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
