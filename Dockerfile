# 使用 ARMv7 专用基础镜像
FROM arm32v7/node:20-alpine3.21 AS builder

# 替换 Alpine 仓库源（避免 edge 导致兼容性问题）
RUN echo "http://dl-cdn.alpinelinux.org/alpine/v3.21/main" > /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/v3.21/community" >> /etc/apk/repositories

# 安装 ARMv7 依赖（不指定版本，避免冲突）
RUN apk add --no-cache \
    gcompat \
    libc6-compat \
    libstdc++

WORKDIR /app

COPY package*.json ./

# 安装依赖（跳过Prisma自动安装）
RUN npm install --ignore-scripts

# 复制本地Prisma引擎
COPY prisma-engines /app/prisma-engines

# 设置Prisma环境变量指向本地引擎
ENV PRISMA_CLI_BINARY_TARGET=custom
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt

# 设置文件执行权限
RUN chmod +x ./prisma-engines/* && \
    chmod +x ./prisma-engines/*.so.node  # 如果.so文件需要执行权限
COPY . .
# 指定 Prisma 使用 ARMv7 引擎
#ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-1.1.x
# 在builder阶段添加
#RUN file /app/prisma-engines/query-engine
# 生成Prisma Client
RUN npx prisma generate
RUN npm run build

FROM arm32v7/node:20-alpine3.21 AS runner

# 修复动态链接器（关键修复）
RUN apk add --no-cache gcompat libc6-compat && \
    mkdir -p /lib && \
    if [ ! -f /lib/ld-linux-armhf.so.3 ]; then \
        wget -q -O /tmp/ld-linux-armhf.so.3 https://github.com/docker-library/faq/raw/main/glibc/ld-linux-armhf.so.3 && \
        mv /tmp/ld-linux-armhf.so.3 /lib/ && \
        chmod +x /lib/ld-linux-armhf.so.3; \
    fi
# 其余部分保持不变...
LABEL author.name="DingDangDog"
LABEL author.email="dingdangdogx@outlook.com"
LABEL project.name="cashbook"
LABEL project.version="3"
WORKDIR /app
# 设置库路径
ENV LD_LIBRARY_PATH=/usr/lib:/lib

# 复制生产环境需要的文件
COPY --from=builder /app/.output/ ./
COPY --from=builder /app/.output/server/node_modules/ ./node_modules/
COPY --from=builder /app/.output/server/node_modules/.prisma/ ./.prisma/
COPY ./prisma/ ./prisma/
COPY ./docker/entrypoint.sh ./entrypoint.sh
RUN chmod +x entrypoint.sh
# 从 builder 复制预编译的引擎
COPY --from=builder /app/prisma-engines /app/prisma-engines
# 设置生产环境变量指向这些引擎
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt
# 确保文件可执行权限
RUN chmod +x /app/prisma-engines/* && \
    chmod +x /app/prisma-engines/*.so.node  # 如果.so文件需要执行权限    
#ENV PRISMA_CLI_BINARY_TARGET=linux-musl
ENV PRISMA_CLI_BINARY_TARGET=custom
#ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-1.1.x
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
# 验证步骤（更新版）
RUN echo "验证动态链接器：" && \
    ls -l /lib/ld-linux-armhf.so.3 && \
    echo "验证库依赖关系：" && \
    ldd /app/prisma-engines/libquery_engine.so.node || echo "ldd验证失败退出" && exit 1;

ENV DATABASE_URL="file:/app/data/db/cashbook.db"
ENV NUXT_APP_VERSION="4.1.3"
ENV NUXT_DATA_PATH="/app/data"
ENV NUXT_AUTH_SECRET="auth123"
ENV NUXT_ADMIN_USERNAME="admin"
ENV NUXT_ADMIN_PASSWORD="fb35e9343a1c095ce1c1d1eb6973dc570953159441c3ee315ecfefb6ed05f4cc"
ENV PORT="9090"

VOLUME /app/data/
EXPOSE 9090
ENTRYPOINT ["/app/entrypoint.sh"]
