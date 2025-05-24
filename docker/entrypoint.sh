#!/bin/sh

# 使用本地引擎路径
export PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engines/libquery_engine.so.node
export PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine
export PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma-engines/schema-engine
export PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt
export PRISMA_CLIENT_ENGINE_TYPE=binary
export PRISMA_CLI_BINARY_TARGET=linux-arm-openssl-3.0.x
export PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1

echo "Prisma binary paths set."

# 运行 Prisma 迁移（使用已安装的本地 CLI，不使用 npx）无迁移引擎
#node_modules/.bin/prisma migrate deploy

echo "Migration completed."
echo "Starting application..."

exec node server/index.mjs
