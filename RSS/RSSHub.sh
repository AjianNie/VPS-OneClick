# RSSHub 一键后端部署(非Docker)
#!/bin/bash

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then
  echo "错误：请使用 sudo 运行此脚本，例如：sudo ./deploy_rsshub.sh"
  exit 1
fi

echo "--- RSSHub Debian 非 Docker 一键部署脚本 ---"
echo "此脚本将安装 RSSHub 及其依赖，并使用 PM2 进行进程管理。"
echo "-------------------------------------------------"

# 1. 更新系统软件包
echo ">>> 1. 正在更新系统软件包..."
apt update && apt upgrade -y
if [ $? -ne 0 ]; then
    echo "错误：系统软件包更新失败，请检查网络连接或源配置。"
    exit 1
fi
echo "系统软件包更新完成。"

# 2. 安装基本依赖：git, curl, build-essential
echo ">>> 2. 正在检查并安装基本依赖 (git, curl, build-essential)..."
INSTALL_BASIC_DEPS=false

if ! command -v git &> /dev/null; then
    echo "  - Git 未安装。"
    INSTALL_BASIC_DEPS=true
fi
if ! command -v curl &> /dev/null; then
    echo "  - Curl 未安装。"
    INSTALL_BASIC_DEPS=true
fi

if [ "$INSTALL_BASIC_DEPS" = true ]; then
    echo "  正在安装 Git, Curl 和 Build-essential..."
    apt install -y git curl build-essential
    if [ $? -ne 0 ]; then
        echo "错误：基本依赖安装失败。"
        exit 1
    fi
    echo "基本依赖安装完成。"
else
    echo "  Git 和 Curl 已安装。Build-essential 将被检查并更新（如果需要）。"
    apt install -y build-essential # 确保 build-essential 存在且是最新的
    echo "基本依赖检查完成。"
fi

# 3. 安装 Node.js (LTS 版本)
echo ">>> 3. 正在检查并安装 Node.js LTS 版本..."
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "  Node.js 或 npm 未安装，正在安装 Node.js LTS 版本..."
    # 添加 NodeSource APT 仓库
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    if [ $? -ne 0 ]; then
        echo "错误：Node.js 安装源配置失败。"
        exit 1
    fi
    # 安装 Node.js
    apt install -y nodejs
    if [ $? -ne 0 ]; then
        echo "错误：Node.js 安装失败。"
        exit 1
    fi
    echo "Node.js 安装完成。版本信息："
    node -v
    npm -v
else
    echo "  Node.js 和 npm 已安装。版本信息："
    node -v
    npm -v
fi

# 4. 安装 Chromium (用于支持 puppeteer 依赖的路由)
echo ">>> 4. 正在检查并安装 Chromium 浏览器 (用于支持需要 puppeteer 的路由)..."
# 检查 chromium 或 chromium-browser 命令是否存在
if ! command -v chromium &> /dev/null && ! command -v chromium-browser &> /dev/null; then
    echo "  Chromium 浏览器未安装，正在安装..."
    apt install -y chromium
    if [ $? -ne 0 ]; then
        echo "警告：Chromium 浏览器安装失败，部分需要 puppeteer 的 RSSHub 路由可能无法正常工作。"
    else
        echo "Chromium 浏览器安装完成。"
    fi
else
    echo "  Chromium 浏览器已安装。"
fi

# 5. 安装 PM2 (Node.js 进程管理工具)
echo ">>> 5. 正在检查并安装 PM2 (Node.js 进程管理工具)..."
if ! command -v pm2 &> /dev/null; then
    echo "  PM2 未安装，正在安装..."
    npm install -g pm2
    if [ $? -ne 0 ]; then
        echo "错误：PM2 安装失败。"
        exit 1
    fi
    echo "PM2 安装完成。"
else
    echo "  PM2 已安装。"
fi

# 6. 下载或更新 RSSHub 源码
echo ">>> 6. 正在下载/更新 RSSHub 源码到 /opt/RSSHub..."
RSSHUB_DIR="/opt/RSSHub"
if [ -d "$RSSHUB_DIR" ]; then
    echo "目录 $RSSHUB_DIR 已存在，将尝试更新源码。"
    cd "$RSSHUB_DIR"
    git pull
