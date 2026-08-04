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
console 的 `443:443` 与 `80:80` 在 compose 里是**硬编码**的，`.env` 里的 `CONSOLE_PORT` 只影响安装横幅的文案。需要换宿主端口只能改 `manifests/docker-compose.yml` 里 console 的 `ports:` 左侧，然后 `./install.sh up`。
:::

::: tip 想收紧暴露面
把 `BIND_IP` 指到管理网段的网卡，prometheus 和 grafana 就只在那张网卡上可达；或者干脆用主机防火墙只放行 443。
:::

## 内部服务名

容器之间通过 compose 网络的服务名互访：

| 调用方 → 被调方 | 地址 |
|---|---|
| console → backend | `http://backend:8080` |
| backend → postgres | `postgres:5432` |
| backend → redis | `redis:6379` |
| backend → litellm | `http://litellm:4000` |
| prometheus → litellm | `litellm:4000/metrics`（Bearer 认证） |
| grafana → prometheus | `http://litellm-prometheus:9090` |
| litellm → otel-collector | `otel-collector:4317/4318` |

::: danger 容器里不要用 127.0.0.1
在容器里 `127.0.0.1` 指向容器自己。把 console 的 `BACKEND_BASE_URL` 写成 `http://127.0.0.1:8080`，结果就是 `/query` 全部 502 —— 这是自定义部署时最常见的错误。
:::

## 需要放行的方向

### 运维 / 使用者 → 平台主机

| 源 | 目标 | 端口 | 必需 |
|---|---|---|---|
| 管理员浏览器 | 平台主机 | **443** | ✅ |
| 管理员浏览器 | 平台主机 | 80 | 可选（跳转用） |
| 监控系统 | 平台主机 | 9090 / 3000 | 可选 |

### 平台主机 → 外部

| 目标 | 端口 | 用途 | 必需 |
|---|---|---|---|
| **vCenter** | 443 | 克隆 VM、读清单、改配置 | ✅ |
| 模型网关（若为外部实例） | 依部署 | 网关管理 API | 视部署 |
| 上游模型服务 | 依部署 | 由 litellm 发起的调用 | ✅ |
| 技能包源（在线下载时） | 依配置 | 后端下载技能包 | 可选 |

::: tip 完全离网也能跑
上表只有 **vCenter** 和**内网模型服务**是必需的。模型与技能包都在内网时，平台主机不需要任何公网出口。
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
控制面到智能体 VM **没有任何入站需求** —— 全部靠 VM 出站心跳。做防火墙策略时可以放心把这个方向整个关掉。
:::

## 一张图看全

```
                 ┌──────────── 管理网 ────────────┐
管理员浏览器 ──443──▶ 平台主机                      │
监控系统 ─────9090/3000──▶ 平台主机                 │
                 └───────────────────────────────┘
                          │
                    443   │  govmomi
                          ▼
                       vCenter
                          │ 克隆 / 开机
                          ▼
   ┌────────────── 智能体网段（NSX 微分段）──────────────┐
   │  Agent VM 1    Agent VM 2    Agent VM N            │
   │      │              │             │                │
   │      └──────────────┴─────────────┘                │
   │              443 出站                              │
   └────────────────────┬───────────────────────────────┘
                        ▼
              平台主机（控制面 + 网关）
                        │
                        ▼
                内网 LLM 推理服务
```

## NSX 微分段建议

为智能体 VM 所在端口组配置 DFW 规则：

| 序 | 方向 | 源 | 目标 | 端口 | 动作 |
|---|---|---|---|---|---|
| 1 | 出站 | Agent VM 组 | 控制面 IP | 443 | 允许 |
| 2 | 出站 | Agent VM 组 | 网关 Agent 访问地址 | 443 | 允许 |
| 3 | 出站 | Agent VM 组 | 包仓库地址 | 依配置 | 允许 |
| 4 | 入站 | 管理网段 | Agent VM 组 | 22, 443 | 允许 |
| 5 | 任意 | Agent VM 组 | Agent VM 组 | any | **拒绝** |
| 6 | 出站 | Agent VM 组 | any | any | **拒绝** |

::: tip 第 5 条是关键
禁止 VM 之间的横向流量。这样即使某台 VM 被攻破，攻击者也无法横向访问其他人的智能体 —— 这是「一人一 VM」隔离模型的价值所在，不配这条规则就白隔离了。
:::

::: warning 第 6 条会拦住公网
默认拒绝出站会让 VM 里的 `pip install` / `npm install` 直接失败。这是设计使然 —— 需要额外的包，走[技能管理](/console/skills)的内网离线库。
:::

## 端口冲突排查

```bash
# 看谁占了 443
ss -lntp

# 看 compose 的端口映射
docker compose -p agent-platform ps

# 从另一台机器验通达性
nc -zv <平台IP> 443
curl -skI https://<平台IP>/ | head -1
```

常见冲突：主机上已有 nginx / Apache 占了 80 / 443。处理方式二选一：

1. 停掉原有服务
2. 改 `manifests/docker-compose.yml` 里 console 的宿主端口，然后 `./install.sh up`

::: tip 文档站和平台装同一台机器
文档站离线包默认监听 8080，与平台的 443 / 80 不冲突。但 backend 也映射在回环 8080 上 —— 为省心建议文档站换到 8081，见[离线部署本手册](/reference/offline-docs#八和平台装在同一台机器上)。
:::
