# 使用ARMv7兼容的Alpine基础镜像
FROM arm32v7/node:20-alpine3.21 AS builder

# 安装ARM兼容依赖
RUN apk add --no-cache \
    gcompat \
    libc6-compat \
    openssl3

WORKDIR /app
COPY package*.json ./
# 正常安装依赖（移除--ignore-scripts）
RUN npm install

# 复制预编译的ARMv7引擎
COPY prisma-engines /app/prisma-engines

# 显式设置权限（ARM设备可能需要不同权限）
RUN chmod 755 /app/prisma-engines/*

# 验证引擎架构
RUN file /app/prisma-engines/query-engine | grep "ARM, EABI5"

# 生成Prisma Client
RUN npx prisma generate

# 构建应用
RUN npm run build

# Runner阶段
FROM arm32v7/node:20-alpine3.21 AS runner

# 保持目标一致
ENV PRISMA_CLI_BINARY_TARGET=linux-arm-gnueabihf

RUN apk add --no-cache \
    gcompat \
    libc6-compat \
    openssl3

WORKDIR /app

# 精简复制文件
COPY --from=builder /app/.output/ ./
COPY --from=builder /app/node_modules/ ./node_modules/
COPY --from=builder /app/.prisma/ ./.prisma/
COPY --from=builder /app/prisma-engines/ /app/prisma-engines/

# 显式设置环境变量
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt

# 最终权限检查
RUN chmod 755 /app/prisma-engines/* && \
    ls -l /app/prisma-engines/

# 生产环境变量
ENV DATABASE_URL="file:/app/data/db/cashbook.db"
ENV NUXT_APP_VERSION="4.1.3"
# ...其他环境变量...

VOLUME /app/data/
EXPOSE 9090
ENTRYPOINT ["/app/entrypoint.sh"]
