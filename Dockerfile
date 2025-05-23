# ===== 构建阶段 =====
FROM --platform=linux/arm/v7 node:18-slim AS builder

# 安装依赖
RUN apt-get update && apt-get install -y openssl ca-certificates

WORKDIR /app

# 拷贝依赖清单
COPY package*.json ./

# 安装依赖（跳过 Prisma 安装脚本）
RUN npm install --ignore-scripts

# 拷贝 Prisma 引擎（你预编译的 5.14.0 引擎）
COPY prisma-engines/ /app/prisma-engines/

# 设置权限
RUN chmod +x /app/prisma-engines/*

# 拷贝源代码和 entrypoint
COPY . .
COPY docker/entrypoint.sh /app/entrypoint.sh

# 设置 Prisma 使用本地引擎
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-1.1.x
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt

# 生成 Prisma Client（默认输出到 node_modules/@prisma/client）
RUN npx prisma generate

# 构建 Nuxt 应用（或其他）
RUN npm run build

# ===== 运行阶段 =====
FROM --platform=linux/arm/v7 node:18-slim AS runner

# 安装运行依赖
RUN apt-get update && apt-get install -y openssl ca-certificates && apt-get clean

WORKDIR /app

# 环境变量配置
ENV LD_LIBRARY_PATH=/lib:/usr/lib
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt
ENV PRISMA_CLIENT_ENGINE_TYPE=binary
ENV PRISMA_HIDE_CHANGELOG=1
ENV PRISMA_HIDE_UPDATE_MESSAGE=1
ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-1.1.x

# 应用环境变量
ENV DATABASE_URL="file:/app/data/db/cashbook.db"
ENV NUXT_APP_VERSION="4.1.3"
ENV NUXT_DATA_PATH="/app/data"
ENV NUXT_AUTH_SECRET="auth123"
ENV NUXT_ADMIN_USERNAME="admin"
ENV NUXT_ADMIN_PASSWORD="fb35e9343a1c095ce1c1d1eb6973dc570953159441c3ee315ecfefb6ed05f4cc"
ENV PORT="9090"

# 拷贝构建产物
COPY --from=builder /app/.output/ ./         # Nuxt 输出
COPY --from=builder /app/node_modules/ ./node_modules/
COPY --from=builder /app/prisma/ ./prisma/
COPY --from=builder /app/prisma-engines/ /app/prisma-engines/
COPY --from=builder /app/entrypoint.sh ./entrypoint.sh

RUN chmod +x ./entrypoint.sh && chmod +x /app/prisma-engines/*

VOLUME /app/data/
EXPOSE 9090

ENTRYPOINT ["/app/entrypoint.sh"]
