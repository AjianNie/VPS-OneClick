#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

DEFAULT_PORT="3128"
DEFAULT_WHITELIST="127.0.0.1"
SQUID_CONF="/etc/squid/squid.conf"
SQUID_PASSWD="/etc/squid/passwd"

cleanup_env() {
  unset squid_user squid_password
}
trap cleanup_env EXIT
trap cleanup_env RETURN

log() {
  printf '%s\n' "$*"
}

warn() {
  printf '警告: %s\n' "$*" >&2
}

die() {
  printf '错误: %s\n' "$*" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

pkg_mgr() {
  if have_cmd apt-get; then
    printf '%s' apt-get
    return 0
  fi
  if have_cmd apk; then
    printf '%s' apk
    return 0
  fi
  return 1
}

is_alpine() {
  [[ -f /etc/alpine-release ]] || [[ "$(pkg_mgr 2>/dev/null || true)" == "apk" ]]
}

as_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

urlencode() {
  python3 - "$1" <<'PY'
import sys
from urllib.parse import quote
print(quote(sys.argv[1], safe=''))
PY
}

random_alnum() {
  python3 - "$1" <<'PY'
import random
import string
import sys

length = int(sys.argv[1])
alphabet = string.ascii_letters + string.digits
print("".join(random.SystemRandom().choice(alphabet) for _ in range(length)))
PY
}

detect_host_ip() {
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  if [[ -z "${ip:-}" ]]; then
    ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}')"
  fi
  printf '%s' "${ip:-127.0.0.1}"
}

pick_basic_auth_bin() {
  local candidate
  for candidate in \
    /usr/lib/squid/basic_ncsa_auth \
    /usr/lib64/squid/basic_ncsa_auth \
    /usr/libexec/squid/basic_ncsa_auth
  do
    if [[ -x "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  if have_cmd basic_ncsa_auth; then
    command -v basic_ncsa_auth
    return 0
  fi
  return 1
}

port_in_use() {
  local port="$1"
  as_root ss -ltn "( sport = :${port} )" 2>/dev/null | awk 'NR > 1 {found = 1} END {exit found ? 0 : 1}'
}

port_used_by_squid() {
  local port="$1"
  as_root ss -ltnp "( sport = :${port} )" 2>/dev/null | grep -qi 'squid'
}

prompt_yes_no() {
  local prompt="$1"
  local answer
  read -r -p "${prompt} [Y/n]: " answer
  case "${answer:-Y}" in
    Y|y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

join_ips() {
  local -a ips=("$@")
  printf '%s' "${ips[*]}"
}

prompt_tty() {
  local prompt="$1"
  local __resultvar="$2"
  local reply=""

  if [[ -r /dev/tty && -w /dev/tty ]]; then
    printf '%s' "$prompt" >/dev/tty
    if IFS= read -r reply </dev/tty; then
      printf -v "$__resultvar" '%s' "$reply"
      return 0
    fi
  fi

  return 1
}

is_sourced() {
  [[ "${BASH_SOURCE[0]}" != "$0" ]]
}

account_exists() {
  local name="$1"
  [[ -r /etc/passwd ]] && grep -qE "^${name}:" /etc/passwd
}

group_exists() {
  local name="$1"
  [[ -r /etc/group ]] && grep -qE "^${name}:" /etc/group
}

pick_squid_owner() {
  if is_alpine; then
    if account_exists squid && group_exists squid; then
      printf '%s' "squid:squid"
      return 0
    fi
    if account_exists proxy && group_exists proxy; then
      printf '%s' "proxy:proxy"
      return 0
    fi
  else
    if account_exists proxy && group_exists proxy; then
      printf '%s' "proxy:proxy"
      return 0
    fi
    if account_exists squid && group_exists squid; then
      printf '%s' "squid:squid"
      return 0
    fi
  fi
  return 1
}

ensure_packages() {
  local mgr
  mgr="$(pkg_mgr)" || die "未找到可用的包管理器（apt-get 或 apk）"
  log "检查并安装依赖：squid / apache2-utils"
  case "$mgr" in
    apt-get)
      as_root apt-get update
      as_root apt-get install -y squid apache2-utils
      ;;
    apk)
      as_root apk add --no-cache squid apache2-utils openrc squid-openrc
      ;;
  esac
}

ensure_python3() {
  if have_cmd python3; then
    return 0
  fi

  local mgr
  mgr="$(pkg_mgr)" || die "缺少 python3，且未找到可用的包管理器（apt-get 或 apk）"

  log "检查并安装依赖：python3"
  case "$mgr" in
    apt-get)
      as_root apt-get update
      as_root apt-get install -y python3
      ;;
    apk)
      as_root apk add --no-cache python3
      ;;
  esac

  have_cmd python3 || die "python3 安装完成后仍不可用"
}

