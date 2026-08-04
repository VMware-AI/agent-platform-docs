# 访问智能体

> 面向**智能体使用者**。管理员把 VM 的地址与凭据发给你之后，从这一页开始。

## 你会拿到什么

管理员在控制台的「智能体实例 → 访问信息」里一键复制，发给你的通常是这几行：

```
密钥名称: agent-研发部-01
OS账户:   agentuser
登录密码: ********
SSH 连接: ssh agentuser@192.168.10.31
IP 地址:  192.168.10.31
```

## 三个入口

| 入口 | 地址 | 用途 |
|---|---|---|
| **SSH** | `ssh <OS账户>@<IP>` | 命令行使用 agent，日常主力 |
| **VM 自服务管理台** | `https://<IP>/manage/` | 改密码、查版本、升级 / 回滚 agent |
| **Agent 自带界面** | 依 agent 类型而定 | 部分 agent 提供自己的 CLI 或 Web UI |

## 第一次登录

<ol class="ap-steps">
<li><strong>SSH 连上去</strong> —— <code>ssh agentuser@192.168.10.31</code>，输入管理员给的密码。</li>
<li><strong>立刻改密码</strong> —— 打开 <code>https://&lt;IP&gt;/manage/</code>，用同一套账号密码登录，在页面上改。这会<strong>同时</strong>更新 OS 登录密码和管理台密码，两边保持一致。</li>
<li><strong>确认 agent 在跑</strong> —— 管理台首页显示安装状态、服务状态与当前版本；也可以 <code>systemctl status agent-manager</code>。</li>
<li><strong>开始用</strong> —— 按你所用 agent 的说明启动会话。</li>
</ol>

::: tip 模型凭据不需要你操心
平台在部署时已经把**网关地址**和**虚拟密钥**注入到 VM 里了。你直接用 agent 就行，不需要、也不应该自己去配公网模型的 API Key —— 那样既绕过了治理，也拿不到内网模型。
:::

::: warning 一定要改初始密码
一批 VM 通常共用同一个初始密码。管理台的改密是 OS + Web 同步事务，改一次两边都变，十秒钟的事。
:::

## 你这台机器的边界

| 你能做 | 你不能做 |
|---|---|
| 在 VM 里安装工具、写代码、跑任务 | 修改平台侧的模型 / 密钥 / 路由配置 |
| 改自己的登录密码 | 访问别人的智能体 VM |
| 升级 / 回滚自己 VM 里的 agent 版本 | 提高自己的模型配额或预算上限 |
| 查看自己 VM 的 agent 状态与版本 | 关闭审计与计量 |
| 装管理员放进离线库的 Skill | 从公网随意拉包（通常没有外网出口） |

配额、预算与可用模型由管理员在平台侧统一治理。需要调整就找管理员，别自己想办法绕。

## 这台 VM 的网络长什么样

| 方向 | 通不通 | 用途 |
|---|---|---|
| VM → 控制面 443 | ✅ | agent-manager 注册 + 心跳（**只出不进**） |
| VM → 模型网关 | ✅ | agent 调用模型 |
| VM → 内网包仓库 | ✅ | 技能包、agent 版本包 |
| VM → 公网 | ❌ 通常关闭 | 这是设计使然 |
| VM ↔ 其他智能体 VM | ❌ 通常被微分段拦住 | 隔离 |
| 你的电脑 → VM 22 / 443 | ✅ | SSH 与管理台 |

::: tip 装不上东西？先想想是不是没外网
在这类 VM 上 `pip install` / `npm install` 常常直接超时 —— 因为没有公网出口。需要额外的包，让管理员通过[技能管理](/console/skills)放进内网离线库，再装到你这台机器上。
:::

## 日常自助清单

| 我想…… | 怎么做 |
|---|---|
| 改密码 | [管理台](/agent-vm/webadmin) → 修改密码 |
| 看 agent 是不是活着 | 管理台首页，或 `systemctl status agent-manager` |
| 升级到新版本 | [管理台 → 升级](/agent-vm/upgrade)，或等管理员批量下发 |
| 新版本有问题 | [管理台 → 回滚](/agent-vm/upgrade#回滚)，留空即退回上一版 |
| 看服务日志 | `sudo journalctl -u agent-manager -f` |
| 重启 agent | `sudo systemctl restart agent-manager` |

## 常见问题

| 现象 | 处理 |
|---|---|
| SSH 连不上 | 确认 IP 正确、VM 处于运行中（让管理员在控制台确认）、你的网络能到该网段 |
| 管理台打不开 | 确认用 `https://` 且路径是 `/manage/`（带尾斜杠） |
| 提示证书不受信 | 正常，VM 使用自签证书，点「继续访问」 |
| 管理台一直弹认证框 | 账号是 **OS 账户名**；连续输错会被临时限流 |
| 密码忘了 | 联系管理员：可通过 vCenter Console 重置，或在控制台触发「密码更新」 |
| agent 调模型报 401 / 429 | 平台侧密钥问题（禁用 / 过期 / 超预算 / 限流），找管理员 |
| agent 调模型超时 | 多半是网关地址在 VM 侧不可达，把现象反馈给管理员 |
| agent 服务没在跑 | 管理台看状态；或 `sudo systemctl restart agent-manager` |
| 想装个新工具但没网 | 找管理员走[技能管理](/console/skills)的离线库 |

## 下一步

- 改密码、查状态、看接口 → [VM 自服务管理台](/agent-vm/webadmin)
- 升级到新版本 agent → [升级与回滚](/agent-vm/upgrade)
