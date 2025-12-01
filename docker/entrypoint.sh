#!/bin/bash
set -e

# ============================================================================
# Cordys CRM 容器入口脚本
# 
# 支持的环境变量：
#   数据库：MYSQL_HOST, MYSQL_PORT, MYSQL_DATABASE, MYSQL_USERNAME, MYSQL_PASSWORD
#   缓存：  REDIS_HOST, REDIS_PORT, REDIS_PASSWORD
#   应用：  JAVA_OPTS, SESSION_TIMEOUT, MCP_ENABLED, CRM_URL
#   SQLBot：SQLBOT_ENCRYPT, SQLBOT_AES_KEY, SQLBOT_AES_IV
# ============================================================================

# 日志函数
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# ============================================================================
# 初始化配置目录
# ============================================================================
init_config() {
    log_info "初始化配置目录..."
    
    # 创建必要的目录
    mkdir -p /opt/cordys/conf
    mkdir -p /opt/cordys/data
    mkdir -p /opt/cordys/logs
    mkdir -p /opt/cordys/files
    
    # 复制默认配置文件（如果不存在）
    if [ ! -f /opt/cordys/conf/cordys-crm.properties ]; then
        log_info "复制默认配置文件..."
        if [ -f /installer/conf/cordys-crm.properties ]; then
            cp /installer/conf/cordys-crm.properties /opt/cordys/conf/
        else
            log_error "默认配置文件不存在: /installer/conf/cordys-crm.properties"
            exit 1
        fi
    fi
}

# ============================================================================
# 安全的配置替换函数
# 处理密码中可能包含的特殊字符: $, &, !, @, #, %, ^, *, (, ), |, \, /
# ============================================================================
safe_config_replace() {
    local config_file=$1
    local key=$2
    local value=$3
    
    # 参数验证
    if [ -z "$config_file" ] || [ -z "$key" ]; then
        log_error "safe_config_replace: 参数不能为空"
        return 1
    fi
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    local temp_file
    temp_file=$(mktemp) || {
        log_error "无法创建临时文件"
        return 1
    }
    
    # 确保临时文件在函数退出时被清理
    trap "rm -f '$temp_file' 2>/dev/null" RETURN
    
    # 使用 awk 进行替换，比 sed 更安全地处理特殊字符
    if grep -q "^${key}=" "$config_file" 2>/dev/null; then
        # 配置项已存在，进行替换
        # 使用 ENVIRON 传递值，避免 shell 转义问题
        REPLACE_VALUE="$value" awk -v k="$key" '
        BEGIN { FS="="; OFS="=" }
        {
            if ($1 == k) {
                print k, ENVIRON["REPLACE_VALUE"]
            } else {
                print $0
            }
        }
        ' "$config_file" > "$temp_file"
        
        if [ -s "$temp_file" ]; then
            # 保留原文件权限
            cat "$temp_file" > "$config_file"
            log_info "配置项 ${key} 已更新"
        else
            log_error "配置项 ${key} 更新失败：awk 输出为空"
            return 1
        fi
    else
        # 配置项不存在，追加到文件末尾
        # 使用 printf 避免特殊字符问题
        printf '%s=%s\n' "$key" "$value" >> "$config_file" || {
            log_error "无法写入配置文件: $config_file"
            return 1
        }
        log_info "配置项 ${key} 已添加"
    fi
    
    return 0
}

# ============================================================================
# 处理 MySQL CA 证书
# - MYSQL_SSL_CA:   直接提供 PEM 内容（多行）；脚本会写入 /opt/cordys/conf/mysql-ca.pem
# - MYSQL_SSL_CA_PATH: 指向容器内已有的 PEM 文件；会复制到 /opt/cordys/conf/mysql-ca.pem
# 返回值：输出生成的 CA 文件路径（若无则空）
# ============================================================================
write_mysql_ca() {
    local ca_target="/opt/cordys/conf/mysql-ca.pem"

    if [ -n "$MYSQL_SSL_CA" ]; then
        log_info "写入 MySQL CA 证书到 ${ca_target}"
        printf '%s\n' "$MYSQL_SSL_CA" > "$ca_target"
        echo "$ca_target"
        return
    fi

    if [ -n "$MYSQL_SSL_CA_PATH" ] && [ -f "$MYSQL_SSL_CA_PATH" ]; then
        log_info "复制 MySQL CA 证书: ${MYSQL_SSL_CA_PATH} -> ${ca_target}"
        cp "$MYSQL_SSL_CA_PATH" "$ca_target"
        echo "$ca_target"
        return
    fi

    echo ""
}

