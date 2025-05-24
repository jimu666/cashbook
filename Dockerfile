# ===== 构建阶段 =====
FROM --platform=linux/arm/v7 node:18-slim AS builder

# 安装系统依赖
RUN apt-get update && apt-get install -y openssl ca-certificates

WORKDIR /app

# 拷贝依赖清单并安装依赖（跳过 Prisma 安装脚本）
COPY package*.json ./
RUN npm install --ignore-scripts

# 拷贝 Prisma 引擎与项目源码
COPY prisma-engines/ /app/prisma-engines/
COPY docker/entrypoint.sh /app/entrypoint.sh
COPY . .

# 修复 Prisma 引擎可执行权限
RUN chmod +x /app/prisma-engines/*

# 设置环境变量（强制使用本地引擎）
ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-3.0.x
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt
ENV PRISMA_CLIENT_ENGINE_TYPE=binary
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1

# 输出 Prisma 版本信息（并再次确保引擎有执行权限）
RUN echo "==== Prisma Version Check ====" && \
    chmod +x /app/prisma-engines/schema-engine && \
    chmod +x /app/prisma-engines/query-engine && \
    chmod +x /app/prisma-engines/prisma-fmt && \
    node_modules/.bin/prisma -v && \
    echo "Using engines from:" && \
    echo "  QUERY_ENGINE_LIBRARY=$PRISMA_QUERY_ENGINE_LIBRARY" && \
    echo "  QUERY_ENGINE_BINARY=$PRISMA_QUERY_ENGINE_BINARY" && \
    echo "  SCHEMA_ENGINE_BINARY=$PRISMA_SCHEMA_ENGINE_BINARY" && \
    echo "  FMT_BINARY=$PRISMA_FMT_BINARY" && \
    echo "==================================="

# 生成 Prisma 客户端（使用本地引擎）
RUN node_modules/.bin/prisma generate

# 构建 Nuxt 应用
RUN npm run build


# ===== 运行阶段 =====
FROM --platform=linux/arm/v7 node:18-slim AS runner

# 安装运行时依赖
RUN apt-get update && apt-get install -y openssl ca-certificates && apt-get clean

WORKDIR /app

# 拷贝构建产物和运行所需内容
COPY --from=builder /app/.output /app
COPY --from=builder /app/.output/server /app/server
COPY --from=builder /app/.output/server/node_modules /app/node_modules
COPY --from=builder /app/prisma /app/prisma
COPY --from=builder /app/prisma-engines /app/prisma-engines
COPY --from=builder /app/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh /app/prisma-engines/*

# 设置权限
RUN chmod +x /app/entrypoint.sh /app/prisma-engines/*

# 设置环境变量（确保使用本地引擎）
ENV LD_LIBRARY_PATH=/lib:/usr/lib
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
#ENV PRISMA_MIGRATION_ENGINE_BINARY=/app/prisma-engines/migration-engine #m没有armv7架构迁移引擎
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt
ENV PRISMA_CLIENT_ENGINE_TYPE=binary
ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-3.0.x
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
ENV PRISMA_HIDE_CHANGELOG=1
ENV PRISMA_HIDE_UPDATE_MESSAGE=1

# 应用配置（可被覆盖）
ENV DATABASE_URL="file:/app/data/db/cashbook.db"
ENV PORT="9090"

# 暴露端口与挂载数据目录
VOLUME /app/data/
EXPOSE 9090

ENTRYPOINT ["/app/entrypoint.sh"]
