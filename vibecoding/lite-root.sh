#!/usr/bin/env bash
set -e

# ========================================================
# 增强版权限配置脚本 v2
# 功能：
#   1. 配置 ACL 权限（读写执行 + 默认继承）
#   2. 自动配置现有 Git 仓库的 safe.directory
#   3. 智能检测代码项目特征
#   4. 无论是否检测到项目特征，都询问是否初始化 Git
# ========================================================

# 1. 权限检查：必须以 root 或 sudo 运行
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31m[错误] 本脚本需要管理员权限，请使用: sudo bash $0\033[0m"
    exit 1
fi

# 2. 依赖检查：自动安装 acl 工具包
if ! command -v setfacl >/dev/null 2>&1; then
    echo -e "\033[33m[提示] 系统未检测到 setfacl，正在自动安装 acl 工具包...\033[0m"
    apt-get update -qq && apt-get install -y -qq acl
    echo -e "\033[32m[完成] acl 工具包已安装\033[0m"
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
        setfacl -m u:"$TARGET_USER":x "$PARENT_DIR" 2>/dev/null || true
        PARENT_DIR="$(dirname "$PARENT_DIR")"
    done

    # 步骤 2：对当前目录及内部所有现有文件/目录递归授予读写执行权限 (rwx)
    echo "[2/4] 配置当前目录及现有文件递归读写执行权限 (rwx)..."
    setfacl -R -m u:"$TARGET_USER":rwx "$TARGET_DIR"

    # 步骤 3：配置默认继承规则 (Default ACL)，让未来新建的文件自动具有 rwx
    echo "[3/4] 配置未来新建文件的默认继承规则 (Default ACL)..."
    setfacl -R -d -m u:"$TARGET_USER":rwx "$TARGET_DIR"

    # 步骤 4：扫描 Git 仓库并配置
    echo "[4/4] 扫描 Git 仓库并配置 safe.directory..."
    if ! command -v git >/dev/null 2>&1; then
        echo -e "  \033[33m! 未安装 git，跳过 Git safe.directory 配置。\033[0m"
        echo -e "\033[32m[完成] $TARGET_DIR 处理完毕！\033[0m"
        continue
    fi

    FOUND_GIT=0
    USER_HOME=$(eval echo ~"$TARGET_USER")

    # 扫描现有 Git 仓库
    while IFS= read -r GIT_DIR; do
        [ -z "$GIT_DIR" ] && continue
        FOUND_GIT=1
        REPO_DIR="$(readlink -f "$(dirname "$GIT_DIR")")"

        # 检查目标用户 git 全局配置中是否已有该目录（避免重复添加）
        if sudo -u "$TARGET_USER" -H git config --global --get-all safe.directory 2>/dev/null | grep -Fxq "$REPO_DIR"; then
            echo "  = [已存在] Git safe.directory: $REPO_DIR"
        else
            if sudo -u "$TARGET_USER" -H git config --global --add safe.directory "$REPO_DIR" 2>&1; then
                echo -e "  \033[32m+ [已添加]\033[0m Git safe.directory: $REPO_DIR"
            else
                echo -e "  \033[31m✗ [失败]\033[0m 无法为 $TARGET_USER 配置: $REPO_DIR"
            fi
        fi
    done < <(find "$TARGET_DIR" -name ".git" -type d 2>/dev/null)

    # 如果没有找到 Git 仓库，检测项目特征并询问初始化
    if [ "$FOUND_GIT" -eq 0 ]; then
        echo "  i 未检测到 .git 目录"

        # 检测项目特征文件
        IS_PROJECT=0
        PROJECT_FILES=()

        [ -f "$TARGET_DIR/package.json" ] && IS_PROJECT=1 && PROJECT_FILES+=("package.json")
        [ -f "$TARGET_DIR/go.mod" ] && IS_PROJECT=1 && PROJECT_FILES+=("go.mod")
        [ -f "$TARGET_DIR/pom.xml" ] && IS_PROJECT=1 && PROJECT_FILES+=("pom.xml")
        [ -f "$TARGET_DIR/Cargo.toml" ] && IS_PROJECT=1 && PROJECT_FILES+=("Cargo.toml")
        [ -f "$TARGET_DIR/requirements.txt" ] && IS_PROJECT=1 && PROJECT_FILES+=("requirements.txt")
        [ -f "$TARGET_DIR/.gitignore" ] && IS_PROJECT=1 && PROJECT_FILES+=(".gitignore")
        [ -f "$TARGET_DIR/pyproject.toml" ] && IS_PROJECT=1 && PROJECT_FILES+=("pyproject.toml")
        [ -f "$TARGET_DIR/composer.json" ] && IS_PROJECT=1 && PROJECT_FILES+=("composer.json")
        [ -f "$TARGET_DIR/Gemfile" ] && IS_PROJECT=1 && PROJECT_FILES+=("Gemfile")

        # 显示检测结果（无论是否检测到）
        echo ""
        if [ "$IS_PROJECT" -eq 1 ]; then
            echo -e "  \033[32m✓ 检测到代码项目特征:\033[0m ${PROJECT_FILES[*]}"
        else
            echo -e "  \033[33m- 未检测到代码项目特征文件\033[0m"
        fi

        # 🔥 无论是否检测到，都询问用户
        read -rp "  是否初始化为本地 Git 仓库（无远程）? [y/N]: " INIT_GIT </dev/tty

        if [[ "$INIT_GIT" =~ ^[Yy]$ ]]; then
            # 初始化仓库
            echo "  ⏳ 正在初始化 Git 仓库..."
            if (cd "$TARGET_DIR" && git init -b main 2>&1 | grep -v "^hint:"); then
                echo -e "  \033[32m✓ 已初始化\033[0m Git 仓库: $TARGET_DIR"

                # 询问是否创建初始提交
                read -rp "  是否创建初始提交（保存当前代码快照）? [y/N]: " INIT_COMMIT </dev/tty
                if [[ "$INIT_COMMIT" =~ ^[Yy]$ ]]; then
                    echo "  ⏳ 正在创建初始提交..."
                    (
                        cd "$TARGET_DIR"
                        # 检查是否有文件需要提交
                        if [ -n "$(ls -A 2>/dev/null | grep -v '^\.git$')" ]; then
                            git add . 2>&1 > /dev/null
                            git commit -m "Initial commit: existing codebase" 2>&1 | head -3
                        else
                            echo "  目录为空或仅有 .git 目录，跳过提交"
                            exit 1
                        fi
                    )
                    if [ $? -eq 0 ]; then
                        echo -e "  \033[32m✓ 已创建初始提交\033[0m"
                    else
                        echo -e "  \033[33m! 初始提交跳过（目录为空或无可提交内容）\033[0m"
                    fi
                else
                    echo "  - [跳过] 不创建初始提交"
                fi

                # 配置 safe.directory
                if sudo -u "$TARGET_USER" -H git config --global --add safe.directory "$TARGET_DIR" 2>&1; then
                    echo -e "  \033[32m+ [已添加]\033[0m safe.directory: $TARGET_DIR"
                fi
            else
                echo -e "  \033[31m✗ Git 初始化失败\033[0m"
            fi
        else
            echo "  - [跳过] 不初始化 Git 仓库"
        fi
    fi

    echo -e "\033[32m[完成] $TARGET_DIR 处理完毕！\033[0m"
done

echo ""
echo "========================================================"
echo -e "\033[32m所有目录处理完毕！\033[0m"
echo ""
echo "提示："
echo "  - 查看 ACL 权限: getfacl <目录>"
echo "  - 查看 Git 配置: git config --global --get-all safe.directory"
echo "  - Git 仓库状态: cd <目录> && git status"
echo "========================================================"
