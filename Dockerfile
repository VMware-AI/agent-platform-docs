# syntax=docker/dockerfile:1.7
#
# 智能体管理平台 · 使用手册 —— VitePress 文档站镜像。
#
# 多阶段构建：
#   1. builder  : quay.io/vmware-ai/node:24-alpine  —— 装依赖 + 跑 vitepress build
#   2. runtime  : quay.io/vmware-ai/nginx:1.31.2    —— 纯静态托管，nginx 1.x
#
# 构建：
#   docker build -t agent-platform-docs:dev .
#   docker build --build-arg VERSION=0.0.3 -t agent-platform-docs:0.0.3 .
#
# 运行：
#   docker run --rm -p 8080:80 agent-platform-docs:dev
#
# 默认监听容器内 80 端口；通过 -p 把宿主机端口映到 80。

# ----------------------------------------------------------------------
# Global build args —— 必须在第一个 FROM 之前声明，才能被 FROM 引用
# ----------------------------------------------------------------------
ARG NODE_IMAGE=quay.io/vmware-ai/node:24-alpine
ARG NGINX_IMAGE=quay.io/vmware-ai/nginx:1.31.2

# ----------------------------------------------------------------------
# Stage 1 — build the VitePress site
# ----------------------------------------------------------------------
FROM ${NODE_IMAGE} AS builder

# VitePress 开启了 lastUpdated:true，构建时会调用 git 拿每个 md 的最后提交时间。
# node:24-alpine 默认没有 git，先装一下。
RUN apk add --no-cache git

WORKDIR /srv

# 先只拷贝 lockfile 让依赖层独立缓存
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

# 再拷源码构建
COPY docs ./docs
# vitepress build 会校验死链（ignoreDeadLinks: false），构建失败 = 内容坏了
RUN npm run build

# ----------------------------------------------------------------------
# Stage 2 — serve the static output from nginx
# ----------------------------------------------------------------------
FROM ${NGINX_IMAGE} AS runtime

ARG VERSION=dev
ARG VCS_REF=unknown
ARG BUILD_DATE=unknown

# OCI 标准镜像元数据，方便运维/CI 解析
LABEL org.opencontainers.image.title="agent-platform-docs" \
      org.opencontainers.image.description="智能体管理平台 · 官方使用手册（VitePress 静态站）" \
      org.opencontainers.image.source="https://github.com/VMware-AI/agent-platform-docs" \
      org.opencontainers.image.licenses="Proprietary" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}"

# 把构建产物搬到 nginx 默认 webroot
COPY --from=builder /srv/docs/.vitepress/dist/ /usr/share/nginx/html/

# 用我们的 server 块替换默认配置。
# 上游 nginx 镜像默认带 /etc/nginx/conf.d/default.conf，直接覆盖即可。
COPY deploy/docker/nginx.conf /etc/nginx/conf.d/default.conf

# 默认 EXPOSE 80；上游镜像已自带 entrypoint。
EXPOSE 80
