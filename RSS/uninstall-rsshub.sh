#!/bin/bash

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then
  echo "错误：请使用 sudo 运行此脚本，例如：sudo ./cleanup_rsshub.sh"
  exit 1
fi

echo "--- RSSHub 完全清除脚本 ---"
echo "此脚本将删除 RSSHub 及其相关依赖和配置。"
echo "-------------------------------------------------"

# 定义 RSSHub 安装目录
RSSHUB_DIR="/opt/RSSHub"

echo ">>> 1. 停止并删除 PM2 进程..."
# 停止并删除 RSSHub 进程
pm2 stop rsshub 2>/dev/null
pm2 delete rsshub 2>/dev/null
# 禁用 PM2 开机自启
pm2 unstartup systemd 2>/dev/null
# 清除 PM2 保存的进程列表
pm2 save --force 2>/dev/null # 强制保存空列表
echo "PM2 进程和开机自启配置已清除。"

echo ">>> 2. 删除 RSSHub 源码目录 ($RSSHUB_DIR)..."
if [ -d "$RSSHUB_DIR" ]; then
    rm -rf "$RSSHUB_DIR"
    echo "目录 $RSSHUB_DIR 已删除。"
else
    echo "目录 $RSSHUB_DIR 不存在，跳过删除。"
fi

echo ">>> 3. 卸载全局安装的 Node.js 包 (pnpm, pm2)..."
# 检查并卸载 pnpm
if command -v pnpm &> /dev/null; then
    npm uninstall -g pnpm
    echo "pnpm 已卸载。"
else
    echo "pnpm 未安装，跳过卸载。"
fi
# 检查并卸载 pm2 (如果之前没有通过pm2 delete删除，这里会再次处理)
if command -v pm2 &> /dev/null; then
    npm uninstall -g pm2
    echo "pm2 已卸载。"
else
    echo "pm2 未安装，跳过卸载。"
fi

echo ">>> 4. 卸载 Node.js, npm 和 Chromium 软件包..."
# 卸载 Node.js 和 npm
if dpkg -s nodejs &> /dev/null; then
    apt purge -y nodejs
    echo "Node.js 和 npm 已卸载。"
else
    echo "Node.js 未安装，跳过卸载。"
fi
# 卸载 Chromium
if dpkg -s chromium &> /dev/null || dpkg -s chromium-browser &> /dev/null; then
    apt purge -y chromium chromium-browser 2>/dev/null
    echo "Chromium 浏览器已卸载。"
else
    echo "Chromium 浏览器未安装，跳过卸载。"
fi

echo ">>> 5. 移除 Node.js 的 APT 仓库源..."
if [ -f "/etc/apt/sources.list.d/nodesource.list" ]; then
    rm /etc/apt/sources.list.d/nodesource.list
    echo "Node.js APT 仓库源已移除。"
else
    echo "Node.js APT 仓库源文件不存在，跳过移除。"
fi

echo ">>> 6. 移除 UFW 防火墙规则 (如果存在)..."
if command -v ufw &> /dev/null; then
    ufw delete allow 1200/tcp 2>/dev/null
    echo "UFW 1200 端口规则已移除。"
else
    echo "UFW 未安装，跳过防火墙规则移除。"
fi

echo ">>> 7. 清理 APT 缓存..."
apt autoremove -y
apt clean
echo "APT 缓存已清理。"

echo "--- RSSHub 清除完成！---"
echo "请注意：基础系统工具 (如 git, curl, build-essential) 未被卸载。"
echo "如果您需要重新部署，请再次运行部署脚本。"
echo "-------------------------------------------------"
