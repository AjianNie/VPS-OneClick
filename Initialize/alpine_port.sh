#!/bin/sh

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Alpine iptables 端口管理脚本 ===${NC}"

# --- 函数定义 ---

# 检查并安装必要的工具
check_dependencies() {
    echo -e "${YELLOW}检查并安装 iptables...${NC}"

    # 检查 iptables
    if ! command -v iptables >/dev/null; then
        echo -e "${YELLOW}iptables 未安装，正在安装...${NC}"
        apk add iptables || { echo -e "${RED}错误：安装 iptables 失败。请检查网络或权限。${NC}"; exit 1; }
    fi

    # 检查 openrc (包含 rc-service)
    if ! command -v rc-service >/dev/null; then
        echo -e "${YELLOW}openrc (包含 rc-service) 未安装，正在安装...${NC}"
        apk add openrc || { echo -e "${RED}错误：安装 openrc 失败。请检查网络或权限。${NC}"; exit 1; }
    fi

    # 检查 iptables 服务是否已启用（通过检查 /etc/runlevels/default/iptables 符号链接）
    # 如果 iptables 服务未添加到默认运行级别，则添加它
    if [ ! -e /etc/runlevels/default/iptables ]; then
        echo -e "${YELLOW}iptables 服务未启用，正在启用...${NC}"
        rc-update add iptables default || { echo -e "${RED}错误：启用 iptables 服务失败。${NC}"; exit 1; }
    fi

    echo -e "${GREEN}iptables 已就绪。${NC}"
}

# 显示当前 iptables 规则
display_current_rules() {
    echo -e "\n${YELLOW}--- 当前 iptables INPUT 链规则 ---${NC}"
    # 确保 iptables 命令存在
    if command -v iptables >/dev/null; then
        iptables -L INPUT -n -v
    else
        echo -e "${RED}iptables 命令未找到，无法显示规则。${NC}"
    fi
    echo -e "${YELLOW}----------------------------------${NC}"
}

# 开放端口函数
open_ports() {
    local port
    for port in $1; do
        echo -e "${YELLOW}尝试开放 TCP 端口 $port...${NC}"
        # 检查规则是否已存在，避免重复添加
        if ! iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
            iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
            echo -e "${GREEN}  TCP 端口 $port 已开放。${NC}"
        else
            echo -e "${YELLOW}  TCP 端口 $port 规则已存在，跳过。${NC}"
        fi

        echo -e "${YELLOW}尝试开放 UDP 端口 $port...${NC}"
        if ! iptables -C INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null; then
            iptables -A INPUT -p udp --dport "$port" -j ACCEPT
            echo -e "${GREEN}  UDP 端口 $port 已开放。${NC}"
        else
            echo -e "${YELLOW}  UDP 端口 $port 规则已存在，跳过。${NC}"
        fi
    done
}

# 删除端口函数
delete_ports() {
    local port
    for port in $1; do
        echo -e "${YELLOW}尝试删除 TCP 端口 $port...${NC}"
        # 检查规则是否存在，避免删除不存在的规则报错
        if iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
            iptables -D INPUT -p tcp --dport "$port" -j ACCEPT
            echo -e "${GREEN}  TCP 端口 $port 已删除。${NC}"
        else
            echo -e "${YELLOW}  TCP 端口 $port 规则不存在，跳过。${NC}"
        fi

        echo -e "${YELLOW}尝试删除 UDP 端口 $port...${NC}"
        if iptables -C INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null; then
            iptables -D INPUT -p udp --dport "$port" -j ACCEPT
            echo -e "${GREEN}  UDP 端口 $port 已删除。${NC}"
        else
            echo -e "${YELLOW}  UDP 端口 $port 规则不存在，跳过。${NC}"
        fi
    done
}

# 保存 iptables 规则
save_iptables_rules() {
    echo -e "${YELLOW}\n保存 iptables 规则...${NC}"
    # 在 Alpine 中，iptables 规则通常保存到 /etc/iptables/rules.v4 和 /etc/iptables/rules.v6
    # 并且由 OpenRC 的 iptables 服务在启动时加载
    # rc-service iptables save 命令会执行此操作
    if command -v rc-service >/dev/null; then
        rc-service iptables save || { echo -e "${RED}错误：保存 iptables 规则失败！请手动检查。${NC}"; exit 1; }
        echo -e "${GREEN}iptables 规则已保存到 /etc/iptables/rules.v4，重启后将自动加载。${NC}"
    else
        echo -e "${RED}rc-service 命令未找到，无法保存规则。请手动保存。${NC}"
        echo -e "${RED}您可以尝试手动执行：iptables-save > /etc/iptables/rules.v4${NC}"
    fi
}

# --- 主逻辑 ---

# 1. 检查依赖
check_dependencies

# 2. 显示当前规则
display_current_rules

# 3. 询问用户操作类型
OPERATION=""
while [ -z "$OPERATION" ]; do
    echo -e "\n${YELLOW}请选择操作类型：${NC}"
    echo "  1) 开放端口 (Open)"
    echo "  2) 删除端口 (Delete)"
    read -p "请输入数字 (1/2): " choice

    case "$choice" in
        1) OPERATION="open";;
        2) OPERATION="delete";;
        *) echo -e "${RED}无效的选择，请重新输入。${NC}";;
    esac
done

# 4. 询问端口号
PORTS_TO_OPERATE=""
while [ -z "$PORTS_TO_OPERATE" ]; do
    # 修改后的行
    echo -en "${YELLOW}请输入要操作的端口号（多个端口用空格隔开，例如：80 443 2222）：${NC} "
    read ports_input
    # 原始的验证逻辑不变
    if [ -n "$ports_input" ]; then
        # 简单验证输入是否为数字和空格
        if echo "$ports_input" | grep -Eq '^[0-9 ]+$'; then
            PORTS_TO_OPERATE="$ports_input"
        else
            echo -e "${RED}无效的端口输入。端口号应为数字，多个端口用空格隔开。${NC}"
        fi
    else
        echo -e "${RED}端口号不能为空，请重新输入。${NC}"
    fi
done

# 5. 执行操作
if [ "$OPERATION" = "open" ]; then
    open_ports "$PORTS_TO_OPERATE"
elif [ "$OPERATION" = "delete" ]; then
    delete_ports "$PORTS_TO_OPERATE"
fi

# 6. 保存规则
save_iptables_rules

# 7. 再次显示最终规则
display_current_rules

echo -e "${GREEN}\n操作完成。${NC}"
