#!/usr/bin/env bash
echo "==========================================="
echo "在 Debian 服务器上一键安装并配置 RSS-to-Telegram-Bot"
echo "PyPI 版 + pm2 后台服务 (含自定义日志轮转)"
echo "原文:https://github.com/Rongronggg9/RSS-to-Telegram-Bot/blob/dev/docs/deployment-guide.md"
echo "==========================================="

# 设置项目目录变量
PROJECT_DIR="$HOME/rsstt"

# 检测是否已安装 RSS-to-Telegram-Bot
if pm2 list | grep -q "rsstt"; then
    echo "检测到 RSS-to-Telegram-Bot (rsstt) 已经通过 pm2 安装并运行。"
    echo "如果您想重新安装，请先手动停止并删除现有的 pm2 进程："
    echo "pm2 stop rsstt"
    echo "pm2 delete rsstt"
    echo "然后删除项目目录：rm -rf $PROJECT_DIR"
    echo "最后重新运行此脚本。"
    exit 0
fi

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
echo
echo "==> 更新系统并安装基础工具…"
sudo apt update
sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv wget curl

# 2. （可选）安装中文字体用于 HTML 表格渲染
echo
echo "==> 默认安装中文字体以支持表格渲染…"
sudo apt install -y fonts-wqy-microhei

# 3. 安装 Node.js 和 npm (用于安装 pm2)
echo
echo "==> 安装 Node.js 和 npm (如果未安装)…"
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js 已安装。"
fi

# 4. 安装 pm2
echo
echo "==> 安装 pm2 全局包…"
sudo npm install -g pm2

# 5. 安装并配置 pm2-logrotate 模块
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

# 6. 检查 Python 3 环境
echo
echo "==> 检查 Python 3 环境…"
if ! command -v python3 &> /dev/null; then
    echo "错误：未找到 python3 命令。请确保 Python 3 已正确安装。"
    exit 1
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
REQUIRED_MAJOR=3
REQUIRED_MINOR=6 # rsstt 通常要求 Python 3.6+，这里可以根据实际需求调整

if (( $(echo "$PYTHON_VERSION" | cut -d'.' -f1) < $REQUIRED_MAJOR )) || \
   (( $(echo "$PYTHON_VERSION" | cut -d'.' -f1) == $REQUIRED_MAJOR && $(echo "$PYTHON_VERSION" | cut -d'.' -f2) < $REQUIRED_MINOR )); then
    echo "错误：检测到 Python 版本为 $PYTHON_VERSION，但 RSS-to-Telegram-Bot 至少需要 Python ${REQUIRED_MAJOR}.${REQUIRED_MINOR}。"
    echo "请升级您的 Python 版本。"
    exit 1
else
    echo "检测到 Python 版本为 $PYTHON_VERSION，符合要求。"
fi


# 7. 创建项目目录与虚拟环境
echo
echo "==> 创建项目目录并初始化虚拟环境：$PROJECT_DIR"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"
python3 -m venv venv
source venv/bin/activate

# 8. 安装与升级核心 Python 包
echo
echo "==> 升级 pip、安装 rsstt…"
pip install --upgrade pip setuptools wheel
pip install rsstt

# 9. 配置环境变量文件
# 将 .env 文件直接创建在项目目录中，以便 rsstt 自动加载
ENV_FILE="$PROJECT_DIR/.env"
echo
echo "==> 写入环境变量到 $ENV_FILE"
cat > "$ENV_FILE" <<EOF
# RSS-to-Telegram-Bot Configuration

TOKEN=${BOT_TOKEN}
MANAGER=${MANAGER_ID}
TELEGRAPH_TOKEN=${TELEGRAPH_TOKENS}
EOF

# 10. 使用 pm2 启动服务
echo "==> 使用 pm2 启动 rsstt 服务…"
pm2 start "$PROJECT_DIR/venv/bin/python3" --name "rsstt" --cwd "$PROJECT_DIR" -- -m rsstt

# 确保 pm2 进程在系统重启后自动启动
echo "==> 配置 pm2 开机自启…"
pm2 save
pm2 startup systemd # 或者 pm2 startup init.d，取决于你的系统

echo
echo "==========================================="
echo "RSS-to-Telegram-Bot 安装完成！"
echo "服务已通过 pm2 启动，并配置了自定义日志轮转。"
echo "==========================================="
echo "常用命令："
echo "查看实时日志：pm2 logs rsstt"
echo "查看运行状态：pm2 status"
echo "停止服务：pm2 stop rsstt"
echo "重启服务：pm2 restart rsstt"
echo "删除服务：pm2 delete rsstt"
echo "查看日志轮转配置：pm2 show pm2-logrotate"
echo "查看日志文件位置：通常在 ~/.pm2/logs/"
echo "==========================================="
