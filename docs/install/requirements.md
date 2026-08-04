# 环境要求

v0.0.1 发布 **docker-compose 单机形态（`dc-standalone`）**：整套控制面跑在一台 Linux 主机上，全部 8 个容器由一份 compose 文件拉起，可在完全离网的环境中安装。

## 平台主机

| 项目 | 要求 |
|---|---|
| 操作系统 | Linux（x86_64 / amd64）。v0.0.1 只发布 `linux/amd64` 离线镜像包 |
| Docker | Docker Engine + **compose 插件**（`docker compose version` 可用） |
| 磁盘 | `/var` 至少 **5 GB** 空闲（preflight 会告警）；建议 40 GB 以上，容纳镜像、数据库与指标 |
| 内存 | 建议 8 GB 以上 |
| 网络 | 一张有固定 IP 的网卡；离线安装不需要任何出站网络 |
| 权限 | 能执行 docker 命令；`CONSOLE_PORT` 使用 1024 以下端口时需 root 或 `CAP_NET_BIND_SERVICE` |

::: warning 架构必须匹配
离线镜像包按架构拆分。v0.0.1 只提供 `amd64`，装在 `aarch64` 主机上 preflight 会告警且容器无法启动。
:::

## 需要放行的主机端口

| 端口 | 服务 | 绑定 | 用途 |
|---|---|---|---|
| 443 | console | `${BIND_IP}`（默认 `0.0.0.0`） | 控制台 HTTPS —— **必须放行** |
| 80 | console | `${BIND_IP}` | HTTP → HTTPS 跳转 |
| 9090 | prometheus | `${BIND_IP}` | 指标抓取状态（可选对外） |
| 3000 | grafana | `${BIND_IP}` | 内置仪表盘（可选对外） |
| 8080 | backend | `127.0.0.1` | 仅回环，由 console 反代 |
| 4000 | litellm | `127.0.0.1` | 仅回环 |
| 5433 / 6379 | postgres / redis | `127.0.0.1` | 仅回环 |
| 4317 / 4318 | otel-collector | `127.0.0.1` | 仅回环，请求日志采集 |

完整清单见 [端口与网络](/reference/ports)。

## vCenter（部署智能体所需）

| 项目 | 要求 |
|---|---|
| vSphere | 支持 Content Library 的版本；接入时平台会显示探测到的 vSphere 版本 |
| 账号权限 | 读取清单；克隆 VM、修改 vApp/guestinfo 属性、开关机、删除 VM；读取内容库 |
| 内容库 | 已导入智能体 OVA/OVF 模板的 Content Library |
| 网络 | 智能体 VM 所在端口组需能出站访问**控制面 443** 和**模型网关地址**；平台主机需能访问 vCenter 443 |
| 证书 | 自签名 / 内网 CA 的 vCenter 可在接入时勾选「跳过 TLS 验证」，生产环境建议保持验证 |

## 模型网关

平台通过 **LiteLLM Proxy** 代理全部模型调用。`dc-standalone` 已内置一个 litellm 容器（回环 4000），也可以接入外部已有的 LiteLLM 实例。接入时需要：

- 网关地址（控制面可达）
- 网关 Master Key
- **Agent 访问地址** —— 智能体 VM 侧访问网关用的 URL。单机形态下 litellm 只绑回环，智能体 VM 要访问它，需通过 console 的 `/litellm/` 反代路径，即 `https://<EXTERNAL_IP>/litellm/`

::: tip 为什么要单独填 Agent 访问地址
控制面和智能体 VM 处在不同网络位置：控制面可以走 `http://litellm:4000`（容器网络内），而 VM 只能走对外的 HTTPS 入口。两个地址分开填，避免把内部地址下发到 VM 里。
:::

## 上游模型

至少准备一个可用的上游模型，用于在[模型管理](/console/models)中登记：

- 供应商分类（如 `openai`、`azure`、`vllm`、`ollama` 等 LiteLLM 支持的 provider）
- 上游模型原名
- API Base（内网私有模型服务也可以）
- API Key（后端加密入库）

## 交付物清单

从 [release v0.0.1](https://github.com/VMware-AI/agent-platform-deployment/releases/tag/release-v0.0.1) 下载：

| 文件 | 说明 |
|---|---|
| `agent-platform-dc-standalone-0.0.1.tar.gz` | 安装包（自包含：脚本 + compose + 配置 + 文档） |
| `agent-platform-images-0.0.1-amd64.tar.gz` | 离线镜像包（amd64） |
| `SHA256SUMS` | 校验和 |

准备好之后 → [离线安装（单机）](/install/dc-standalone)
