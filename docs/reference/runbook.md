# 日常运维手册

按「我要做什么」组织的操作手册。每条都是完整流程，照着走即可，不用先去理解概念。

## 交付类

### 给一个新人开一台智能体

<ol class="ap-steps">
<li>智能体中心 → <strong>智能体市场</strong>，在合适的模板卡片上点「部署智能体」。</li>
<li>基础运行环境：选版本、vSphere 放置资源池、目标端口组、目标数据存储。</li>
<li>全局安全与认证：设 VM 登录密码。</li>
<li>部署模式选「单台部署」，网络用 DHCP 或分配一个未占用的静态 IP。</li>
<li>实例清单：填主机名，密钥绑定选「新建密钥」。</li>
<li>点部署，等 5–10 分钟到「运行中」。</li>
<li><a href="/console/agents">智能体实例</a> → 该实例 → <strong>访问信息</strong> → 一键复制全部凭据。</li>
<li>把凭据 + <code>https://&lt;VM_IP&gt;/manage/</code> 发给本人，要求<strong>首次登录立即改密</strong>。</li>
</ol>

### 给一个部门批量开 10 台

<ol class="ap-steps">
<li>先在<a href="/console/keys">密钥管理</a>用「克隆」造够 10 把未绑定的密钥，打上部门标签，各设消费上限。</li>
<li>目标网段先扫一遍确认 IP 空闲：<code>nmap -sn 192.168.10.0/24</code>。</li>
<li>市场 → 部署智能体 → 克隆模式选<strong>即时克隆</strong>（秒级）。</li>
<li>部署模式选「批量部署」，填名称前缀、数量 10、起始 IP，点「生成清单」。</li>
<li><strong>逐行核对 IP</strong>，给每台选一把密钥。</li>
<li>部署。各台独立推进，部分失败不影响其余。</li>
<li>失败的删掉重试；成功的逐台复制访问信息发人。</li>
</ol>

### 回收一台机器（员工离职）

<ol class="ap-steps">
<li><a href="/console/keys">密钥管理</a> → <strong>禁用</strong>该实例绑定的密钥（不要删，保留账单与审计关联）。</li>
<li><a href="/console/users">用户与权限</a> → <strong>禁用</strong>该用户账号（同样不要删）。</li>
<li>确认无需保留数据后，<a href="/console/agents">智能体实例</a> → <strong>删除</strong>，实例转「已回收」。</li>
<li>确认无需追溯后（通常一个季度），再「彻底删除」并删除账号与密钥。</li>
</ol>

::: warning 顺序别反
先删实例再禁密钥的话，中间那段时间密钥还是活的。先禁密钥是唯一正确的开始。
:::

## 变更类

### 给某台机器加内存 / 加盘

<ol class="ap-steps">
<li><a href="/console/agents">智能体实例</a> → 该实例 → <strong>配置</strong>。</li>
<li>虚拟机资源配置里改数值。<strong>运行中只能往大改</strong>；要缩 CPU / 内存先停止实例（磁盘任何时候都只能扩）。</li>
<li>点「保存配置」，在<strong>确认配置变更</strong>对话框里核对「变更前 / 变更后」。</li>
<li>确认后在 vCenter 上同步执行。</li>
</ol>

### 换一个模型 / 上新模型

<ol class="ap-steps">
<li><a href="/console/models">模型管理</a> → 新建模型：填名称、选网关、加 spec（供应商、上游原名、API Base、API Key）、<strong>填单价</strong>。</li>
<li>测试连接 → 提交 → 点「检测健康」确认变「健康」。</li>
<li><a href="/console/routes">网关路由</a> → 编辑目标路由 → 把新模型挑进「已选定的模型」。</li>
<li>点「同步路由」把配置推到网关。</li>
<li>到<a href="/observability/request-log">请求日志</a>确认真有流量落到新模型上。</li>
</ol>

::: tip 平滑换模型的技巧
不要改路由名。把新模型加进同一条路由、观察一段时间没问题后，再把旧模型移出去 —— 全程对 agent 无感。
:::

### 升级一批 agent 到新版本

<ol class="ap-steps">
<li>先确认包在仓库里：随便找一台 VM 的<a href="/agent-vm/webadmin">管理台</a>看「服务端可拉取版本」。</li>
<li>挑一台非关键实例，<a href="/console/agents">智能体实例</a> → 版本更新 → 填版本号 → 下发。</li>
<li>等一次心跳，去那台 VM 的管理台确认版本与服务状态。</li>
<li>观察半天到一天，看<a href="/observability/request-log">请求日志</a>有没有新增错误。</li>
<li>没问题后分批推，一次 5–10 台。</li>
<li>确认旧版本还在各机器的「本地已装版本」里，保留回滚路径。</li>
</ol>

### 换平台证书

