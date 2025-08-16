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

# 2. 卸载npm及相关依赖（含旧pm2）
echo ">>> 卸载 npm 及相关依赖..."
sudo apt purge -y npm nodejs
sudo apt autoremove -y
sudo rm -rf /usr/local/lib/node_modules/npm
sudo rm -rf /usr/local/bin/npm
sudo rm -rf /usr/bin/npm
sudo rm -rf /usr/local/bin/pm2
sudo rm -rf /usr/bin/pm2

# 3. 安装Node.js 18.x（pnpm与pm2需要）
if ! command -v node >/dev/null; then
  echo ">>> 安装Node.js 18.x ..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  sudo apt install -y nodejs
fi

# 4. 安装pnpm（如未装）
if ! command -v pnpm >/dev/null; then
  echo ">>> 安装 pnpm..."
  
  # 1. 下载并运行 pnpm 安装脚本
  curl -fsSL https://get.pnpm.io/install.sh | sh -

  # 2. 运行 pnpm setup 来配置全局目录和环境变量
  # pnpm setup 会提示用户将配置添加到 .bashrc 或 .zshrc
  # 并且在执行后，会打印出需要 source 的文件路径
  pnpm setup

  # 3. 确定 pnpm setup 写入的配置文件并 source 它
  # pnpm setup 可能会将 PNPM_HOME 设置在 ~/.bashrc, ~/.profile, ~/.zshrc 等
  # 检查这些文件，并 source 最可能被修改的那个
  # 优先检查 .bashrc，因为这是最常见的
  if [ -f "$HOME/.bashrc" ]; then
    echo ">>> Sourcing $HOME/.bashrc for pnpm environment..."
    source "$HOME/.bashrc"
  elif [ -f "$HOME/.profile" ]; then
    echo ">>> Sourcing $HOME/.profile for pnpm environment..."
    source "$HOME/.profile"
  elif [ -f "$HOME/.zshrc" ]; then # 如果你可能使用zsh
    echo ">>> Sourcing $HOME/.zshrc for pnpm environment..."
    source "$HOME/.zshrc"
  fi
  # 如果是 root 用户，并且上述路径未能生效，可以尝试明确 source /root/.bashrc
  # 但通常 $HOME/.bashrc 已经足够
  # if [ "$EUID" -eq 0 ] && [ -f "/root/.bashrc" ]; then
  #   echo ">>> Sourcing /root/.bashrc for pnpm environment (as root)..."
  #   source "/root/.bashrc"
  # fi

  # 4. 再次检查 pnpm 是否在 PATH 中
  # 这一步是关键，确保 pnpm 命令在脚本的后续部分可用
  if ! command -v pnpm >/dev/null; then
    echo "!!! 警告: pnpm 仍然无法找到。尝试手动添加 PATH。"
    # 假设 pnpm 默认安装到 ~/.local/share/pnpm
    export PATH="$HOME/.local/share/pnpm:$PATH"
    if ! command -v pnpm >/dev/null; then
      echo "!!! 错误: 即使手动添加 PATH，pnpm 仍然无法找到。请检查安装。"
      exit 1 # 退出脚本，因为 pnpm 无法使用
    fi
  fi

  echo "pnpm 安装完成并配置。"
else
  echo "pnpm 已安装。"
fi


# 5. 安装pm2（pnpm全局）
if ! command -v pm2 >/dev/null; then
  echo ">>> 使用 pnpm 安装 pm2..."
  pnpm add -g pm2
fi

# 6. 安装基础工具
for pkg in git curl build-essential; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    sudo apt update && sudo apt install -y "$pkg"
  else
    echo "  - $pkg 已安装"
  fi
done

# 7. Puppeteer依赖（仅ARM/ARM64）
ARCH=$(dpkg --print-architecture)
if [[ "$ARCH" =~ ^arm64$|^armhf$ ]]; then
  echo ">>> ARM架构，安装Chromium ..."
  sudo apt install -y chromium
  PUPPETER_PATH=$(command -v chromium || command -v chromium-browser)
else
  echo ">>> 非ARM架构，无需安装Chromium"
  PUPPETER_PATH=""
fi

# 8. 克隆或更新RSSHub源码
if [ -d RSSHub ]; then
  echo ">>> RSSHub目录存在，更新..."
  cd RSSHub && git pull
else
  echo ">>> 克隆RSSHub源码..."
  git clone https://github.com/DIYgod/RSSHub.git && cd RSSHub
fi

# 9. 用pnpm安装依赖
echo ">>> 用 pnpm 安装依赖..."
pnpm install

# 10. 用pnpm编译项目
echo ">>> 用 pnpm 编译项目..."
pnpm build

# 11. 写入 .env 环境变量（覆盖原内容）
echo ">>> 写入环境变量 .env ..."
cat > .env <<EOF
PORT=$PORT
EOF
if [ -n "$PUPPETER_PATH" ]; then
  echo "CHROMIUM_EXECUTABLE_PATH=$PUPPETER_PATH" >> .env
fi

# 12. pm2启动RSSHub
echo ">>> 用 pm2 启动 RSSHub ..."
pm2 start pnpm --name rsshub -- start

# 13. pm2设置开机自启
echo ">>> pm2 开机自启 ..."
pm2 startup systemd -u "$(whoami)" --hp "$HOME"
pm2 save

# 14. 完成提示
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
