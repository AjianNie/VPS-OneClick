#!/usr/bin/env bash
#
# uninstall-uptime-kuma.sh
# 一键卸载 Uptime Kuma（非 Docker 安装），保留 PM2 及其他进程
# 使用前：chmod +x uninstall-uptime-kuma.sh
# 以 root 或 sudo 运行：sudo ./uninstall-uptime-kuma.sh

set -e

# —————— 配置 ——————
# 根据实际安装位置修改
INSTALL_DIR="/opt/uptime-kuma"

# PM2 日志目录（一般在用户家目录下）
PM2_HOME="${PM2_HOME:-$HOME/.pm2}"
LOG_DIR="$PM2_HOME/logs"

echo "=== 开始卸载 Uptime Kuma（保留 PM2）==="

# 1. 停止并删除 PM2 中的 uptime-kuma 进程
if command -v pm2 >/dev/null 2>&1; then
  echo "→ 停止 uptime-kuma 进程"
  pm2 stop uptime-kuma 2>/dev/null || true
  echo "→ 删除 uptime-kuma 进程"
  pm2 delete uptime-kuma 2>/dev/null || true
else
  echo "→ 未检测到 pm2，请先安装 pm2 或确认环境"
  exit 1
fi

# 2. 清理该进程的日志
if [ -d "$LOG_DIR" ]; then
  echo "→ 删除 uptime-kuma 日志"
  rm -f "$LOG_DIR"/uptime-kuma-out.log "$LOG_DIR"/uptime-kuma-error.log || true
fi

# 3. 删除 Uptime Kuma 安装目录
if [ -d "$INSTALL_DIR" ]; then
  echo "→ 删除安装目录：$INSTALL_DIR"
  rm -rf "$INSTALL_DIR"
else
  echo "→ 未找到安装目录：$INSTALL_DIR，已跳过"
fi

echo "=== 卸载完成：Uptime Kuma 已被移除 ==="