<ol class="ap-steps">
<li>把证书和私钥放到主机上（私钥<strong>不能带密码短语</strong>）。</li>
<li><code>.env</code> 里把 <code>SSL_CERT_PATH</code> / <code>SSL_KEY_PATH</code> 指过去。</li>
<li>访问地址若同时变了（IP → 域名），同步改 <code>EXTERNAL_IP</code> 与 <code>ALLOWED_ORIGINS</code>。</li>
<li><code>./install.sh up</code>。</li>
<li><code>./verify.sh</code>，然后浏览器验证证书生效。</li>
</ol>

## 排查类

### 有人说「我的 agent 报错了」

<ol class="ap-steps">
<li>问清楚<strong>时间点</strong>和<strong>实例名</strong>。</li>
<li><a href="/observability/request-log">请求日志</a>：时间范围锁到事发前后 1 小时，状态码筛 4xx / 5xx，智能体列搜实例名。</li>
<li>看状态码：401 查密钥、403 查作用域、404 查路由名、429 查限流、5xx 查上游模型健康。</li>
<li>对应到<a href="/console/keys">密钥管理</a>或<a href="/console/models">模型管理</a>处理。</li>
</ol>

### 平台整体变慢

<ol class="ap-steps">
<li><a href="/observability/monitor">实时监控</a>：看 P95 延迟曲线的拐点时间。</li>
<li>看「上游健康」是否有网关不可达或端点异常。</li>
<li>请求日志按响应时间排序，看最慢那批的共同点（同一模型？同一时段？）。</li>
<li>是上游慢就去模型管理看健康状态；是平台慢就 <code>./verify.sh</code> + 看容器资源。</li>
</ol>

### 一台机器状态变「异常」

<ol class="ap-steps">
<li>vCenter 里确认 VM 是否还在运行。</li>
<li>SSH 进去：<code>systemctl status agent-manager</code>。</li>
<li><code>sudo journalctl -u agent-manager -n 100 --no-pager</code> 找心跳失败原因。</li>
<li>验网络：<code>curl -sk -o /dev/null -w '%{http_code}\n' https://&lt;控制面IP&gt;/</code>。</li>
<li>服务挂了就 <code>sudo systemctl restart agent-manager</code>；网络不通就查防火墙 / IP 配置。</li>
</ol>

## 对账类

### 月度成本对账

<ol class="ap-steps">
<li><a href="/observability/metering">计量中心</a> → 时间范围「本月」。</li>
<li>数据源切「<strong>网关记录（litellm）</strong>」—— 这是计费源头。</li>
<li>维度选「按部门」，导出 CSV。</li>
<li>与财务的分摊表比对；有争议时再切「按密钥」导一份，密钥能精确追到人。</li>
<li>关注「未归属」占比 —— 偏高说明有密钥没绑实例，下个月要修。</li>
</ol>

### 季度合规报告

<ol class="ap-steps">
<li><a href="/observability/audit-log">审计日志</a> → 时间范围选整个季度。</li>
<li>分批导出（单次上限 5000 条，按月切分）。</li>
<li>按需筛出：密钥签发 / 吊销、用户创建 / 删除、角色变更、资源池接入变更。</li>
<li>归档到企业日志平台。</li>
</ol>

## 维护类

### 平台升级

见[升级与卸载](/install/upgrade#保留数据升级到新版本)，核心是四步：**备份 → down → 换目录并放回密钥 → install**。

### 备份

见[备份清单](/install/upgrade#备份清单)。最关键的是 `.secrets_encryption_key` 与 `.env`。

### 恢复演练

每季度一次：测试环境新装一套 → 放回两份文件 + 恢复数据库 → 确认 vCenter 凭据仍能「测试连接」通过。**能通过才算备份有效。**

## 巡检节奏

| 频率 | 做什么 | 花多久 |
|---|---|---|
| 每天 | [总览仪表盘](/console/overview)：平台健康度是否「正常」、「异常与待处理事项」是否为空 | 1 分钟 |
| 每周 | `./verify.sh`；[计量中心](/observability/metering)看本周花费是否异常 | 10 分钟 |
| 每月 | 导出审计日志归档；检查磁盘余量；确认备份文件仍在；检查长期未登录账号 | 30 分钟 |
| 每季 | 恢复演练；证书与许可到期检查；[安全基线](/reference/security)过一遍 | 半天 |
| 变更后 | 任何 `.env` 改动或升级之后重跑 `./verify.sh` | 1 分钟 |

## 需要提前准备的信息

出问题找支持时，把这些一次性备好能省一轮来回：

- 「关于」对话框里的**平台版本号**
- 问题的**具体时间点**
- 涉及的**智能体名称 / 请求 ID / 密钥名称**
- `./verify.sh` 的输出
- 相关容器的日志片段

打包命令见[故障排查 → 收集诊断信息](/install/troubleshooting#收集诊断信息)。
