#!/bin/bash
# ============================================================================
# Cordys CRM - 外部服务模式部署脚本
# 
# 适用系统：Debian 10/11/12, Ubuntu 18.04+
# 
# 使用方法：
#   1. 确保已配置好外部 MySQL 和 Redis
#   2. 运行脚本: ./deploy-external.sh
#   3. 按提示输入配置信息
#
# 注意事项：
#   - 此脚本不包含 nginx，使用 Traefik 反向代理
#   - 基础镜像与 Debian 完全兼容（glibc）
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

log_step() {
    echo -e "\n${BLUE}====== $1 ======${NC}\n"
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

# 检查系统要求
check_prerequisites() {
    log_step "检查系统要求"
    
    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_info "操作系统: $PRETTY_NAME"
        
        if [[ "$ID" != "debian" && "$ID" != "ubuntu" && "$ID_LIKE" != *"debian"* ]]; then
            log_warn "非 Debian 系列系统，部分命令可能需要调整"
        fi
    fi
    
    # 检查 Docker
    if ! check_command docker; then
        log_error "Docker 未安装！请先安装 Docker:"
        echo "  curl -fsSL https://get.docker.com | sudo sh"
        echo "  sudo usermod -aG docker \$USER"
        exit 1
    fi
    log_info "Docker 版本: $(docker --version)"
    
    # 检查 Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose V2 未安装！请升级 Docker 或安装 docker-compose-plugin"
        exit 1
    fi
    log_info "Docker Compose 版本: $(docker compose version --short)"
    
    # 检查网络工具
    if check_command nc; then
        log_info "netcat: 已安装"
    else
        log_warn "netcat 未安装，建议安装: sudo apt-get install -y netcat-openbsd"
    fi
    
    log_info "系统检查通过！"
}

# 配置向导
configure_wizard() {
    log_step "配置向导"
    
    echo "请输入外部服务配置信息（直接回车使用默认值）："
    echo ""
    
    # MySQL 配置
    echo -e "${BLUE}--- MySQL 配置 ---${NC}"
    read -p "MySQL 主机地址 (必填): " MYSQL_HOST
    if [ -z "$MYSQL_HOST" ]; then
        log_error "MySQL 主机地址不能为空！"
        exit 1
    fi
    
    read -p "MySQL 端口 [3306]: " MYSQL_PORT
    MYSQL_PORT=${MYSQL_PORT:-3306}
    
    read -p "数据库名称 [cordys-crm]: " MYSQL_DATABASE
    MYSQL_DATABASE=${MYSQL_DATABASE:-cordys-crm}
    
    read -p "数据库用户名 [cordys]: " MYSQL_USERNAME
    MYSQL_USERNAME=${MYSQL_USERNAME:-cordys}
    
    read -sp "数据库密码 (必填): " MYSQL_PASSWORD
    echo ""
    if [ -z "$MYSQL_PASSWORD" ]; then
        log_error "数据库密码不能为空！"
        exit 1
    fi
    
    echo ""
    
    # Redis 配置
    echo -e "${BLUE}--- Redis 配置 ---${NC}"
    read -p "Redis 主机地址 (必填): " REDIS_HOST
    if [ -z "$REDIS_HOST" ]; then
        log_error "Redis 主机地址不能为空！"
        exit 1
    fi
    
    read -p "Redis 端口 [6379]: " REDIS_PORT
    REDIS_PORT=${REDIS_PORT:-6379}
    
    read -sp "Redis 密码 (无密码则留空): " REDIS_PASSWORD
    echo ""
    
    echo ""
    
    # 其他配置
    echo -e "${BLUE}--- 其他配置 ---${NC}"
    read -p "CRM 访问域名 (如 crm.example.com): " TRAEFIK_HOST
    TRAEFIK_HOST=${TRAEFIK_HOST:-localhost}
    
    read -p "是否使用 Traefik 反向代理? [y/N]: " USE_TRAEFIK
    
    # 导出变量
    export MYSQL_HOST MYSQL_PORT MYSQL_DATABASE MYSQL_USERNAME MYSQL_PASSWORD
    export REDIS_HOST REDIS_PORT REDIS_PASSWORD
    export TRAEFIK_HOST USE_TRAEFIK
}

# 生成环境配置文件
generate_env_file() {
    log_step "生成环境配置文件"
    
    local env_file=".env"
    
    cat > "$env_file" << EOF
# ============================================================================
# Cordys CRM - 自动生成的环境配置
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# ============================================================================

# 基础配置
CRM_VERSION=latest
TZ=Asia/Shanghai

# 端口配置
WEB_PORT=8081
MCP_PORT=8082

# MySQL 配置
MYSQL_HOST=${MYSQL_HOST}
MYSQL_PORT=${MYSQL_PORT}
MYSQL_DATABASE=${MYSQL_DATABASE}
MYSQL_USERNAME=${MYSQL_USERNAME}
MYSQL_PASSWORD='${MYSQL_PASSWORD}'
MYSQL_SSL=false
MYSQL_POOL_MIN=5
MYSQL_POOL_MAX=20

# Redis 配置
REDIS_HOST=${REDIS_HOST}
REDIS_PORT=${REDIS_PORT}
REDIS_PASSWORD='${REDIS_PASSWORD}'

# JVM 配置
JVM_XMS=512m
JVM_XMX=1024m

# MCP 配置
MCP_ENABLED=true
CRM_URL=https://${TRAEFIK_HOST}

# 会话配置
SESSION_TIMEOUT=30d

# 日志配置
LOG_LEVEL=INFO

# 资源限制
LIMIT_CPU=4
LIMIT_MEMORY=4G
RESERVE_CPU=1
RESERVE_MEMORY=1G

# 数据目录
DATA_PATH=./data

# Traefik 配置
TRAEFIK_HOST=${TRAEFIK_HOST}
TRAEFIK_MCP_HOST=mcp.${TRAEFIK_HOST}
TRAEFIK_NETWORK=traefik-public
TRAEFIK_CERT_RESOLVER=letsencrypt
EOF

    chmod 600 "$env_file"
    log_info "配置文件已生成: $env_file"
}

# 创建数据目录
create_data_directories() {
    log_step "创建数据目录"
    
    mkdir -p ./data/cordys/{conf,data,logs,files}
    log_info "数据目录已创建: ./data/cordys/"
}

# 部署服务
deploy_services() {
    log_step "部署 Cordys CRM"
    
    local compose_files="-f docker-compose.external.yml"
    
    if [[ "$USE_TRAEFIK" =~ ^[Yy]$ ]]; then
        log_info "使用 Traefik 反向代理模式"
        
        # 检查 Traefik 网络
        if ! docker network ls | grep -q traefik-public; then
            log_info "创建 Traefik 网络..."
            docker network create traefik-public
        fi
        
        compose_files="$compose_files -f docker-compose.traefik.yml"
    else
        log_info "使用端口直接暴露模式"
    fi
    
    log_info "拉取最新镜像..."
    docker compose $compose_files pull
    
    log_info "启动服务..."
    docker compose $compose_files up -d
    
    log_info "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    docker compose $compose_files ps
}

# 显示部署结果
show_result() {
    log_step "部署完成"
    
    echo ""
    echo "=========================================="
    echo "       Cordys CRM 部署成功！"
    echo "=========================================="
    echo ""
    
    if [[ "$USE_TRAEFIK" =~ ^[Yy]$ ]]; then
        echo "访问地址: https://${TRAEFIK_HOST}"
        echo "MCP 地址: https://mcp.${TRAEFIK_HOST}"
    else
        echo "访问地址: http://$(hostname -I | awk '{print $1}'):8081"
        echo "MCP 地址: http://$(hostname -I | awk '{print $1}'):8082"
    fi
    
    echo ""
    echo "默认账号: admin"
    echo "默认密码: CordysCRM"
    echo ""
    echo "⚠️  请立即修改默认密码！"
    echo ""
    echo "常用命令:"
    echo "  查看日志: docker compose -f docker-compose.external.yml logs -f"
    echo "  重启服务: docker compose -f docker-compose.external.yml restart"
    echo "  停止服务: docker compose -f docker-compose.external.yml down"
    echo ""
}

# 主函数
main() {
    echo ""
    echo "=========================================="
    echo "  Cordys CRM 外部服务模式部署脚本"
    echo "  系统: Debian / Ubuntu"
    echo "  注意: 不包含 nginx，使用 Traefik 反代"
    echo "=========================================="
    echo ""
    
    # 切换到脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$SCRIPT_DIR/.."
    
    # 执行部署流程
    check_prerequisites
    configure_wizard
    generate_env_file
    create_data_directories
    deploy_services
    show_result
}

# 执行主函数
main "$@"
