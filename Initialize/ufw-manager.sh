#!/bin/bash

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then
  echo "错误: 请以root用户运行此脚本 (sudo ./ufw_port_manager.sh)。"
  exit 1
fi

# 检查UFW是否安装
if ! command -v ufw &> /dev/null; then
  echo "错误: UFW 未安装或不在PATH中。"
  echo "在Debian/Ubuntu上，您可以使用 'sudo apt update && sudo apt install ufw' 进行安装。"
  echo "注意: Alpine Linux通常不使用UFW，而是直接使用iptables或nftables。"
  echo "如果您在Alpine上，请考虑使用iptables或nftables命令，或者尝试安装ufw (可能需要额外的配置)。"
  exit 1
fi

# 函数：处理端口操作
# 参数：$1=操作 (allow/delete), $2=协议 (tcp/udp), $3=端口字符串
process_ports() {
  local action="$1"
  local protocol="$2"
  local ports_string="$3"

  if [ -z "$ports_string" ]; then
    echo "  没有为 $protocol 提供端口，跳过。"
    return 0
  fi

  # 使用IFS分割端口字符串
  IFS=' ' read -r -a ports_array <<< "$ports_string"

  for port in "${ports_array[@]}"; do
    # 简单的端口验证
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -le 0 ] || [ "$port" -gt 65535 ]; then
      echo "  警告: 无效的 $protocol 端口 '$port'，跳过。"
      continue
    fi

    local ufw_command=""
    if [ "$action" == "allow" ]; then
      ufw_command="ufw allow $port/$protocol"
    elif [ "$action" == "delete" ]; then
      # 修正点：删除操作明确指定 'allow' 规则
      ufw_command="ufw delete allow $port/$protocol"
    else
      echo "  错误: 未知的操作 '$action'。"
      continue # 跳过当前端口
    fi

    echo "  正在执行: $ufw_command"
    $ufw_command
    if [ $? -eq 0 ]; then
      echo "  成功: $ufw_command"
    else
      echo "  失败: $ufw_command (可能规则不存在或已存在)"
    fi
  done
}

# 主逻辑
echo "UFW 端口管理脚本"
echo "-----------------"

# 询问用户要执行的操作
ACTION=""
while true; do
  read -p "请选择操作 [allow (放行) / delete (删除)]: " user_action
  user_action=$(echo "$user_action" | tr '[:upper:]' '[:lower:]') # 转换为小写
  if [ "$user_action" == "allow" ] || [ "$user_action" == "delete" ]; then
    ACTION="$user_action"
    break
  else
    echo "无效的选择，请重新输入 'allow' 或 'delete'。"
  fi
done

echo ""
echo "您选择了: $( [ "$ACTION" == "allow" ] && echo "放行端口" || echo "删除端口" )"
echo "----------------------------------------------------------------"

TCP_PORTS=""
UDP_PORTS=""

# 询问TCP端口
read -p "请输入要${ACTION}的TCP端口 (多个端口用空格隔开，留空则跳过): " TCP_PORTS
TCP_PORTS=$(echo "$TCP_PORTS" | xargs) # 清理首尾空格

# 询问UDP端口
read -p "请输入要${ACTION}的UDP端口 (多个端口用空格隔开，输入'00'则与TCP端口相同，留空则跳过): " UDP_PORTS
UDP_PORTS=$(echo "$UDP_PORTS" | xargs) # 清理首尾空格

# 处理UDP端口为'00'的情况
if [ "$UDP_PORTS" == "00" ]; then
  if [ -z "$TCP_PORTS" ]; then
    echo "警告: 您选择了UDP端口与TCP端口相同，但未输入任何TCP端口。UDP端口操作将跳过。"
    UDP_PORTS="" # 清空UDP端口，确保不执行操作
  else
    UDP_PORTS="$TCP_PORTS"
    echo "UDP端口将与TCP端口相同: $UDP_PORTS"
  fi
fi

echo ""
echo "----------------------------------------------------------------"
echo "开始执行操作..."

# 执行TCP端口操作
if [ -n "$TCP_PORTS" ]; then
  echo "处理TCP端口:"
  process_ports "$ACTION" "tcp" "$TCP_PORTS"
else
  echo "未提供TCP端口，跳过TCP操作。"
fi

echo ""

# 执行UDP端口操作
if [ -n "$UDP_PORTS" ]; then
  echo "处理UDP端口:"
  process_ports "$ACTION" "udp" "$UDP_PORTS"
else
  echo "未提供UDP端口，跳过UDP操作。"
fi

echo ""
echo "操作完成。您可以使用 'sudo ufw status' 查看当前UFW状态。"
echo "如果您想启用UFW，请使用 'sudo ufw enable'。"

