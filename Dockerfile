# ========= 构建阶段 =========
FROM arm32v7/node:18-alpine3.18 as builder

# 修复Alpine仓库源（使用长期支持版本）
RUN echo -e "http://dl-cdn.alpinelinux.org/alpine/v3.21/main\nhttp://dl-cdn.alpinelinux.org/alpine/v3.21/community" > /etc/apk/repositories

# 安装glibc兼容层（关键步骤）
RUN apk add --no-cache \
    gcompat \
    libc6-compat \
    openssl3 \
    && ln -s /usr/lib/libc.so.6 /usr/glibc-compat/lib/libc.so.6 \
    && ln -sf /usr/glibc-compat/lib/ld-linux-armhf.so.3 /lib/

WORKDIR /app

# 复制预编译引擎（必须确保是ARMv7版本）
COPY prisma-engines ./prisma-engines

# 验证引擎架构（构建时立即检查）
RUN if ! file ./prisma-engines/query-engine | grep -q 'ARMv7'; then \
        echo "错误：引擎文件不是ARMv7架构"; exit 1; \
    fi

COPY package*.json ./
COPY prisma/schema.prisma ./prisma/

# 安装依赖（跳过引擎自动下载）
RUN npm install --ignore-scripts

# 配置Prisma使用本地引擎
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt

# 生成客户端（强制使用本地引擎）
RUN npx prisma generate --generator enginesVersion

# 构建应用
RUN npm run build

# ========= 运行时阶段 =========
FROM arm32v7/node:18-alpine3.18 AS runner

# 安装运行时依赖
RUN apk add --no-cache \
    gcompat \
    libc6-compat \
    openssl3 \
    # 修复动态链接器路径
    && mkdir -p /lib \
    && ln -sf /usr/glibc-compat/lib/ld-linux-armhf.so.3 /lib/ \
    && ln -sf /usr/lib/libc.so.6 /usr/glibc-compat/lib/

WORKDIR /app

# 复制构建产物
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.output ./
COPY --from=builder /app/prisma ./prisma

# 复制预编译引擎到标准路径
COPY --from=builder /app/prisma-engines /app/node_modules/.prisma/client/

# 设置库路径和权限
ENV LD_LIBRARY_PATH="/usr/glibc-compat/lib:/lib:$LD_LIBRARY_PATH"
RUN chmod +x /app/node_modules/.prisma/client/query-engine \
    && chmod +x /app/node_modules/.prisma/client/schema-engine

# 运行时验证（关键诊断）
RUN echo "=== 运行时诊断开始 ===" \
    && ls -lh /lib/ld-linux-armhf.so.3 \
    && ldd /app/node_modules/.prisma/client/query-engine | tee /tmp/ldd.log \
    && grep -q 'not found' /tmp/ldd.log && (echo "缺失依赖检测到"; exit 1) || true \
    && echo "=== 引擎架构验证 ===" \
    && file /app/node_modules/.prisma/client/query-engine | grep 'ARMv7' \
    && echo "=== 运行时诊断通过 ==="

# 应用配置
ENV DATABASE_URL="file:/app/data/db/cashbook.db"
ENV NUXT_APP_VERSION="4.1.3"
VOLUME /app/data
EXPOSE 9090

ENTRYPOINT ["node", "./server/index.mjs"]
