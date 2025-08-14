#!/bin/bash

# 非docker安装方式的一键rsshub卸载

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then
  echo "错误：请使用 sudo 运行此脚本，例如：sudo ./cleanup_rsshub.sh"
  exit 1
fi

echo "--- RSSHub 完全清除脚本 (安全模式，不误伤其他服务) ---"
echo "此脚本旨在彻底删除所有与 RSSHub 相关的源码、编译产物、依赖、缓存和 PM2 配置。"
echo "对于可能影响系统其他服务的组件（如 Node.js、Chromium），会征求您的确认。"
echo "PM2 自身不会被卸载，其管理的其它应用的启动项和配置不受影响。"
echo "------------------------------------------------------------------"

# 定义 RSSHub 安装目录
RSSHUB_DIR="/opt/RSSHub"

echo ">>> 1. 停止并删除 RSSHub 的 PM2 进程..."
# 停止并删除名为 'rsshub' 的 PM2 进程
pm2 stop rsshub 2>/dev/null
pm2 delete rsshub 2>/dev/null
# 重新保存 PM2 进程列表，以移除 rsshub 进程的记录
# 注意：这会保存当前所有正在运行的PM2进程，如果其他进程没有自动保存，可能需要手动保存
pm2 save 2>/dev/null
echo "RSSHub 的 PM2 进程已停止并从列表中移除。"

echo ">>> 2. 删除 RSSHub 源码目录 ($RSSHUB_DIR)，包含所有编译产物和项目依赖..."
if [ -d "$RSSHUB_DIR" ]; then
    rm -rf "$RSSHUB_DIR"
    echo "目录 $RSSHUB_DIR 已删除。"
else
    echo "目录 $RSSHUB_DIR 不存在，跳过删除。"
fi

echo ">>> 3. 卸载全局安装的 pnpm (如果它只为 RSSHub 安装)..."
# 注意：如果 pnpm 还被其他项目使用，请勿执行此步骤
if command -v pnpm &> /dev/null; then
    read -p "是否卸载全局安装的 pnpm？(y/N) " -n 1 -r
    echo # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        npm uninstall -g pnpm
        echo "pnpm 已卸载。"
    else
        echo "跳过 pnpm 卸载。"
    fi
else
    echo "pnpm 未安装，跳过卸载。"
fi

echo ">>> 4. 卸载 Node.js, npm 和 Chromium 软件包..."
# 卸载 Node.js 和 npm
# 再次提醒：如果系统其他应用依赖Node.js，请勿执行此步骤
if dpkg -s nodejs &> /dev/null; then
    read -p "是否卸载 Node.js 和 npm？(y/N) " -n 1 -r
    echo # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apt purge -y nodejs
        echo "Node.js 和 npm 已卸载。"
    else
        echo "跳过 Node.js 和 npm 卸载。"
    fi
else
    echo "Node.js 未安装，跳过卸载。"
fi

# 卸载 Chromium
# 再次提醒：如果系统其他应用依赖Chromium，请勿执行此步骤
if dpkg -s chromium &> /dev/null || dpkg -s chromium-browser &> /dev/null; then
    read -p "是否卸载 Chromium 浏览器？(y/N) " -n 1 -r
    echo # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apt purge -y chromium chromium-browser 2>/dev/null
        echo "Chromium 浏览器已卸载。"
    else
        echo "跳过 Chromium 浏览器卸载。"
    fi
else
    echo "Chromium 浏览器未安装，跳过卸载。"
fi

echo ">>> 5. 移除 Node.js 的 APT 仓库源..."
if [ -f "/etc/apt/sources.list.d/nodesource.list" ]; then
    read -p "是否移除 Node.js APT 仓库源？(y/N) " -n 1 -r
    echo # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm /etc/apt/sources.list.d/nodesource.list
        echo "Node.js APT 仓库源已移除。"
    else
        echo "跳过 Node.js APT 仓库源移除。"
    fi
else
    echo "Node.js APT 仓库源文件不存在，跳过移除。"
fi

echo ">>> 6. 清理 pnpm 全局存储 (可能占用大量空间)..."
# pnpm store 的位置通常在 ~/.pnpm-store 或 /usr/local/share/pnpm/store
# 查找 pnpm store 的实际路径
PNPM_STORE_PATH=$(pnpm store path 2>/dev/null)
if [ -n "$PNPM_STORE_PATH" ]; then
    echo "检测到 pnpm 全局存储路径: $PNPM_STORE_PATH"
    read -p "是否清理 pnpm 全局存储？(这将删除所有 pnpm 项目的共享依赖缓存，y/N) " -n 1 -r
    echo # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pnpm store prune # 清理未被引用的包
        if [ $? -eq 0 ]; then
            echo "pnpm 全局存储已清理 (prune)。"
        else
            echo "pnpm 全局存储清理失败 (prune)。"
        fi
        # 如果需要更彻底的删除整个store，可以执行 rm -rf "$PNPM_STORE_PATH"
        # 但这非常激进，通常不推荐，除非确信没有其他pnpm项目
    else
        echo "跳过 pnpm 全局存储清理。"
    fi
else
    echo "未检测到 pnpm 全局存储，跳过清理。"
fi

echo ">>> 7. 清理 npm 缓存..."
if command -v npm &> /dev/null; then
    read -p "是否清理 npm 缓存？(y/N) " -n 1 -r
    echo # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        npm cache clean --force
        echo "npm 缓存已清理。"
    else
        echo "跳过 npm 缓存清理。"
    fi
else
    echo "npm 未安装，跳过缓存清理。"
fi

echo ">>> 8. 清理 PM2 日志文件..."
# PM2 日志通常在 ~/.pm2/logs
# 尝试获取 PM2_HOME 环境变量，如果未设置，则默认为 ~/.pm2
PM2_HOME_DIR=$(pm2 env | grep 'PM2_HOME' | cut -d '=' -f 2 | tr -d "'" | xargs echo)
if [ -z "$PM2_HOME_DIR" ]; then
    PM2_HOME_DIR="$HOME/.pm2"
fi
PM2_LOGS_DIR="$PM2_HOME_DIR/logs"

if [ -d "$PM2_LOGS_DIR" ]; then
    echo "检测到 PM2 日志目录: $PM2_LOGS_DIR"
    read -p "是否清理 PM2 日志文件？(y/N) " -n 1 -r
    echo # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$PM2_LOGS_DIR"/*
        echo "PM2 日志文件已清理。"
    else
        echo "跳过 PM2 日志文件清理。"
    fi
else
    echo "PM2 日志目录不存在或无法确定，跳过清理。"
fi


echo ">>> 9. 移除 UFW 防火墙规则 (如果存在)..."
if command -v ufw &> /dev/null; then
    ufw delete allow 1200/tcp 2>/dev/null
    echo "UFW 1200 端口规则已移除。"
else
    echo "UFW 未安装，跳过防火墙规则移除。"
fi

echo ">>> 10. 清理 APT 缓存..."
apt autoremove -y
apt clean
echo "APT 缓存已清理。"

echo "--- RSSHub 清除完成！---"
echo "请注意：基础系统工具 (如 git, curl, build-essential) 未被卸载。"
echo "PM2 自身未被卸载，其管理的其它应用不受影响。"
echo "如果您需要重新部署，请再次运行部署脚本。"
echo "清理后，您可以使用 'df -h' 再次检查磁盘空间。"
echo "-------------------------------------------------"
