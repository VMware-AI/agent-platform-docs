# 平台简介

**智能体管理平台**是一套跑在企业自有 VMware Cloud Foundation（VCF）基础设施上的私有 AI Agent 交付与治理平台。它让管理员在一个控制台里，把 AI 智能体像云实例一样批量交付给内部员工，并对模型调用、凭据、成本与操作轨迹做统一治理 —— 全程可在完全离网的环境中运行。

## 企业落地 AI Agent 的三个卡点

| 卡点 | 具体表现 |
|---|---|
| **部署难** | 想让每个开发者都用上 agent，却要逐台配环境、装 agent、发凭据、接本地模型、调网络 —— 慢、重复、易错。 |
| **管不住** | agent 种类多、迭代快；员工自行运行未受管控的 agent；没有审计轨迹与访问控制，也说不清谁在用、用了多少 token。 |
| **数据泄漏风险** | 提示词、代码、文档被发送到公网 LLM API，全部离开企业边界，监管合规一票否决。 |

平台针对这三点给出的答案是：**把 agent 装进受管的虚拟机，把模型调用收进受管的网关，把两者的生命周期、凭据与账单收进一个控制台。**

## 五根支柱

<div class="ap-rule-list">

<div class="ap-rule-row">
<div class="num">01</div>
<div>
<strong>批量交付</strong>
<span>一个控制台把 agent 部署给内部用户，从 OVA 模板克隆虚拟机，单台或成批，5–10 分钟交付。</span>
</div>
</div>

<div class="ap-rule-row">
<div class="num">02</div>
<div>
<strong>集中治理</strong>
<span>生命周期、凭据、token 计量、审计 —— 一处管全，RBAC 分权到角色。</span>
</div>
</div>

<div class="ap-rule-row">
<div class="num">03</div>
<div>
<strong>Agent 中立</strong>
<span>不绑定单一 agent 或厂商；OpenClaw、Hermes、OpenCode、QCoder、小怪等模板可替换、可并存。</span>
</div>
</div>

<div class="ap-rule-row">
<div class="num">04</div>
<div>
<strong>零外网可运行</strong>
<span>离线镜像包 + 自包含安装脚本 + 内网模型；代码、数据、模型不出域，满足金融政企合规要求。</span>
</div>
</div>

<div class="ap-rule-row">
<div class="num">05</div>
<div>
<strong>复用现有底座</strong>
<span>跑在已有的 vSphere / vSAN / NSX 与本地 LLM 上，无需另购资源、另建 K8s 集群。</span>
</div>
</div>

</div>

## 平台化 vs 分散式

| 对比项 | 分散式（各自本地部署） | 平台化（本平台） |
|---|---|---|
| 部署 | 每个端点手动安装，繁琐 | 像 VDI 一样交付，控制台一键部署 |
| 硬件成本 | 高 CAPEX，每个 agent 独占资源 | 高密度整合，1 agent = 1 轻量 VM |
| 安全 | 本地 agent 常需广泛 OS 权限 | 严格隔离的 VM 沙箱 + 网络微分段 |
| 稳定性 | 崩溃需人工干预修复 | VM 快照回滚 + 集群自动故障转移 |
| IT 管理 | 影子 IT：员工自行运行不受管的 agent | 集中管理：统一仪表盘 + RBAC + 计量 |
| 数据隐私 | 依赖公网 API，数据外泄风险 | 内网模型网关，调用全量留痕 |

## 一次典型的交付链路

<ol class="ap-steps">
<li><strong>管理员接入底座。</strong> 在控制台接入 vCenter <a href="/console/resource-pools">资源池</a> 和 LiteLLM <a href="/console/gateway-connections">模型网关</a>。</li>
<li><strong>准备模型与密钥。</strong> 在<a href="/console/models">模型管理</a>里登记上游模型，在<a href="/console/routes">网关路由</a>里配置分派策略，为智能体<a href="/console/keys">颁发虚拟密钥</a>。</li>
<li><strong>从市场部署。</strong> 在<a href="/console/marketplace">智能体市场</a>选模板，填资源池、网络与凭据，单台或批量<a href="/console/deploy">部署</a>。</li>
<li><strong>交付到人。</strong> 把 VM 的 IP 与初始凭据发给使用者；使用者按<a href="/agent-vm/access">访问智能体</a>连上去，立即开始工作。</li>
<li><strong>持续观测。</strong> 管理员在<a href="/observability/metering">计量中心</a>看成本、在<a href="/observability/audit-log">审计日志</a>看操作轨迹，随时在<a href="/console/agents">智能体实例</a>页启停、升级、回收。</li>
</ol>

## 下一步

- 想先了解系统由哪些部件组成 → [架构与组成](/guide/architecture)
- 想先对齐术语（资源池、网关、虚拟密钥、模板族……）→ [核心概念](/guide/concepts)
- 想直接动手 → [快速开始](/guide/quickstart)
