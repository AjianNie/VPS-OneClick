#!/usr/bin/env bash

echo "==========================================="
echo "一键卸载 RSS-to-Telegram-Bot 项目"
echo "此脚本将删除项目文件和pm2配置，但保留系统级工具。"
echo "==========================================="

read -p "警告：此操作将永久删除 RSS-to-Telegram-Bot 的所有数据和配置。确定要继续吗？(y/N): " confirm_uninstall
if [[ ! "$confirm_uninstall" =~ ^[yY]$ ]]; then
    echo "卸载已取消。"
    exit 0
fi

set -euo pipefail

PROJECT_DIR="$HOME/rsstt"
PM2_PROCESS_NAME="rsstt"

echo "==> 1. 停止并删除 pm2 进程 '$PM2_PROCESS_NAME'…"
if pm2 list | grep -q "$PM2_PROCESS_NAME"; then
    pm2 stop "$PM2_PROCESS_NAME" || true # 即使停止失败也继续
    pm2 delete "$PM2_PROCESS_NAME" || true # 即使删除失败也继续
    echo "pm2 进程 '$PM2_PROCESS_NAME' 已停止并删除。"
else
    echo "未找到 pm2 进程 '$PM2_PROCESS_NAME'，跳过停止/删除。"
fi

echo "==> 2. 删除项目目录：$PROJECT_DIR…"
if [ -d "$PROJECT_DIR" ]; then
    rm -rf "$PROJECT_DIR"
    echo "项目目录 '$PROJECT_DIR' 已删除。"
else
    echo "项目目录 '$PROJECT_DIR' 不存在，跳过删除。"
fi

echo "==> 3. 保存 pm2 状态 (移除已删除的进程配置)…"
pm2 save

echo "==========================================="
echo "RSS-to-Telegram-Bot 项目已成功卸载。"
echo "以下系统级工具已保留："
echo "- Python 3 及其虚拟环境工具"
echo "- Node.js 和 npm"
echo "- pm2 (及其日志轮转模块)"
echo "- 中文字体 (fonts-wqy-microhei)"
echo "==========================================="
echo "如果您想完全移除 pm2 或 Node.js，需要单独执行相关命令。"
echo "例如，卸载 pm2: sudo npm uninstall -g pm2"
echo "卸载 Node.js: sudo apt purge nodejs && sudo rm -rf /etc/apt/sources.list.d/nodesource.list"
