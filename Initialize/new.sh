#!/usr/bin/env bash

set -e

if [[ $EUID -ne 0 ]]; then
  echo "请使用 sudo 运行此脚本：sudo $0"
  exit 1
fi

echo "==========================================="
echo "  Debian 一键安装：更新、UFW、Snell Server"
echo "==========================================="
echo

# 1. 更新并升级系统
echo "[1/4] 更新软件包列表并升级系统..."
apt update && apt -y upgrade
echo "完成系统更新。"
echo

# 2. 安装 UFW
echo "[2/4] 安装 UFW 防火墙..."
apt -y install ufw
echo "UFW 安装完成。"
echo

# 2.1 输入 TCP 端口列表
read -p "请输入要开放的 TCP 端口（多个端口以空格分隔），回车跳过: " TCP_PORTS

# 2.2 输入 UDP 端口列表
read -p "请输入要开放的 UDP 端口，默认为 TCP 端口列表，输入 00 则不开放 UDP: " UDP_PORTS

if [[ -z "$UDP_PORTS" ]]; then
  UDP_PORTS="$TCP_PORTS"
elif [[ "$UDP_PORTS" == "00" ]]; then
  UDP_PORTS=""
fi

echo "配置 UFW 规则..."
# TCP
if [[ -n "$TCP_PORTS" ]]; then
  echo "开放 TCP 端口：$TCP_PORTS"
  for port in $TCP_PORTS; do
    ufw allow ${port}/tcp
    echo "  已添加 TCP/$port"
  done
else
  echo "未指定 TCP 端口，跳过。"
fi

# UDP
if [[ -n "$UDP_PORTS" ]]; then
  echo "开放 UDP 端口：$UDP_PORTS"
  for port in $UDP_PORTS; do
    ufw allow ${port}/udp
    echo "  已添加 UDP/$port"
  done
else
  echo "未配置任何 UDP 端口。"
fi

# 3. 启用 UFW
echo "[3/4] 启用 UFW 防火墙（自动确认）..."
ufw --force enable
echo "UFW 已启用。"
echo

# 4. 安装 Snell Server
echo "[4/4] 下载并安装 Snell Server..."
wget -O snell.sh --no-check-certificate https://git.io/Snell.sh
chmod +x snell.sh
./snell.sh
echo "Snell Server 安装完成。"
echo

echo "==========================================="
echo "一键安装脚本执行完毕！"
echo "==========================================="
