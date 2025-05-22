FROM docker.1ms.run/library/node:20-alpine3.21 AS builder

WORKDIR /app

COPY package*.json ./

# 安装依赖（跳过Prisma自动安装）
RUN npm install --ignore-scripts

# 复制本地Prisma引擎
COPY prisma-engines /app/prisma-engines

# 设置Prisma环境变量指向本地引擎
ENV PRISMA_CLI_BINARY_TARGET=custom
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
ENV PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt

# 设置文件执行权限
RUN chmod +x ./app/prisma-engines/schema-engine && \
    chmod +x ./app/prisma-engines/query-engine && \
    chmod +x ./app/prisma-engines/prisma-fmt
COPY . .

# 生成Prisma Client
RUN npx prisma generate
RUN npm run build

FROM docker.1ms.run/library/node:20-alpine3.21 AS runner

LABEL author.name="DingDangDog"
LABEL author.email="dingdangdogx@outlook.com"
LABEL project.name="cashbook"
LABEL project.version="3"

WORKDIR /app

# 复制生产环境需要的文件
COPY --from=builder /app/.output/ ./
COPY --from=builder /app/.output/server/node_modules/ ./node_modules/
COPY --from=builder /app/.output/server/node_modules/.prisma/ ./.prisma/
COPY ./prisma/ ./prisma/
COPY ./docker/entrypoint.sh ./entrypoint.sh
RUN chmod +x entrypoint.sh

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
