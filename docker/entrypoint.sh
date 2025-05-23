#!/bin/sh

# 强制指定使用本地引擎
export PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
export PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
export PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
export PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt

echo "Prisma binary paths set."
echo "Running Prisma database migration..."

# 使用本地引擎 + 指定版本的 CLI 进行迁移
npx prisma@5.1.4 migrate deploy

echo "Migration completed."
echo "Starting application..."

exec node server/index.mjs
