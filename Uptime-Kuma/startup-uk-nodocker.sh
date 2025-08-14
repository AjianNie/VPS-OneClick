#!/usr/bin/env bash
set -e

# 提示用户输入 Web 端口
read -p "请输入 Uptime Kuma Web 服务端口（默认 3001）: " UK_PORT
UK_PORT=${UK_PORT:-3001}

echo
echo "===== 更新系统 & 安装依赖 ====="
sudo apt update
sudo apt install -y curl git build-essential

echo
echo "===== 安装 Node.js & npm ====="
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

echo
echo "===== 克隆 Uptime Kuma 源码 ====="
if [ -d uptime-kuma ]; then
  echo "检测到已有 uptime-kuma 目录，跳过克隆，直接进入目录"
else
  git clone https://github.com/louislam/uptime-kuma.git
fi
cd uptime-kuma

echo
echo "===== 安装项目依赖 & 构建 ====="
npm install
npm run setup

echo
echo "===== 安装 PM2 & 日志轮转 ====="
sudo npm install pm2 -g
pm2 install pm2-logrotate

echo
echo "===== 启动 Uptime Kuma 服务 ====="
pm2 delete uptime-kuma || true
pm2 start server/server.js --name uptime-kuma -- --port "$UK_PORT"

echo
echo "===== 配置 PM2 开机自启 ====="
pm2 save
pm2 startup -u "$USER" --hp "$HOME"

cat <<EOF

安装完成！Uptime Kuma 已通过 PM2 守护启动，Web 界面端口: $UK_PORT

管理服务命令：
  启动： pm2 start uptime-kuma
  停止： pm2 stop  uptime-kuma
  重启： pm2 restart uptime-kuma
查看状态与日志：
  查看列表： pm2 ls
  实时监控： pm2 monit
  查看最新日志： pm2 logs uptime-kuma --lines 50

访问 Web 界面：
  http://<服务器IP或域名>:$UK_PORT

EOF
