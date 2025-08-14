#!/usr/bin/env bash
#
# uninstall-uptime-kuma.sh
# 一键完全卸载 Uptime Kuma（非 Docker 安装）
# 使用前请确保脚本具有可执行权限：chmod +x uninstall-uptime-kuma.sh
# 然后以 root 或 sudo 用户运行：sudo ./uninstall-uptime-kuma.sh

set -e

# —————— 配置 ——————
# 请根据实际安装位置修改
INSTALL_DIR="/opt/uptime-kuma"

# —————— 脚本开始 ——————
echo "=== 开始卸载 Uptime Kuma ==="

# 1. 停止并删除 PM2 进程
if command -v pm2 >/dev/null 2>&1; then
  echo "→ 停止并删除 PM2 进程 uptime-kuma"
  pm2 stop uptime-kuma 2>/dev/null || true
  pm2 delete uptime-kuma 2>/dev/null || true

  # 2. 取消 PM2 开机自启
  echo "→ 取消 PM2 开机自启配置"
  pm2 unstartup >/dev/null 2>&1 || true
else
  echo "→ 未检测到 PM2，跳过进程停止与自启取消"
fi

# 3. 全局卸载 PM2 及其日志轮转插件
if command -v npm >/dev/null 2>&1; then
  echo "→ 卸载全局 PM2 及 pm2-logrotate"
  npm uninstall -g pm2 pm2-logrotate 2>/dev/null || true
else
  echo "→ 未检测到 npm，跳过全局卸载 PM2"
fi

# 4. 删除 Uptime Kuma 安装目录
if [ -d "$INSTALL_DIR" ]; then
  echo "→ 删除安装目录：$INSTALL_DIR"
  rm -rf "$INSTALL_DIR"
else
  echo "→ 未找到安装目录：$INSTALL_DIR，跳过删除"
fi

# 5. 清理 PM2 残留文件
PM2_HOME="${PM2_HOME:-$HOME/.pm2}"
if [ -d "$PM2_HOME" ]; then
  echo "→ 清理 PM2 配置与日志：$PM2_HOME"
  rm -rf "$PM2_HOME"
fi

echo "=== 卸载完成：Uptime Kuma 已被完全移除 ==="