ensure_ufw() {
  if have_cmd ufw; then
    return 0
  fi
  local mgr
  mgr="$(pkg_mgr)" || return 1
  log "检测到 ufw 未安装，正在安装"
  case "$mgr" in
    apt-get)
      if ! as_root apt-get update || ! as_root apt-get install -y ufw; then
        warn "ufw 安装失败，已跳过自动放行"
        return 1
      fi
      ;;
    apk)
      if ! as_root apk add --no-cache ufw; then
        warn "当前环境无法安装 ufw，已跳过自动放行"
        return 1
      fi
      ;;
  esac
  have_cmd ufw
}

start_squid_service() {
  if is_alpine; then
    if ! have_cmd rc-service || ! have_cmd rc-update; then
      if have_cmd apk; then
        log "Alpine: 检测到 OpenRC 工具缺失，正在安装 openrc"
        as_root apk add --no-cache openrc
      fi
    fi

    have_cmd rc-service || die "Alpine 环境缺少 rc-service，无法启动 squid"
    have_cmd rc-update || die "Alpine 环境缺少 rc-update，无法设置 squid 开机启动"

    as_root rc-update add squid default
    if ! as_root rc-service squid restart; then
      as_root rc-service squid start
    fi
    return 0
  fi

  as_root systemctl enable squid
  as_root systemctl restart squid
}

main() {
  if ! have_cmd sudo && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "需要 root 权限或可用的 sudo"
  fi

  ensure_python3

  log "步骤 0: 读取环境变量"
  local env_user=""
  local env_password=""
  local had_env_user=0
  local had_env_password=0
  local username=""
  local password=""
  local auto_generate_creds=0

  env_user="${squid_user:-}"
  env_password="${squid_password:-}"
  [[ -n "${env_user}" ]] && had_env_user=1
  [[ -n "${env_password}" ]] && had_env_password=1

  if [[ -n "${env_user}" ]]; then
    username="${env_user}"
    log "0.1 用户名: 已读取 squid_user"
  else
    warn "0.1 用户名: 未设置 squid_user"
    log 'export squid_user="proxyuser"'
  fi

  if [[ -n "${env_password}" ]]; then
    password="${env_password}"
    log "0.2 密码: 已读取 squid_password"
  else
    warn "0.2 密码: 未设置 squid_password"
    log 'export squid_password="your_password"'
  fi

  if [[ -z "${env_user}" && -z "${env_password}" ]]; then
    local choice=""
    if prompt_tty "0.3 选择: 1) 停止并导入变量  2) 继续并自动生成\n0.3 请输入 [1/2] (默认 2): " choice; then
      case "${choice:-2}" in
        1)
          log "0.3.1 导入: export squid_user=\"proxyuser\"; export squid_password=\"your_password\""
          log "0.3.2 完成后重跑: ./scripts/squid.sh"
          if is_sourced; then
            return 0
          fi
          exit 0
          ;;
        2|"")
          auto_generate_creds=1
          log "0.3.2 继续: 将自动生成用户名和密码"
          ;;
        *)
          die "无效选择，仅支持 1 或 2"
          ;;
      esac
    else
      auto_generate_creds=1
      log "0.3.2 继续: 未检测到 TTY，自动生成用户名和密码"
    fi
  fi

  log "步骤 1: IP 白名单"
  local whitelist_input
  read -r -p "白名单(IP，空格分隔) [127.0.0.1]: " whitelist_input
  whitelist_input="${whitelist_input:-$DEFAULT_WHITELIST}"
  whitelist_input="${whitelist_input//,/ }"
  local -a whitelist=()
  read -r -a whitelist <<< "${whitelist_input}"
  if [[ "${#whitelist[@]}" -eq 0 ]]; then
    whitelist=("$DEFAULT_WHITELIST")
  fi

  log "步骤 2: 监听端口"
  local port=""
  while :; do
    read -r -p "端口 [3128]: " port
    port="${port:-$DEFAULT_PORT}"
    if [[ ! "$port" =~ ^[0-9]{1,5}$ ]] || (( port < 1 || port > 65535 )); then
      warn "端口无效，请输入 1-65535。"
      continue
    fi

    if port_in_use "$port"; then
      if port_used_by_squid "$port"; then
        warn "端口 ${port} 已由 squid 使用"
        break
      fi
      warn "端口 ${port} 已被占用"
      continue
    fi
    break
  done

  log "步骤 3: 用户名"
  if [[ -z "$username" ]]; then
    if (( auto_generate_creds == 1 )); then
      username="proxy$(random_alnum 8)"
      log "用户名: 已自动生成"
    else
      while :; do
        read -r -p "用户名: " username
        if [[ -n "$username" ]]; then
          break
        fi
        warn "用户名不能为空"
      done
    fi
  else
    log "用户名: 使用环境变量"
  fi

  log "步骤 4: 密码"
  if [[ -z "$password" ]]; then
    if (( auto_generate_creds == 1 )); then
      password="$(random_alnum 12)"
      log "密码: 已自动生成"
    else
      local password_input=""
      read -r -s -p "密码(回车自动生成12位): " password_input
      printf '\n'
      if [[ -z "$password_input" ]]; then
        password="$(random_alnum 12)"
        log "密码: 已自动生成"
      else
        password="$password_input"
      fi
    fi
  else
    log "密码: 使用环境变量"
  fi

  log "步骤 5: UFW"
  local ufw_enabled=0
  if prompt_yes_no "UFW自动放行"; then
    if ensure_ufw; then
      ufw_enabled=1
    fi
  fi

  log "步骤 6: 安装与配置 Squid"
  ensure_packages

  local auth_bin
  auth_bin="$(pick_basic_auth_bin)" || die "未找到 basic_ncsa_auth，可确认 squid/apache2-utils 是否安装成功。"

  if [[ -f "$SQUID_CONF" ]]; then
    local backup
    backup="/etc/squid/squid.conf.bak.$(date +%Y%m%d%H%M%S)"
    as_root cp -a "$SQUID_CONF" "$backup"
    log "已备份原配置到: ${backup}"
  fi

  local whitelist_line
  whitelist_line="$(join_ips "${whitelist[@]}")"

  log "写入配置"
  as_root tee "$SQUID_CONF" >/dev/null <<EOF
