#!/bin/sh

# =========================================================
# Komari Agent 禁用 WebSSH 脚本
# 适配:
#   - Debian / Ubuntu (systemd)
#   - Alpine Linux (OpenRC / systemd)
#
# 功能:
#   1. 检查 komari-agent.service 是否存在
#   2. 检查是否已包含 --disable-web-ssh
#   3. 若不存在则自动追加
#   4. 自动重载并重启服务
#
# 用法:
#   sh disable-komari-webssh.sh
# =========================================================

set -eu

SERVICE_FILE="/etc/systemd/system/komari-agent.service"
FLAG="--disable-web-ssh"

echo "[INFO] 检查 Komari Agent 服务文件..."

if [ ! -f "$SERVICE_FILE" ]; then
    echo "[ERROR] 未找到: $SERVICE_FILE"
    exit 1
fi

echo "[INFO] 检查是否已禁用 WebSSH..."

if grep -q -- "$FLAG" "$SERVICE_FILE"; then
    echo "[OK] 已存在 $FLAG ，无需修改"
else
    echo "[INFO] 正在写入 $FLAG ..."

    # 备份
    cp "$SERVICE_FILE" "${SERVICE_FILE}.bak.$(date +%s)"

    # 仅修改 ExecStart 行
    sed -i "/^ExecStart=/{
        /$FLAG/! s|\$| $FLAG|
    }" "$SERVICE_FILE"

    echo "[OK] 已追加参数"
fi

echo "[INFO] 检查 init 系统..."

# systemd
if command -v systemctl >/dev/null 2>&1; then
    echo "[INFO] 使用 systemd 重载服务..."

    systemctl daemon-reload
    systemctl restart komari-agent

    echo "[OK] systemd 服务已重启"

# OpenRC（部分 Alpine）
elif command -v rc-service >/dev/null 2>&1; then
    echo "[INFO] 检测到 OpenRC"

    rc-service komari-agent restart || true

    echo "[OK] OpenRC 服务已重启"

else
    echo "[WARN] 未识别 init 系统，请手动重启 komari-agent"
fi

echo
echo "[DONE] Komari WebSSH 已关闭"