# ===== 构建阶段 =====
FROM --platform=linux/arm/v7 node:18-slim AS builder

# 安装系统依赖
RUN apt-get update && apt-get install -y openssl ca-certificates

WORKDIR /app

# 拷贝依赖清单并安装依赖（跳过 Prisma 安装脚本）
COPY package*.json ./
RUN npm install --ignore-scripts

# 复制 Prisma 引擎与入口脚本
COPY prisma-engines/ /app/prisma-engines/
COPY docker/entrypoint.sh ./entrypoint.sh
RUN chmod +x /app/prisma-engines/* /app/entrypoint.sh

# 环境变量用于 Prisma 引擎路径配置
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-1.1.x
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt

# 拷贝完整项目源码并生成 Prisma 客户端
COPY . .
RUN npx prisma generate

# 构建 Nuxt 应用
RUN npm run build && ls -la /app

# ===== 运行阶段 =====
FROM --platform=linux/arm/v7 node:18-slim AS runner

# 安装运行依赖
RUN apt-get update && apt-get install -y openssl ca-certificates && apt-get clean

WORKDIR /app

# 环境变量（Prisma 引擎配置 + 应用配置）
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

# 可以从 .env 中加载以下内容（不要硬编码密码）
ENV DATABASE_URL="file:/app/data/db/cashbook.db"
ENV NUXT_APP_VERSION="4.1.3"
ENV NUXT_DATA_PATH="/app/data"
ENV PORT="9090"

# 拷贝构建产物
COPY --from=builder /app/.output/ ./          # Nuxt 输出
COPY --from=builder /app/node_modules/ ./node_modules/
COPY --from=builder /app/prisma/ ./prisma/
# 删除以下这行，避免报错
# COPY --from=builder /app/.prisma/ ./.prisma/
COPY --from=builder /app/prisma-engines/ /app/prisma-engines/
COPY --from=builder /app/entrypoint.sh ./entrypoint.sh


# 设置执行权限
RUN chmod +x ./entrypoint.sh && chmod +x /app/prisma-engines/*

# 挂载数据卷 + 暴露端口
VOLUME /app/data/
EXPOSE 9090

ENTRYPOINT ["/app/entrypoint.sh"]
