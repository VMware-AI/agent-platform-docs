# VM 自服务管理台

每台智能体 VM 内置一个极简的中文 Web 管理台，地址：

```
https://<VM_IP>/manage/
```

用**你的 OS 账户和密码**登录（HTTP Basic 认证）。这是 VM 的**唯一对外管理接口** —— 由 nginx 终结 TLS 并做认证，后端进程只监听回环。

## 能做什么

| 功能 | 说明 |
|---|---|
| **修改密码** | 自服务改密，同时更新 OS 登录密码与管理台密码 |
| **查看状态** | agent 安装状态、systemd 服务状态 |
| **查看版本** | 当前运行版本 |
| **列出版本** | 当前版本 + 本地已装版本 + 服务端可拉取版本 |
| **升级** | 拉取指定版本包并安装 |
| **回滚** | 切回某个已安装版本 |

## 修改密码

这是使用者最常用的功能。管理台的改密是**事务性**的：

<ol class="ap-steps">
<li>先重新校验当前密码。</li>
<li>先改管理台（nginx htpasswd）—— 这一步可回滚。</li>
<li>再改操作系统（<code>chpasswd</code>）。</li>
<li>任一步失败都会执行补偿回滚，保证两边始终同步。</li>
</ol>

::: tip 为什么两边一起改
如果只改了 OS 密码，你下次就进不了管理台；只改管理台则 SSH 用不了。平台把两者绑成一次事务，就是为了避免这种半截状态。
:::

## 安全边界

| 设计 | 说明 |
|---|---|
| 唯一入口 | 所有入站请求都经 nginx `/manage/` 反代（TLS + Basic Auth）；后端进程只监听回环 |
| 认证 | 除首页外所有端点都需要 HTTP Basic 认证 |
| 不存明文 | 本地状态文件 `/var/lib/agent-manager/state.json`（权限 0600）只存密码**指纹**与 VM token |
| 审计 | 改密码、升级、回滚、认证失败都会发结构化审计事件到 journald，**只存指纹，绝不存明文** |

查看 VM 内的审计事件：

```bash
sudo journalctl -u agent-manager-webadmin | grep AUDIT
```

## 两个 systemd 单元

VM 内跑两个服务，共用同一个 Python 包：

| 单元 | 方向 | 职责 |
|---|---|---|
| `agent-manager` | **出站** | 向控制面 enroll 注册、周期心跳（含真实已装版本）、同步知识包。仅 443 出站，带断路器与指数退避 |
| `agent-manager-webadmin` | **入站** | 本管理台的 REST API + Web UI |

常用命令：

```bash
systemctl status agent-manager
systemctl status agent-manager-webadmin

sudo journalctl -u agent-manager -f
sudo systemctl restart agent-manager
```

## API 接口

管理台的全部端点有 **OpenAPI 3.1** 规范，在线获取：

```
https://<VM_IP>/manage/api/openapi.json
```

主要端点：

| 端点 | 作用 |
|---|---|
| `POST /api/credentials` | 自服务改密码 |
| `GET /api/status` | agent 安装 / 服务状态 |
| `GET /api/version` | 当前版本 |
| `GET /api/versions` | 当前 + 本地已装 + 服务端可拉取版本 |
| `POST /api/upgrade` | 升级到指定版本 |
| `POST /api/rollback` | 回滚到已安装版本 |
| `GET /api/openapi.json` | 本接口规范 |

::: tip 想在工具里看接口文档
把 `https://<VM_IP>/manage/api/openapi.json` 导入任何 OpenAPI 工具即可（如 editor.swagger.io 的 *File ▸ Import file*，或 VS Code 的 OpenAPI 扩展）。
:::

## 常见问题

| 现象 | 处理 |
|---|---|
| 打不开 `/manage/` | 确认用 `https://`、路径带尾斜杠；确认 VM 在运行；确认 nginx 服务正常 |
| 一直弹认证框 | 账号是 **OS 账户名**，密码是当前 OS 密码；连续失败会记审计事件 |
| 改密码失败 | 新密码需满足复杂度要求；失败时会自动回滚，两边密码保持原样 |
| 页面显示 agent 服务未运行 | `sudo systemctl restart agent-manager`，仍失败看 `journalctl -u agent-manager` |
| 心跳一直失败 | VM 能否出站访问控制面 443；断路器退避期间会自动重试，不会把进程搞挂 |
