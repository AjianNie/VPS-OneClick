#!/bin/bash
# 一键安装 Docker 脚本 - 适配 Debian 10/11/12
# 需要以 root 权限运行（或 sudo 执行）

set -e

echo "=== 更新软件包列表 ==="
sudo apt update -y

echo "=== 安装必要依赖 ==="
sudo apt install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common lsb-release

echo "=== 添加 Docker 官方 GPG 密钥 ==="
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "=== 添加 Docker 官方仓库源 ==="
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== 更新软件包并安装 Docker Engine ==="
sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io

echo "=== 启动并设置 Docker 开机自启 ==="
sudo systemctl start docker
sudo systemctl enable docker

echo "=== 将当前用户添加到 docker 组（免 sudo 运行 docker） ==="
sudo usermod -aG docker $USER

echo "=== 验证 Docker 版本 ==="
docker --version

echo "=== 运行测试镜像 hello-world ==="
docker run hello-world

echo "=== Docker 安装完成！请注销并重新登录以应用用户组变更 ==="
