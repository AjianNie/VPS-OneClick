#!/bin/bash

echo "停止Docker服务..."
sudo systemctl stop docker.socket
sudo systemctl stop docker


echo "卸载Docker相关软件包..."
sudo apt purge -y docker-ce docker-ce-cli containerd.io docker docker-engine docker.io runc

echo "自动删除无用依赖包..."
sudo apt autoremove -y --purge

echo "删除Docker相关文件和目录..."
sudo rm -rf /etc/docker /var/lib/docker /var/run/docker.sock /var/run/docker /var/lib/containerd /run/containerd /opt/containerd

echo "删除docker用户组（如果存在）..."
sudo groupdel docker 2>/dev/null || echo "docker用户组不存在，跳过"

echo "卸载完成，检查docker命令是否还存在..."
if command -v docker >/dev/null 2>&1; then
  echo "警告：docker命令仍然存在，请手动检查"
else
  echo "docker已成功卸载"
fi
