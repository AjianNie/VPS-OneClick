#!/usr/bin/env bash
echo "==========================================="
echo "在 Debian 服务器上一键安装并配置 RSS-to-Telegram-Bot"
echo "PyPI 版 + systemd 后台服务"
echo "原文:https://github.com/Rongronggg9/RSS-to-Telegram-Bot/blob/dev/docs/deployment-guide.md"
echo "==========================================="
echo "开始前，您还需要："
echo "1. 从 @BotFather 新建机器人并获取Token"
echo "2. 从 @userinfobot 获取您的 Telegram ID"
echo "3. API access tokens（在 https://api.telegra.ph/createAccount?short_name=RSStT&author_name=Generated%20by%20RSStT&author_url=https%3A%2F%2Fgithub.com%2FRongronggg9%2FRSS-to-Telegram-Bot 页面获取，刷新一次即为新token，用逗号分隔）"
echo "==========================================="
read -p "准备好后回车，按照指引输入以上信息"

# 从 @BotFather 获取 Token、Telegram 用户 ID、Telegraph API Tokens
echo
echo "请依次输入以下信息："
read -p "1) Telegram Bot Token: " BOT_TOKEN
read -p "2) 您的 Telegram 用户ID: " MANAGER_ID
read -p "3) Telegraph API access tokens（多个则使用英文逗号分隔）: " TELEGRAPH_TOKENS


set -euo pipefail

# 1. 系统更新与基础工具安装
echo "==> 更新系统并安装基础工具…"
sudo apt update
sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv wget

# 2. （可选）安装中文字体用于 HTML 表格渲染
echo "==> 默认安装中文字体以支持表格渲染…"
sudo apt install -y fonts-wqy-microhei

# 4. 创建项目目录与虚拟环境
PROJECT_DIR="$HOME/rsstt"
echo
echo "==> 创建项目目录并初始化虚拟环境：$PROJECT_DIR"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"
python3 -m venv venv
source venv/bin/activate

# 5. 安装与升级核心 Python 包
echo "==> 升级 pip、安装 rsstt…"
pip install --upgrade pip setuptools wheel
pip install rsstt

# 6. 配置环境变量文件
ENV_DIR="$HOME/.rsstt"
ENV_FILE="$ENV_DIR/.env"
echo
echo "==> 写入环境变量到 $ENV_FILE"
mkdir -p "$ENV_DIR"
cat > "$ENV_FILE" <<EOF
# RSS-to-Telegram-Bot Configuration

TOKEN=${BOT_TOKEN}
MANAGER=${MANAGER_ID}
TELEGRAPH_TOKEN=${TELEGRAPH_TOKENS}
EOF

# 7. 创建 systemd 服务单元
SERVICE_FILE="/etc/systemd/system/rsstt.service"
echo
echo "==> 创建 systemd 服务文件：$SERVICE_FILE"
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=RSS-to-Telegram-Bot Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python3 -m rsstt
Restart=on-failure
EnvironmentFile=$ENV_FILE

[Install]
WantedBy=multi-user.target
EOF

# 8. 启用并启动服务
echo "==> 重新加载 systemd、启用并启动 rsstt 服务…"
sudo systemctl daemon-reload
sudo systemctl enable rsstt
sudo systemctl start rsstt

echo
echo "安装完成！"
echo "可通过 'sudo journalctl -u rsstt -f' 查看实时日志。"
echo "运行状态：sudo systemctl status rsstt"
