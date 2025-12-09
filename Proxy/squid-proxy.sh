#!/bin/bash

################################################################################
# Squid 代理服务一键安装脚本 - Debian
# 功能：自动安装、配置 Squid + 用户认证 + IP白名单 + UFW防火墙
# 使用方法：bash install_squid.sh
################################################################################

set -e  # 任何命令失败则退出

# ============================================================================
# 颜色定义
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# 函数定义
# ============================================================================

print_title() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

wait_for_service() {
    local service=$1
    local max_attempts=30
    local attempt=0
    
    print_info "等待 $service 服务启动..."
    while [ $attempt -lt $max_attempts ]; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            print_success "$service 服务已启动"
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    
    print_error "$service 服务启动超时"
    return 1
}

# ============================================================================
# 检查 Root 权限
# ============================================================================
print_title "权限检查"
if [ "$EUID" -ne 0 ]; then
    print_error "此脚本需要 root 权限或使用 sudo 运行"
    exit 1
fi
print_success "已获取 root 权限"

# ============================================================================
# 检查系统
# ============================================================================
print_title "系统检查"
if ! grep -qi debian /etc/os-release && ! grep -qi ubuntu /etc/os-release; then
    print_error "此脚本仅支持 Debian/Ubuntu 系统"
    exit 1
fi
print_success "系统验证通过（Debian/Ubuntu）"

# ============================================================================
# 第一步：获取用户输入
# ============================================================================
print_title "用户输入"

# 获取代理用户名
read -p "请输入 Squid 代理服务的用户名: " proxy_username
while [ -z "$proxy_username" ]; do
    print_error "用户名不能为空"
    read -p "请重新输入用户名: " proxy_username
done

# 获取代理密码
while true; do
    read -sp "请输入代理服务的密码: " proxy_password
    echo
    if [ -z "$proxy_password" ]; then
        print_error "密码不能为空"
        continue
    fi
    read -sp "请再次确认密码: " proxy_password_confirm
    echo
    if [ "$proxy_password" = "$proxy_password_confirm" ]; then
        print_success "密码已设置"
        break
    else
        print_error "两次密码不一致，请重新输入"
    fi
done

# 获取 IP 白名单（用户只填“额外 IP”，127.0.0.1 脚本自动加）
read -p "请输入允许的客户端 IP 白名单（多个 IP 用空格隔开，如：192.168.1.1 10.0.0.1）: " ip_whitelist
if [ -z "$ip_whitelist" ]; then
    print_info "未设置额外 IP 白名单，将只允许 127.0.0.1"
    allowed_ips="127.0.0.1"
else
    # 最终用于 acl 的 IP 列表：127.0.0.1 + 用户输入
    allowed_ips="127.0.0.1 $ip_whitelist"
fi

# 获取监听端口（默认 3128）
read -p "请输入 Squid 监听端口（默认 3128）: " squid_port
squid_port=${squid_port:-3128}

print_success "用户信息已收集"

# ============================================================================
# 第二步：更新系统并安装依赖
# ============================================================================
print_title "更新系统和安装依赖包"

print_info "更新软件包列表..."
apt update -qq

print_info "安装 Squid 和相关工具..."
apt install -y squid apache2-utils > /dev/null 2>&1

print_success "依赖包安装完成"

# ============================================================================
# 第三步：备份原始配置
# ============================================================================
print_title "备份原始配置"

if [ -f /etc/squid/squid.conf ]; then
    print_info "备份原始配置文件..."
    cp /etc/squid/squid.conf /etc/squid/squid.conf.bak.$(date +%s)
    print_success "配置文件备份完成"
fi

# ============================================================================
# 第四步：生成配置文件
# ============================================================================
print_title "生成 Squid 配置文件"

print_info "生成新的配置文件..."

# 构建 IP 白名单配置行（单行多 IP）
ip_whitelist_line="acl allowed_ips src $allowed_ips"

# 使用 tee 命令写入配置文件
sudo tee /etc/squid/squid.conf > /dev/null <<EOF
# ============================================================================
# Squid 配置文件 - 自动生成
# 生成时间: $(date)
# ============================================================================

# 1. 认证配置
# 指定认证程序和密码文件位置
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm "Squid Proxy - Authentication Required"

# 2. 定义安全端口列表
acl SSL_ports port 443
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http

# 3. 定义本地网络
acl localnet src 127.0.0.1

# 4. 定义允许访问的客户端 IP 白名单
$ip_whitelist_line

# 5. 定义已认证用户的 ACL
acl authenticated proxy_auth REQUIRED

