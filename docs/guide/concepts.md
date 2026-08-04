# 核心概念

控制台里的对象之间有明确的依赖顺序。先对齐术语，后面的配置步骤就只是照着填。

## 对象关系全景

```
资源池 ResourcePool（一个 vCenter）
   └─ 内容库 Content Library
        └─ OVA 模板族 Family ──▶ 模板版本 Version（含 OVF 属性）
                                     │
                                     ├─ 部署 ──▶ 智能体实例 Agent（一台 VM）
                                     │              ├─ 运行 agent 运行时
模型网关 ModelGateway（LiteLLM）        │              ├─ agent-manager（心跳/知识包）
   ├─ 模型 ProviderModel               │              └─ webadmin（自服务）
   │    └─ 规格 ModelSpec ×N（真实上游）│
   ├─ 网关路由 ModelRoute（逻辑模型名） │
   └─ 虚拟密钥 VirtualKey ─────────────┘  绑定
```

一句话概括依赖：**资源池 → 模板 → 实例**，**网关 → 模型 → 路由 / 密钥 → 绑定到实例**。

## 底座类

### 资源池 Resource Pool

一个**已接入的 vCenter**，是智能体运行的物理底座。接入时填 VC 地址、账号口令，选择存放 OVA 模板的**内容库（Content Library）**。

接入成功后平台会同步该 vCenter 的资产，按层级组织：

```
数据中心 → 集群 → ESXi 主机 / vSphere 资源池
         → 数据存储 / 网络（端口组）/ VM 文件夹 / 存储策略
```

同步状态有五档：已同步 `SYNCED` · 同步中 `SYNCING` · 部分同步 `PARTIAL` · 失败 `FAILED` · 未同步 `NEVER`。

→ [资源池接入](/console/resource-pools)

### 模型网关 Model Gateway

一个**已接入的 LiteLLM Proxy 实例**，是所有模型调用的数据面入口。接入时要填**两个地址**：

| 地址 | 谁用 |
|---|---|
| 网关地址 | 控制面 |
| **Agent 访问地址** | 智能体 VM |

::: danger 两个地址的区别是新手第一大坑
控制面和 VM 在网络上位置不同。填错会出现「控制台测试连接是绿的，但 agent 调不通模型」这种最难查的故障。
:::

→ [模型网关接入](/console/gateway-connections)

## 模型类

三个都叫「模型」，含义完全不同，务必分清：

| 概念 | 是什么 | 举例 |
|---|---|---|
| **上游模型原名** | 厂商侧的真名 | `deepseek-chat` |
| **模型（ProviderModel）** | 平台里的登记 | `ds-chat-生产` |
| **路由（ModelRoute）** | 对外暴露的逻辑名，**agent 请求里写的就是它** | `CHAT-GENERAL` |

### 模型 ProviderModel 与规格 ModelSpec

一条「模型」登记归属一个网关，下面挂 **N 个规格（spec）**。每个 spec 描述一个真实上游端点：供应商分类、上游模型原名、API Base、API Key、限流、单价、标签。

支持的供应商分类：`custom`（任意 OpenAI 兼容端点）· `openai` · `anthropic` · `deepseek` · `minimax` · `moonshot` · `openrouter`。

**健康状态**汇总到模型级别：

| 状态 | 含义 | 还能服务吗 |
|---|---|---|
| 健康 `full_healthy` | 全部 spec 正常 | 是 |
| 降级 `partial_outage` | 部分正常 | 是 |
| 熔断 `full_outage` | 全部异常并冷却 | **否，拦截新请求** |
| 未探测 `unknown` | 探测结果超时 | 未知 |

→ [模型管理](/console/models)

### 网关路由 Gateway Route

对外暴露的**逻辑模型名**，把请求按策略分派到一组 spec 上。

| 策略 | 行为 |
|---|---|
| 简单洗牌 | 随机分流 |
| 最闲优先 | 选并发最少的 |
| 延迟优先 | 选历史延迟最低的 |
| 使用率优先 | 按用量均衡 |
| 成本优先 | 选单价最低的 |

还可配置三类**降级链**：常规故障转移、上下文超限降级、内容策略降级。

→ [网关路由](/console/routes)

### 虚拟密钥 Virtual Key

发给调用方的 **API 密钥**（`sk-…`）。它不是裸的通行证，而是一组治理参数的载体：

