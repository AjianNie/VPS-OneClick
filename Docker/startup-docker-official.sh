#!/bin/bash

set -e

# 确认以 root 用户执行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 用户运行此脚本"
  exit 1
fi

echo "开始安装 Docker..."

# 更新 apt 包索引，安装依赖
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

# 添加 Docker 官方 GPG 密钥
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 添加 Docker 官方源
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

# 更新 apt 包索引
apt-get update

# 安装 Docker 组件
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 创建 Docker 配置目录并写配置文件
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "1m",
        "max-file": "2"
    },
    "experimental": true,
    "data-root": "/root/docker_data"
}
EOF

# 启动并开机启动 Docker 服务
systemctl daemon-reload
systemctl enable docker
systemctl restart docker

# 显示 Docker 版本确认安装成功
echo "Docker 版本："
docker --version

echo "Docker 安装完成！"