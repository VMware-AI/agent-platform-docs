# 架构与组成

平台分三层：**控制面**（管理平台自身）、**数据面**（模型网关）、**运行面**（智能体虚拟机）。三层都跑在企业已有的 VCF / vSphere 底座上。

## 分层视图

<div class="ap-stack">
  <div class="ap-layer ap-layer-user">
    <div class="ap-layer-title">使用者 / 管理员</div>
    <div class="ap-chips"><span>浏览器控制台</span><span>Agent 自带 CLI / Web UI</span><span>SSH</span></div>
  </div>
  <div class="ap-layer ap-layer-ctrl">
    <div class="ap-layer-title">控制面 —— 智能体管理平台</div>
    <div class="ap-chips"><span>console（Vue SPA + nginx）</span><span>backend（Go / GraphQL）</span><span>PostgreSQL</span><span>Redis</span><span>Prometheus</span><span>Grafana</span></div>
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

单机（`dc-standalone`）形态下由 7 个容器组成：

| 容器 | 作用 | 对外暴露 |
|---|---|---|
| `agent-platform-console` | nginx，托管控制台 SPA，并反代 `/api/` → backend、`/litellm/` → litellm | `${EXTERNAL_IP}:${CONSOLE_PORT}`（HTTPS，默认 443） |
| `agent-platform-backend` | Go + GraphQL 控制面：RBAC、vCenter 编排（govmomi）、网关治理、审计与计量聚合 | 仅 `127.0.0.1:8080`（由 console 反代） |
| `litellm` | LiteLLM Proxy 数据面网关，代理全部上游模型调用 | 仅 `127.0.0.1:4000`（由 console 反代） |
| `postgres` | 控制面库 `agentplatform` + 网关库 `litellm`（standalone 共用实例） | 内部 |
| `redis` | 缓存与限流计数 | 内部 |
| `litellm-prometheus` | 抓取 litellm `/metrics` | `${BIND_IP}:9090` |
| `grafana` | 内置仪表盘 | `${BIND_IP}:3000` |

::: tip 为什么 backend 和 litellm 只绑回环
两者都由 console 的 nginx 反代对外，浏览器只需要访问一个 HTTPS 端口。这样默认就没有第二个未加密的入站面。
:::

## 运行面：智能体 VM 内部

每台智能体 VM 由 OVA 模板克隆而来，开机后由 cloud-init 完成注入，内部跑两个加固的 systemd 单元：

| 单元 | 职责 |
|---|---|
| `agent-manager` | **出站**：向控制面 enroll 注册、周期上报心跳（含真实已装 agent 版本）、同步知识包。仅 443 出站，带断路器与指数退避。 |
| `agent-manager-webadmin` | **入站**：自服务改密码、查询状态与版本、升级 / 回滚 agent。监听回环，由 nginx `/manage/` 反代（TLS + Basic Auth）对外，是 VM 唯一对外接口。 |

::: warning 凭据不落盘
LLM 的 URL 与 API Key 在 VM 启动时运行时注入，绝不带进镜像。VM 本地状态文件只存密码**指纹**与 VM token，不存明文口令。
:::

## 关键数据流

**部署一台智能体**

```
控制台 ─(GraphQL deployAgent)→ backend ─(govmomi)→ vCenter
                                          │
                                          ├─ clone -on=false（从 Content Library 的 OVA 模板）
                                          ├─ 注入 guestinfo（gzip+base64：凭据、网关地址、虚拟密钥）
                                          ├─ power on → 等待 VM IP
                                          └─ 失败则 destroy 回滚
VM 开机 → cloud-init → agent-manager enroll → 心跳上报 → 控制台状态转「运行中」
```

**一次模型调用**

```
Agent 运行时 ──(虚拟密钥 sk-…)──▶ LiteLLM 网关 ──(路由策略 / 降级链)──▶ 上游模型
                                     │
                                     ├─ 限流（RPM / TPM）、预算上限、密钥作用域校验
                                     ├─ 写请求日志（模型、Token、延迟、状态码）
                                     └─ Prometheus 指标 → 实时监控 / 计量中心
```

## 数据存放在哪里

| 数据 | 位置 |
|---|---|
| 平台元数据（用户、资源池、模板、实例、审计） | PostgreSQL 库 `agentplatform` |
| 网关密钥与调用账单 | PostgreSQL 库 `litellm` |
| 加密凭据（vCenter 口令、上游 API Key 等） | `platform_secrets` 表，使用 `SECRETS_ENCRYPTION_KEY` 加密 |
| 指标时序 | Prometheus 卷 `agent-platform_litellm_prom_data` |
| 智能体工作数据 | 各自 VM 的磁盘（vSAN 数据存储） |

::: danger 务必备份 SECRETS_ENCRYPTION_KEY
安装时生成的 `.secrets_encryption_key` 文件是解开 `platform_secrets` 的唯一钥匙。丢失它，所有已加密凭据将变成无法解密的死数据。详见 [升级与卸载](/install/upgrade)。
:::

## 下一步

- [核心概念](/guide/concepts) —— 资源池、网关、路由、虚拟密钥、模板族之间的关系
- [环境要求](/install/requirements) —— 开始安装
