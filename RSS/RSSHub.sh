#!/bin/bash

# install_rsshub.sh — 一键手动部署 RSSHub（Debian）
# 功能：
#  1. 交互设置监听端口（默认1200）
#  2. 安装 Node.js、Git、Chromium（ARM/ARM64 系统）等依赖
#  3. 安装 pm2 进程管理器，避免重复安装
#  4. 克隆或更新 RSSHub 源码，安装依赖并编译
#  5. 启动 RSSHub 并设置开机自启
#  6. 完成后提示 .env 配置示例与说明

set -e

# 1. 交互设置监听端口
read -p "请输入 RSSHub 监听端口（回车默认1200）: " PORT
PORT=${PORT:-1200}

# 2. 安装基础工具：git、curl、build-essential
echo ">>> 安装基础工具 git、curl、build-essential（如已安装将跳过）..."
for pkg in git curl build-essential; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    sudo apt update && sudo apt install -y "$pkg"
  else
    echo "  - $pkg 已安装"
  fi
done

# 3. 安装 Node.js 18.x（如已安装将跳过）
if ! command -v node >/dev/null || [[ "$(node -v)" != v1?* ]]; then
  echo ">>> 安装 Node.js 18.x..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  sudo apt install -y nodejs
else
  echo ">>> Node.js $(node -v) 已安装"
fi

# 4. 检测系统架构并安装 Puppeteer 依赖（仅 ARM/ARM64 系统）
ARCH=$(dpkg --print-architecture)
if [[ "$ARCH" =~ ^arm64$|^armhf$ ]]; then
  echo ">>> 检测到 ARM 架构 ($ARCH)，安装 Chromium 供 Puppeteer 使用..."
  sudo apt install -y chromium
  PUPPETER_PATH=$(command -v chromium || command -v chromium-browser)
else
  echo ">>> 非 ARM 架构 ($ARCH)，跳过 Puppeteer 依赖安装"
  PUPPETER_PATH=""
fi

# 5. 安装 pm2（如已安装将跳过）
if ! command -v pm2 >/dev/null; then
  echo ">>> 安装 pm2 进程管理器..."
  sudo npm install -g pm2
else
  echo ">>> pm2 $(pm2 -v) 已安装"
fi

# 安装并配置 pm2-logrotate 模块
echo
echo "==> 安装 pm2-logrotate 模块以管理日志轮转…"
sudo pm2 install pm2-logrotate

echo "==> 配置 pm2-logrotate 模块…"
# 达到10mb开始轮转 (默认就是10M，但为了明确，可以显式设置)
pm2 set pm2-logrotate:max_size 10M
# 保留最近7个旧日志文件
pm2 set pm2-logrotate:retain 7
# 启用压缩旧日志文件
pm2 set pm2-logrotate:compress true
# 检查间隔为5分钟 (300秒)
pm2 set pm2-logrotate:worker_interval 300

# 6. 克隆或更新 RSSHub 源码
if [ -d RSSHub ]; then
  echo ">>> RSSHub 源码目录已存在，执行更新..."
  cd RSSHub && git pull
else
  echo ">>> 克隆 RSSHub 源码仓库..."
  git clone https://github.com/DIYgod/RSSHub.git && cd RSSHub
fi

# 7. 安装项目依赖
echo ">>> 安装项目依赖..."
npm install

# 8. 编译项目
echo ">>> 编译 RSSHub..."
npm run build

# 9. 修改端口信息而不影响其他 .env 环境变量
# 先删除旧 PORT 行
grep -v '^PORT=' .env > .env.tmp && mv .env.tmp .env
# 再追加新 PORT
echo "PORT=$PORT" >> .env

# 如果有 Puppeteer 路径，追加 CHROMIUM_EXECUTABLE_PATH
if [ -n "$PUPPETER_PATH" ]; then
  echo "CHROMIUM_EXECUTABLE_PATH=$PUPPETER_PATH" >> .env
fi

# 10. 用 pm2 启动 RSSHub 服务
echo ">>> 使用 pm2 启动 RSSHub..."
pm2 start npm --name rsshub -- start

# 11. 设置 pm2 开机自启
echo ">>> 设置 pm2 开机自启..."
pm2 startup systemd -u "$(whoami)" --hp "$HOME"
pm2 save

# 12. 完成提示
echo
echo ">>> 部署完成！RSSHub 已启动，监听端口：$PORT"
echo "访问地址： http://$(hostname -I | awk '{print $1}'):$PORT"
echo "pm2 管理命令示例： pm2 status rsshub | pm2 stop rsshub | pm2 restart rsshub | pm2 logs rsshub"
echo
cat <<MESSAGE
可以通过设置环境变量来配置 RSSHub。在项目根目录新建一个 .env 文件，
每行以 NAME=VALUE 格式添加环境变量，例如：
CACHE_TYPE=redis
CACHE_EXPIRE=600

注意它不会覆盖已有的环境变量，更多规则请参考：https://github.com/motdotla/dotenv

该部署方式不包括 Redis 依赖，如需启用 Redis，请使用 Docker Compose 部署或自行部署外部依赖。

更多部署参考：https://docs.rsshub.app/zh/deploy/

更多自定义的环境变量参考：https://docs.rsshub.app/zh/deploy/config
MESSAGE






















