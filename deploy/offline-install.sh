#!/usr/bin/env bash
#
# 智能体管理平台 · 使用手册 —— 离线安装到本机 nginx。
#
#   sudo ./install.sh                              # 默认：/var/www/agent-platform-docs，端口 8080
#   sudo ./install.sh --port=80                    # 换端口
#   sudo ./install.sh --root=/data/www/docs        # 换 webroot
#   sudo ./install.sh --server-name=docs.corp.lan  # 换域名
#   sudo ./install.sh --no-nginx-conf              # 只铺静态文件，nginx 配置自己写
#   ./install.sh --dry-run                         # 只打印将要做什么
#
# 目标机只需要 nginx，不需要 node，不需要联网。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WEBROOT="/var/www/agent-platform-docs"
PORT="8080"
SERVER_NAME="_"
WRITE_NGINX_CONF=1
DRY_RUN=0

for arg in "$@"; do
  case "${arg}" in
    --root=*)        WEBROOT="${arg#*=}" ;;
    --port=*)        PORT="${arg#*=}" ;;
    --server-name=*) SERVER_NAME="${arg#*=}" ;;
    --no-nginx-conf) WRITE_NGINX_CONF=0 ;;
    --dry-run)       DRY_RUN=1 ;;
    -h|--help)       sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "未知参数: ${arg}（-h 看用法）" >&2; exit 1 ;;
  esac
done

say() { echo ">>> $*"; }
run() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    echo "    [dry-run] $*"
  else
    "$@"
  fi
}

# ---------- 前置检查 ----------

[[ -f "${SCRIPT_DIR}/site/index.html" ]] || {
  echo "发布包不完整：找不到 site/index.html" >&2; exit 1; }

if ! command -v nginx >/dev/null 2>&1; then
  if [[ "${DRY_RUN}" == "1" ]]; then
    echo "!!! 未检测到 nginx —— dry-run 继续（真正安装前需先装好）" >&2
  else
    echo "未检测到 nginx。请先安装（离线环境用本地源）：" >&2
    echo "  Debian/Ubuntu: apt-get install -y nginx" >&2
    echo "  RHEL/Rocky:    yum install -y nginx" >&2
    exit 1
  fi
fi

if [[ "${DRY_RUN}" == "0" && "${EUID}" -ne 0 ]]; then
  echo "需要 root 权限写 ${WEBROOT} 和 nginx 配置。请用 sudo 执行，或加 --dry-run 先看看。" >&2
  exit 1
fi

VERSION="$(cat "${SCRIPT_DIR}/VERSION" 2>/dev/null || echo unknown)"
say "版本 ${VERSION}"

# ---------- 铺静态文件 ----------

say "部署站点 → ${WEBROOT}"
run mkdir -p "${WEBROOT}"
if command -v rsync >/dev/null 2>&1; then
  run rsync -a --delete "${SCRIPT_DIR}/site/" "${WEBROOT}/"
else
  # 没有 rsync 时退化为「清空 + 拷贝」，效果一致。
  run find "${WEBROOT}" -mindepth 1 -delete
  run cp -R "${SCRIPT_DIR}/site/." "${WEBROOT}/"
fi

# ---------- nginx 配置 ----------

if [[ "${WRITE_NGINX_CONF}" == "1" ]]; then
  if   [[ -d /etc/nginx/conf.d ]];            then CONF="/etc/nginx/conf.d/agent-platform-docs.conf"
  elif [[ -d /etc/nginx/sites-available ]];   then CONF="/etc/nginx/sites-available/agent-platform-docs.conf"
  else echo "找不到 /etc/nginx/conf.d 或 sites-available，请用 --no-nginx-conf 并手工配置。" >&2; exit 1
  fi

  say "写入 nginx 配置 → ${CONF}"
  if [[ "${DRY_RUN}" == "1" ]]; then
    echo "    [dry-run] 生成 server 块：listen ${PORT}; server_name ${SERVER_NAME}; root ${WEBROOT}"
  else
    cat > "${CONF}" <<EOF
# 智能体管理平台 · 使用手册（离线包 ${VERSION} 自动生成）
# cleanUrls 已开启，try_files 三段缺一不可，否则除首页外全部 404。
server {
    listen       ${PORT};
    listen       [::]:${PORT};
    server_name  ${SERVER_NAME};

    root  ${WEBROOT};
    index index.html;
    charset utf-8;

    location / {
        try_files \$uri \$uri.html \$uri/index.html =404;
    }

    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    location ~* \.html\$ {
        add_header Cache-Control "no-cache, must-revalidate";
    }

    gzip            on;
    gzip_comp_level 5;
    gzip_min_length 1024;
    gzip_vary       on;
    gzip_types      text/plain text/css text/javascript application/javascript
                    application/json application/xml image/svg+xml;

    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options        SAMEORIGIN;

    error_page 404 /404.html;
}
EOF
  fi

  # Debian 系还要 enable
  if [[ "${CONF}" == /etc/nginx/sites-available/* && -d /etc/nginx/sites-enabled ]]; then
    say "启用站点软链"
    run ln -sfn "${CONF}" /etc/nginx/sites-enabled/agent-platform-docs.conf
  fi

  say "校验 nginx 配置"
  run nginx -t

  say "重载 nginx"
  if command -v systemctl >/dev/null 2>&1; then
    run systemctl reload nginx
  else
    run nginx -s reload
  fi
fi

echo
if [[ "${DRY_RUN}" == "1" ]]; then
  echo "dry-run 结束，什么都没改。"
  exit 0
fi

IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
IP="${IP:-localhost}"
echo "────────────────────────────────────────────"
echo " 使用手册已就绪"
echo
echo "   浏览器打开:  http://${IP}:${PORT}/"
echo "   站点目录:    ${WEBROOT}"
[[ "${WRITE_NGINX_CONF}" == "1" ]] && echo "   nginx 配置:  ${CONF}"
echo
echo " 全站可离线使用：搜索索引在本地，页面无任何外部请求。"
echo "────────────────────────────────────────────"
