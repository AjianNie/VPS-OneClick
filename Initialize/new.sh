#!/usr/bin/env bash
# Debian 一键脚本 —— 更新、安装并配置 ufw，安装 Snell Server
set -e

# 1. 更新软件包列表并升级已安装的软件
sudo apt update && sudo apt upgrade -y

# 2. 安装 UFW 和 wget
sudo apt install -y ufw wget

# 3. 提示用户输入 TCP 端口（空格分隔）
read -p "请输入需要开放的 TCP 端口（空格分隔），回车跳过: " tcp_ports
if [ -n "$tcp_ports" ]; then
  echo "开放 TCP 端口：$tcp_ports"
  sudo ufw allow $tcp_ports/tcp
else
  echo "未输入 TCP 端口，跳过 TCP 开放"
fi

# 4. 提示用户输入 UDP 端口
#    - 回车继承 TCP 端口
#    - 输入 00 不开启任何 UDP 端口
read -p "请输入需要开放的 UDP 端口（回车继承 TCP，输入 00 不开启 UDP）: " udp_ports
if [ "$udp_ports" = "00" ]; then
  echo "选择不开放任何 UDP 端口"
elif [ -z "$udp_ports" ]; then
  if [ -n "$tcp_ports" ]; then
    echo "继承 TCP 端口，开放 UDP：$tcp_ports"
    sudo ufw allow $tcp_ports/udp
  else
    echo "未输入 TCP 端口，跳过 UDP 开放"
  fi
else
  echo "开放 UDP 端口：$udp_ports"
  sudo ufw allow $udp_ports/udp
fi

# 5. 自动启用 UFW（无需交互）
sudo ufw --force enable
echo "UFW 已启用并应用规则。"

# 6. 下载并运行 Snell Server 安装脚本
echo "下载并安装 Snell Server..."
wget -O snell.sh --no-check-certificate https://git.io/Snell.sh
chmod +x snell.sh
sudo ./snell.sh

echo "所有操作完成！"
