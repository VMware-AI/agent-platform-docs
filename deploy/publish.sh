#!/usr/bin/env bash
#
# 构建文档站并同步到 nginx 服务器。
#
#   ./deploy/publish.sh user@docs-host:/var/www/agent-platform-docs
#
# 依赖：node ≥ 18、npm、rsync、ssh。
set -euo pipefail

TARGET="${1:-}"
if [[ -z "${TARGET}" ]]; then
  echo "用法: $0 <user@host:/path/to/webroot>" >&2
  echo "例如: $0 deploy@docs.corp.example.com:/var/www/agent-platform-docs" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="${REPO_ROOT}/docs/.vitepress/dist"

cd "${REPO_ROOT}"

echo ">>> 安装依赖"
npm ci

echo ">>> 构建"
npm run build

if [[ ! -f "${DIST}/index.html" ]]; then
  echo "构建产物缺失: ${DIST}/index.html" >&2
  exit 1
fi

echo ">>> 同步到 ${TARGET}"
# --delete 会清掉目标端的历史文件；先确认路径没填错。
rsync -avz --delete "${DIST}/" "${TARGET}/"

echo ">>> 完成。记得在目标机上 reload nginx（配置变更时才需要）："
echo "    sudo nginx -t && sudo systemctl reload nginx"
