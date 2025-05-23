# ========= Builder 阶段 =========
FROM node:18-alpine3.18 AS builder

# 使用稳定的 Alpine 仓库源，避免 edge 包兼容性问题
RUN echo "http://dl-cdn.alpinelinux.org/alpine/v3.21/main" > /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/v3.21/community" >> /etc/apk/repositories

# 安装必要的兼容层（gcompat 处理 glibc 符号）
RUN apk add --no-cache \
    gcompat \
    libc6-compat \
    openssl3 \
    openssl1.1-compat \
    --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community

WORKDIR /app

# 复制依赖文件并跳过 Prisma 安装
COPY package*.json ./
RUN npm install --ignore-scripts

# 复制本地预编译的 Prisma 引擎
COPY prisma-engines /app/prisma-engines
RUN chmod +x /app/prisma-engines/*

# 设置环境变量用于 npx prisma generate
ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-1.1.x \
    PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1 \
    PRISMA_CLIENT_ENGINE_TYPE=binary \
    PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node \
    PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine \
    PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine \
    PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt

# 复制项目文件并生成 Prisma Client
COPY . .
RUN npx prisma generate
RUN npm run build

# ========= Runner 阶段 =========
FROM node:18-alpine3.18 AS runner

# 安装兼容层并验证动态链接器是否存在
RUN apk add --no-cache gcompat libc6-compat && \
    mkdir -p /lib && \
    if [ ! -f /lib/ld-linux-armhf.so.3 ]; then \
       echo "错误：ld-linux-armhf.so.3 不存在" && exit 1; \
    fi

WORKDIR /app

LABEL author.name="DingDangDog" \
      author.email="dingdangdogx@outlook.com" \
      project.name="cashbook" \
      project.version="3"

# 设置共享库搜索路径
ENV LD_LIBRARY_PATH=/usr/lib:/lib

# 复制构建产物
COPY --from=builder /app/.output/ ./
COPY --from=builder /app/.output/server/node_modules/ ./node_modules/
COPY --from=builder /app/.output/server/node_modules/.prisma/ ./.prisma/
COPY ./prisma/ ./prisma/
COPY ./docker/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

# 复制 Prisma 引擎并验证文件
COPY --from=builder /app/prisma-engines /app/prisma-engines
RUN chmod +x /app/prisma-engines/* && \
    test -f /app/prisma-engines/query-engine || (echo "query-engine 缺失" && exit 1)

# 设置 Prisma 环境变量
ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-1.1.x \
    PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1 \
    PRISMA_CLIENT_ENGINE_TYPE=binary \
    PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine \
    PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node \
    PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine \
    PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt \
    PRISMA_HIDE_CHANGELOG=1 \
    PRISMA_HIDE_UPDATE_MESSAGE=1

# 验证依赖情况（不影响构建）
RUN echo "验证动态链接器：" && \
    ls -l /lib/ld-linux-armhf.so.3 && \
    echo "验证库依赖关系：" && \
    ldd /app/prisma-engines/libquery_engine.so.node || echo "ldd 验证失败，继续构建"

# 应用运行相关环境变量
ENV DATABASE_URL="file:/app/data/db/cashbook.db" \
    NUXT_APP_VERSION="4.1.3" \
    NUXT_DATA_PATH="/app/data" \
    NUXT_AUTH_SECRET="auth123" \
    NUXT_ADMIN_USERNAME="admin" \
    NUXT_ADMIN_PASSWORD="fb35e9343a1c095ce1c1d1eb6973dc570953159441c3ee315ecfefb6ed05f4cc" \
    PORT="9090"

VOLUME /app/data/
EXPOSE 9090

ENTRYPOINT ["/app/entrypoint.sh"]
