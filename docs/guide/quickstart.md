# 快速开始

从一台空白 Linux 主机到「第一个智能体跑起来」，大约 60–90 分钟 —— 其中安装本身只需 1–2 分钟，剩下的时间花在接入 vCenter、配模型和等 VM 克隆上。

## 开始之前

::: tip 需要准备的四样东西
| | 说明 |
|---|---|
| **一台 Linux 主机** | 已装 Docker + compose 插件，`/var` ≥ 5 GB 空闲，有固定 IP，能访问 `quay.io`（默认安装）。详见[环境要求](/install/requirements) |
| **一套 vCenter** | 地址 + 账号，账号需要克隆 VM、改 vApp 属性、开关机的权限 |
| **一个可用的上游模型** | API Base + API Key（内网私有模型服务也行） |
| **v0.0.1 的安装 tarball** | [`agent-platform-dc-standalone-0.0.1.tar.gz`](https://github.com/VMware-AI/agent-platform-deployment/releases/download/v0.0.1/agent-platform-dc-standalone-0.0.1.tar.gz)（如果完全离网，再加一个自造镜像包，见下文） |
:::

## 一、装平台（约 3 分钟）

::: tip 下载安装包
**v0.0.1**：[`agent-platform-dc-standalone-0.0.1.tar.gz`](https://github.com/VMware-AI/agent-platform-deployment/releases/download/v0.0.1/agent-platform-dc-standalone-0.0.1.tar.gz) — 自包含 tarball，约 1 MB，附 `SHA256SUMS`。

其他形态（`dc-distribution` / `k8s-standalone` / `k8s-ha`）见 [release 页](https://github.com/VMware-AI/agent-platform-deployment/releases/tag/v0.0.1)。
:::

```bash
mkdir -p /opt/agent-platform && cd /opt/agent-platform

tar -xzf /path/to/agent-platform-dc-standalone-0.0.1.tar.gz

cd agent-platform-dc-standalone-0.0.1
cp .env.example .env
```

编辑 `.env`，**必改两项**：

```bash
EXTERNAL_IP=192.168.1.42            # 浏览器访问用的真实服务器 IP
ADMIN_BOOTSTRAP_PASSWORD=<强口令>    # 默认值是 ChangeMe123!，务必改掉
```

安装：

```bash
./install.sh
```

脚本自动生成所有密钥、自签 TLS 证书、从 `quay.io/vmware-ai/<image>` 拉取镜像、拉起 8 个容器，最后跑一次 smoke test。**全程 60–120 秒。**

> 目标机无法访问 `quay.io`？在能上网的机器上跑 `make package-images-amd64` 造一个镜像包，作为同级目录放好，`install.sh` 会自动 `docker load` 而不联网拉。详见[离线安装（单机）](/install/dc-standalone#6-离线安装可选气隙环境)。

→ 细节见[安装单机形态（dc-standalone）](/install/dc-standalone)

## 二、首次登录（约 2 分钟）

安装结束的 banner 会打印访问地址与初始凭据：

- 地址：`https://<EXTERNAL_IP>/`
- 用户名：`admin@platform.local`
- 密码：`.env` 里的 `ADMIN_BOOTSTRAP_PASSWORD`

```bash
grep ^ADMIN_BOOTSTRAP_PASSWORD .env
```

::: warning banner 里的端口可能显示成 `:80`
这是 v0.0.1 的显示问题。实际 HTTPS 在 **443**，直接访问 `https://<EXTERNAL_IP>/` 即可（不带端口）。
:::

自签名证书会触发浏览器告警，点「高级 → 继续访问」。

→ 细节见[首次登录](/install/first-login)

## 三、接上底座（约 20 分钟）

::: danger 顺序不能颠倒
路由依赖模型，模型依赖网关；部署智能体依赖资源池 + 内容库里的 OVA。缺哪一步，下一步的下拉框就是空的。
:::

<ol class="ap-steps">
<li>
<strong>接入资源池。</strong> 系统配置 → 资源池接入 → 接入资源池。填 vCenter 地址 / 账号 / 口令 → 点 <em>测试连接</em> → 成功后选内容库 → 保存 → 等同步状态变「已同步」。
<a href="/console/resource-pools">详解 →</a>
</li>
<li>
<strong>接入模型网关。</strong> 系统配置 → 模型网关接入 → 接入模型网关。<br>
· 网关地址：<code>http://litellm:4000</code>（平台内置的那个）<br>
· <strong>Agent 访问地址</strong>：<code>https://&lt;EXTERNAL_IP&gt;/litellm/</code><br>
· Master Key：从安装 banner 里抄，或 <code>grep ^LITELLM_MASTER_KEY .env</code><br>
测试连接通过后保存。<a href="/console/gateway-connections">详解 →</a>
</li>
<li>
<strong>登记模型。</strong> 模型调度台 → 模型管理 → 新建模型。填名称 → 选网关 → 加一个 spec（供应商分类、上游模型原名、API Base、API Key）→ <strong>填上输入/输出单价</strong> → 测试连接 → 提交。
<a href="/console/models">详解 →</a>
</li>
<li>
<strong>建一条路由。</strong> 模型调度台 → 网关路由 → 新建路由。名称用大写（如 <code>CHAT-GENERAL</code>）→ 选网关 → 策略选「简单洗牌」→ 把刚才的模型挑进「已选定的模型」→ 创建。
<a href="/console/routes">详解 →</a>
</li>
</ol>

::: tip 第 2 步的两个地址是全流程最容易错的地方
控制台的「测试连接」只验证**网关地址**。Agent 访问地址填错的话，一切正常到部署完成，直到 agent 第一次调模型才超时 —— 那时候你已经忘了是这里的问题。
:::

## 四、部署第一个智能体（约 15 分钟）

<ol class="ap-steps">
<li><strong>登记模板。</strong> 智能体中心 → 智能体市场。卡片为空时点「新增智能体模版」：选资源池 → 内容库 → OVA 模板，填名称、类型、初始版本号。</li>
<li><strong>发起部署。</strong> 在目标卡片上点「部署智能体」。</li>
<li><strong>基础运行环境</strong> —— 选版本、vSphere 放置资源池、目标端口组、目标数据存储；克隆模式先选「全量克隆」。</li>
<li><strong>全局安全与认证</strong> —— 设 VM 登录密码（两次确认），可选填 SSH 公钥。</li>
<li><strong>部署模式与网络</strong> —— 先来一台：选「单台部署」，网络用 DHCP 最省事。</li>
<li><strong>实例配置清单</strong> —— 填主机名，密钥绑定选「新建密钥」。</li>
<li>点 <strong>部署</strong>。</li>
</ol>

实例会先进入「部署中」，克隆 + 开机 + 注册完成后转「运行中」，通常 **5–10 分钟**。

→ 细节见[部署智能体](/console/deploy)

::: tip 第一次先用 DHCP
静态 IP 冲突是部署卡住的头号原因。第一台先用 DHCP 跑通全链路，确认没问题之后再上静态 IP 和批量部署。
:::

## 五、交付给使用者（约 2 分钟）

在**智能体实例**列表里点该实例的「访问信息」，点「一键复制全部凭据」，把这几项发给使用者：

- IP 地址与 SSH 连接命令
- OS 账户与登录密码
- VM 自服务管理台地址：`https://<VM_IP>/manage/`

并提醒对方：**首次登录后立即改密码**（在管理台上改，OS 和管理台会同步更新）。

→ 使用者侧看[访问智能体](/agent-vm/access)

## 六、验证闭环

让使用者在 VM 里跑一次 agent 调用，然后回控制台确认数据真的通了：

| 看哪 | 期望 |
|---|---|
| [实时监控](/observability/monitor) | 请求量有数字，上游健康显示「健康」 |
| [请求日志](/observability/request-log) | 有对应的调用记录，状态 200 |
| [计量中心](/observability/metering) | 按智能体维度能看到这台机器的 Token 与花费 |
| [总览仪表盘](/console/overview) | 活跃智能体 ≥ 1，本月费用不为 0 |

::: tip 计量里花费是 0？
模型没配单价。回[模型管理](/console/models)补上输入 / 输出单价 —— 这是最容易漏的一步。
:::

## 首日常见问题

| 现象 | 处理 |
|---|---|
| 浏览器打不开控制台 | 确认 `EXTERNAL_IP` 是真实网卡 IP，防火墙放行 443 |
| 登录后请求全红 | CORS：`.env` 的 `ALLOWED_ORIGINS` 要含你用的 URL，改完 `docker compose -p agent-platform restart backend` |
| 部署对话框里下拉为空 | 资源池尚未同步，回资源池列表点「立即同步」 |
| 智能体一直停在「部署中」 | ① VM 是否拿到 IP ② VM 能否出站访问控制面 443 |
| 模型探测显示「熔断」 | 上游不可达或 API Key 失效，重新「测试连接」，修好后手工「解除熔断」 |
| agent 调模型超时 | 网关的「Agent 访问地址」填错了 |
| 计量中心没数据 | 确认 `otel-collector` 容器在跑 |

完整清单见[故障排查](/install/troubleshooting)与[常见问题](/reference/faq)。

## 跑通之后

| 下一步 | 去哪 |
|---|---|
| 批量部署一批机器 | [部署智能体](/console/deploy#三部署模式与网络策略) |
| 按部门发密钥、设预算 | [密钥管理](/console/keys#治理模板) |
| 建多模型 + 降级链 | [网关路由](/console/routes#降级链) |
| 配好计量口径 | [计量设置](/observability/metering-settings) |
| 建具名管理员账号 | [用户与权限](/console/users#账号治理建议) |
| 规划防火墙与微分段 | [端口与网络](/reference/ports) |
| 把手册带进内网 | [离线部署本手册](/reference/offline-docs) |
