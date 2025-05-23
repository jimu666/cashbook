# 使用 ARMv7 专用基础镜像（Debian Bullseye）
FROM arm32v7/node:20-bullseye AS builder 

# 安装 ARMv7 依赖（Debian 包管理器）
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgcompat0 \
    libc6-dev \
    libstdc++6
    
WORKDIR /app

COPY package*.json ./

# 安装依赖（跳过Prisma自动安装）
RUN npm install --ignore-scripts

# 复制本地Prisma引擎
COPY prisma-engines /app/prisma-engines

# 设置Prisma环境变量指向本地引擎
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt

# 设置文件执行权限
RUN chmod +x ./prisma-engines/*
COPY . .
ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-1.1.x

# 严格架构验证
RUN file ./prisma-engines/query-engine | grep -q 'ELF 32-bit LSB.*ARM' || { \
  echo "[错误] 检测到无效的Prisma引擎架构！当前文件信息："; \
  file ./prisma-engines/query-engine; \
  exit 1; \
}
RUN npx prisma generate
RUN npm run build

# 使用与构建阶段相同的基础镜像（关键修复）
FROM arm32v7/node:20-bullseye AS runner

# 安装运行时依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgcompat0 \
    libc6-dev \
    libstdc++6 \
    openssl \
    && rm -rf /var/lib/apt/lists/*

LABEL author.name="DingDangDog"
LABEL author.email="dingdangdogx@outlook.com"
LABEL project.name="cashbook"
LABEL project.version="3"
WORKDIR /app

# 复制生产环境文件
COPY --from=builder /app/.output/ ./
COPY --from=builder /app/node_modules/ ./node_modules/
COPY --from=builder /app/.prisma/ ./.prisma/
COPY ./prisma/ ./prisma/
COPY ./docker/entrypoint.sh ./entrypoint.sh
RUN chmod +x entrypoint.sh

# 复制预编译引擎
COPY --from=builder /app/prisma-engines /app/prisma-engines

# 设置生产环境变量
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt
ENV PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-1.1.x
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1

# 最终验证
RUN /app/prisma-engines/query-engine --version || { \
  echo "[错误] 最终引擎验证失败！"; \
  ldd /app/prisma-engines/libquery_engine.so.node; \
  exit 1; \
}

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
