#!/bin/bash

# 定义要替换的目标文件
JOURNALD_CONF="/etc/systemd/journald.conf"

# 定义新的文件内容
NEW_CONTENT='
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it under the
#  terms of the GNU Lesser General Public License as published by the Free
#  Software Foundation; either version 2.1 of the License, or (at your option)
#  any later version.
#
# Entries in this file show the compile time defaults. Local configuration
# should be created by either modifying this file, or by creating "drop-ins" in
# the journald.conf.d/ subdirectory. The latter is generally recommended.
# Defaults can be restored by simply deleting this file and all drop-ins.
#
# Use "systemd-analyze cat-config systemd/journald.conf" to display the full config.
#
# See journald.conf(5) for details.

[Journal]
Storage=persistent
Compress=yes
#Seal=yes
#SplitMode=uid
#SyncIntervalSec=5m
#RateLimitIntervalSec=30s
#RateLimitBurst=10000
SystemMaxUse=300M
#SystemKeepFree=
SystemMaxFileSize=50M
#SystemMaxFiles=100
#RuntimeMaxUse=
#RuntimeKeepFree=
#RuntimeMaxFileSize=
#RuntimeMaxFiles=100
MaxRetentionSec=7day
#MaxFileSec=1month
#ForwardToSyslog=yes
#ForwardToKMsg=no
#ForwardToConsole=no
#ForwardToWall=yes
#TTYPath=/dev/console
#MaxLevelStore=debug
#MaxLevelSyslog=debug
#MaxLevelKMsg=notice
#MaxLevelConsole=info
#MaxLevelWall=emerg
#LineMax=48K
#ReadKMsg=yes
#Audit=no
'

# 检查脚本是否以root用户权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "此脚本需要root权限才能运行。请使用 sudo 执行。"
    exit 1
fi

echo "正在备份原始的 $JOURNALD_CONF 文件..."
cp "$JOURNALD_CONF" "${JOURNALD_CONF}.bak_$(date +%Y%m%d%H%M%S)"

if [ $? -eq 0 ]; then
    echo "备份成功。"
else
    echo "备份失败，请检查权限或磁盘空间。"
    exit 1
fi

echo "正在替换 $JOURNALD_CONF 的内容..."
echo "$NEW_CONTENT" | tee "$JOURNALD_CONF" > /dev/null

if [ $? -eq 0 ]; then
    echo "文件内容替换成功。"
    echo "正在重新加载 systemd-journald 配置..."
    systemctl restart systemd-journald
    if [ $? -eq 0 ]; then
        echo "systemd-journald 服务已成功重启。"
    else
        echo "systemd-journald 服务重启失败，请手动检查。"
    fi
else
    echo "文件内容替换失败，请检查权限或磁盘空间。"
    exit 1
fi

echo "脚本执行完毕。"
