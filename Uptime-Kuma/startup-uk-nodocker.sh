#!/bin/bash

# 一键安装 Uptime Kuma（非 Docker）并设置监听端口

read -rp "请输入 Uptime Kuma 监听端口（默认30000）： " PORT
PORT=${PORT:-30000}

echo "开始安装依赖和环境准备..."
curl -fsSL https://deb.nodesource.com/setup_16.x | bash
apt-get update
apt-get install -y nodejs git
npm install -g pm2 pm2-logrotate

echo "克隆 Uptime Kuma 仓库并初始化..."
git clone https://github.com/louislam/uptime-kuma.git
cd uptime-kuma || exit
npm run setup

echo "使用 PM2 启动 Uptime Kuma，监听端口设为 $PORT..."
PORT=$PORT pm2 start server/server.js --name uptime-kuma

echo "保存 PM2 进程列表并配置开机自启..."
pm2 save
pm2 startup systemd -u $(whoami) --hp $(eval echo "~$(whoami)")

echo "安装和启动完成！请根据提示执行最后一条命令完成自启设置。"
echo "浏览器访问 http://<你的服务器IP>:$PORT 访问 Uptime Kuma"
