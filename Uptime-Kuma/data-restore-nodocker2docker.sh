#!/bin/bash
echo "--- Uptime Kuma 非docker安装方式的数据迁移至docker ---"
echo "------------------------------"
echo "警告：在运行此脚本前，请确保 Uptime Kuma 容器已停止！docker stop uptime-kuma"
echo "---------------"
echo "预备工作："
echo "先将uptime-kuma/data数据包压缩，重命名为“data.tar.gz”，再上传到root文件夹下"
echo "根据docker的数据目录，修改路径TARGET_DIR，默认为/var/lib/docker/volumes/uptime-kuma/_data；docker环境部署时若启用了/app/data文件夹的本地挂载（映射）A，则修改路径TARGET_DIR为该路径A"
# read -p "准备好后回车确认"
echo "------------------------------"
echo "开始迁移数据…"


# 命令失败时立即退出
set -e

# --- 配置变量 ---
ARCHIVE_PATH="/root/data.tar.gz"                     # 你的压缩包路径
TARGET_DIR="/root/docker_data/uptime_kuma" # 修改为Uptime Kuma docker数据卷的宿主机路径
TEMP_EXTRACT_DIR="/tmp/uptime_kuma_restore_temp_$(date +%s)" # 使用时间戳避免临时目录冲突

# 压缩包解压后，我们期望的数据目录路径
# 根据你提供的结构，解压后数据在 TEMP_EXTRACT_DIR/root/uptime-kuma/data
SOURCE_DATA_DIR="${TEMP_EXTRACT_DIR}/root/uptime-kuma/data"


# 1. 检查是否以root用户运行
if [ "$(id -u)" -ne 0 ]; then
    echo "错误：此脚本需要以root用户运行。"
    echo "请使用 'sudo bash 脚本名.sh' 或切换到root用户执行。"
    exit 1
fi

# 2. 检查压缩包是否存在
if [ ! -f "$ARCHIVE_PATH" ]; then
    echo "错误：压缩包 '$ARCHIVE_PATH' 不存在。"
    exit 1
fi

# 3. 检查目标目录是否存在
if [ ! -d "$TARGET_DIR" ]; then
    echo "错误：目标目录 '$TARGET_DIR' 不存在。"
    echo "请确认 Uptime Kuma 容器已运行过，并且 Docker 卷已正确创建。"
    exit 1
fi

echo "1. 创建临时解压目录: $TEMP_EXTRACT_DIR"
mkdir -p "$TEMP_EXTRACT_DIR" || { echo "错误：无法创建临时目录。"; exit 1; }

echo "2. 解压 '$ARCHIVE_PATH' 到临时目录..."
# -C 参数指定解压到哪个目录
tar -xzf "$ARCHIVE_PATH" -C "$TEMP_EXTRACT_DIR" || { echo "错误：解压失败。请检查压缩包是否损坏或格式正确。"; rm -rf "$TEMP_EXTRACT_DIR"; exit 1; }

# 检查解压后的数据路径是否存在，以确保压缩包结构符合预期
if [ ! -d "$SOURCE_DATA_DIR" ]; then
    echo "错误：解压后的数据目录 '$SOURCE_DATA_DIR' 不存在。"
    echo "这可能意味着压缩包的内部结构与预期不符。"
    rm -rf "$TEMP_EXTRACT_DIR"
    exit 1
fi

echo "3. 清空目标目录: $TARGET_DIR 下的所有内容..."
# 删除所有非隐藏文件和目录
rm -rf "${TARGET_DIR}"/* || { echo "警告：清空非隐藏文件失败，可能没有此类文件或权限问题。"; }
# 删除所有隐藏文件和目录 (排除 . 和 ..)
find "${TARGET_DIR}" -mindepth 1 -maxdepth 1 -name ".*" -exec rm -rf {} + 2>/dev/null || { echo "警告：清空隐藏文件失败，可能没有此类文件或权限问题。"; }

echo "4. 将解压后的数据移动到目标目录: $TARGET_DIR..."
# 移动非隐藏文件和目录
mv "${SOURCE_DATA_DIR}"/* "${TARGET_DIR}"/ || { echo "错误：移动非隐藏文件失败。"; rm -rf "$TEMP_EXTRACT_DIR"; exit 1; }
# 移动隐藏文件和目录 (排除 . 和 ..)
# 'mv' 尝试移动 '.' 和 '..' 会报错，所以将错误输出重定向到 /dev/null
mv "${SOURCE_DATA_DIR}"/.* "${TARGET_DIR}"/ 2>/dev/null || { echo "警告：移动隐藏文件失败，可能没有此类文件。"; }

echo "5. 清理临时目录: $TEMP_EXTRACT_DIR"
rm -rf "$TEMP_EXTRACT_DIR" || { echo "警告：无法清理临时目录。请手动删除 '$TEMP_EXTRACT_DIR'。"; }

echo "--- 数据恢复完成！ ---"
echo "现在你可以重新启动 Uptime Kuma 容器以加载新数据了。"
echo "例如：docker start uptime-kuma"
