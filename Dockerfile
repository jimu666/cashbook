# ===== 构建阶段 =====
FROM --platform=linux/arm/v7 node:18-slim AS builder

RUN apt-get update && apt-get install -y openssl ca-certificates

WORKDIR /app

# 安装依赖（忽略 Prisma 安装脚本）
COPY package*.json ./
RUN npm install --ignore-scripts

# 复制项目文件和本地 Prisma 引擎
COPY prisma-engines/ /app/prisma-engines/
COPY docker/entrypoint.sh /app/entrypoint.sh
COPY . .

# 设置环境变量指向本地引擎
ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-1.1.x
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt
ENV PRISMA_CLIENT_ENGINE_TYPE=binary
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1

# 使用本地 Prisma CLI + 引擎生成客户端
RUN ./node_modules/.bin/prisma generate

# 构建 Nuxt 应用
RUN npm run build

# ===== 运行阶段 =====
FROM --platform=linux/arm/v7 node:18-slim AS runner

RUN apt-get update && apt-get install -y openssl ca-certificates && apt-get clean

WORKDIR /app

# 拷贝构建产物与运行依赖
COPY --from=builder /app/.output /app/.output
COPY --from=builder /app/.output/server /app/server
COPY --from=builder /app/.output/server/node_modules /app/node_modules
COPY --from=builder /app/prisma /app/prisma
COPY --from=builder /app/prisma-engines /app/prisma-engines
COPY --from=builder /app/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh /app/prisma-engines/*

# 设置环境变量，确保使用本地 Prisma 引擎
ENV LD_LIBRARY_PATH=/lib:/usr/lib
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt
ENV PRISMA_CLIENT_ENGINE_TYPE=binary
ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-1.1.x
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
ENV PRISMA_HIDE_CHANGELOG=1
ENV PRISMA_HIDE_UPDATE_MESSAGE=1

# 应用配置
ENV DATABASE_URL="file:/app/data/db/cashbook.db"
ENV PORT="9090"

# 挂载目录与端口
VOLUME /app/data/
EXPOSE 9090

ENTRYPOINT ["/app/entrypoint.sh"]