# ============================================================================
# 应用环境变量到配置文件
# ============================================================================
apply_env_config() {
    local config_file="/opt/cordys/conf/cordys-crm.properties"
    
    log_info "应用环境变量配置..."
    
    # ========================================
    # MySQL 配置
    # ========================================
    if [ -n "$MYSQL_HOST" ]; then
        log_info "检测到外部 MySQL 配置: ${MYSQL_HOST}:${MYSQL_PORT:-3306}"
        
        # 禁用内置 MySQL
        safe_config_replace "$config_file" "mysql.embedded.enabled" "false"
        
        # 构建 JDBC URL（包含连接池优化参数）
        local mysql_url="jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT:-3306}/${MYSQL_DATABASE:-cordys-crm}"
        mysql_url="${mysql_url}?autoReconnect=true&useUnicode=true&characterEncoding=UTF-8"
        mysql_url="${mysql_url}&characterSetResults=UTF-8&zeroDateTimeBehavior=convertToNull"
        mysql_url="${mysql_url}&allowPublicKeyRetrieval=true&useSSL=${MYSQL_SSL:-false}"
        mysql_url="${mysql_url}&serverTimezone=${TZ:-Asia/Shanghai}"
        mysql_url="${mysql_url}&connectTimeout=10000&socketTimeout=60000"
        mysql_url="${mysql_url}&sessionVariables=sql_mode=%27STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION%27"

        # SSL 模式和 CA 证书
        local mysql_ssl_mode=""
        if [ -n "$MYSQL_SSL_MODE" ]; then
            mysql_ssl_mode="$MYSQL_SSL_MODE"
        elif [ "${MYSQL_SSL,,}" = "true" ]; then
            mysql_ssl_mode="VERIFY_CA"
        fi
        if [ -n "$mysql_ssl_mode" ]; then
            mysql_url="${mysql_url}&sslMode=${mysql_ssl_mode}"
        fi

        # 如果提供 CA，则写入文件并注入 serverSslCert
        if [ "${MYSQL_SSL,,}" = "true" ] || [ "$mysql_ssl_mode" = "VERIFY_CA" ] || [ "$mysql_ssl_mode" = "VERIFY_IDENTITY" ]; then
            local mysql_ca_file
            mysql_ca_file=$(write_mysql_ca)
            if [ -n "$mysql_ca_file" ]; then
                mysql_url="${mysql_url}&serverSslCert=${mysql_ca_file}"
            fi
        fi
        
        safe_config_replace "$config_file" "spring.datasource.url" "$mysql_url"
        safe_config_replace "$config_file" "spring.datasource.username" "${MYSQL_USERNAME:-root}"
        safe_config_replace "$config_file" "spring.datasource.password" "${MYSQL_PASSWORD}"
        
        # 连接池配置（HikariCP）
        safe_config_replace "$config_file" "spring.datasource.hikari.minimum-idle" "${MYSQL_POOL_MIN:-5}"
        safe_config_replace "$config_file" "spring.datasource.hikari.maximum-pool-size" "${MYSQL_POOL_MAX:-20}"
        safe_config_replace "$config_file" "spring.datasource.hikari.idle-timeout" "300000"
        safe_config_replace "$config_file" "spring.datasource.hikari.max-lifetime" "1800000"
        safe_config_replace "$config_file" "spring.datasource.hikari.connection-timeout" "30000"
        safe_config_replace "$config_file" "spring.datasource.hikari.validation-timeout" "5000"
    else
        log_info "使用内置 MySQL"
    fi
    
    # ========================================
    # Redis 配置
    # ========================================
    if [ -n "$REDIS_HOST" ]; then
        # 支持 rediss:// 或 redis:// 前缀，统一剥离为纯主机名
        local redis_host="${REDIS_HOST#*://}"
        log_info "检测到外部 Redis 配置: ${redis_host}:${REDIS_PORT:-6379}"
        
        # 禁用内置 Redis
        safe_config_replace "$config_file" "redis.embedded.enabled" "false"
        
        safe_config_replace "$config_file" "spring.data.redis.host" "${redis_host}"
        safe_config_replace "$config_file" "spring.data.redis.port" "${REDIS_PORT:-6379}"
        
        if [ -n "$REDIS_PASSWORD" ]; then
            safe_config_replace "$config_file" "spring.data.redis.password" "${REDIS_PASSWORD}"
        fi

        # TLS 支持（Aiven 等云服务通常强制 TLS）
        if [ -n "$REDIS_SSL" ]; then
            safe_config_replace "$config_file" "spring.data.redis.ssl" "${REDIS_SSL}"
        fi
    else
        log_info "使用内置 Redis"
    fi
    
    # ========================================
    # MCP Server 配置
    # ========================================
    if [ -n "$MCP_ENABLED" ]; then
        safe_config_replace "$config_file" "mcp.embedded.enabled" "${MCP_ENABLED}"
    fi
    
    if [ -n "$CRM_URL" ]; then
        safe_config_replace "$config_file" "cordys.crm.url" "${CRM_URL}"
    fi
    
    # ========================================
    # 会话配置
    # ========================================
    if [ -n "$SESSION_TIMEOUT" ]; then
        safe_config_replace "$config_file" "spring.session.timeout" "${SESSION_TIMEOUT}"
    fi
    
    # ========================================
    # SQLBot 配置
    # ========================================
    if [ -n "$SQLBOT_ENCRYPT" ]; then
        safe_config_replace "$config_file" "sqlbot.encrypt" "${SQLBOT_ENCRYPT}"
    fi
    
    if [ -n "$SQLBOT_AES_KEY" ]; then
        safe_config_replace "$config_file" "sqlbot.aes-key" "${SQLBOT_AES_KEY}"
    fi
    
    if [ -n "$SQLBOT_AES_IV" ]; then
        safe_config_replace "$config_file" "sqlbot.aes-iv" "${SQLBOT_AES_IV}"
    fi
    
    # ========================================
    # 日志级别配置
    # ========================================
    if [ -n "$LOG_LEVEL" ]; then
        safe_config_replace "$config_file" "logging.level.root" "${LOG_LEVEL}"
    fi
    
    log_info "环境变量配置应用完成"
}

