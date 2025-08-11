cat > install_snell.sh <<'EOS'
#!/usr/bin/env bash
set -e

# 非交互模式，保留本地配置文件
export DEBIAN_FRONTEND=noninteractive
APT_OPTS="-y \
  -o Dpkg::Options::=--force-confdef \
  -o Dpkg::Options::=--force-confold"

# 更新并升级
sudo apt update
sudo apt upgrade $APT_OPTS

# 安装 ufw 和 wget
sudo apt install $APT_OPTS ufw wget

# 放行 SSH（假设 22）
sudo ufw allow 22/tcp

# 交互：TCP 端口
read -p "请输入需要开放的 TCP 端口（空格分隔），回车跳过: " tcp_ports
if [[ -n "$tcp_ports" ]]; then
  sudo ufw allow $tcp_ports/tcp
fi

# 交互：UDP 端口
read -p "请输入需要开放的 UDP 端口（回车继承 TCP，输入 00 不开启 UDP）: " udp_ports
if [[ "$udp_ports" == "00" ]]; then
  :
elif [[ -z "$udp_ports" && -n "$tcp_ports" ]]; then
  sudo ufw allow $tcp_ports/udp
elif [[ -n "$udp_ports" ]]; then
  sudo ufw allow $udp_ports/udp
fi

# 启用 ufw
sudo ufw --force enable

# 安装 Snell Server
wget -O snell.sh --no-check-certificate https://git.io/Snell.sh
chmod +x snell.sh
sudo ./snell.sh

echo "全部操作完成！"
EOS

chmod +x install_snell.sh
sudo ./install_snell.sh
