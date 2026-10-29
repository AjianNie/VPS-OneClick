#!/usr/bin/env bash
set -e

# 1. 权限检查：必须以 root 或 sudo 运行
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31m[错误] 本脚本需要管理员权限，请使用: sudo bash $0\033[0m"
    exit 1
fi

# 2. 依赖检查：自动补全 acl 软件包
if ! command -v setfacl >/dev/null 2>&1; then
    echo -e "\033[33m[提示] 系统未检测到 setfacl，正在自动安装 acl 工具包...\033[0m"
    apt-get update -qq && apt-get install -y -qq acl
fi

# 3. 交互获取被授权用户名（默认自动识别 sudo 调用的普通用户）
DEFAULT_USER="${SUDO_USER:-vibecoding}"
read -rp "请输入需要授权的用户名 [默认: $DEFAULT_USER]: " INPUT_USER </dev/tty
TARGET_USER="${INPUT_USER:-$DEFAULT_USER}"

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo -e "\033[31m[错误] 用户 '$TARGET_USER' 不存在，退出操作。\033[0m"
    exit 1
fi

# 4. 交互获取目标目录
while true; do
    echo ""
    read -rp "请输入需要授权的目录绝对路径 (例如: /root/my-project): " INPUT_DIR </dev/tty
    TARGET_DIR="$(readlink -f "$INPUT_DIR" 2>/dev/null || echo "$INPUT_DIR")"

    if [ -z "$TARGET_DIR" ]; then
        echo -e "\033[33m[警告] 路径不能为空，请重新输入。\033[0m"
        continue
    fi

    # 安全阻断：禁止直接对根目录或 /root 主目录赋予完整读写
    if [ "$TARGET_DIR" = "/" ] || [ "$TARGET_DIR" = "/root" ]; then
        echo -e "\033[31m[安全拦截] 禁止直接授权 '/' 或 '/root' 家目录本身！\033[0m"
        echo "请指定 /root 下的具体项目子文件夹（如: /root/my-app）。"
        continue
    fi

    if [ ! -d "$TARGET_DIR" ]; then
        echo -e "\033[33m[提示] 目录 '$TARGET_DIR' 尚不存在。\033[0m"
        read -rp "是否立即自动创建该目录？ [y/N]: " CONFIRM_MKDIR </dev/tty
        if [[ "$CONFIRM_MKDIR" =~ ^[Yy]$ ]]; then
            mkdir -p "$TARGET_DIR"
            echo "[OK] 已创建目录: $TARGET_DIR"
            break
        else
            continue
        fi
    else
        break
    fi
done

echo ""
echo "[1/3] 打通沿途父目录穿透权限 (+x)..."
# 递归向上寻找所有上级目录并仅赋予 x 权限，确保用户能穿透进入，但不能查看同级非授权文件
PARENT_DIR="$(dirname "$TARGET_DIR")"
while [ "$PARENT_DIR" != "/" ] && [ "$PARENT_DIR" != "." ]; do
    setfacl -m u:"$TARGET_USER":x "$PARENT_DIR"
    PARENT_DIR="$(dirname "$PARENT_DIR")"
done

echo "[2/3] 配置当前目录及现有文件递归读写执行权限 (rwx)..."
setfacl -R -m u:"$TARGET_USER":rwx "$TARGET_DIR"

echo "[3/3] 配置未来新建文件的默认继承规则 (Default ACL)..."
setfacl -R -d -m u:"$TARGET_USER":rwx "$TARGET_DIR"

echo ""
echo -e "\033[32m[成功] 权限配置已完全就绪！\033[0m"
echo "--------------------------------------------------------"
echo "授权用户: $TARGET_USER"
echo "授权目录: $TARGET_DIR"
echo "--------------------------------------------------------"
echo "当前目录 ACL 规则确认:"
getfacl "$TARGET_DIR" 2>/dev/null | grep -E "user:$TARGET_USER|default:user:$TARGET_USER"
echo "--------------------------------------------------------"
