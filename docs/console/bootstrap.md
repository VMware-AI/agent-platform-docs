# 初始化四步走

新装的平台是空的。四步之后，你就能部署第一个智能体。

::: danger 顺序不能颠倒
后一步的下拉框依赖前一步的数据。跳步的结果是「点开表单发现全是空选项」，然后一头雾水。
:::

<div class="ap-rule-list">

<div class="ap-rule-row">
<div class="num">01</div>
<div>
<strong>接入资源池（vCenter）</strong>
<span>系统配置 → 资源池接入。填 VC 地址、账号、口令 → <em>测试连接</em> → 选内容库 → 保存 → <strong>等同步状态变「已同步」</strong>。<a href="/console/resource-pools">详解 →</a></span>
</div>
</div>

<div class="ap-rule-row">
<div class="num">02</div>
<div>
<strong>接入模型网关（LiteLLM）</strong>
<span>系统配置 → 模型网关接入。填网关地址、Master Key、<strong>Agent 访问地址</strong> → <em>测试连接</em> → 保存。<a href="/console/gateway-connections">详解 →</a></span>
</div>
</div>

<div class="ap-rule-row">
<div class="num">03</div>
<div>
<strong>登记模型 + 建路由</strong>
<span>模型调度台 → 模型管理新建模型（供应商、上游原名、API Base、API Key、<strong>单价</strong>）→ 网关路由新建路由，选策略、把模型挑进已选定列表。<a href="/console/models">模型 →</a> <a href="/console/routes">路由 →</a></span>
</div>
</div>

<div class="ap-rule-row">
<div class="num">04</div>
<div>
<strong>颁发密钥 + 登记模板</strong>
<span>模型调度台 → 密钥管理颁发虚拟密钥；智能体中心 → 智能体市场新增模板族（选资源池 → 内容库 → OVA 模板）。<a href="/console/keys">密钥 →</a> <a href="/console/marketplace">市场 →</a></span>
</div>
</div>

</div>

完成后即可 [部署智能体](/console/deploy)。

## 每一步的验收标准

别急着往下走，每步都有一个明确的「算过了」的信号：

| 步骤 | 验收标准 |
|---|---|
| 1. 资源池 | 列表里同步状态显示**「已同步」**，且「资产 → 查看」能看到集群、网络、数据存储 |
| 2. 网关 | 列表里连接状态正常、同步状态「已同步」，**后端模型数**能刷出来 |
| 3. 模型 | 健康状态是**「健康」**（不是「未探测」），且填了输入 / 输出单价 |
| 3. 路由 | 路由列表里「网关模型」列能看到刚挑的模型 |
| 4. 密钥 | 列表里状态「启用」，掩码正常 |
| 4. 模板 | 智能体市场里能看到卡片，且显示版本号 |

## 依赖关系速查

如果某个下拉框是空的，对照这张表往回补：

| 空的地方 | 缺的是 |
|---|---|
| 新增模板时「资源池」为空 | 还没接入资源池 |
| 新增模板时「内容库」为空 | 资源池未测试连接 / 未同步完成 |
| 新增模板时「OVA 模板」为空 | 该内容库里没有 OVF/OVA 模板 |
| 新建模型时「模型网关」为空 | 还没接入模型网关 |
| 新建路由时「可选模型列表」为空 | 还没登记模型，或没先选网关 |
| 颁发密钥时「可调用模型」为空 | 同上，需先选网关 |
| 部署时「vSphere 放置资源池 / 端口组 / 数据存储」为空 | 资源池尚未同步资产，回列表点「立即同步」 |
| 部署时「网关密钥绑定」的已有密钥为空 | 现有密钥都绑了实例；克隆几把，或用「新建密钥」 |
| 部署时即时克隆的「父虚拟机」为空 | 该资源池上没有可用父机；改用「创建新父虚拟机」 |

## 两个最容易埋雷的地方

::: danger 一、网关的「Agent 访问地址」
控制台的「测试连接」只验证**网关地址**（控制面视角）。「Agent 访问地址」填错的话，一切正常到部署完成，直到 agent 第一次调模型才超时。

单机形态下的正确值：

| 字段 | 值 |
|---|---|
| 网关地址 | `http://litellm:4000` |
| Agent 访问地址 | `https://<EXTERNAL_IP>/litellm/` |
:::

::: danger 二、模型单价
不填单价，仪表盘的「本月费用」、计量中心的成本、密钥的消费进度**全都是 0**。等到月底对账才发现，历史数据已经补不回来了。

登记模型时顺手就填掉，成本最低。
:::

## 建议的第一批配置

刚上手不必求全，先用最小集合跑通闭环：

| 对象 | 建议 |
|---|---|
| 资源池 | **1 个** —— 生产 vCenter |
| 模型网关 | **1 个** —— 平台内置的 litellm |
| 模型 | **1 个** —— 一个稳定的内网模型，记得填单价 |
| 路由 | **1 条** —— 策略选「简单洗牌」，名字用能力名如 `CHAT-GENERAL` |
| 虚拟密钥 | **1 把** —— 不设预算上限，先验证连通性 |
| 模板族 | **1 个 + 1 个版本** —— 一种 agent 类型 |
| 智能体 | **1 台** —— 单台部署，DHCP 取址 |

跑通之后再逐步加：

<ol class="ap-steps">
<li><strong>多模型 + 降级链</strong> —— 主模型挂了自动落到备用，见<a href="/console/routes#降级链">网关路由</a>。</li>
<li><strong>按部门发密钥并设预算</strong> —— 见<a href="/console/keys#治理模板">密钥管理</a>。</li>
<li><strong>批量部署 + 静态 IP</strong> —— 见<a href="/console/deploy#三部署模式与网络策略">部署智能体</a>。</li>
<li><strong>配好计量口径</strong> —— 汇率、价格缺失策略、预算告警，见<a href="/observability/metering-settings">计量设置</a>。</li>
<li><strong>NSX 微分段</strong> —— 见<a href="/reference/ports#nsx-微分段建议">端口与网络</a>。</li>
</ol>

## 别忘了这三件事

<ol class="ap-steps">
<li><strong>改掉管理员默认口令</strong>（默认 <code>ChangeMe123!</code>）→ <a href="/install/first-login">首次登录</a></li>
<li><strong>建具名 admin 账号</strong>，别一直用共享的 bootstrap 账号 → <a href="/console/users#账号治理建议">用户与权限</a></li>
<li><strong>看一眼许可剩余天数</strong>，正式许可绑定<strong>首个接入资源池</strong>的 vCenter IP → <a href="/console/settings">平台设置</a></li>
</ol>
