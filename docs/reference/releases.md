# 发布说明

按版本归类的 **agent platform** 整体发布信息汇总。每个版本下，列出本仓库对应的 [agent-platform-*](https://github.com/VMware-AI) 仓库各自的 release tag、可下载产物与变更要点，方便一次看完一整套组件的版本对齐情况。

> **这套组件**（同一发布列车同步迭代）：
> - [agent-platform-deployment](https://github.com/VMware-AI/agent-platform-deployment) —— 部署包（`install.sh` / docker-compose / Helm chart / 离线脚本）
> - [agent-platform-console](https://github.com/VMware-AI/agent-platform-console) —— 控制台前端（Vite + React + Apollo）
> - [agent-platform-backend](https://github.com/VMware-AI/agent-platform-backend) —— 控制面后端（Go + GraphQL + gqlgen）
> - [agent-platform-docs](https://github.com/VMware-AI/agent-platform-docs) —— 本手册仓库（VitePress 静态站）
>
> `agent-manager-daemon` 与 `agent-marketplace-packages` 随 backend 的版本号发，没有独立的 release tag。

## v0.0.1

**发布日期**：2026-08-05
**关联的 4 个仓库 tag**：均为 `v0.0.1`

### agent-platform-deployment

- **Release**：[v0.0.1 — First Stable Release](https://github.com/VMware-AI/agent-platform-deployment/releases/tag/v0.0.1)
- **产物**：`agent-platform-dc-standalone-0.0.1.tar.gz`（48K，自包含：脚本 + compose + 配置 + 文档）
- **SHA256**：`317294b36cae0fc7f5a8933312d60fb865e8430923334e88f5dfcbc46caa482f`

**变更要点**：

- 拆成 **per-flavor 自包含 tarball**（v0.0.1 仅发布 `dc-standalone`；`dc-distribution` / `k8s-standalone` / `k8s-ha` 源码就绪但本 release 不出包）
- **不再随 release 发布离线镜像包** —— `install.sh` 默认从 `quay.io/vmware-ai/<image>` 拉取；目标机需要能访问 `quay.io`。气隙安装见 [离线安装（可选）](/install/dc-standalone#6-离线安装可选气隙环境)
- **k8s 打包统一改为 Helm** —— 删掉了 28 个 envsubst 模板化 YAML，每个 flavor 一份 Helm chart 作为唯一事实来源
- **`SECRETS_ENCRYPTION_KEY` 自动生成** —— 32 字节 hex，写入 `.secrets_encryption_key` 和 `.env`
- **`dc-standalone` 一键起全栈** —— console + backend + litellm + postgres + redis，单 `./install.sh` 拉起
- **运行时镜像清单**：[`origin-images-list.txt`](https://github.com/VMware-AI/agent-platform-deployment/blob/main/origin-images-list.txt) 是镜像源清单的唯一事实来源

完整记录：[CHANGELOG](https://github.com/VMware-AI/agent-platform-deployment/blob/main/CHANGELOG.md) · [README](https://github.com/VMware-AI/agent-platform-deployment/blob/main/README.md)

### agent-platform-console

- **Release**：[v0.0.1 — First Stable Release](https://github.com/VMware-AI/agent-platform-console/releases/tag/v0.0.1)
- **产物**：源码 release（不发布预构建产物；构建镜像走 `agent-platform-console:<tag>`）

**变更要点**：

- **智能体中心**：列表 / 配置 / 市场 / 部署向导全流程；OVA/vApp/OVF/Instant Clone 四种部署形态；批量部署 + 初始登录密码设置 + GOSC 密码注入
- **模型网关**：模型路由（负载均衡 + 后端选择 + 两步式删除）、虚拟密钥（1:1 agent-key 策略 UX 改进）、多维度限流（模型 / 路由 / 密钥 / 租户 × 时间窗）
- **可观测性**：计量中心（统一时间范围、Gateway 权威花费面板）、实时监控（真实 KPI + 上游健康矩阵）、请求日志 / 审计日志（多维过滤 + CSV 导出）
- **平台管理**：资源池接入（新增 full-path 选择器）、模型网关接入、用户与权限、技能管理
- **前端质量**：198 次 commit / 中英文 i18n / 深浅主题 / 状态徽标统一收敛到注册图标

完整记录：[release body](https://github.com/VMware-AI/agent-platform-console/releases/tag/v0.0.1) · [commit history](https://github.com/VMware-AI/agent-platform-console/commits/v0.0.1)

### agent-platform-backend

- **Release**：[v0.0.1 — first stable release](https://github.com/VMware-AI/agent-platform-backend/releases/tag/v0.0.1)
- **产物**：源码 release（不发布预构建产物；构建镜像走 `agent-platform-backend:<tag>`）

**变更要点**：

- **控制面 + 数据面统一编排**：单 GraphQL API 编排 vCenter（govmomi）+ LiteLLM 网关；后端做对账 / 补齐 / 策略下发
- **RBAC + 审计完整闭环**：`@hasRole` / `@hasPermission` directive 在 gqlgen resolver 层真实拦截；审计日志支持操作者解析 + 多维过滤
- **Agent 生命周期 + 部署**：OVF/VMTX 部署完成后置接 NIC；Instant Clone + CustomizationSpec + GOSC 密码注入；recycle / power-off / hardDelete / restart 全覆盖；密钥 1:1 与 agent 绑定
- **License 系统**：90 天 trial + vCenter-IP 绑定；license 状态在 overview agent health 上独立可见
- **资源池同步**：timeout → retry → circuit breaker 三级熔断；Postgres advisory lock 选主；Open 态不写 status，避免污染健康表
- **凭据层**：生产默认 Vaultwarden；dev 允许 `LITELLM_MASTER_KEY` 兜底；`sk-` 前缀在 path log 里脱敏
- **可观测性**：request logs 全量入库 + 多维过滤；请求指标 p50/p99；gateway health fan-out；spend 跨网关聚合
- **CI gate**：`gofmt` / `vet` / `build` / `docs-check` / `migration-drift` 周一 cron + 手动 weekly

完整记录：[release body](https://github.com/VMware-AI/agent-platform-backend/releases/tag/v0.0.1) · [commit history](https://github.com/VMware-AI/agent-platform-backend/commits/v0.0.1)

### agent-platform-docs（本仓库）

- **GitHub Pages**：[本站点](https://agent-platform-docs.pages.dev/)
- **Release**：本仓库首次正式发布（commit tag 走 PR 流程；当前 HEAD 在 `docs/adapt-v0.0.1-install-flow` 分支）
- **产物**：[Docker 镜像](https://github.com/VMware-AI/agent-platform-docs/pkgs/container/agent-platform-docs)（多架构 amd64 + arm64）/ 离线 tarball / GitHub Pages
- **文档站版本**：`0.0.1`（`package.json`）—— 与**平台版本** `v0.0.1`（`PLATFORM_VERSION`）独立编号

**变更要点**：

- 全站 **42 页** VitePress 静态文档；含指南 / 安装 / 控制台 / 可观测性 / 智能体 VM / 参考 6 大块
- **离线包**：`agent-platform-docs-<v>.tar.gz`（目标机只需 nginx，全站含搜索可离线使用）
- **Docker 镜像**：`quay.io/vmware-ai/agent-platform-docs:<v>`，多架构 buildx 构建（`make release-images`）
- **CI**：push / PR 构建（兼做死链检查）→ 打 `v*` tag 自动出离线包 + 推镜像

完整记录：[CHANGELOG.md](https://github.com/VMware-AI/agent-platform-docs/blob/main/CHANGELOG.md)

---

## 看发布列车历史的几种姿势

| 想看... | 去哪 |
|---|---|
| 每个仓库单独的完整 CHANGELOG | 各仓库根目录的 `CHANGELOG.md`（console / backend / docs 没有 CHANGELOG.md，变更要点在 release body / commit history 里） |
| 单个仓库的 commit 时间线 | GitHub 上每个仓库的 `commits/<branch>` 页 |
| 各仓库的 GitHub Release 列表 | [deployment](https://github.com/VMware-AI/agent-platform-deployment/releases) · [console](https://github.com/VMware-AI/agent-platform-console/releases) · [backend](https://github.com/VMware-AI/agent-platform-backend/releases) |
| 本仓库镜像 / 离线包 | [quay.io 镜像](https://quay.io/repository/vmware-ai/agent-platform-docs) / 本仓库 `Releases` 里的离线 tarball / `make image` 本地构建 |