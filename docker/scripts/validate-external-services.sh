#!/bin/bash
# ============================================================================
# Cordys CRM - 外部服务连接验证脚本
# 
# 用途：在部署前验证外部 MySQL 和 Redis 服务的连通性
# 
# 使用方法：
#   chmod +x validate-external-services.sh
#   ./validate-external-services.sh
#
# 支持的 Linux 发行版：Debian/Ubuntu、CentOS/RHEL、Alpine
# ============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# 检测操作系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
    else
        OS="unknown"
    fi
    
    log_info "检测到操作系统: ${OS} ${OS_VERSION:-}"
}

# 安装必要的工具
install_tools() {
    log_section "检查依赖工具"
    
    local tools_needed=()
    
    # 检查 nc (netcat)
    if ! command -v nc &> /dev/null; then
        tools_needed+=("netcat")
    fi
    
    # 检查 mysql 客户端
    if ! command -v mysql &> /dev/null; then
        tools_needed+=("mysql-client")
    fi
    
    # 检查 redis-cli
    if ! command -v redis-cli &> /dev/null; then
        tools_needed+=("redis-tools")
    fi
    
    if [ ${#tools_needed[@]} -eq 0 ]; then
        log_info "所有依赖工具已安装"
        return 0
    fi
    
    log_warn "需要安装以下工具: ${tools_needed[*]}"
    
    case $OS in
        debian|ubuntu)
            log_info "使用 apt-get 安装..."
            sudo apt-get update -qq
            for tool in "${tools_needed[@]}"; do
                case $tool in
                    netcat) sudo apt-get install -y -qq netcat-openbsd ;;
                    mysql-client) sudo apt-get install -y -qq default-mysql-client ;;
                    redis-tools) sudo apt-get install -y -qq redis-tools ;;
                esac
            done
            ;;
        centos|rhel|fedora)
            log_info "使用 yum/dnf 安装..."
            for tool in "${tools_needed[@]}"; do
                case $tool in
                    netcat) sudo yum install -y -q nc ;;
                    mysql-client) sudo yum install -y -q mysql ;;
                    redis-tools) sudo yum install -y -q redis ;;
                esac
            done
            ;;
        alpine)
            log_info "使用 apk 安装..."
            for tool in "${tools_needed[@]}"; do
                case $tool in
                    netcat) sudo apk add --no-cache netcat-openbsd ;;
                    mysql-client) sudo apk add --no-cache mysql-client ;;
                    redis-tools) sudo apk add --no-cache redis ;;
                esac
            done
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            log_error "请手动安装: ${tools_needed[*]}"
            return 1
            ;;
    esac
    
    log_info "工具安装完成"
}

# 加载环境变量
load_env() {
    log_section "加载环境变量"
    
    local env_file=""
    
    # 查找 .env 文件
    if [ -f ".env" ]; then
        env_file=".env"
    elif [ -f "../.env" ]; then
        env_file="../.env"
    elif [ -f "docker/.env" ]; then
        env_file="docker/.env"
    fi
    
    if [ -n "$env_file" ]; then
        log_info "加载配置文件: $env_file"
        export $(grep -v '^#' "$env_file" | grep -v '^$' | xargs)
    fi
    
    # 交互式输入（如果环境变量未设置）
    if [ -z "$MYSQL_HOST" ]; then
        read -p "请输入 MySQL 主机地址: " MYSQL_HOST
    fi
    
    if [ -z "$MYSQL_PORT" ]; then
        MYSQL_PORT=3306
    fi
    
    if [ -z "$MYSQL_USERNAME" ]; then
        read -p "请输入 MySQL 用户名 [cordys]: " MYSQL_USERNAME
        MYSQL_USERNAME=${MYSQL_USERNAME:-cordys}
    fi
    
    if [ -z "$MYSQL_PASSWORD" ]; then
        read -sp "请输入 MySQL 密码: " MYSQL_PASSWORD
        echo ""
    fi
    
    if [ -z "$MYSQL_DATABASE" ]; then
        MYSQL_DATABASE="cordys-crm"
    fi
    
    if [ -z "$REDIS_HOST" ]; then
        read -p "请输入 Redis 主机地址: " REDIS_HOST
    fi
    
    if [ -z "$REDIS_PORT" ]; then
        REDIS_PORT=6379
    fi
    
    if [ -z "$REDIS_PASSWORD" ]; then
        read -sp "请输入 Redis 密码 (无密码直接回车): " REDIS_PASSWORD
        echo ""
    fi
    
    log_info "配置加载完成"
}

# 测试网络连通性
test_network() {
    local host=$1
    local port=$2
    local service=$3
    local timeout=${4:-5}
    
    log_info "测试 ${service} 网络连通性: ${host}:${port}"
    
    if nc -z -w "$timeout" "$host" "$port" 2>/dev/null; then
        log_info "${service} 端口可达 ✓"
        return 0
    else
        log_error "${service} 端口不可达 ✗"
        log_error "请检查:"
        log_error "  1. 服务是否启动"
        log_error "  2. 防火墙是否开放端口 ${port}"
        log_error "  3. 网络连通性"
        return 1
    fi
}

