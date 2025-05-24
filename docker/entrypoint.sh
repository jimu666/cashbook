#!/bin/sh

# 强制指定使用本地引擎
export PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
export PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
export PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
export PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt

echo "Prisma binary paths set."
echo "Running Prisma database migration..."

# 使用项目内本地 CLI 调用 migrate（避免 npx 联网拉包）
./node_modules/.bin/prisma migrate deploy

echo "Migration completed."
echo "Starting application..."

exec node server/index.mjs
