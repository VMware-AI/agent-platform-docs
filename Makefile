# 智能体管理平台 · 使用手册 —— 顶层 Makefile
#
# 把所有常用动作收成 `make <target>`：
#
#   本地开发
#     make dev          vitepress dev server（http://localhost:5173/）
#     make install      npm ci 一次
#     make build        vitepress build → docs/.vitepress/dist/
#     make preview      本地预览构建产物
#
#   离线发布包
#     make package      ./deploy/package.sh → dist/agent-platform-docs-<v>.tar.gz
#     make publish      ./deploy/publish.sh  user@host:/webroot
#
#   Docker 镜像
#     make image                       构建本地镜像 agent-platform-docs:$(TAG)（单架构）
#     make image-run                   docker run -p 8080:80 启起来
#     make release-images              多架构 (amd64+arm64) build + push
#                                       推到 $(REGISTRY)/$(IMAGE):$(TAG) 与 :latest
#
#   杂项
#     make clean      清理 build / dist / node_modules 缓存
#     make help       列目标
#     make version    打印当前版本号
#
# 可在命令行覆盖：
#     make release-images REGISTRY=quay.io/myorg/ TAG=0.0.3
#     make release-images PLATFORMS=linux/amd64,linux/arm64
#     make image TAG=dev

# ----------------------------------------------------------------------
# 变量
# ----------------------------------------------------------------------

# 默认版本取 package.json，可由 make VERSION=... 覆盖
VERSION       ?= $(shell node -p "require('./package.json').version" 2>/dev/null || echo dev)
IMAGE         ?= agent-platform-docs
TAG           ?= $(VERSION)
# 参考 agent-platform-console：REGISTRY 末尾不带 /，由 IMAGE_REF 在中间拼 /
REGISTRY      ?= quay.io/vmware-ai

# 多架构目标 —— buildx 一次出 amd64 + arm64 的 manifest
PLATFORMS     ?= linux/amd64,linux/arm64
# buildx 用的 builder 实例名；首次会自动创建（docker-container 驱动支持 QEMU 跨架构）
BUILDER       ?= agent-platform-builder

# 镜像 base —— 仓库只声明，不在 Makefile 里偷偷写死，避免被误以为强耦合
NODE_IMAGE    ?= quay.io/vmware-ai/node:24-alpine
NGINX_IMAGE   ?= quay.io/vmware-ai/nginx:1.31.2

# 推导：带 registry 前缀的最终镜像名
# REGISTRY 默认末尾不带 /，IMAGE 与它之间用 / 隔开 —— 与 console 仓库一致
IMAGE_REF     = $(REGISTRY)/$(IMAGE)
FULL_TAG      = $(IMAGE_REF):$(TAG)
LATEST_TAG    = $(IMAGE_REF):latest

# shell / 工具自检
NPM           ?= npm
DOCKER        ?= docker

.DEFAULT_GOAL := help

# ----------------------------------------------------------------------
# help
# ----------------------------------------------------------------------

.PHONY: help
help: ## 列出所有可用目标
	@printf "智能体管理平台 · 使用手册 —— Make 目标\n\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@printf "\n当前: VERSION=$(VERSION)  IMAGE=$(FULL_TAG)  REGISTRY='%s'\n" "$(REGISTRY)"

.PHONY: version
version: ## 打印当前版本号
	@echo "$(VERSION)"

# ----------------------------------------------------------------------
# 本地开发
# ----------------------------------------------------------------------

.PHONY: install
install: ## 装 npm 依赖（npm ci）
	$(NPM) ci

.PHONY: dev
dev: ## 启动 vitepress 开发服务器（5173）
	$(NPM) run dev

.PHONY: build
build: ## 构建站点到 docs/.vitepress/dist/
	$(NPM) run build

.PHONY: preview
preview: ## 本地预览构建产物
	$(NPM) run preview

# ----------------------------------------------------------------------
# 离线发布包
# ----------------------------------------------------------------------

.PHONY: package
package: ## 打出离线 tarball 到 dist/（包内含 nginx.conf + install.sh）
	@bash deploy/package.sh $(VERSION)

.PHONY: publish
publish: ## rsync 同步构建产物到指定 webroot（参数 TARGET=user@host:/path）
	@test -n "$(TARGET)" || (echo "用法: make publish TARGET=user@host:/webroot" >&2; exit 1)
	@bash deploy/publish.sh $(TARGET)

# ----------------------------------------------------------------------
# Docker 镜像
# ----------------------------------------------------------------------

.PHONY: image
image: ## 构建本地镜像 agent-platform-docs:$(TAG)（同时打 latest tag）
	$(DOCKER) build \
	  --build-arg NODE_IMAGE=$(NODE_IMAGE) \
	  --build-arg NGINX_IMAGE=$(NGINX_IMAGE) \
	  --build-arg VERSION=$(VERSION) \
	  --build-arg VCS_REF=$$(git rev-parse --short HEAD 2>/dev/null || echo unknown) \
	  --build-arg BUILD_DATE=$$(date -u +%Y-%m-%dT%H:%M:%SZ) \
	  -t $(FULL_TAG) \
	  -t $(LATEST_TAG) \
	  .
	@echo ">>> built $(FULL_TAG) (also tagged $(LATEST_TAG))"

.PHONY: image-run
image-run: ## 用本地镜像跑起来（宿主机 :8080 → 容器 :80），Ctrl-C 停
	$(DOCKER) run --rm -p 8080:80 --name $(IMAGE) $(FULL_TAG)

.PHONY: release-images
release-images: ## 多架构 (amd64+arm64) build + push 到 $(REGISTRY)/$(IMAGE):$(TAG) 和 :latest
	@command -v docker >/dev/null || { echo "需要 docker" >&2; exit 1; }
	docker buildx create --name $(BUILDER) --use --driver docker-container 2>/dev/null || true
	docker buildx build \
		--builder $(BUILDER) \
		--platform $(PLATFORMS) \
		--build-arg NODE_IMAGE=$(NODE_IMAGE) \
		--build-arg NGINX_IMAGE=$(NGINX_IMAGE) \
		--build-arg VERSION=$(VERSION) \
		--build-arg VCS_REF=$$(git rev-parse --short HEAD 2>/dev/null || echo unknown) \
		--build-arg BUILD_DATE=$$(date -u +%Y-%m-%dT%H:%M:%SZ) \
		--tag $(FULL_TAG) \
		--tag $(LATEST_TAG) \
		--push \
		.
	@echo ">>> pushed $(FULL_TAG) 和 $(LATEST_TAG)（$(PLATFORMS)）"

# ----------------------------------------------------------------------
# 杂项
# ----------------------------------------------------------------------

.PHONY: clean
clean: ## 清理 build / dist 缓存（保留 node_modules）
	rm -rf docs/.vitepress/dist docs/.vitepress/cache dist

.PHONY: distclean
distclean: clean ## 在 clean 基础上再删 node_modules
	rm -rf node_modules

.PHONY: verify
verify: build package ## 跑一遍完整构建 + 出包，确保能 ship
	@echo ">>> verify ok: $(FULL_TAG) 与 dist/agent-platform-docs-$(VERSION).tar.gz 都已就绪"
