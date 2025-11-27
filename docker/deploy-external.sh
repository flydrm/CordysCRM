#!/bin/bash
# ============================================================================
# Cordys CRM - 外部服务部署脚本 (方案3)
# 
# 适用于：使用已有的外部 MySQL 和 Redis 服务
# 
# 使用方法：
#   chmod +x deploy-external.sh
#   ./deploy-external.sh
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
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# ============================================================================
# 检查前置条件
# ============================================================================
check_prerequisites() {
    log_step "检查前置条件"
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    log_info "Docker: $(docker --version)"
    
    # 检查 Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose 未安装或版本过低，需要 2.0+"
        exit 1
    fi
    log_info "Docker Compose: $(docker compose version --short)"
    
    # 检查配置文件
    if [ ! -f ".env" ]; then
        if [ -f "env.template" ]; then
            log_warn ".env 文件不存在，从模板创建"
            cp env.template .env
        else
            log_error "找不到 env.template 文件"
            exit 1
        fi
    fi
}

# ============================================================================
# 验证外部服务配置
# ============================================================================
validate_config() {
    log_step "验证外部服务配置"
    
    # 加载环境变量
    source .env 2>/dev/null || true
    
    local has_error=0
    
    # 检查 MySQL 配置
    if [ -z "$MYSQL_HOST" ]; then
        log_error "MYSQL_HOST 未配置"
        has_error=1
    else
        log_info "MySQL Host: $MYSQL_HOST:${MYSQL_PORT:-3306}"
    fi
    
    if [ -z "$MYSQL_PASSWORD" ]; then
        log_error "MYSQL_PASSWORD 未配置"
        has_error=1
    fi
    
    # 检查 Redis 配置
    if [ -z "$REDIS_HOST" ]; then
        log_error "REDIS_HOST 未配置"
        has_error=1
    else
        log_info "Redis Host: $REDIS_HOST:${REDIS_PORT:-6379}"
    fi
    
    if [ $has_error -eq 1 ]; then
        log_error "请编辑 .env 文件配置外部服务地址"
        log_info "必填配置项："
        echo "  MYSQL_HOST=<MySQL服务器地址>"
        echo "  MYSQL_PASSWORD=<MySQL密码>"
        echo "  REDIS_HOST=<Redis服务器地址>"
        echo "  REDIS_PASSWORD=<Redis密码> (如果需要)"
        exit 1
    fi
}

# ============================================================================
# 测试外部服务连通性
# ============================================================================
test_connectivity() {
    log_step "测试外部服务连通性"
    
    source .env 2>/dev/null || true
    local has_error=0
    
    # 测试 MySQL
    log_info "测试 MySQL 连接 (${MYSQL_HOST}:${MYSQL_PORT:-3306})..."
    if nc -z -w 5 "$MYSQL_HOST" "${MYSQL_PORT:-3306}" 2>/dev/null; then
        log_info "MySQL 端口连通 ✓"
    else
        log_error "无法连接到 MySQL"
        has_error=1
    fi
    
    # 测试 Redis
    log_info "测试 Redis 连接 (${REDIS_HOST}:${REDIS_PORT:-6379})..."
    if nc -z -w 5 "$REDIS_HOST" "${REDIS_PORT:-6379}" 2>/dev/null; then
        log_info "Redis 端口连通 ✓"
    else
        log_error "无法连接到 Redis"
        has_error=1
    fi
    
    if [ $has_error -eq 1 ]; then
        log_error "外部服务连通性测试失败"
        log_info "请检查："
        echo "  1. 服务是否启动"
        echo "  2. 防火墙是否开放端口"
        echo "  3. 网络路由是否正确"
        exit 1
    fi
    
    log_info "所有外部服务连通性测试通过 ✓"
}

# ============================================================================
# 部署 Cordys CRM
# ============================================================================
deploy() {
    log_step "部署 Cordys CRM"
    
    # 拉取最新镜像
    log_info "拉取镜像..."
    docker compose -f docker-compose.external.yml pull
    
    # 启动服务
    log_info "启动服务..."
    docker compose -f docker-compose.external.yml up -d
    
    # 等待服务就绪
    log_info "等待服务启动..."
    local max_wait=120
    local wait_time=0
    
    while [ $wait_time -lt $max_wait ]; do
        if curl -sf http://localhost:${WEB_PORT:-8081}/actuator/health >/dev/null 2>&1; then
            log_info "服务已就绪 ✓"
            break
        fi
        sleep 5
        wait_time=$((wait_time + 5))
        echo -n "."
    done
    echo ""
    
    if [ $wait_time -ge $max_wait ]; then
        log_warn "服务启动超时，请检查日志"
        docker compose -f docker-compose.external.yml logs --tail=50
    fi
}

# ============================================================================
# 打印访问信息
# ============================================================================
print_access_info() {
    source .env 2>/dev/null || true
    
    log_step "部署完成"
    
    echo ""
    echo "=========================================="
    echo "  Cordys CRM 部署完成！"
    echo "=========================================="
    echo ""
    echo "  访问地址: http://localhost:${WEB_PORT:-8081}"
    echo "  MCP 地址: http://localhost:${MCP_PORT:-8082}"
    echo ""
    echo "  默认账号: admin"
    echo "  默认密码: CordysCRM"
    echo ""
    echo "  ⚠️  请立即修改默认密码！"
    echo "=========================================="
    echo ""
    echo "常用命令："
    echo "  查看日志: docker compose -f docker-compose.external.yml logs -f"
    echo "  停止服务: docker compose -f docker-compose.external.yml down"
    echo "  重启服务: docker compose -f docker-compose.external.yml restart"
    echo ""
}

# ============================================================================
# 主函数
# ============================================================================
main() {
    echo ""
    echo "=========================================="
    echo "  Cordys CRM 外部服务部署脚本"
    echo "=========================================="
    echo ""
    
    # 切换到脚本所在目录
    cd "$(dirname "$0")"
    
    # 执行部署流程
    check_prerequisites
    validate_config
    test_connectivity
    deploy
    print_access_info
}

# 执行主函数
main "$@"

