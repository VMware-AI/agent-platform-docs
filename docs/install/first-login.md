# 首次登录

## 打开控制台

```
https://<EXTERNAL_IP>/
```

访问 `http://<EXTERNAL_IP>/` 会被 301 跳转到 HTTPS。

::: warning banner 里可能显示 `:80`
v0.0.1 的安装横幅会打印 `https://<IP>:80/`，这是显示问题。实际映射是硬编码的：**443 提供 HTTPS，80 只做跳转**。直接访问 `https://<EXTERNAL_IP>/`（不带端口）即可。
:::

::: warning 浏览器会告警「不安全」
默认使用 `install.sh` 生成的自签名证书。点击「高级 → 继续访问」。要永久消除告警，换成企业 CA 或 Let's Encrypt 证书，见[网络与证书](/install/network-tls)。
:::

## 初始凭据

| 字段 | 值 |
|---|---|
| 用户名 | `admin@platform.local` |
| 密码 | `.env` 里的 `ADMIN_BOOTSTRAP_PASSWORD` |

查看当前密码：

```bash
grep ^ADMIN_BOOTSTRAP_PASSWORD .env
```

::: danger 默认值是 `ChangeMe123!`
`.env.example` 预置了这个值。因为它非空，`install.sh` **不会**替你重新生成 —— 也就是说，如果安装时没改，你的平台现在正挂着一个众所周知的弱口令。

**登录后第一件事就是改掉它**：右上角用户菜单 → 个人资料 → 修改密码。
:::

如果后端判定该账号需要强制改密，登录后会直接弹出「修改密码」对话框，提示「为了您的账户安全，请设置一个新的登录密码」，未完成前无法进行其他操作。

**新密码要求**：

| 规则 | 说明 |
|---|---|
| 长度 ≥ 12 | 至少 12 位 |
| 含大写字母 | A–Z |
| 含小写字母 | a–z |
| 含数字 | 0–9 |

## 跨机访问的 CORS 前置条件

如果浏览器和平台主机**不是同一台机器**，后端必须认得你输入的那个 URL，否则每个 GraphQL 请求都会被 CORS 拒绝，表现为**控制台白屏或所有数据加载失败**。

`install.sh` 已经自动把 `https://${EXTERNAL_IP}` 写进 `ALLOWED_ORIGINS`。只有在你**换了访问地址**时才需要手工追加：

```bash
# .env —— 逗号分隔，多个来源都写上
ALLOWED_ORIGINS=https://192.168.1.42,https://agent.corp.example.com
```

改完只需重启后端：

```bash
docker compose -p agent-platform restart backend
```

::: tip 快速验证 CORS 是否放行
```bash
curl -fsSk -X POST "https://<你用的地址>/query" \
  -H 'Content-Type: application/json' \
  -H "Origin: https://<你用的地址>" \
  -d '{"query":"{ __typename }"}'
```
返回 `{"data":{"__typename":"Query"}}` 就是通的。
:::

## 登录后你会看到什么

首页是**总览仪表盘**，此时大部分卡片是 0 —— 因为还没接入任何资源池、网关与智能体。

左侧导航分四组：

| 导航组 | 页面 |
|---|---|
| **智能体中心** | 智能体实例 · 智能体市场 · 技能管理 |
| **模型调度台** | 模型管理 · 密钥管理 · 网关路由 |
| **可观测性** | 计量中心 · 实时监控 · 请求日志 · 审计日志 |
| **系统配置** | 资源池接入 · 模型网关接入 · 用户与权限 · 平台设置 |

顶栏右侧：搜索、主题切换（浅色 / 深色）、语言切换、用户菜单（个人资料 / 关于 / 退出）。

::: tip 页面按角色显示
非 `admin` 角色看不到系统配置类页面；`read_only` 观测岗只能进可观测性四页。详见[角色与权限矩阵](/reference/roles)。
:::

## 装完之后立刻要做的四件事

<ol class="ap-steps">
<li><strong>改掉 bootstrap 管理员密码。</strong> 见上文。</li>
<li><strong>给自己建一个具名 admin 账号</strong>，日常用它操作 —— 这样<a href="/observability/audit-log">审计日志</a>里才看得出是谁干的，而不是永远显示同一个共享账号。见<a href="/console/users">用户与权限</a>。</li>
<li><strong>看一眼许可剩余天数。</strong> 系统配置 → 平台设置 → 许可管理。平台默认 90 天试用，正式许可绑定<strong>首个接入资源池</strong>的 vCenter IP。见<a href="/console/settings">平台设置</a>。</li>
<li><strong>改 Grafana 默认口令。</strong> 内置 Grafana 默认 <code>admin/admin</code> 且暴露在 3000 端口。在 <code>.env</code> 设 <code>GRAFANA_ADMIN_USER</code> / <code>GRAFANA_ADMIN_PASSWORD</code> 后 <code>./install.sh up</code>。</li>
</ol>

## 试用许可

平台默认提供 **90 天试用**。左侧「系统配置 → 平台设置 → 许可管理」可以看到剩余天数与到期时间。

::: warning 试用到期会锁定管理操作
到期后已部署的智能体不会被停掉，但控制台的管理类操作会被拦住。正式许可绑定首个接入资源池的 vCenter IP，凭该 IP 向厂商申请 —— **别等最后一周才开始走流程**。
:::

## 下一步

- 校验安装是否真的健康 → [健康检查](/install/verify)
- 开始接入底座 → [初始化四步走](/console/bootstrap)
