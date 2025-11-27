# Cordys CRM 部署指南

本文档详细介绍 Cordys CRM 的部署方式、配置参数和最佳实践。

---

## 📋 目录

- [系统要求](#系统要求)
- [快速部署](#快速部署)
- [部署模式](#部署模式)
- [环境变量配置](#环境变量配置)
- [高级配置](#高级配置)
- [生产环境部署](#生产环境部署)
- [Traefik 反向代理](#traefik-反向代理)
- [升级与维护](#升级与维护)
- [故障排查](#故障排查)

---

## ⚠️ 重要说明

### 系统兼容性

| 组件 | 基础镜像 | 说明 |
|------|---------|------|
| CRM 应用 | `eclipse-temurin:21-jre-jammy` | Ubuntu 22.04 LTS，与 Debian 10/11/12 完全兼容 |
| MySQL | `mysql:8.0-debian` | Debian 版本，glibc 兼容 |
| Redis | `redis:7-bookworm` | Debian 12 版本，glibc 兼容 |

> **注意**: 本项目**不使用 Alpine 镜像**，避免 musl/glibc 兼容性问题。

### 安全特性

- ✅ **MySQL 健康检查不暴露密码**: 使用 TCP 端口检测
- ✅ **Redis 健康检查不暴露密码**: 使用 TCP 端口检测
- ✅ **支持 Docker Secrets**: 生产环境敏感信息管理
- ✅ **不包含 nginx**: 使用 Traefik 反向代理（或其他反代）

---

## 系统要求

### 硬件要求

| 环境 | CPU | 内存 | 磁盘 |
|------|-----|------|------|
| 最低配置 | 2 核 | 4 GB | 50 GB |
| 推荐配置 | 4 核 | 8 GB | 100 GB |
| 生产环境 | 8 核+ | 16 GB+ | 200 GB+ SSD |

### 软件要求

| 软件 | 版本要求 | 说明 |
|------|---------|------|
| Docker | 20.10+ | 容器运行时 |
| Docker Compose | 2.0+ | 容器编排 |
| Linux | Debian 10+/Ubuntu 18.04+/CentOS 7+ | 操作系统 |

### Debian Linux 环境准备

```bash
# 更新系统
sudo apt-get update && sudo apt-get upgrade -y

# 安装 Docker（官方源）
curl -fsSL https://get.docker.com | sudo sh

# 将当前用户加入 docker 组
sudo usermod -aG docker $USER
newgrp docker

# 验证 Docker 安装
docker --version
docker compose version

# 安装网络工具（用于连通性测试）
sudo apt-get install -y netcat-openbsd mysql-client redis-tools curl
```

### 端口要求

| 端口 | 用途 | 必需 |
|------|------|------|
| 8081 | Web 应用 | ✅ 是 |
| 8082 | MCP Server (AI) | ⚡ 推荐 |
| 3306 | MySQL 数据库 | 🔧 分离模式 |
| 6379 | Redis 缓存 | 🔧 分离模式 |

---

## 快速部署

### 方式一：一键部署（推荐新手）

```bash
# 拉取并启动容器
docker run -d \
  --name cordys-crm \
  --restart unless-stopped \
  -p 8081:8081 \
  -p 8082:8082 \
  -v ~/cordys:/opt/cordys \
  1panel/cordys-crm:latest

# 查看启动日志
docker logs -f cordys-crm
```

### 方式二：Docker Compose 部署

```bash
# 克隆仓库
git clone https://github.com/1Panel-dev/CordysCRM.git
cd CordysCRM/docker

# 复制配置文件
cp .env.example .env

# 启动服务
docker compose up -d

# 查看状态
docker compose ps
```

### 访问系统

- **访问地址**: http://<服务器IP>:8081
- **默认账号**: admin
- **默认密码**: CordysCRM

> ⚠️ **重要提示**: 首次登录后请立即修改默认密码！

---

## 部署模式

### 模式一：单机模式 (All-in-One)

适用于快速体验、开发测试、小型团队使用。

**特点**：
- 所有服务（MySQL、Redis、CRM 应用）在同一容器内运行
- 配置简单，一键启动
- 资源占用相对较小

```bash
# 使用默认配置启动
docker compose up -d

# 或指定 profile
docker compose --profile allinone up -d
```

**配置文件结构**：
```
~/cordys/
├── conf/
│   └── cordys-crm.properties  # 应用配置
├── data/
│   ├── mysql/                 # MySQL 数据
│   └── redis/                 # Redis 数据
├── logs/                      # 应用日志
└── files/                     # 上传文件
```

### 模式二：分离模式 (Separated)

适用于生产环境、大型团队、高可用需求。

**特点**：
- MySQL、Redis、CRM 应用分别运行在独立容器
- 便于独立扩展和维护
- 更好的资源隔离和监控

```bash
# 启动分离模式
docker compose --profile separated up -d

# 查看所有服务状态
docker compose ps
```

**服务架构**：
```
┌─────────────────────────────────────────┐
│            Docker Network               │
│                                         │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐ │
│  │ MySQL   │  │  Redis  │  │ Cordys  │ │
│  │  :3306  │  │  :6379  │  │ :8081   │ │
│  └────┬────┘  └────┬────┘  └────┬────┘ │
│       │            │            │       │
└───────┼────────────┼────────────┼───────┘
        │            │            │
   mysql-data   redis-data   cordys-data
```

### 模式三：外部服务模式（推荐生产环境）

连接已有的外部 MySQL 和 Redis 服务，适用于：
- 云数据库（阿里云 RDS、AWS RDS、腾讯云 CDB 等）
- 云缓存（阿里云 Redis、AWS ElastiCache 等）
- 企业已有的 MySQL/Redis 基础设施

#### 方式 A：使用 Docker Compose（推荐）

```bash
cd docker

# 复制外部服务模式的环境变量模板
cp env.external.template .env

# 编辑配置文件，填写外部服务信息
vim .env

# 使用外部服务模式启动
docker compose -f docker-compose.external.yml up -d

# 查看日志
docker compose -f docker-compose.external.yml logs -f
```

#### 方式 B：使用 Docker Run

```bash
# 启动 CRM 应用（连接外部服务）
docker run -d \
  --name cordys-crm \
  --restart unless-stopped \
  -p 8081:8081 \
  -p 8082:8082 \
  -v ~/cordys:/opt/cordys \
  -e TZ=Asia/Shanghai \
  -e JAVA_OPTS="-Xms1g -Xmx2g -XX:+UseG1GC" \
  -e MYSQL_HOST=your-mysql-host \
  -e MYSQL_PORT=3306 \
  -e MYSQL_DATABASE=cordys-crm \
  -e MYSQL_USERNAME=cordys \
  -e MYSQL_PASSWORD=your-mysql-password \
  -e REDIS_HOST=your-redis-host \
  -e REDIS_PORT=6379 \
  -e REDIS_PASSWORD=your-redis-password \
  -e MCP_ENABLED=true \
  -e CRM_URL=https://crm.example.com \
  1panel/cordys-crm:latest
```

#### 外部服务要求

**MySQL 要求**：
| 项目 | 要求 |
|------|------|
| 版本 | MySQL 8.0+ |
| 字符集 | utf8mb4 |
| 排序规则 | utf8mb4_unicode_ci |
| 数据库 | 需要预先创建 `cordys-crm` 数据库 |
| 用户权限 | ALL PRIVILEGES on cordys-crm.* |

**创建数据库脚本**：
```sql
CREATE DATABASE IF NOT EXISTS `cordys-crm` 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'cordys'@'%' IDENTIFIED BY 'your-password';
GRANT ALL PRIVILEGES ON `cordys-crm`.* TO 'cordys'@'%';
FLUSH PRIVILEGES;
```

**Redis 要求**：
| 项目 | 要求 |
|------|------|
| 版本 | Redis 6.0+ |
| 内存 | 建议 512MB+ |
| 持久化 | 建议开启 RDB 或 AOF |

#### 连接验证

启动后检查日志确认连接成功：

```bash
# 查看启动日志
docker logs cordys-crm | grep -E "(MySQL|Redis|就绪)"

# 预期输出：
# [INFO] 检测到外部 MySQL 配置: your-mysql-host:3306
# [INFO] 检测到外部 Redis 配置: your-redis-host:6379
# [INFO] MySQL (your-mysql-host:3306) 已就绪 (耗时 2s)
# [INFO] Redis (your-redis-host:6379) 已就绪 (耗时 1s)
```

---

## 环境变量配置

### 基础配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `CRM_VERSION` | latest | 镜像版本 |
| `TZ` | Asia/Shanghai | 时区设置 |
| `WEB_PORT` | 8081 | Web 应用端口 |
| `MCP_PORT` | 8082 | MCP Server 端口 |

### MySQL 配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `MYSQL_HOST` | - | MySQL 主机地址（外部模式必填） |
| `MYSQL_PORT` | 3306 | MySQL 端口 |
| `MYSQL_DATABASE` | cordys-crm | 数据库名称 |
| `MYSQL_USERNAME` | cordys | 数据库用户名 |
| `MYSQL_PASSWORD` | CordysCRM@mysql | 数据库密码 |
| `MYSQL_ROOT_PASSWORD` | CordysCRM@mysql | Root 密码（分离模式） |

### Redis 配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `REDIS_HOST` | - | Redis 主机地址（外部模式必填） |
| `REDIS_PORT` | 6379 | Redis 端口 |
| `REDIS_PASSWORD` | CordysCRM@redis | Redis 密码 |

### JVM 配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `JAVA_OPTS` | -Xms512m -Xmx1024m | JVM 参数 |
| `SESSION_TIMEOUT` | 30d | 会话超时时间 |

**JVM 参数建议**：

| 内存规模 | 推荐配置 |
|----------|----------|
| 4 GB | `-Xms512m -Xmx1g` |
| 8 GB | `-Xms1g -Xmx2g` |
| 16 GB | `-Xms2g -Xmx4g -XX:+UseG1GC` |
| 32 GB+ | `-Xms4g -Xmx8g -XX:+UseG1GC -XX:MaxGCPauseMillis=100` |

### MCP Server 配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `MCP_ENABLED` | true | 是否启用 MCP Server |
| `CRM_URL` | http://localhost:8081 | CRM 访问 URL |

### SQLBot 配置（可选）

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `SQLBOT_ENCRYPT` | false | 是否加密 API 返回数据 |
| `SQLBOT_AES_KEY` | - | AES 加密密钥 |
| `SQLBOT_AES_IV` | - | AES 初始化向量 |

---

## 高级配置

### 配置文件详解

主配置文件路径：`/opt/cordys/conf/cordys-crm.properties`

```properties
# ============================================================
# 数据库配置
# ============================================================
# 使用内置 MySQL（单机模式）
mysql.embedded.enabled=true

# 外部 MySQL 配置
spring.datasource.url=jdbc:mysql://localhost:3306/cordys-crm?...
spring.datasource.username=root
spring.datasource.password=CordysCRM@mysql

# ============================================================
# Redis 配置
# ============================================================
# 使用内置 Redis（单机模式）
redis.embedded.enabled=true

# 外部 Redis 配置
spring.data.redis.host=127.0.0.1
spring.data.redis.port=6379
spring.data.redis.password=CordysCRM@redis

# ============================================================
# 会话配置
# ============================================================
spring.session.timeout=30d
spring.session.redis.repository-type=indexed

# ============================================================
# MCP Server 配置
# ============================================================
mcp.embedded.enabled=true
cordys.crm.url=http://127.0.0.1:8081
spring.ai.mcp.server.name=cordys-crm-mcp-server
spring.ai.mcp.server.version=1.0.0

# ============================================================
# SQLBot 智能问数配置
# ============================================================
# 支持配置只读用户
# sqlbot.datasource.username=readonly-user
# sqlbot.datasource.password=readonly-password

# 支持加密返回数据
# sqlbot.encrypt=true
# sqlbot.aes-key=your-32-char-key
# sqlbot.aes-iv=your-16-char-iv

# ============================================================
# 仪表盘白名单配置
# ============================================================
dashboard.whitelist.enabled=false
dashboard.whitelist.allowed=192.168.1.0/24,10.0.0.0/8
```

### SSL/HTTPS 配置

#### 方式一：使用 Traefik 反向代理（推荐）

Traefik 是现代化的云原生反向代理，支持自动 HTTPS、服务发现和负载均衡。

**步骤 1：创建 Traefik 网络**

```bash
docker network create traefik-public
```

**步骤 2：部署 Traefik（如尚未部署）**

创建 `traefik/docker-compose.yml`：

```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=traefik-public"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=admin@example.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik-letsencrypt:/letsencrypt
    networks:
      - traefik-public
    labels:
      - "traefik.enable=true"
      # Dashboard（可选）
      - "traefik.http.routers.traefik.rule=Host(`traefik.example.com`)"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.tls.certresolver=letsencrypt"
      - "traefik.http.routers.traefik.service=api@internal"

networks:
  traefik-public:
    external: true

volumes:
  traefik-letsencrypt:
```

启动 Traefik：

```bash
cd traefik
docker compose up -d
```

**步骤 3：部署 Cordys CRM（使用 Traefik）**

```bash
cd CordysCRM/docker

# 配置环境变量
cat >> .env << EOF
DOMAIN=crm.example.com
MCP_DOMAIN=mcp.example.com
TRAEFIK_NETWORK=traefik-public
CERT_RESOLVER=letsencrypt
EOF

# 启动服务（外部服务 + Traefik）
docker compose -f docker-compose.external.yml -f docker-compose.traefik.yml up -d
```

**Traefik 标签说明**：

| 标签 | 说明 |
|------|------|
| `traefik.enable=true` | 启用 Traefik 代理 |
| `traefik.http.routers.*.rule` | 路由规则（域名匹配） |
| `traefik.http.routers.*.tls.certresolver` | 证书解析器（自动申请证书） |
| `traefik.http.services.*.loadbalancer.server.port` | 后端服务端口 |

**完整的 Traefik 集成配置**请参考：`docker/docker-compose.traefik.yml`

#### 方式二：应用内配置 SSL（不推荐生产环境）

在配置文件中添加（需要预先准备 PKCS12 格式证书）：

```properties
server.ssl.enabled=true
server.ssl.key-store=/opt/cordys/conf/keystore.p12
server.ssl.key-store-password=your-keystore-password
server.ssl.key-store-type=PKCS12
```

> ⚠️ **注意**：直接在应用内配置 SSL 不便于证书管理和更新，生产环境强烈建议使用 Traefik 统一管理证书。

---

## Traefik 反向代理

### 前置条件

- Traefik v2.x 或 v3.x 已部署
- 域名 DNS 已配置
- SSL 证书配置（推荐 Let's Encrypt）

### 部署步骤

```bash
# 1. 创建 Traefik 网络（如果尚未创建）
docker network create traefik-public

# 2. 配置环境变量
cd docker
cp env.external.template .env
vim .env

# 3. 设置 Traefik 相关变量
cat >> .env << EOF
TRAEFIK_HOST=crm.example.com
TRAEFIK_ENTRYPOINT=websecure
TRAEFIK_CERT_RESOLVER=letsencrypt
EOF

# 4. 启动服务（外部 MySQL/Redis + Traefik）
docker compose -f docker-compose.external.yml -f docker-compose.traefik.yml up -d
```

### Traefik 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `TRAEFIK_HOST` | crm.example.com | 主域名 |
| `TRAEFIK_MCP_HOST` | mcp.crm.example.com | MCP 子域名（可选）|
| `TRAEFIK_ENTRYPOINT` | websecure | Traefik 入口点 |
| `TRAEFIK_CERT_RESOLVER` | letsencrypt | 证书解析器 |

### Traefik 功能

- ✅ 自动 HTTPS 证书（Let's Encrypt）
- ✅ HTTP 自动重定向到 HTTPS
- ✅ 安全响应头（HSTS、XSS 保护等）
- ✅ Gzip 压缩
- ✅ MCP Server 路由支持

---

## 生产环境部署

### 部署清单

- [ ] 修改所有默认密码
- [ ] 配置 SSL/HTTPS
- [ ] 设置防火墙规则
- [ ] 配置日志轮转
- [ ] 设置定期备份
- [ ] 配置监控告警
- [ ] 准备灾难恢复方案

### 使用生产配置

```bash
# 复制生产环境配置
cp .env.example .env
vim .env  # 修改配置

# 使用生产配置启动
docker compose -f docker-compose.yml -f docker-compose.prod.yml --profile separated up -d
```

### 资源限制配置

生产环境建议配置资源限制：

```yaml
# docker-compose.prod.yml
services:
  cordys-app:
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 4G
        reservations:
          cpus: '2'
          memory: 2G
```

### 数据备份

#### 自动备份脚本

```bash
#!/bin/bash
# backup.sh - Cordys CRM 备份脚本

BACKUP_DIR="/backup/cordys"
DATE=$(date +%Y%m%d_%H%M%S)

# 创建备份目录
mkdir -p ${BACKUP_DIR}

# 备份 MySQL 数据
docker exec cordys-mysql mysqldump -u root -p'CordysCRM@mysql' cordys-crm | gzip > ${BACKUP_DIR}/mysql_${DATE}.sql.gz

# 备份配置文件
tar -czf ${BACKUP_DIR}/conf_${DATE}.tar.gz /opt/cordys/conf

# 备份上传文件
tar -czf ${BACKUP_DIR}/files_${DATE}.tar.gz /opt/cordys/files

# 清理 7 天前的备份
find ${BACKUP_DIR} -type f -mtime +7 -delete

echo "备份完成: ${BACKUP_DIR}"
```

#### 配置定时备份

```bash
# 添加定时任务（每天凌晨 2 点执行）
echo "0 2 * * * /opt/scripts/backup.sh >> /var/log/cordys-backup.log 2>&1" | crontab -
```

### 监控配置

#### Prometheus 指标

Cordys CRM 暴露 Prometheus 指标端点：

```
http://localhost:8081/actuator/prometheus
```

#### 健康检查端点

```
http://localhost:8081/actuator/health
```

---

## 升级与维护

### 升级步骤

```bash
# 1. 备份数据
./backup.sh

# 2. 拉取新版本镜像
docker compose pull

# 3. 停止当前服务
docker compose down

# 4. 启动新版本
docker compose up -d

# 5. 检查服务状态
docker compose ps
docker compose logs -f cordys-app
```

### 回滚操作

```bash
# 如果新版本有问题，可以回滚到之前的版本
docker compose down

# 修改 .env 中的版本号
echo "CRM_VERSION=v1.3.1" >> .env

# 重新启动
docker compose up -d
```

### 日志管理

```bash
# 查看实时日志
docker compose logs -f

# 查看特定服务日志
docker compose logs -f cordys-app

# 查看最近 100 行日志
docker compose logs --tail=100 cordys-app
```

---

## 故障排查

### 常见问题

#### 1. 服务无法启动

```bash
# 检查容器状态
docker compose ps

# 查看启动日志
docker compose logs cordys-app

# 检查端口占用
netstat -tlnp | grep 8081
```

#### 2. 数据库连接失败

```bash
# 检查 MySQL 状态
docker compose logs mysql

# 测试数据库连接
docker exec -it cordys-mysql mysql -u root -p

# 检查网络连接
docker network ls
docker network inspect cordys-network
```

#### 3. 内存不足

```bash
# 查看内存使用
docker stats

# 调整 JVM 参数
vim .env
# 修改 JAVA_OPTS=-Xms256m -Xmx512m

# 重启服务
docker compose restart cordys-app
```

#### 4. 磁盘空间不足

```bash
# 检查磁盘使用
df -h

# 清理 Docker 资源
docker system prune -a

# 清理日志文件
docker compose logs --no-log-prefix cordys-app > /dev/null
```

#### 5. 外部服务模式连接问题（方案3）

**问题：无法连接到外部 MySQL**

```bash
# 1. 检查网络连通性
nc -zv $MYSQL_HOST $MYSQL_PORT
# 或
telnet $MYSQL_HOST $MYSQL_PORT

# 2. 检查防火墙（Debian）
sudo iptables -L -n | grep $MYSQL_PORT

# 3. 测试 MySQL 认证
mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USERNAME -p'$MYSQL_PASSWORD' -e "SELECT 1"

# 4. 检查 MySQL 用户权限
mysql -h $MYSQL_HOST -u root -p -e "SHOW GRANTS FOR 'cordys'@'%';"

# 5. 查看容器日志中的具体错误
docker logs cordys-crm 2>&1 | grep -i "mysql\|connection\|refused\|timeout"
```

**常见 MySQL 连接错误及解决方案**：

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| `Connection refused` | MySQL 未监听或防火墙阻止 | 检查 MySQL bind-address 和防火墙 |
| `Access denied` | 用户名/密码错误或权限不足 | 重新创建用户并授权 |
| `Unknown database` | 数据库不存在 | 创建 cordys-crm 数据库 |
| `Communications link failure` | 网络不稳定或超时 | 检查网络延迟，增加连接超时 |

**问题：无法连接到外部 Redis**

```bash
# 1. 检查网络连通性
nc -zv $REDIS_HOST $REDIS_PORT

# 2. 测试 Redis 认证
redis-cli -h $REDIS_HOST -p $REDIS_PORT -a '$REDIS_PASSWORD' ping

# 3. 检查 Redis 日志
docker logs cordys-crm 2>&1 | grep -i "redis\|jedis"
```

**常见 Redis 连接错误及解决方案**：

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| `NOAUTH Authentication required` | 需要密码但未提供 | 设置 REDIS_PASSWORD |
| `ERR invalid password` | 密码错误 | 检查 REDIS_PASSWORD 配置 |
| `Connection refused` | Redis 未启动或防火墙阻止 | 检查 Redis 状态和 bind 配置 |

**问题：密码包含特殊字符导致连接失败**

```bash
# 错误示例（密码包含 $ 符号）
docker run -e MYSQL_PASSWORD=P@ss$word ...  # 错误！$ 会被 shell 解释

# 正确做法 1：使用单引号
docker run -e MYSQL_PASSWORD='P@ss$word' ...

# 正确做法 2：转义特殊字符
docker run -e MYSQL_PASSWORD=P@ss\$word ...

# 正确做法 3：使用 .env 文件（推荐）
echo "MYSQL_PASSWORD=P@ss\$word" >> .env
docker compose up -d
```

#### 6. Debian 特定问题

**问题：Docker 服务启动失败**

```bash
# 检查 Docker 服务状态
sudo systemctl status docker

# 查看详细日志
sudo journalctl -u docker -f

# 重启 Docker 服务
sudo systemctl restart docker
```

**问题：权限不足**

```bash
# 确保用户在 docker 组
sudo usermod -aG docker $USER

# 重新登录或运行
newgrp docker

# 验证
docker ps
```

**问题：DNS 解析问题**

```bash
# 如果容器内无法解析主机名
# 编辑 /etc/docker/daemon.json
sudo cat > /etc/docker/daemon.json << 'EOF'
{
  "dns": ["8.8.8.8", "8.8.4.4"]
}
EOF

# 重启 Docker
sudo systemctl restart docker
```

### 获取帮助

- **在线文档**: https://cordys.cn/docs/
- **GitHub Issues**: https://github.com/1Panel-dev/CordysCRM/issues
- **微信交流群**: 扫描 README 中的二维码

---

## 附录

### 目录结构

```
/opt/cordys/
├── conf/                      # 配置文件目录
│   └── cordys-crm.properties  # 主配置文件
├── data/                      # 数据目录
│   ├── mysql/                 # MySQL 数据（单机模式）
│   └── redis/                 # Redis 数据（单机模式）
├── logs/                      # 日志目录
│   ├── cordys.log             # 应用日志
│   └── gc.log                 # GC 日志
└── files/                     # 上传文件目录
    └── attachments/           # 附件存储
```

### 端口说明

| 端口 | 服务 | 协议 | 说明 |
|------|------|------|------|
| 8081 | Cordys CRM | HTTP | Web 应用主端口 |
| 8082 | MCP Server | HTTP | AI 智能体服务端口 |
| 3306 | MySQL | TCP | 数据库端口 |
| 6379 | Redis | TCP | 缓存服务端口 |

### 环境变量速查表

| 变量 | 必需 | 默认值 | 说明 |
|------|------|--------|------|
| `MYSQL_HOST` | 外部模式 | - | MySQL 地址 |
| `MYSQL_PASSWORD` | 是 | CordysCRM@mysql | MySQL 密码 |
| `REDIS_HOST` | 外部模式 | - | Redis 地址 |
| `REDIS_PASSWORD` | 是 | CordysCRM@redis | Redis 密码 |
| `JAVA_OPTS` | 否 | -Xms512m -Xmx1024m | JVM 参数 |
| `MCP_ENABLED` | 否 | true | MCP 服务开关 |
| `TZ` | 否 | Asia/Shanghai | 时区 |

---

*文档更新时间: 2024-11*