else
    git clone https://github.com/DIYgod/RSSHub.git "$RSSHUB_DIR"
    if [ $? -ne 0 ]; then
        echo "错误：RSSHub 源码下载失败。"
        exit 1
    fi
    cd "$RSSHUB_DIR"
fi
echo "RSSHub 源码下载/更新完成。"

# 7. 安装 RSSHub 依赖
echo ">>> 7. 正在安装 RSSHub 项目所有依赖 (包括开发依赖)..."
# 将 npm install --production 改为 npm install
npm install
if [ $? -ne 0 ]; then
    echo "错误：RSSHub 依赖安装失败。"
    exit 1
fi
echo "RSSHub 依赖安装完成。"

# 8. 编译 RSSHub
echo ">>> 8. 正在编译 RSSHub..."
npm run build
if [ $? -ne 0 ]; then
    echo "错误：RSSHub 编译失败。"
    exit 1
fi
echo "RSSHub 编译完成。"

# 9. 启动 RSSHub (使用 PM2)
echo ">>> 9. 正在使用 PM2 启动 RSSHub..."
# 检查是否已存在名为 rsshub 的 pm2 进程
pm2 describe rsshub > /dev/null
if [ $? -eq 0 ]; then
    echo "PM2 中已存在名为 'rsshub' 的进程，将尝试重启。"
    pm2 restart rsshub
else
    pm2 start lib/index.js --name rsshub
fi

if [ $? -ne 0 ]; then
    echo "错误：RSSHub 启动失败，请检查日志。"
    exit 1
fi
pm2 save # 保存当前进程列表
pm2 startup systemd # 配置 PM2 开机自启
echo "RSSHub 已成功启动并设置为开机自启。"

# 10. 配置防火墙 (如果安装了ufw)
echo ">>> 10. 正在尝试配置防火墙以允许访问 1200 端口..."
if command -v ufw &> /dev/null; then
    echo "  UFW 防火墙已安装。"
    ufw allow 1200/tcp
    ufw --force enable # 强制启用，避免交互式提示
    echo "  UFW 防火墙已配置并启用，1200 端口已放行。"
else
    echo "  未检测到 UFW 防火墙，请手动确保 1200 端口已开放。"
    echo "  例如，对于 Debian 10+，可以使用 'sudo apt install ufw' 安装，然后运行 'sudo ufw allow 1200/tcp && sudo ufw enable'。"
fi

# 11. 提示信息
echo "--- RSSHub 部署完成！---"
echo "您现在可以通过以下地址访问 RSSHub："
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "http://${SERVER_IP}:1200"
echo "或者使用您的服务器域名（如果已配置）: http://您的域名:1200"
echo ""
echo "重要提示和后续操作："
echo "1. RSSHub 默认运行在 1200 端口。"
echo "2. **配置 RSSHub**：如需配置 RSSHub (例如缓存类型、GitHub Token等)，请编辑 `/opt/RSSHub/.env` 文件。"
echo "   示例 `.env` 文件内容（请根据需要修改或添加）："
echo "   \`\`\`"
echo "   CACHE_TYPE=memory" # 默认为 memory，可改为 redis
echo "   CACHE_EXPIRE=3600" # 缓存过期时间，单位秒
echo "   # 如果您部署了 Redis，请取消注释并填写 Redis URL"
echo "   # REDIS_URL=redis://localhost:6379/"
echo "   # 如果您在 ARM/ARM64 架构上遇到 puppeteer 问题，请尝试设置："
echo "   # CHROMIUM_EXECUTABLE_PATH=chromium"
echo "   \`\`\`"
echo "   修改 \`.env\` 文件后，请运行 \`cd /opt/RSSHub && pm2 restart rsshub\` 使配置生效。"
echo "3. **更新 RSSHub**：进入 \`/opt/RSSHub\` 目录，执行以下命令以更新到最新版本并重启："
echo "   \`git pull && npm install --production && npm run build && pm2 restart rsshub\`"
echo "4. **查看 RSSHub 运行状态**：\`pm2 status\`"
echo "5. **查看 RSSHub 日志**：\`pm2 logs rsshub\`"
echo "6. 此脚本未包含 Nginx 等反向代理配置，如需通过 80/443 端口访问并配置 HTTPS，请自行配置 Nginx 或 Caddy。"
echo "-------------------------------------------------"