# ============================================================================
# Squid 配置文件 - 自动生成
# 生成时间: $(date)
# ============================================================================

auth_param basic program ${auth_bin} ${SQUID_PASSWD}
auth_param basic realm "Squid Proxy - Authentication Required"

acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777

acl localnet src 127.0.0.1
acl allowed_ips src ${whitelist_line}
acl authenticated proxy_auth REQUIRED
acl CONNECT method CONNECT

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localnet
http_access allow allowed_ips
http_access allow authenticated
http_access deny all

http_port ${port}
cache_dir ufs /var/spool/squid 100 16 100
coredump_dir /var/spool/squid
visible_hostname squid.proxy.local

access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log
EOF

  log "生成账号文件"
  as_root htpasswd -bc "$SQUID_PASSWD" "$username" "$password"
  local squid_owner
  if squid_owner="$(pick_squid_owner)"; then
    as_root chown "$squid_owner" "$SQUID_PASSWD"
  else
    warn "未识别到 proxy 或 squid 账号，已保留默认属主"
  fi
  as_root chmod 640 "$SQUID_PASSWD"

  log "检查配置语法"
  as_root squid -k parse

  log "启动服务"
  start_squid_service

  if (( ufw_enabled == 1 )); then
    log "放行 UFW 端口"
    as_root ufw allow "${port}/tcp"
    if as_root ufw status | grep -qi "Status: active"; then
      as_root ufw reload
    fi
  fi

  local server_ip proxy_url test_url enc_user enc_pass
  server_ip="$(detect_host_ip)"
  enc_user="$(urlencode "$username")"
  enc_pass="$(urlencode "$password")"
  proxy_url="http://${enc_user}:${enc_pass}@${server_ip}:${port}"
  test_url="curl -v -x \"${proxy_url}\" https://www.google.com"

  log ""
  log "结果"
  log "代理: ${proxy_url}"
  log "测试: ${test_url}"
  if (( had_env_user == 1 )) || (( had_env_password == 1 )); then
    local cleared_vars=()
    (( had_env_user == 1 )) && cleared_vars+=("squid_user")
    (( had_env_password == 1 )) && cleared_vars+=("squid_password")
    log "已清除: ${cleared_vars[*]}"
  fi
}

main "$@"