# 测试 MySQL 连接
test_mysql() {
    log_section "MySQL 连接测试"
    
    # 测试网络连通性
    if ! test_network "$MYSQL_HOST" "$MYSQL_PORT" "MySQL"; then
        return 1
    fi
    
    # 测试认证和数据库访问
    log_info "测试 MySQL 认证和数据库访问..."
    
    local mysql_result
    mysql_result=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" \
        -u "$MYSQL_USERNAME" -p"$MYSQL_PASSWORD" \
        -e "SELECT 1 AS test; SHOW DATABASES LIKE '${MYSQL_DATABASE}';" \
        2>&1) || {
        log_error "MySQL 认证失败"
        log_error "错误信息: $mysql_result"
        return 1
    }
    
    log_info "MySQL 认证成功 ✓"
    
    # 检查数据库是否存在
    if echo "$mysql_result" | grep -q "$MYSQL_DATABASE"; then
        log_info "数据库 ${MYSQL_DATABASE} 已存在 ✓"
    else
        log_warn "数据库 ${MYSQL_DATABASE} 不存在，应用启动时会自动创建"
    fi
    
    # 检查 MySQL 版本
    local mysql_version
    mysql_version=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" \
        -u "$MYSQL_USERNAME" -p"$MYSQL_PASSWORD" \
        -e "SELECT VERSION();" -N 2>/dev/null)
    log_info "MySQL 版本: ${mysql_version}"
    
    # 检查字符集
    local charset
    charset=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" \
        -u "$MYSQL_USERNAME" -p"$MYSQL_PASSWORD" \
        -e "SHOW VARIABLES LIKE 'character_set_server';" -N 2>/dev/null | awk '{print $2}')
    
    if [ "$charset" = "utf8mb4" ]; then
        log_info "字符集配置正确: utf8mb4 ✓"
    else
        log_warn "字符集为 ${charset}，建议使用 utf8mb4"
    fi
    
    return 0
}

# 测试 Redis 连接
test_redis() {
    log_section "Redis 连接测试"
    
    # 测试网络连通性
    if ! test_network "$REDIS_HOST" "$REDIS_PORT" "Redis"; then
        return 1
    fi
    
    # 测试认证
    log_info "测试 Redis 认证..."
    
    local redis_result
    if [ -n "$REDIS_PASSWORD" ]; then
        redis_result=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
            -a "$REDIS_PASSWORD" ping 2>&1)
    else
        redis_result=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping 2>&1)
    fi
    
    if echo "$redis_result" | grep -q "PONG"; then
        log_info "Redis 认证成功 ✓"
    else
        log_error "Redis 认证失败"
        log_error "错误信息: $redis_result"
        return 1
    fi
    
    # 检查 Redis 版本
    local redis_version
    if [ -n "$REDIS_PASSWORD" ]; then
        redis_version=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
            -a "$REDIS_PASSWORD" INFO server 2>/dev/null | grep redis_version | cut -d: -f2 | tr -d '\r')
    else
        redis_version=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
            INFO server 2>/dev/null | grep redis_version | cut -d: -f2 | tr -d '\r')
    fi
    log_info "Redis 版本: ${redis_version}"
    
    # 检查可用内存
    local redis_memory
    if [ -n "$REDIS_PASSWORD" ]; then
        redis_memory=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
            -a "$REDIS_PASSWORD" INFO memory 2>/dev/null | grep maxmemory_human | cut -d: -f2 | tr -d '\r')
    else
        redis_memory=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
            INFO memory 2>/dev/null | grep maxmemory_human | cut -d: -f2 | tr -d '\r')
    fi
    
    if [ -n "$redis_memory" ] && [ "$redis_memory" != "0B" ]; then
        log_info "Redis 最大内存: ${redis_memory}"
    else
        log_warn "Redis 未设置最大内存限制"
    fi
    
    return 0
}

# 生成启动命令
generate_command() {
    log_section "生成部署命令"
    
    echo ""
    echo "方式一：使用 Docker Compose（推荐）"
    echo "----------------------------------------"
    echo "cd docker"
    echo "docker compose -f docker-compose.external.yml up -d"
    echo ""
    echo "方式二：使用 Docker Run"
    echo "----------------------------------------"
    cat << EOF
docker run -d \\
  --name cordys-crm \\
  --restart unless-stopped \\
  -p 8081:8081 \\
  -p 8082:8082 \\
  -v ~/cordys:/opt/cordys \\
  -e TZ=Asia/Shanghai \\
  -e MYSQL_HOST=${MYSQL_HOST} \\
  -e MYSQL_PORT=${MYSQL_PORT} \\
  -e MYSQL_DATABASE=${MYSQL_DATABASE} \\
  -e MYSQL_USERNAME=${MYSQL_USERNAME} \\
  -e MYSQL_PASSWORD='${MYSQL_PASSWORD}' \\
  -e REDIS_HOST=${REDIS_HOST} \\
  -e REDIS_PORT=${REDIS_PORT} \\
  -e REDIS_PASSWORD='${REDIS_PASSWORD}' \\
  -e MCP_ENABLED=true \\
  1panel/cordys-crm:latest
EOF
    echo ""
}

# 主函数
main() {
    echo ""
    echo "=============================================="
    echo " Cordys CRM 外部服务连接验证工具"
    echo "=============================================="
    echo ""
    
    # 检测操作系统
    detect_os
    
    # 安装必要工具
    install_tools || exit 1
    
    # 加载环境变量
    load_env
    
    local has_error=0
    
    # 测试 MySQL
    if ! test_mysql; then
        has_error=1
    fi
    
    # 测试 Redis
    if ! test_redis; then
        has_error=1
    fi
    
    # 输出结果
    log_section "验证结果"
    
    if [ $has_error -eq 0 ]; then
        log_info "所有外部服务验证通过 ✓"
        generate_command
        echo ""
        log_info "可以开始部署 Cordys CRM 了！"
    else
        log_error "部分服务验证失败，请检查配置后重试"
        exit 1
    fi
}

# 执行主函数
main "$@"