# ============================================================================
# 打印启动信息
# ============================================================================
print_startup_info() {
    local version=$(cat /tmp/CRM_VERSION 2>/dev/null || echo "unknown")
    
    log_info "=========================================="
    log_info "       Cordys CRM 容器启动"
    log_info "=========================================="
    log_info "版本:        ${version}"
    log_info "JVM 参数:    ${JAVA_OPTS:-默认}"
    
    if [ -n "$MYSQL_HOST" ]; then
        log_info "MySQL:       ${MYSQL_HOST}:${MYSQL_PORT:-3306}/${MYSQL_DATABASE:-cordys-crm}"
    else
        log_info "MySQL:       内置服务"
    fi
    
    if [ -n "$REDIS_HOST" ]; then
        log_info "Redis:       ${REDIS_HOST}:${REDIS_PORT:-6379}"
    else
        log_info "Redis:       内置服务"
    fi
    
    log_info "MCP Server:  ${MCP_ENABLED:-true}"
    log_info "=========================================="
}

# ============================================================================
# 启动应用
# ============================================================================
start_application() {
    log_info "启动 Cordys CRM 应用..."
    
    export CRM_VERSION=$(cat /tmp/CRM_VERSION 2>/dev/null || echo "main")
    
    # 构建 Java 命令
    local java_cmd="java"
    java_cmd="${java_cmd} ${JAVA_OPTIONS:-}"
    java_cmd="${java_cmd} ${JAVA_OPTS:-}"
    java_cmd="${java_cmd} -cp ${JAVA_CLASSPATH:-/app:/app/lib/*}"
    java_cmd="${java_cmd} ${JAVA_MAIN_CLASS:-cn.cordys.Application}"
    java_cmd="${java_cmd} --spring.config.additional-location=file:/opt/cordys/conf/"
    
    log_info "执行命令: ${java_cmd}"
    
    # 使用 exec 替换当前进程
    exec ${java_cmd}
}

# ============================================================================
# 优雅关闭处理
# ============================================================================
shutdown_handler() {
    log_info "收到关闭信号，正在优雅关闭..."
    # Java 应用会收到 SIGTERM 信号并优雅关闭
    exit 0
}

# 注册信号处理
trap shutdown_handler SIGTERM SIGINT

# ============================================================================
# 验证必要的环境变量
# ============================================================================
validate_required_env() {
    local has_error=0
    
    # 外部 MySQL 模式下必须提供密码
    if [ -n "$MYSQL_HOST" ]; then
        if [ -z "$MYSQL_PASSWORD" ]; then
            log_error "使用外部 MySQL 时，必须设置 MYSQL_PASSWORD 环境变量"
            has_error=1
        fi
        
        if [ -z "$MYSQL_DATABASE" ]; then
            log_warn "MYSQL_DATABASE 未设置，将使用默认值: cordys-crm"
        fi
    fi
    
    # 外部 Redis 模式下的警告
    if [ -n "$REDIS_HOST" ] && [ -z "$REDIS_PASSWORD" ]; then
        log_warn "REDIS_PASSWORD 未设置，如果 Redis 需要认证，连接将失败"
    fi
    
    if [ $has_error -eq 1 ]; then
        log_error "环境变量验证失败，请检查配置"
        exit 1
    fi
}

# ============================================================================
# 主函数
# ============================================================================
main() {
    # 打印启动信息
    print_startup_info
    
    # 验证必要的环境变量
    validate_required_env
    
    # 初始化配置
    init_config
    
    # 应用环境变量配置
    apply_env_config
    
    # 启动应用
    start_application
}

# 执行主函数
main "$@"
