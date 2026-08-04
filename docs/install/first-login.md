# 首次登录

## 打开控制台

```
https://<EXTERNAL_IP>/
```

访问 `http://<EXTERNAL_IP>/` 会被 301 跳转到 HTTPS。

::: warning 浏览器会告警「不安全」
默认使用 `install.sh` 生成的自签名证书。点击「高级 → 继续访问」即可。要永久消除告警，换成企业 CA 或 Let's Encrypt 证书，见 [网络与证书](/install/network-tls)。
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

::: danger 立即修改默认口令
`.env.example` 预置的默认值是 `ChangeMe123!`。登录后第一件事就是改掉它 —— 右上角用户菜单 → 个人资料 → 修改密码。
:::

如果后端判定该账号需要强制改密，登录后会直接弹出「修改密码」对话框，未完成前无法进行其他操作。新密码要求：

- 长度 ≥ 12
- 含大写字母、小写字母、数字

## 跨机访问的 CORS 前置条件

如果浏览器和平台主机**不是同一台机器**，后端必须认得你输入的那个 URL，否则每个 GraphQL 请求都会被 CORS 拒绝。

`install.sh` 已经自动把 `https://${EXTERNAL_IP}` 写进 `ALLOWED_ORIGINS`。只有在你**换了访问地址**（比如通过 DNS 名或反向代理访问）时才需要手工追加：

```bash
# .env
ALLOWED_ORIGINS=https://192.168.1.42,https://agent.corp.example.com
```

改完只需重启后端：

```bash
docker compose -p agent-platform restart backend
```

## 登录后你会看到什么

首页是**总览仪表盘**，此时大部分卡片是空的 —— 因为还没有接入任何资源池、网关与智能体。左侧导航分四组：

| 导航组 | 页面 |
|---|---|
| 智能体中心 | 智能体实例 · 智能体市场 · 技能管理 |
| 模型调度台 | 模型管理 · 密钥管理 · 网关路由 |
| 可观测性 | 计量中心 · 实时监控 · 请求日志 · 审计日志 |
| 系统配置 | 资源池接入 · 模型网关接入 · 用户与权限 · 平台设置 |

::: tip 页面按角色显示
非 `admin` 角色看不到系统配置类页面；`read_only` 观测岗只能进可观测性四页。详见 [角色与权限矩阵](/reference/roles)。
:::

## 试用许可

平台默认提供 **90 天试用**。左侧「系统配置 → 平台设置 → 许可管理」可以看到剩余天数。正式许可与**首个接入的资源池的 vCenter IP** 绑定，凭该 IP 向厂商申请。

试用到期后管理类操作会被锁定，请提前申请。→ [平台设置](/console/settings)

## 下一步

- 校验安装是否真的健康 → [健康检查](/install/verify)
- 开始接入底座 → [初始化四步走](/console/bootstrap)
