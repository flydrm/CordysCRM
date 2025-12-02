# ============================================================================
# Cordys CRM - 多阶段 Docker 构建文件
# 
# 说明：
#   - 阶段 1 (frontend): 构建前端资源
#   - 阶段 2 (build): 构建后端 Java 应用
#   - 阶段 3 (runtime): 最终运行时镜像
#
# 构建命令：
#   docker build -t cordys-crm:latest -f docker/Dockerfile .
#   docker build -t cordys-crm:v1.3.2 --build-arg CRM_VERSION=v1.3.2 -f docker/Dockerfile .
# ============================================================================

# ================================
# 阶段 1: 前端构建
# ================================
FROM --platform=${BUILDPLATFORM:-linux/amd64} node:22-slim AS frontend

LABEL stage="frontend-builder"

WORKDIR /frontend

# 复制前端源码（包含所有配置文件）
COPY frontend/package.json frontend/pnpm-workspace.yaml frontend/tsconfig.json ./
COPY frontend/postcss.config.cjs ./
COPY frontend/packages ./packages

# 安装依赖并构建
# 说明：
#   - 根目录有 package.json 和 pnpm-workspace.yaml
#   - pnpm install 会自动处理 workspace 中的所有包
#   - pnpm run build 会递归构建所有包
RUN npm install -g pnpm && \
    pnpm install --no-frozen-lockfile && \
    pnpm run build && \
    echo "Frontend build completed successfully"

# ================================
# 阶段 2: 后端构建
# ================================
FROM eclipse-temurin:21-jdk AS build

LABEL stage="backend-builder"

WORKDIR /build

# 复制 Maven 包装器和 POM 文件（利用 Docker 缓存）
COPY mvnw mvnw.cmd pom.xml lombok.config ./
COPY .mvn .mvn
COPY backend backend

# 复制 frontend/pom.xml（Maven 需要解析模块结构）
COPY frontend/pom.xml frontend/pom.xml

# 复制前端构建产物到 Maven 期望的位置
COPY --from=frontend /frontend/packages/web/dist /build/frontend/packages/web/dist
COPY --from=frontend /frontend/packages/mobile/dist /build/frontend/packages/mobile/dist

# 构建后端应用（排除 frontend 模块，因为前端已经单独构建）
RUN chmod +x mvnw && \
    ./mvnw clean package -DskipTests -pl '!frontend' -Dmaven.repo.local=/root/.m2/repository && \
    mkdir -p backend/app/target/dependency && \
    cd backend/app/target/dependency && \
    jar -xf ../*.jar && \
    echo "Backend build completed successfully"

# ================================
# 阶段 3: 运行时镜像
# ================================
# 重要说明：
# - 使用 eclipse-temurin:21-jre-jammy (基于 Ubuntu 22.04 LTS)
# - 与 Debian 10/11/12 生产环境完全兼容（同为 glibc 系）
# - 不使用 Alpine（musl libc 可能导致兼容性问题）
# - 不包含 nginx（使用外部 Traefik 反代）
# ================================
FROM eclipse-temurin:21-jre-jammy AS runtime

LABEL maintainer="FIT2CLOUD <support@fit2cloud.com>"
LABEL org.opencontainers.image.title="Cordys CRM"
LABEL org.opencontainers.image.description="新一代开源 AI CRM 系统"
LABEL org.opencontainers.image.url="https://github.com/1Panel-dev/CordysCRM"
LABEL org.opencontainers.image.vendor="FIT2CLOUD"
LABEL org.opencontainers.image.base.name="eclipse-temurin:21-jre-jammy"

# 安装必要的运行时依赖（Debian/Ubuntu 包管理器）
# - curl: HTTP 请求和健康检查
# - netcat-openbsd: TCP 端口检测（nc 命令）
# - gettext-base: envsubst 配置模板替换
# - gawk: 配置文件处理
# - default-mysql-client: MySQL 连接测试
# - redis-tools: redis-cli 连接测试
# 注意：不包含 nginx，使用外部 Traefik 反代
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    netcat-openbsd \
    gettext-base \
    gawk \
    default-mysql-client \
    redis-tools \
    procps \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

# 创建应用目录和非 root 用户（安全最佳实践）
RUN groupadd -g 1000 cordys && \
    useradd -u 1000 -g cordys -m -s /bin/bash cordys && \
    mkdir -p /app /opt/cordys/conf /opt/cordys/data /opt/cordys/logs

# 设置工作目录
WORKDIR /app

# 复制构建产物
ARG MODULE=app
ARG DEPENDENCY=/build/backend/${MODULE}/target/dependency

COPY --from=build ${DEPENDENCY}/BOOT-INF/lib /app/lib
COPY --from=build ${DEPENDENCY}/META-INF /app/META-INF
COPY --from=build ${DEPENDENCY}/BOOT-INF/classes /app
COPY --from=build /build/backend/${MODULE}/src/main/resources/static /app/static
# 备份原始 Spring Boot 可执行包，便于回退使用 -jar 方式（使用通配符覆盖所有产物）
COPY --from=build /build/backend/${MODULE}/target/*.jar /app/app.jar

# 复制配置和启动脚本
COPY installer/shells /shells
COPY installer/conf /installer/conf
COPY installer/mcp /app/mcp
COPY docker/entrypoint.sh /entrypoint.sh

# 设置权限
RUN chmod +x /shells/*.sh /entrypoint.sh && \
    chown -R cordys:cordys /app /opt/cordys /shells

# 环境变量配置
ENV JAVA_CLASSPATH=/app:/app/lib/*
ENV JAVA_MAIN_CLASS=cn.cordys.Application
ENV AB_OFF=true
ENV JAVA_OPTIONS="-Dfile.encoding=utf-8 -Djava.awt.headless=true --add-opens java.base/jdk.internal.loader=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED"

# JVM 性能调优参数
ENV JAVA_OPTS="-Xms512m -Xmx1024m -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/opt/cordys/logs"

# 版本信息
ARG CRM_VERSION=main
ENV CRM_VERSION=${CRM_VERSION}
RUN echo -n "${CRM_VERSION}" > /tmp/CRM_VERSION

# 数据卷
VOLUME ["/opt/cordys"]

# 暴露端口
# 8081: Web 应用端口
# 8082: MCP Server 端口
EXPOSE 8081 8082

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8081/actuator/health || exit 1

# 入口点
ENTRYPOINT ["/entrypoint.sh"]