| 维度 | 内容 |
|---|---|
| 作用域 | 可调用模型、可调用接口（`CHAT` / `EMBEDDINGS` / `IMAGES` / `AUDIO`） |
| 限流 | RPM / TPM 上限及模式（保量 / 尽力）、最大并发 |
| 预算 | 消费上限、预算周期、已消费、消费进度 |
| 生命周期 | 有效时长、自动轮换周期、启用 / 禁用 / 吊销 |
| 归属 | 绑定到某个智能体实例，成本按此归集 |

→ [密钥管理](/console/keys)

## 智能体类

### OVA 模板族与版本

| 概念 | 内容 |
|---|---|
| **模板族 Family** | 一类智能体（OpenClaw / Hermes / OpenCode / QCoder / 小怪），带描述、预装工具、预装技能、适用场景、图标 |
| **版本 Version** | 该族下的具体 OVA，指向内容库里的一个 OVF 标识符，附带一组 **OVF 属性**（键、类型、默认值、是否必填、是否密码型、可选值） |

部署时选族 + 选版本。加新版本**只影响新部署**，存量实例要走[版本更新](/agent-vm/upgrade)。

→ [智能体市场](/console/marketplace)

### 智能体实例 Agent

一台**已部署的智能体虚拟机**，平台的核心运行单位。

| 状态 | 含义 |
|---|---|
| 部署中 `provisioning` | 克隆 / 开机 / 等待注册 |
| 运行中 `running` | 心跳正常 |
| 已停止 `stopped` | VM 已关机 |
| 异常 `exception` | 心跳超时或部署失败 |
| 已回收 | 已释放，记录保留用于审计与账单 |

每台实例有：绑定密钥、运行账户、访问端点、VM 资源规格（CPU / 内存 / 磁盘 / 端口组）、vApp 属性。

→ [智能体实例](/console/agents)

### 技能 Skill

给智能体扩展能力的**可安装包**（pip / npm / 二进制，可带 MCP 配置）。分发是离线优先的：包先进跳板机离线仓库，VM 再从内网拉取安装。

→ [技能管理](/console/skills)

### 知识包 Knowledge Pack

挂在**智能体配置**上的离线知识资料包。部署时随 guestinfo 下发授权列表，VM 内 agent-manager 在心跳时拉取、sha256 三重校验、防路径穿越解压、原子切换到知识根目录。

**属于本地文件分发，不是 RAG 索引。** 失败时 best-effort 降级，**绝不影响心跳**。

| | 技能 | 知识包 |
|---|---|---|
| 内容 | 可执行能力 | 静态资料 |
| 下发 | 控制台触发 SSH 安装 | 随心跳自动同步 |
| 失败影响 | 该次安装失败 | 降级，不影响心跳 |

## 治理类

### 角色

| 角色 | 定位 |
|---|---|
| <span class="ap-badge admin">admin</span> 超级管理员 | 平台全量读写 |
| <span class="ap-badge readonly">read_only</span> 只读用户 | 观测岗：看计量、监控、请求日志、审计日志，从不写 |
| `user` 普通用户 | 只看自己名下的资源 |

→ [角色与权限矩阵](/reference/roles)

### 计量、请求日志与审计日志

| | 记录什么 | 用来干嘛 |
|---|---|---|
| **计量** | 按时间窗聚合的调用量、Token、成本 | 对账、分摊、预算 |
| **请求日志** | 每一次经网关的上游调用 | 排障、追单条请求 |
| **审计日志** | 人在控制台上的操作轨迹 | 合规、安全复盘 |

计量有两个数据源：**平台记录**（带智能体归属）与**网关记录 litellm**（计费源头）。

→ [可观测性](/observability/metering)

## 术语速查表

| 中文 | 英文 / 后端 | 一句话 |
|---|---|---|
| 资源池 | ResourcePool | 一个已接入的 vCenter |
| 内容库 | Content Library | vCenter 里存 OVA 的库 |
| 模型网关 | ModelGateway | 一个 LiteLLM 实例 |
| 模型 | ProviderModel | 平台里的模型登记 |
| 供应商模型 / 规格 | ModelSpec | 一个真实上游端点 |
| 网关路由 | ModelRoute | 对外的逻辑模型名 |
| 虚拟密钥 | VirtualKey | 带治理参数的 API Key |
| 模板族 | OvaTemplateFamily | 一类智能体 |
| 模板版本 | OvaTemplateVersion | 一个具体的 OVA |
| 智能体实例 | Agent | 一台已部署的 VM |
| 技能 | Skill | 可安装的能力扩展 |
| 知识包 | Knowledge Pack | 离线知识资料 |