# 6. 定义 CONNECT 方法
acl CONNECT method CONNECT

# 7. 设置访问规则 (顺序很重要)
# 拒绝不安全的端口连接
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports

# 允许本地网络访问
http_access allow localnet

# 允许白名单 IP 的访问
http_access allow allowed_ips

# 允许已认证用户且来自白名单 IP 的请求
http_access allow authenticated allowed_ips

# 拒绝所有其他访问
http_access deny all

# 8. 基础配置
http_port $squid_port
cache_dir ufs /var/spool/squid 100 16 100
coredump_dir /var/spool/squid
visible_hostname squid.proxy.local

# 9. 日志配置
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log

EOF

print_success "Squid 配置文件已生成"

# ============================================================================
# 第五步：创建认证用户
# ============================================================================
print_title "创建认证用户"

print_info "创建用户: $proxy_username"

# 使用 openssl passwd 生成加密密码，然后直接写入 htpasswd 格式的密文
encrypted_password=$(echo -n "$proxy_password" | openssl passwd -apr1 -stdin)

# 直接写入密码文件，格式为 username:encrypted_password
echo "$proxy_username:$encrypted_password" | sudo tee /etc/squid/passwd > /dev/null 2>&1

print_success "用户 $proxy_username 已创建"

# 设置权限
print_info "设置密码文件权限..."
chown proxy:proxy /etc/squid/passwd
chmod 640 /etc/squid/passwd
print_success "权限设置完成"

# ============================================================================
# 第六步：检查配置文件语法
# ============================================================================
print_title "验证配置文件"

print_info "检查 Squid 配置文件语法..."
if squid -k parse 2>&1 | grep -q "ERROR\|error"; then
    print_error "配置文件语法错误，请检查"
    exit 1
fi
print_success "配置文件语法正确"

# ============================================================================
# 第七步：启用并启动 Squid 服务
# ============================================================================
print_title "启动 Squid 服务"

print_info "停止现有 Squid 服务（如果有）..."
systemctl stop squid 2>/dev/null || true
sleep 2

print_info "启用 Squid 开机自启..."
systemctl enable squid

print_info "启动 Squid 服务..."
systemctl start squid

# 等待服务启动
wait_for_service "squid" || print_error "服务启动可能失败，请检查日志"
sleep 3

print_success "Squid 服务已启动"

# ============================================================================
# 第八步：配置 UFW 防火墙
# ============================================================================
print_title "配置防火墙"

# 检查 UFW 是否已启用
if ufw status | grep -q "Status: active"; then
    print_info "UFW 防火墙已启用，添加规则..."
    
    # 添加端口规则
    ufw allow "$squid_port/tcp" > /dev/null 2>&1
    
    print_info "重载防火墙规则..."
    ufw reload > /dev/null 2>&1
    
    print_success "防火墙规则已添加 (端口: $squid_port/tcp)"
else
    print_info "UFW 防火墙未启用或不可用，跳过防火墙配置"
fi

# ============================================================================
# 第九步：获取服务器 IP
# ============================================================================
print_title "服务器信息"

# 尝试获取外网 IP（如果可用）
server_ip=$(hostname -I | awk '{print $1}')
if [ -z "$server_ip" ]; then
    server_ip="<your_server_ip>"
fi

# ============================================================================
# 第十步：输出最终信息
# ============================================================================
print_title "安装完成"

echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}        Squid 代理服务安装配置完成！${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}【代理服务器信息】${NC}"
echo -e "  IP 地址:          ${BLUE}$server_ip${NC}"
echo -e "  监听端口:         ${BLUE}$squid_port${NC}"
echo -e "  用户名:           ${BLUE}$proxy_username${NC}"
echo -e "  密码:             ${BLUE}$proxy_password${NC}"
echo -e "  IP 白名单:        ${BLUE}$allowed_ips${NC}\n"

echo -e "${YELLOW}【重要：请检查以下内容】${NC}"
echo -e "  1. 请检查 ${BLUE}/etc/squid/squid.conf${NC} 文件中的 IP 白名单设置是否正确"
echo -e "     编辑命令: ${BLUE}sudo nano /etc/squid/squid.conf${NC}\n"

echo -e "${YELLOW}【测试有效性】${NC}"
echo -e "  在${BLUE}另一台客户端机器${NC}上执行以下命令进行测试：\n"
echo -e "  ${BLUE}curl -v -x http://$proxy_username:$proxy_password@$server_ip:$squid_port http://www.example.com${NC}\n"

echo -e "  或使用 HTTPS 测试：\n"
echo -e "  ${BLUE}curl -v -x http
