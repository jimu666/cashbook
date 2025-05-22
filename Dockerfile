# 修改基础镜像为 ARMv7 兼容的 Alpine 版本
FROM arm32v7/node:20-alpine3.21 AS builder

# 安装 Alpine ARMv7 所需依赖
RUN apk add --no-cache gcompat libc6-compat
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
# 在builder阶段添加
#RUN file /app/prisma-engines/query-engine
# 生成Prisma Client
RUN npx prisma generate
RUN npm run build

FROM arm32v7/node:20-alpine3.21 AS runner
# 强制使用 ARMv7 的 Alpine 仓库源
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" > /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories

# 安装 ARMv7 专用兼容层
RUN apk add --no-cache \
    libc6-compat=2.38-r8 \
    libgcc=12.2.1_git20231014-r4 \
    libstdc++=12.2.1_git20231014-r4

# 修复关键符号链接（ARMv7 专用路径）
RUN mkdir -p /lib && \
    ln -sf /usr/lib/libc.so /lib/ld-linux-armhf.so.3

# 验证链接库
RUN ls -l /lib/ld-linux-armhf.so.3 && \
    ldd /app/prisma-engines/libquery_engine.so.node
LABEL author.name="DingDangDog"
LABEL author.email="dingdangdogx@outlook.com"
LABEL project.name="cashbook"
LABEL project.version="3"
WORKDIR /app

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
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
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
