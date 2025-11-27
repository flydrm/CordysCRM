#!/bin/bash
# ============================================================================
# Cordys CRM - Docker Secrets 初始化脚本
# 
# 使用方法：
#   chmod +x scripts/init-secrets.sh
#   ./scripts/init-secrets.sh
#
# 说明：
#   此脚本创建 Docker Compose 所需的 secrets 文件
#   生产环境请修改默认密码
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="${DOCKER_DIR}/secrets"

echo "=========================================="
echo "Cordys CRM - 初始化 Docker Secrets"
echo "=========================================="

# 创建 secrets 目录
mkdir -p "$SECRETS_DIR"

# 生成随机密码函数
generate_password() {
    # 生成 24 字符的随机密码（字母+数字）
    tr -dc 'A-Za-z0-9!@#$%' < /dev/urandom | head -c 24
}

# MySQL root 密码
if [ ! -f "${SECRETS_DIR}/mysql_root_password" ]; then
    echo "创建 MySQL root 密码..."
    read -sp "请输入 MySQL root 密码 (留空则自动生成): " MYSQL_ROOT_PWD
    echo
    
    if [ -z "$MYSQL_ROOT_PWD" ]; then
        MYSQL_ROOT_PWD=$(generate_password)
        echo "已生成随机密码: $MYSQL_ROOT_PWD"
    fi
    
    echo -n "$MYSQL_ROOT_PWD" > "${SECRETS_DIR}/mysql_root_password"
    echo "✅ MySQL root 密码已保存"
else
    echo "⚠️  MySQL root 密码文件已存在，跳过"
fi

# MySQL 应用用户密码
if [ ! -f "${SECRETS_DIR}/mysql_password" ]; then
    echo "创建 MySQL 应用用户密码..."
    read -sp "请输入 MySQL 应用用户密码 (留空则自动生成): " MYSQL_PWD
    echo
    
    if [ -z "$MYSQL_PWD" ]; then
        MYSQL_PWD=$(generate_password)
        echo "已生成随机密码: $MYSQL_PWD"
    fi
    
    echo -n "$MYSQL_PWD" > "${SECRETS_DIR}/mysql_password"
    echo "✅ MySQL 应用用户密码已保存"
else
    echo "⚠️  MySQL 应用用户密码文件已存在，跳过"
fi

# 设置文件权限（仅 owner 可读写）
chmod 600 "${SECRETS_DIR}"/*
chmod 700 "${SECRETS_DIR}"

echo ""
echo "=========================================="
echo "✅ Secrets 初始化完成"
echo "=========================================="
echo ""
echo "密码文件位置: ${SECRETS_DIR}"
echo ""
echo "下一步操作："
echo "  1. 记录上述生成的密码（重要！）"
echo "  2. 启动服务: docker compose --profile separated up -d"
echo ""
echo "⚠️  安全提醒："
echo "  - 请妥善保管密码文件"
echo "  - 生产环境请设置更强的密码"
echo "  - 不要将 secrets 目录提交到版本控制"
echo ""

