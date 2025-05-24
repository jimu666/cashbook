# =====================
# === 构建阶段 Builder ===
# =====================
FROM --platform=linux/arm/v7 node:18-slim AS builder

# 安装构建依赖（glibc + openssl）
RUN apt-get update && apt-get install -y openssl ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 拷贝依赖清单并安装生产依赖（跳过 Prisma 安装脚本）
COPY package*.json ./
RUN npm install --ignore-scripts

# 拷贝 Prisma 引擎与项目代码
COPY prisma-engines/ ./prisma-engines/
COPY docker/entrypoint.sh ./entrypoint.sh
COPY . .

# 修复 Prisma 引擎权限
RUN chmod +x ./prisma-engines/*

# 设置环境变量：强制使用本地 Prisma 引擎
ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-3.0.x
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt
ENV PRISMA_CLIENT_ENGINE_TYPE=binary
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1

# 显示 Prisma 版本（验证引擎可用）
RUN echo "=== Prisma Version Check ===" && \
    chmod +x ./prisma-engines/* && \
    node_modules/.bin/prisma -v

# 生成 Prisma 客户端
RUN node_modules/.bin/prisma generate

# 构建 Nuxt 应用
RUN npm run build


# =====================
# === 运行阶段 Runner ===
# =====================
FROM --platform=linux/arm/v7 node:18-slim AS runner

# 安装运行所需依赖
RUN apt-get update && apt-get install -y openssl ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 数据目录
RUN mkdir -p /app/data/db

# 拷贝 Nuxt 输出
COPY --from=builder /app/.output /app

# 拷贝 Prisma 引擎和 schema
COPY --from=builder /app/prisma /app/prisma
COPY --from=builder /app/prisma-engines/query-engine /app/prisma-engines/query-engine
COPY --from=builder /app/prisma-engines/schema-engine /app/prisma-engines/schema-engine
COPY --from=builder /app/prisma-engines/prisma-fmt /app/prisma-engines/prisma-fmt
COPY --from=builder /app/prisma-engines/libquery_engine.so.node /app/prisma-engines/libquery_engine.so.node

# 拷贝入口脚本和数据库
COPY --from=builder /app/entrypoint.sh /app/entrypoint.sh
COPY default-sqlite/cashbook.db /app/data/db/cashbook.db

# 权限设置
RUN chmod +x /app/entrypoint.sh /app/prisma-engines/*

# 设置 Prisma 环境变量
ENV LD_LIBRARY_PATH=/lib:/usr/lib
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt
ENV PRISMA_CLIENT_ENGINE_TYPE=binary
ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-3.0.x
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
ENV PRISMA_HIDE_CHANGELOG=1
ENV PRISMA_HIDE_UPDATE_MESSAGE=1

# 应用默认配置
ENV DATABASE_URL="file:/app/data/db/cashbook.db"
#前台登录加密使用的密钥 （随意填写即可，无格式要求）
ENV NUXT_AUTH_SECRET="auth123456"
#后台登录用户名
ENV NUXT_ADMIN_USERNAME="admin"
# 密码是加密后的，加密方法见 server/utils 中的 test.js 或 common.ts,登录页面输入的密码请仍然使用加密前的123456789！
ENV NUXT_ADMIN_PASSWORD="c7c7c392e92774ca08a39aefd22efadc9b9019927e8fe3ce38d47332f4fa1231"
ENV PORT="9090"

# 对外暴露端口和数据卷
VOLUME /app/data/
EXPOSE 9090

ENTRYPOINT ["/app/entrypoint.sh"]
