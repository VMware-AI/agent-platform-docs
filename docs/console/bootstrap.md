# 初始化四步走

新装的平台是空的。四步之后，你就能部署第一个智能体。**顺序不能颠倒** —— 后一步的下拉框依赖前一步的数据。

<div class="ap-rule-list">

<div class="ap-rule-row">
<div class="num">01</div>
<div>
<strong>接入资源池（vCenter）</strong>
<span>系统配置 → 资源池接入。填 VC 地址、账号、口令 → 测试连接 → 选内容库 → 保存 → 等同步完成。<a href="/console/resource-pools">详解 →</a></span>
</div>
</div>

<div class="ap-rule-row">
<div class="num">02</div>
<div>
<strong>接入模型网关（LiteLLM）</strong>
<span>系统配置 → 模型网关接入。填网关地址、Master Key、<strong>Agent 访问地址</strong> → 测试连接 → 保存。<a href="/console/gateway-connections">详解 →</a></span>
</div>
</div>

<div class="ap-rule-row">
<div class="num">03</div>
<div>
<strong>登记模型 + 建路由</strong>
<span>模型调度台 → 模型管理新建模型（供应商、上游原名、API Base、API Key）→ 网关路由新建路由，选策略、把模型挑进已选定列表。<a href="/console/models">模型 →</a> <a href="/console/routes">路由 →</a></span>
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
| 部署时「网关密钥绑定」为空 | 还没颁发虚拟密钥 |

## 建议的第一批配置

刚上手时不必求全，先用最小集合跑通闭环：

- **1 个资源池** —— 生产 vCenter
- **1 个模型网关** —— 平台内置的 litellm
- **1 个模型 + 1 条路由** —— 一个稳定的内网模型，策略选「简单洗牌」
- **1 个虚拟密钥** —— 不设预算上限，先验证连通性
- **1 个模板族 + 1 个版本** —— 一种 agent 类型
- **1 台智能体** —— 单台部署，DHCP 取址

跑通之后再考虑：多模型 + 降级链、按部门发密钥并设预算、批量静态 IP 部署、NSX 微分段。

## 别忘了这两件事

1. **改掉管理员默认口令**（如果安装时没改）→ [首次登录](/install/first-login)
2. **看一眼许可剩余天数** —— 平台默认 90 天试用，正式许可绑定首个资源池的 vCenter IP → [平台设置](/console/settings)
