# Traefik 反向代理部署指南

本目录包含 Traefik 反向代理的独立部署配置。

## 快速开始

### 1. 创建 Traefik 网络

```bash
docker network create traefik-public
```

### 2. 配置环境变量

```bash
# 创建环境变量文件
cat > .env << 'EOF'
TZ=Asia/Shanghai
ACME_EMAIL=your-email@example.com
TRAEFIK_DASHBOARD_HOST=traefik.yourdomain.com
TRAEFIK_LOG_LEVEL=INFO
EOF
```

### 3. 启动 Traefik

```bash
docker compose up -d
```

### 4. 部署 Cordys CRM（使用 Traefik）

```bash
cd ../
cp env.external.template .env

# 编辑 .env 配置外部 MySQL/Redis 和 Traefik 域名
vim .env

# 启动 Cordys CRM
docker compose -f docker-compose.external.yml -f docker-compose.traefik.yml up -d
```

## 环境变量说明

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `TZ` | Asia/Shanghai | 时区 |
| `ACME_EMAIL` | admin@example.com | Let's Encrypt 证书邮箱 |
| `TRAEFIK_DASHBOARD_HOST` | traefik.example.com | Dashboard 域名 |
| `TRAEFIK_LOG_LEVEL` | INFO | 日志级别 |

## 证书管理

Traefik 会自动申请和续期 Let's Encrypt 证书。证书存储在 `traefik-letsencrypt` 卷中。

### 查看证书状态

```bash
docker exec traefik cat /letsencrypt/acme.json | jq '.letsencrypt.Certificates'
```

## 安全建议

1. **生产环境禁用 Dashboard** 或限制访问 IP
2. **使用强密码** 配置 Basic Auth
3. **定期更新** Traefik 镜像
4. **监控日志** 及时发现异常

## 故障排查

```bash
# 查看 Traefik 日志
docker logs -f traefik

# 检查路由配置
docker exec traefik traefik healthcheck

# 查看访问日志
docker exec traefik tail -f /var/log/traefik/access.log
```

