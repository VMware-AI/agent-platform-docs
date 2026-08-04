# 平台简介

**智能体管理平台**是一套跑在企业自有 VMware Cloud Foundation（VCF）基础设施上的私有 AI Agent 交付与治理平台。

它让管理员在一个控制台里，把 AI 智能体像云实例一样批量交付给内部员工，并对模型调用、凭据、成本与操作轨迹做统一治理 —— 全程可在完全离网的环境中运行。

## 企业落地 AI Agent 的三个卡点

| 卡点 | 具体表现 | 平台的答案 |
|---|---|---|
| **部署难** | 想让每个开发者都用上 agent，却要逐台配环境、装 agent、发凭据、接本地模型、调网络 —— 慢、重复、易错 | 从 OVA 模板批量克隆，单台或成批，5–10 分钟交付；凭据与模型接入自动注入 |
| **管不住** | agent 种类多、迭代快；员工自行运行未受管控的 agent；没有审计轨迹与访问控制，说不清谁在用、用了多少 token | 实例生命周期、虚拟密钥、计量、审计四张视图收在一个控制台 |
| **数据泄漏风险** | 提示词、代码、文档被发送到公网 LLM API，全部离开企业边界，监管合规一票否决 | 模型调用统一走内网网关；完全气隙环境可以自造镜像包实现零外网运行 |

一句话概括做法：**把 agent 装进受管的虚拟机，把模型调用收进受管的网关，把两者的生命周期、凭据与账单收进一个控制台。**

## 五根支柱

<div class="ap-rule-list">

<div class="ap-rule-row">
<div class="num">01</div>
<div>
<strong>批量交付</strong>
<span>一个控制台把 agent 部署给内部用户，从 OVA 模板克隆虚拟机，单台或成批，5–10 分钟交付。即时克隆模式下创建是秒级的。</span>
</div>
</div>

<div class="ap-rule-row">
<div class="num">02</div>
<div>
<strong>集中治理</strong>
<span>生命周期、凭据、token 计量、审计 —— 一处管全，RBAC 分权到角色。每把密钥都带作用域、限流、预算与轮换策略。</span>
</div>
</div>

<div class="ap-rule-row">
<div class="num">03</div>
<div>
<strong>Agent 中立</strong>
<span>不绑定单一 agent 或厂商；OpenClaw、Hermes、OpenCode、QCoder、小怪等模板可替换、可并存。上游模型同样中立：内网 vLLM 与公有云 API 是同一套接法。</span>
</div>
</div>

<div class="ap-rule-row">
<div class="num">04</div>
<div>
<strong>零外网可运行</strong>
<span>自包含安装脚本 + 可选自造离线镜像包 + 内网模型 + 离线技能仓库；代码、数据、模型不出域，满足金融政企合规要求。</span>
</div>
</div>

<div class="ap-rule-row">
<div class="num">05</div>
<div>
<strong>复用现有底座</strong>
<span>跑在已有的 vSphere / vSAN / NSX 与本地 LLM 上，无需另购资源、另建 K8s 集群。快照、vMotion、HA、微分段全部直接可用。</span>
</div>
</div>

</div>

## 平台化 vs 分散式

| 对比项 | 分散式（各自本地部署） | 平台化（本平台） |
|---|---|---|
| 部署 | 每个端点手动安装，繁琐 | 像 VDI 一样交付，控制台一键部署 |
| 硬件成本 | 高 CAPEX，每个 agent 独占资源 | 高密度整合，1 agent = 1 轻量 VM；vSAN 去重让同模板克隆几乎不额外占空间 |
| 安全 | 本地 agent 常需广泛 OS 权限 | 严格隔离的 VM 沙箱 + NSX 微分段 |
| 稳定性 | 崩溃需人工干预修复 | VM 快照回滚 + 集群自动故障转移 |
| IT 管理 | 影子 IT：员工自行运行不受管的 agent | 集中管理：统一仪表盘 + RBAC + 计量 |
| 知识保留 | 员工离职后 agent 记忆和技能丢失 | 知识包与技能集中维护，随实例分发 |
| 数据隐私 | 依赖公网 API，数据外泄风险 | 内网模型网关，调用全量留痕 |

## 谁在用这套东西

| 角色 | 在平台上做什么 | 从哪读起 |
|---|---|---|
| **平台运维** | 装平台、接 vCenter、日常巡检与升级 | [环境要求](/install/requirements) |
| **平台管理员** | 配模型与路由、发密钥、部署与回收实例、看账单 | [初始化四步走](/console/bootstrap) |
| **观测 / 合规岗** | 只读看计量、监控、请求日志、审计日志 | [可观测性](/observability/metering) |
| **智能体使用者** | 用自己那台 VM 干活，自助改密与升级 | [访问智能体](/agent-vm/access) |

## 一次典型的交付链路

<ol class="ap-steps">
<li><strong>管理员接入底座。</strong> 在控制台接入 vCenter <a href="/console/resource-pools">资源池</a> 和 LiteLLM <a href="/console/gateway-connections">模型网关</a>。</li>
<li><strong>准备模型与密钥。</strong> 在<a href="/console/models">模型管理</a>里登记上游模型，在<a href="/console/routes">网关路由</a>里配置分派策略与降级链，为智能体<a href="/console/keys">颁发虚拟密钥</a>。</li>
<li><strong>从市场部署。</strong> 在<a href="/console/marketplace">智能体市场</a>选模板，填资源池、网络与凭据，单台或批量<a href="/console/deploy">部署</a>。</li>
<li><strong>交付到人。</strong> 把 VM 的 IP 与初始凭据发给使用者；使用者按<a href="/agent-vm/access">访问智能体</a>连上去，立即开始工作。</li>
<li><strong>持续观测。</strong> 管理员在<a href="/observability/metering">计量中心</a>看成本、在<a href="/observability/audit-log">审计日志</a>看操作轨迹，随时在<a href="/console/agents">智能体实例</a>页启停、升级、回收。</li>
</ol>

## 当前版本能做什么 / 还不能做什么

| 能力 | v0.0.1 |
|---|---|
| docker-compose 单机部署（dc-standalone） | ✅ 默认从 `quay.io` 拉镜像；气隙环境可自造镜像包走 `docker load` |
| docker-compose 多服务部署（dc-distribution） | ✅ 自包含 tarball |
| k8s 小集群部署（k8s-standalone，自带 PG/Redis） | ✅ Helm chart 自包含 |
| k8s 生产 HA（k8s-ha，外部 PG/Redis，≥2 副本） | ✅ Helm chart 自包含 |
| vCenter 资源池接入与资产同步 | ✅ |
| OVA 模板族 / 版本管理 | ✅ |
| 单台 / 批量部署，全量与即时克隆 | ✅ |
| 实例启停、改配、回收、版本更新 | ✅ |
| 模型 / 路由 / 虚拟密钥治理 | ✅ |
| 计量、监控、请求日志、审计日志 | ✅ |
| 技能离线仓库与安装 | ✅ |
| VM 内自服务管理台（改密 / 升级 / 回滚） | ✅ |
| 控制台里的快照按钮 | ❌ 后端支持，界面未暴露（可在 vCenter 侧操作） |
| 更细粒度的自定义角色 | ❌ 当前为三个内置角色 |

## 下一步

- 想先了解系统由哪些部件组成 → [架构与组成](/guide/architecture)
- 想先对齐术语（资源池、网关、虚拟密钥、模板族……）→ [核心概念](/guide/concepts)
- 想直接动手 → [快速开始](/guide/quickstart)
