# 架构与组成

平台分三层：**控制面**（管理平台自身）、**数据面**（模型网关）、**运行面**（智能体虚拟机）。三层都跑在企业已有的 VCF / vSphere 底座上。

## 分层视图

<div class="ap-stack">
  <div class="ap-layer ap-layer-user">
    <div class="ap-layer-title">使用者 / 管理员</div>
    <div class="ap-chips"><span>浏览器控制台</span><span>Agent 自带 CLI / Web UI</span><span>SSH</span><span>VM 管理台 /manage/</span></div>
  </div>
  <div class="ap-layer ap-layer-ctrl">
    <div class="ap-layer-title">控制面 —— 智能体管理平台</div>
    <div class="ap-chips"><span>console（Vue SPA + nginx）</span><span>backend（Go / GraphQL）</span><span>PostgreSQL</span><span>Redis</span><span>Prometheus</span><span>Grafana</span><span>OTel Collector</span></div>
  </div>
  <div class="ap-layer ap-layer-data">
    <div class="ap-layer-title">数据面 —— 模型网关</div>
    <div class="ap-chips"><span>LiteLLM Proxy</span><span>虚拟密钥 / 限流 / 预算</span><span>路由与降级链</span><span>本地 LLM · 私有模型服务</span></div>
  </div>
  <div class="ap-layer ap-layer-run">
    <div class="ap-layer-title">运行面 —— 智能体 VM 池（1 用户 = 1 隔离 VM）</div>
    <div class="ap-chips"><span>Agent 运行时</span><span>agent-manager（心跳 / 知识包）</span><span>agent-manager-webadmin（自服务）</span><span>nginx TLS</span></div>
  </div>
  <div class="ap-layer ap-layer-infra">
    <div class="ap-layer-title">基础设施 —— VMware Cloud Foundation</div>
    <div class="ap-chips"><span>vSphere / vCenter</span><span>vSAN</span><span>NSX 微分段</span><span>GPU / vGPU</span><span>Content Library（OVA）</span></div>
  </div>
</div>

## 控制面组件

单机（`dc-standalone`）形态下由 **8 个容器**组成：

| 容器 | 技术栈 | 作用 | 对外暴露 |
|---|---|---|---|
| `agent-platform-console` | nginx + Vue SPA | 托管控制台，并反代 `/api/` → backend、`/litellm/` → litellm | `${BIND_IP}:443`（HTTPS）+ `:80`（跳转） |
| `agent-platform-backend` | Go + gqlgen + Ent | 控制面：RBAC、vCenter 编排（govmomi）、网关治理、审计与计量聚合 | 仅 `127.0.0.1:8080` |
| `litellm` | LiteLLM Proxy | 数据面网关，代理全部上游模型调用 | 仅 `127.0.0.1:4000` |
| `postgres` | PostgreSQL 16 | 控制面库 `agentplatform` + 网关库 `litellm`（standalone 共用实例） | 仅 `127.0.0.1:5433` |
| `redis` | Redis 7 | 缓存与限流计数 | 仅 `127.0.0.1:6379` |
| `litellm-prometheus` | Prometheus | 抓取 litellm `/metrics`（Bearer 认证） | `${BIND_IP}:9090` |
| `grafana` | Grafana | 内置 LiteLLM 仪表盘 | `${BIND_IP}:3000` |
| `otel-collector` | OTel Collector | 接收网关 span，落 jsonl 供 backend 摄入请求日志 | 仅 `127.0.0.1:4317/4318` |

::: tip 为什么 backend 和 litellm 只绑回环
两者都由 console 的 nginx 反代对外，浏览器只需要访问一个 HTTPS 端口。这样默认就**没有第二个未加密的入站面**，也不用为它们单独配证书。
:::

### 控制面内部依赖

```
浏览器 ──HTTPS:443──▶ console(nginx)
                        ├─ /            静态 SPA
                        ├─ /query       ──▶ backend:8080   (GraphQL)
                        └─ /litellm/    ──▶ litellm:4000   (供 VM 访问网关)

backend ──▶ postgres:5432   平台元数据 + 加密凭据
        ──▶ redis:6379      缓存 / 限流
        ──▶ litellm:4000    推送模型、路由、密钥（admin API）
        ──▶ vCenter:443     govmomi 编排
        ──tail──▶ 共享 jsonl ◀──写──  otel-collector ◀──OTLP── litellm

prometheus ──抓取──▶ litellm:4000/metrics
grafana    ──查询──▶ litellm-prometheus:9090
```

::: warning 容器内不要用 127.0.0.1
容器里的 `127.0.0.1` 指向容器自己。跨容器一律用 compose 的服务名（`backend`、`postgres`、`litellm`）。这是自定义部署时最常见的 502 来源。
:::

## 数据面：模型网关

LiteLLM Proxy 是所有模型调用的必经之路，平台把治理钩子全挂在这里：

| 能力 | 由谁配 |
|---|---|
| 虚拟密钥的作用域、限流、预算 | 平台 → 推送到网关 |
| 路由策略与降级链 | 平台 → 推送到网关 |
| 上游模型与凭据 | 平台 → 推送到网关（API Key 加密存平台库） |
| 调用指标 | 网关 → prometheus / OTel → 平台 |

平台侧改配置的路径永远是：**先落平台库 → 再同步到网关**。所以网关侧不需要人工维护配置文件。

