# Cordys CRM Docker 部署

本目录包含 Cordys CRM 的 Docker 部署相关文件。

## 📁 目录结构

```
docker/
├── Dockerfile                    # 多阶段构建文件（基于 Ubuntu 22.04）
├── entrypoint.sh                 # 容器入口脚本
├── docker-compose.yml            # 分离模式编排（含内置 MySQL/Redis）
├── docker-compose.external.yml   # ⭐ 外部服务模式（推荐生产环境）
├── docker-compose.traefik.yml    # Traefik 反代覆盖配置
├── docker-compose.prod.yml       # 生产环境资源限制
├── env.template                  # 分离模式环境变量模板
├── env.external.template         # ⭐ 外部服务模式环境变量模板
├── conf/                         # 配置文件目录
│   ├── mysql/my.cnf              # MySQL 配置（分离模式用）
│   └── redis/redis.conf          # Redis 配置（分离模式用）
└── init/                         # 初始化脚本
    └── mysql/init.sql            # MySQL 初始化 SQL
```

## 🚀 部署方案选择

| 方案 | 适用场景 | MySQL | Redis | 推荐度 |
|------|---------|-------|-------|--------|
| 方案1：单机模式 | 快速体验、开发测试 | 内置 | 内置 | ⭐⭐ |
| 方案2：分离模式 | 小型生产环境 | 容器内 | 容器内 | ⭐⭐⭐ |
| **方案3：外部服务** | **生产环境（推荐）** | **外部** | **外部** | ⭐⭐⭐⭐⭐ |

---

## ⭐ 方案3：外部服务部署（生产推荐）

使用已有的外部 MySQL 和 Redis 服务，配合 Traefik 反向代理。

### 前置条件

- [x] 外部 MySQL 8.0+ 服务已就绪
- [x] 外部 Redis 6.0+ 服务已就绪
- [x] 数据库 `cordys-crm` 已创建
- [x] 数据库用户已授权
- [x] Traefik 已部署（可选）

### 快速部署

```bash
# 1. 进入 docker 目录
cd docker

# 2. 复制外部服务环境变量模板
cp env.external.template .env

# 3. 编辑配置（必填：MySQL 和 Redis 连接信息）
vim .env

# 4. 启动服务
docker compose -f docker-compose.external.yml up -d

# 5. 查看日志
docker compose -f docker-compose.external.yml logs -f
```

### 配合 Traefik 部署

```bash
# 1. 创建 Traefik 网络（如果不存在）
docker network create traefik-public

# 2. 配置环境变量
cp env.external.template .env
vim .env  # 设置 TRAEFIK_DOMAIN=crm.example.com

# 3. 启动服务
docker compose -f docker-compose.external.yml -f docker-compose.traefik.yml up -d
```

### 必填环境变量

```bash
# MySQL 配置
MYSQL_HOST=your-mysql-host          # MySQL 地址
MYSQL_PASSWORD=your-mysql-password  # MySQL 密码

# Redis 配置
REDIS_HOST=your-redis-host          # Redis 地址
REDIS_PASSWORD=your-redis-password  # Redis 密码（如有）
```

---

## 方案1：单机模式（快速体验）

所有服务在同一容器内运行。

```bash
# 使用官方镜像一键启动
docker run -d \
  --name cordys-crm \
  --restart unless-stopped \
  -p 8081:8081 \
  -p 8082:8082 \
  -v ~/cordys:/opt/cordys \
  1panel/cordys-crm:latest
```

**访问地址**: http://localhost:8081  
**默认账号**: admin / CordysCRM

---

## 方案2：分离模式

MySQL、Redis、CRM 应用分别运行在独立容器。

```bash
# 1. 复制环境变量模板
cp env.template .env

# 2. 修改密码等配置
vim .env

# 3. 启动分离模式
docker compose --profile separated up -d
```

---

## 📊 端口说明

| 端口 | 服务 | 说明 |
|------|------|------|
| 8081 | Web 应用 | Cordys CRM 主服务 |
| 8082 | MCP Server | AI 智能体服务 |
| 3306 | MySQL | 仅分离模式暴露 |
| 6379 | Redis | 仅分离模式暴露 |

---

## 🔧 常用命令

```bash
# 启动服务（外部服务模式）
docker compose -f docker-compose.external.yml up -d

# 停止服务
docker compose -f docker-compose.external.yml down

# 查看状态
docker compose -f docker-compose.external.yml ps

# 查看日志
docker compose -f docker-compose.external.yml logs -f

# 重启服务
docker compose -f docker-compose.external.yml restart

# 进入容器
docker compose -f docker-compose.external.yml exec cordys-crm bash

# 更新镜像
docker compose -f docker-compose.external.yml pull
docker compose -f docker-compose.external.yml up -d
```

---

## 🔒 安全说明

### 密码处理

- ✅ 密码通过环境变量传递，不在命令行暴露
- ✅ 健康检查使用 TCP 端口检测，不暴露密码
- ✅ entrypoint.sh 使用安全的配置替换方法
- ✅ .env 文件应设置适当权限 (chmod 600)

### 镜像兼容性

- ✅ 基础镜像: `eclipse-temurin:21-jre-jammy` (Ubuntu 22.04 LTS)
- ✅ 与 Debian 10/11/12 完全兼容（glibc 系）
- ❌ 不使用 Alpine 镜像（避免 musl/glibc 兼容问题）
- ❌ 不包含 nginx（使用外部 Traefik 反代）

---

## 📚 详细文档

请参阅项目根目录的 [DEPLOYMENT.md](../DEPLOYMENT.md) 获取完整部署指南。
