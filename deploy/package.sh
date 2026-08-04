#!/usr/bin/env bash
#
# 打出可离线分发的文档站发布包。
#
#   ./deploy/package.sh              # 版本号取 package.json
#   ./deploy/package.sh 0.0.2        # 手工指定版本号
#
# 产物：dist/agent-platform-docs-<版本>.tar.gz
#       dist/agent-platform-docs-<版本>.tar.gz.sha256
#
# 包内是自包含的：静态站点 + nginx 配置 + 安装脚本 + 离线部署说明。
# 目标机不需要 node、不需要联网。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

VERSION="${1:-$(node -p "require('./package.json').version" 2>/dev/null || echo "0.0.0")}"
NAME="agent-platform-docs-${VERSION}"
OUT="${REPO_ROOT}/dist"
STAGE="${OUT}/${NAME}"

echo ">>> 版本: ${VERSION}"

echo ">>> 安装依赖"
if [[ -f package-lock.json ]]; then npm ci; else npm install; fi

echo ">>> 构建"
npm run build

SITE="${REPO_ROOT}/docs/.vitepress/dist"
[[ -f "${SITE}/index.html" ]] || { echo "构建产物缺失: ${SITE}/index.html" >&2; exit 1; }

echo ">>> 组装发布包"
rm -rf "${STAGE}"
mkdir -p "${STAGE}/site"
cp -R "${SITE}/." "${STAGE}/site/"
cp "${REPO_ROOT}/deploy/nginx.conf" "${STAGE}/nginx.conf"
cp "${REPO_ROOT}/deploy/offline-install.sh" "${STAGE}/install.sh"
cp "${REPO_ROOT}/deploy/OFFLINE-README.md" "${STAGE}/README.md"
chmod +x "${STAGE}/install.sh"

cat > "${STAGE}/VERSION" <<EOF
${VERSION}
EOF

echo ">>> 打包"
tar -czf "${OUT}/${NAME}.tar.gz" -C "${OUT}" "${NAME}"
rm -rf "${STAGE}"

cd "${OUT}"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "${NAME}.tar.gz" > "${NAME}.tar.gz.sha256"
else
  shasum -a 256 "${NAME}.tar.gz" > "${NAME}.tar.gz.sha256"
fi

echo
echo "完成:"
ls -lh "${OUT}/${NAME}.tar.gz" "${OUT}/${NAME}.tar.gz.sha256"
echo
echo "目标机上:"
echo "  tar -xzf ${NAME}.tar.gz && cd ${NAME} && sudo ./install.sh"
