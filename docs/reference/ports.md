# 端口与网络

## 平台主机端口

`dc-standalone` 默认只把 **console** 与 **prometheus / grafana** 暴露到外网，其余全部绑回环。

| 服务 | 主机绑定 | 容器内端口 | 说明 |
|---|---|---|---|
| console（HTTPS） | `${BIND_IP:-0.0.0.0}:443` | 443 | **控制台入口**，TLS 由 console 镜像终结 |
| console（HTTP） | `${BIND_IP:-0.0.0.0}:80` | 80 | 301 跳转到 443 |
| prometheus | `${BIND_IP:-0.0.0.0}:9090` | 9090 | 抓取状态查看 |
| grafana | `${BIND_IP:-0.0.0.0}:3000` | 3000 | 内置仪表盘 |
| backend | `127.0.0.1:${BACKEND_PORT:-8080}` | 8080 | 仅回环，由 console 反代 |
| litellm | `127.0.0.1:4000` | 4000 | 仅回环，由 console 反代 |
| postgres | `127.0.0.1:5433` | 5432 | 仅回环 |
| redis | `127.0.0.1:6379` | 6379 | 仅回环 |
| otel-collector | `127.0.0.1:4317` / `4318` | 4317 / 4318 | gRPC / OTLP-HTTP，请求日志采集 |

::: warning `CONSOLE_PORT` 在 v0.0.1 不改变实际映射
console 的 `443:443` 与 `80:80` 在 compose 里是硬编码的，`.env` 里的 `CONSOLE_PORT` 只影响安装横幅的文案。需要换宿主端口只能改 `manifests/docker-compose.yml`。
:::

## 内部服务名

容器之间通过 compose 网络的服务名互访（**不要用 `127.0.0.1`** —— 在容器里它指向容器自己）：

| 服务名 | 地址 |
|---|---|
| console → backend | `http://backend:8080` |
| backend → postgres | `postgres:5432` |
| backend → redis | `redis:6379` |
| backend → litellm | `http://litellm:4000` |
| prometheus → litellm | `litellm:4000/metrics`（Bearer 认证） |
| grafana → prometheus | `http://litellm-prometheus:9090` |

## 需要放行的方向

### 运维 / 使用者 → 平台主机

| 源 | 目标 | 端口 |
|---|---|---|
| 管理员浏览器 | 平台主机 | 443（必须），80（可选，跳转用） |
| 监控系统 | 平台主机 | 9090 / 3000（可选） |

### 平台主机 → 外部

| 目标 | 端口 | 用途 |
|---|---|---|
| vCenter | 443 | 克隆 VM、读清单、改配置 |
| 模型网关（若为外部实例） | 依部署 | 网关管理 API |
| 上游模型服务 | 依部署 | 由 litellm 发起的调用 |

::: tip 完全离网也能跑
上表只有 vCenter 是必需的。模型网关与上游模型都在内网时，平台主机不需要任何公网出口。
:::

### 智能体 VM → 外部

| 目标 | 端口 | 用途 |
|---|---|---|
| 控制面 `EXTERNAL_IP` | 443 | agent-manager 注册 + 心跳 + 知识包（**仅出站**） |
| 模型网关的「Agent 访问地址」 | 443 或网关端口 | agent 调用模型 |
| 离线技能 / 版本包仓库 | 依配置（FTP / HTTP-S） | 技能与 agent 版本包下载 |

### 使用者 → 智能体 VM

| 目标 | 端口 | 用途 |
|---|---|---|
| VM | 22 | SSH |
| VM | 443（路径 `/manage/`） | VM 自服务管理台 |

::: tip 控制面不主动连 VM
控制面到智能体 VM **没有**入站需求 —— 全部靠 VM 出站心跳。做防火墙策略时可以放心把这个方向关掉。
:::

## NSX 微分段建议

为智能体 VM 所在端口组配置 DFW 规则：

```
允许 出站 → 控制面 IP:443
允许 出站 → 网关 Agent 访问地址
允许 出站 → 包仓库地址
允许 入站 ← 管理网段:22, 443
拒绝   其他（含 VM 之间的横向流量）
```

这样即使某台 VM 被攻破，也无法横向访问其他人的智能体。
