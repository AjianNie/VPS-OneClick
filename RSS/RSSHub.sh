#!/bin/bash

echo "==========================================="
echo "全量pnpm一键部署RSSHub（Debian）"
echo "注意：因npm自身缺陷以及会导致编译失败，若非必要，建议彻底卸载npm/node相关依赖，并仅用pnpm管理，含pm2进程管理"

read -p "是否彻底清除 npm 及其相关依赖？(Y/N，默认N): " uninstall_npm
uninstall_npm=${uninstall_npm:-N}

if [[ "$uninstall_npm" =~ ^[Yy]$ ]]; then
  echo ">>> 卸载 npm 及相关依赖..."
  sudo apt purge -y npm nodejs
  sudo apt autoremove -y
  sudo rm -rf /usr/local/lib/node_modules/npm
  sudo rm -rf /usr/local/bin/npm
  sudo rm -rf /usr/bin/npm
  sudo rm -rf /usr/local/bin/pm2
  sudo rm -rf /usr/bin/pm2
  sudo rm -rf /usr/lib/node_modules
else
  echo ">>> 保留现有 npm 及相关依赖"
fi


set -e

# 1. 交互设置监听端口
read -p "请输入 RSSHub 监听端口（回车默认1200）: " PORT
PORT=${PORT:-1200}

# 2. 安装Node.js 22.x（pnpm与pm2需要）
# 检查 Node.js 版本，自动升级到 22.x（适用于Debian/Ubuntu）

REQUIRED_NODE_VER=22

CURRENT_NODE_VER="$(node -v 2>/dev/null | grep -oP '\d+' | head -1)"

if [ -z "$CURRENT_NODE_VER" ] || [ "$CURRENT_NODE_VER" -lt "$REQUIRED_NODE_VER" ]; then
  echo ">>> 当前 Node.js 版本为 ${CURRENT_NODE_VER:-未安装}，需要安装/升级到 v${REQUIRED_NODE_VER}.x"
  sudo apt purge -y nodejs
  sudo apt autoremove -y
  curl -fsSL https://deb.nodesource.com/setup_${REQUIRED_NODE_VER}.x | sudo -E bash -
  sudo apt install -y nodejs
  echo ">>> Node.js 已升级完成，当前版本：$(node -v)"
else
  echo ">>> 检测到 Node.js 已符合要求（$(node -v)），无需安装。"
fi


# 3. 安装pnpm（如未装）
if ! command -v pnpm >/dev/null; then
  echo ">>> 检测到未安装 pnpm，开始安装..."
  curl -fsSL https://get.pnpm.io/install.sh | sh -

  if [ "$EUID" -eq 0 ]; then
    export PNPM_HOME="/root/.local/share/pnpm"
  else
    export PNPM_HOME="$HOME/.local/share/pnpm"
  fi
  export PATH="$PNPM_HOME:$PATH"

  if ! command -v pnpm >/dev/null; then
    echo "❌ 错误：pnpm 安装成功但命令不可用，请检查 PATH 设置。"
    exit 1
  fi

  echo "pnpm 安装完成并配置。"
else
  echo ">>> 已检测到 pnpm 已安装，跳过安装。"
fi



# 4. 安装pm2（pnpm全局）
if ! command -v pm2 >/dev/null; then
  echo ">>> 使用 pnpm 安装 pm2..."
  pnpm add -g pm2
fi

# 5. 安装基础工具
for pkg in git curl build-essential; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    sudo apt update && sudo apt install -y "$pkg"
  else
    echo "  - $pkg 已安装"
  fi
done

# 6. Puppeteer依赖（仅ARM/ARM64）
ARCH=$(dpkg --print-architecture)
if [[ "$ARCH" =~ ^arm64$|^armhf$ ]]; then
  echo ">>> ARM架构，安装Chromium ..."
  sudo apt install -y chromium
  PUPPETER_PATH=$(command -v chromium || command -v chromium-browser)
else
  echo ">>> 非ARM架构，无需安装Chromium"
  PUPPETER_PATH=""
fi

# 7. 克隆或更新RSSHub源码
if [ -d RSSHub ]; then
  echo ">>> RSSHub目录存在，更新..."
  cd RSSHub && git pull
else
  echo ">>> 克隆RSSHub源码..."
  git clone https://github.com/DIYgod/RSSHub.git && cd RSSHub
fi

# 8. 用pnpm安装依赖
echo ">>> 用 pnpm 安装依赖..."
pnpm install

# 9. 用pnpm编译项目
echo ">>> 用 pnpm 编译项目..."
pnpm build

# 10. 写入 .env 环境变量（覆盖原内容）
echo ">>> 写入环境变量 .env ..."
cat > .env <<EOF
PORT=$PORT
EOF
if [ -n "$PUPPETER_PATH" ]; then
  echo "CHROMIUM_EXECUTABLE_PATH=$PUPPETER_PATH" >> .env
fi

# 11. pm2启动RSSHub
echo ">>> 用 pm2 启动 RSSHub ..."
pm2 start pnpm --name rsshub -- start

# 12. pm2设置开机自启
echo ">>> pm2 开机自启 ..."
pm2 startup systemd -u "$(whoami)" --hp "$HOME"
pm2 save

# 13. 完成提示
echo ""
echo ">>> 部署完成！RSSHub已开启，监听端口：$PORT"
echo "访问地址：http://$(hostname -I | awk '{print $1}'):$PORT"
cat <<TIP

可以通过设置环境变量来配置 RSSHub。在项目根目录新建一个 .env 文件，
每行以 NAME=VALUE 格式添加环境变量，例如：
CACHE_TYPE=redis
CACHE_EXPIRE=600

注意它不会覆盖已有的环境变量，更多规则请参考：https://github.com/motdotla/dotenv
该部署方式不包括 redis 依赖，如需启用 Redis，请用 Docker Compose 或自行安装 Redis。
TIP
