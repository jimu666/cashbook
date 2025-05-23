# ===== 构建阶段 =====
FROM --platform=linux/arm/v7 node:18-slim AS builder

# 安装系统依赖
RUN apt-get update && apt-get install -y openssl ca-certificates

WORKDIR /app

# 拷贝依赖清单并安装依赖（跳过 Prisma 安装脚本）
COPY package*.json ./
RUN npm install --ignore-scripts

# 复制 Prisma 引擎与项目源码
COPY prisma-engines/ /app/prisma-engines/
COPY . .

# 设置环境变量，指向本地引擎路径
ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-1.1.x
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt
ENV PRISMA_CLIENT_ENGINE_TYPE=binary
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1

# 生成 Prisma 客户端（使用 5.1.4）
RUN npx prisma@5.1.4 generate

# 构建 Nuxt 应用
RUN npm run build


# ===== 运行阶段 =====
FROM --platform=linux/arm/v7 node:18-slim AS runner

# 安装运行依赖
RUN apt-get update && apt-get install -y openssl ca-certificates && apt-get clean

WORKDIR /app

# 拷贝构建产物和运行所需内容
COPY --from=builder /app/.output /app/.output
COPY --from=builder /app/.output/server /app/server
COPY --from=builder /app/.output/server/node_modules /app/node_modules
COPY --from=builder /app/prisma /app/prisma
COPY --from=builder /app/prisma-engines /app/prisma-engines
COPY --from=builder /app/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh /app/prisma-engines/*

# 环境变量配置（确保使用本地 Prisma 引擎）
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

# 应用配置（可覆盖）
ENV DATABASE_URL="file:/app/data/db/cashbook.db"
ENV PORT="9090"

# 暴露端口与挂载数据目录
VOLUME /app/data/
EXPOSE 9090

ENTRYPOINT ["/app/entrypoint.sh"]