## 运行面：智能体 VM 内部

每台智能体 VM 由 OVA 模板克隆而来，开机后由 cloud-init 完成注入，内部跑两个加固的 systemd 单元：

| 单元 | 方向 | 职责 |
|---|---|---|
| `agent-manager` | **出站** | 向控制面 enroll 注册、周期心跳（上报状态 + 真实已装版本）、同步知识包。仅 443 出站，带断路器与指数退避 |
| `agent-manager-webadmin` | **入站** | 自服务改密码、查状态与版本、升级 / 回滚。监听回环，由 nginx `/manage/` 反代（TLS + Basic Auth）对外 |

```
             ┌─────────────── 智能体 VM ───────────────┐
使用者 ──443─▶│ nginx  /manage/  ──▶ webadmin(127.0.0.1:8090) │
使用者 ──22──▶│ sshd                                        │
             │ agent 运行时 ──虚拟密钥──┐                    │
             │ agent-manager ───────────┼──443 出站──────────┼──▶ 控制面 / 网关
             └──────────────────────────┴────────────────────┘
```

::: danger 凭据不落盘
LLM 的 URL 与 API Key 在 VM 启动时**运行时注入**，绝不带进镜像。VM 本地状态文件 `/var/lib/agent-manager/state.json`（`0600`）只存密码**指纹**与 VM token，不存明文口令。
:::

::: tip 控制面不主动连 VM
所有状态都靠 VM 出站心跳上报。做防火墙策略时，控制面 → VM 这个方向可以整个关掉。
:::

## 关键数据流

### 部署一台智能体

```
控制台 ─(GraphQL deployAgent)→ backend ─(govmomi)→ vCenter
   ① clone -on=false               从 Content Library 的 OVA 模板克隆，先不开机
   ② 注入 guestinfo (gzip+base64)   OS 凭据、SSH 公钥、网关 Agent 访问地址、
                                    虚拟密钥、知识包授权列表、网络配置
   ③ power on
   ④ wait vm.ip
   ⑤ 失败 → vm.destroy 回滚          不留半成品

VM 侧：cloud-init → agent-manager enroll（一次性 token 换长期 VM token）
        → 周期心跳
控制台：状态 provisioning → running
```

### 一次模型调用

```
Agent 运行时 ──(虚拟密钥 sk-…)──▶ LiteLLM 网关 ──(路由策略/降级链)──▶ 上游模型
                                     │
                                     ├─ 校验：密钥有效性、作用域、限流、预算
                                     ├─ 写调用账单（网关库）
                                     ├─ 发 OTLP span → otel-collector → 请求日志
                                     └─ 暴露 /metrics → prometheus → 实时监控
```

### 一次心跳

```
agent-manager ──POST /v1/agents/{vm_id}/heartbeat──▶ 控制面
   上报：运行状态、真实已装 agent 版本
   下发：待执行命令（如版本升级）、知识包授权列表
   顺带：VM token 续期

失败时：断路器指数退避重试，不会让进程崩掉
知识包同步失败：best-effort 降级，绝不破坏心跳
```

## 数据存放在哪里

| 数据 | 位置 |
|---|---|
| 平台元数据（用户、资源池、模板、实例、审计） | PostgreSQL 库 `agentplatform` |
| 网关密钥与调用账单 | PostgreSQL 库 `litellm` |
| **加密凭据**（vCenter 口令、上游 API Key 等） | `platform_secrets` 表，用 `SECRETS_ENCRYPTION_KEY` 加密 |
| 指标时序 | Prometheus 卷 `agent-platform_litellm_prom_data` |
| Grafana 配置 | 卷 `agent-platform_grafana_data` |
| 请求日志中转 | `manifests/shared-spans/requestlog-spans.jsonl` |
| 智能体工作数据 | 各自 VM 的磁盘（vSAN 数据存储） |

::: danger 务必备份 SECRETS_ENCRYPTION_KEY
安装时生成的 `.secrets_encryption_key` 是解开 `platform_secrets` 的唯一钥匙。丢失它，所有已加密凭据将变成无法解密的死数据 —— 数据库还在，但里面的 vCenter 口令和模型 API Key 全部报废。详见[升级与卸载](/install/upgrade#备份清单)。
:::

## 为什么是这个架构

| 设计选择 | 理由 |
|---|---|
| agent 装进 VM 而不是容器 | 复用 vSphere 的隔离、快照、vMotion、HA；agent 常需要较宽的 OS 权限，VM 沙箱更合适 |
| 模型调用统一走网关 | 治理钩子只需要挂一处：限流、预算、审计、计量全都落在网关上 |
| 控制面不连 VM，只收心跳 | 防火墙策略单向，VM 侧不开入站面；VM 数量增长时也不需要控制面维护长连接 |
| 凭据运行时注入 | 镜像可以随便分发、复制，不携带任何密钥 |
| backend 用 Go、VM 内 daemon 用 Python | 控制面要并发与类型安全；VM 内要贴近 cloud-init / systemd / OS 工具链 |

## 下一步

- [核心概念](/guide/concepts) —— 资源池、网关、路由、虚拟密钥、模板族之间的关系
- [环境要求](/install/requirements) —— 开始安装
- [端口与网络](/reference/ports) —— 防火墙与微分段规划
