#!/usr/bin/env bash
set -e

# 1. 权限检查：必须以 root 或 sudo 运行
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31m[错误] 本脚本需要管理员权限，请使用: sudo bash $0\033[0m"
    exit 1
fi

# 2. 依赖检查：自动补全 acl 工具包
if ! command -v setfacl >/dev/null 2>&1; then
    echo -e "\033[33m[提示] 系统未检测到 setfacl，正在自动安装 acl 工具包...\033[0m"
    apt-get update -qq && apt-get install -y -qq acl
fi

# 3. 交互获取被授权用户名
DEFAULT_USER="${SUDO_USER:-vibecoding}"
read -rp "请输入需要授权的用户名 [默认: $DEFAULT_USER]: " INPUT_USER </dev/tty
TARGET_USER="${INPUT_USER:-$DEFAULT_USER}"

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo -e "\033[31m[错误] 用户 '$TARGET_USER' 不存在，退出操作。\033[0m"
    exit 1
fi

# 4. 交互获取多个目录（空格分割并读入数组）
while true; do
    echo ""
    read -rp "请输入需要授权的目录路径 (多个目录用空格隔开): " -a DIRS_LIST </dev/tty

    if [ ${#DIRS_LIST[@]} -eq 0 ]; then
        echo -e "\033[33m[警告] 输入不能为空，请重新输入。\033[0m"
        continue
    fi
    break
done

echo ""
echo "========================================================"
echo "开始批量处理授权与 Git 配置 (目标用户: $TARGET_USER)"
echo "========================================================"

# 5. 循环处理每一个目录
for RAW_DIR in "${DIRS_LIST[@]}"; do
    TARGET_DIR="$(readlink -f "$RAW_DIR" 2>/dev/null || echo "$RAW_DIR")"
    echo ""
    echo -e "\033[36m>>> 正在处理: $TARGET_DIR\033[0m"

    # 安全检查：拦截危险的全局主目录
    if [ "$TARGET_DIR" = "/" ] || [ "$TARGET_DIR" = "/root" ]; then
        echo -e "\033[31m[跳过] 安全拦截：禁止直接授权 '/' 或 '/root' 家目录本身！\033[0m"
        continue
    fi

    # 检查目录是否存在，不存在则询问创建
    if [ ! -d "$TARGET_DIR" ]; then
        echo -e "\033[33m[提示] 目录 '$TARGET_DIR' 尚不存在。\033[0m"
        read -rp "是否立即创建该目录？ [y/N]: " CONFIRM_MKDIR </dev/tty
        if [[ "$CONFIRM_MKDIR" =~ ^[Yy]$ ]]; then
            mkdir -p "$TARGET_DIR"
            echo "[OK] 已创建目录: $TARGET_DIR"
        else
            echo "[跳过] 已跳过该目录。"
            continue
        fi
    fi

    # 步骤 1：向上遍历沿途父目录并仅赋予穿透执行权限 (+x)
    echo "[1/4] 打通沿途父目录穿透权限 (+x)..."
    PARENT_DIR="$(dirname "$TARGET_DIR")"
    while [ "$PARENT_DIR" != "/" ] && [ "$PARENT_DIR" != "." ]; do
        setfacl -m u:"$TARGET_USER":x "$PARENT_DIR"
        PARENT_DIR="$(dirname "$PARENT_DIR")"
    done

    # 步骤 2：对当前目录及内部所有现有文件/目录递归授予读写执行权限 (rwx)
    echo "[2/4] 配置当前目录及现有文件递归读写执行权限 (rwx)..."
    setfacl -R -m u:"$TARGET_USER":rwx "$TARGET_DIR"

    # 步骤 3：配置默认继承规则 (Default ACL)，让未来新建的文件自动具有 rwx
    echo "[3/4] 配置未来新建文件的默认继承规则 (Default ACL)..."
    setfacl -R -d -m u:"$TARGET_USER":rwx "$TARGET_DIR"

    # 步骤 4：扫描 Git 仓库并为目标用户配置 safe.directory
    echo "[4/4] 扫描 Git 仓库并配置 safe.directory..."
    if command -v git >/dev/null 2>&1; then
        FOUND_GIT=0
        while IFS= read -r GIT_ITEM; do
            [ -z "$GIT_ITEM" ] && continue
            FOUND_GIT=1
            REPO_DIR="$(readlink -f "$(dirname "$GIT_ITEM")")"

            # 检查目标用户 git 全局配置中是否已有该目录（避免重复添加）
            if sudo -u "$TARGET_USER" -H git config --global --get-all safe.directory 2>/dev/null | grep -Fxq "$REPO_DIR"; then
                echo "  = [已存在] Git safe.directory: $REPO_DIR"
            else
                sudo -u "$TARGET_USER" -H git config --global --add safe.directory "$REPO_DIR"
                echo -e "  \033[32m+ [已添加]\033[0m Git safe.directory: $REPO_DIR"
            fi
        done < <(find "$TARGET_DIR" -name ".git" -prune 2>/dev/null)

        if [ "$FOUND_GIT" -eq 0 ]; then
            echo "  i 未检测到 Git 仓库，跳过 safe.directory 配置。"
        fi
    else
        echo -e "  \033[33m! 未安装 git，跳过 Git safe.directory 配置。\033[0m"
    fi

    echo -e "\033[32m[完成] $TARGET_DIR 处理完毕！\033[0m"
done

echo ""
echo "========================================================"
echo -e "\033[32m所有目录处理完毕！\033[0m"
echo "========================================================"
