# ===== 构建阶段 =====
FROM --platform=linux/arm/v7 node:18-slim AS builder

# 安装构建所需系统依赖
RUN apt-get update && apt-get install -y openssl ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 拷贝依赖清单并安装依赖（跳过 Prisma 的安装脚本）
COPY package*.json ./
RUN npm install --ignore-scripts --omit=dev

# 拷贝 Prisma 引擎与入口脚本
COPY prisma-engines/ /app/prisma-engines/
COPY docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh /app/prisma-engines/*

# 环境变量用于 Prisma 引擎生成
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-1.1.x
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt

# 拷贝项目并生成 Prisma 客户端
COPY . .
RUN npx prisma generate

# 构建 Nuxt 应用
RUN npm run build

# ===== 运行阶段 =====
FROM --platform=linux/arm/v7 node:18-slim AS runner

# 安装运行依赖并清理缓存
RUN apt-get update && apt-get install -y openssl ca-certificates && rm -rf /var/lib/apt/lists/* /tmp/* /root/.npm

WORKDIR /app

# 应用和 Prisma 环境变量
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

ENV DATABASE_URL="file:/app/data/db/cashbook.db"
ENV NUXT_APP_VERSION="4.1.3"
ENV NUXT_DATA_PATH="/app/data"
ENV PORT="9090"


# 复制生产环境需要的文件
COPY --from=builder /app/.output /app/.output
COPY --from=builder /app/.output/server/node_modules /app/node_modules
COPY --from=builder /app/.output/server/node_modules/.prisma /app/.prisma
COPY --from=builder /app/prisma /app/prisma
COPY --from=builder /app/entrypoint.sh /app/entrypoint.sh
COPY --from=builder /app/prisma-engines /app/prisma-engines
RUN chmod +x /app/entrypoint.sh /app/prisma-engines/*

VOLUME /app/data
EXPOSE 9090

ENTRYPOINT ["/app/entrypoint.sh"]
