# VM 自服务管理台

每台智能体 VM 内置一个极简的中文 Web 管理台：

```
https://<VM_IP>/manage/
```

用**你的 OS 账户和密码**登录（HTTP Basic 认证）。这是 VM 的**唯一对外管理接口**。

## 能做什么

| 功能 | 说明 |
|---|---|
| **修改密码** | 自服务改密，同时更新 OS 登录密码与管理台密码 |
| **查看状态** | agent 是否已安装、systemd 服务是否在跑 |
| **查看版本** | 当前运行版本 |
| **列出版本** | 当前 + 本地已装 + 服务端可拉取版本 |
| **升级** | 拉取指定版本包并安装 |
| **回滚** | 切回某个已安装版本 |

界面是原生 JS 写的极简页面，**无构建产物、无外部依赖**，气隙环境下也能正常打开。

## 访问模型

```
浏览器 ──HTTPS──▶ nginx (VM :443, 路径 /manage/)
                    │  ① 终结 TLS
                    │  ② htpasswd 校验 Basic 认证
                    ▼
              agent-manager-webadmin (127.0.0.1:8090)
                    ③ 再校验一次透传过来的 Authorization 头（纵深防御）
```

| 设计 | 说明 |
|---|---|
| 只绑回环 | 服务进程监听 `127.0.0.1:8090`，不直接对外 |
| 唯一入口 | 所有入站请求都经 nginx `/manage/` 反代 |
| 双重认证 | nginx 先查 htpasswd，应用再验一次 —— 即使有人直连回环也仍需认证 |
| 登录身份 | **OS 账户**（默认是 OS 用户 `agent`），其密码由 `/api/credentials` 与 OS 账户保持同步 |

## 修改密码

这是使用者最常用的功能，也是设计上最讲究的一个 —— 改密是**事务性**的：

<ol class="ap-steps">
<li>先重新校验当前密码。</li>
<li>先改管理台（nginx htpasswd）—— 这一步可回滚。</li>
<li>再改操作系统（<code>chpasswd</code>）。</li>
<li>任一步失败都执行补偿回滚，保证两边始终同步。</li>
</ol>

::: tip 为什么两边一起改
只改 OS 密码，下次就进不了管理台；只改管理台，SSH 又用不了。平台把两者绑成一次事务，就是为了杜绝这种半截状态。
:::

**密码策略**由平台侧下发（长度下限、字符要求、最大字节数），不满足会明确告诉你差在哪。新密码不能与当前密码相同。

## 安全边界

| 设计 | 说明 |
|---|---|
| 不存明文 | 本地状态文件 `/var/lib/agent-manager/state.json`（权限 `0600`）只存密码**指纹**与 VM token |
| 审计 | 改密码、升级、回滚、认证失败都会发结构化审计事件（`AUDIT {json}`）到 journald，**只存指纹，绝不存明文** |
| 限流 | 认证连续失败会被节流（返回 `429`） |
| 错误信息 | 500 时前端只看到一句笼统的中文提示，完整堆栈只进 journal —— 不向外泄露内部细节 |

查看 VM 内的审计事件：

```bash
sudo journalctl -u agent-manager-webadmin | grep AUDIT
```

## 两个 systemd 单元

VM 内跑两个加固的服务，共用同一个 Python 包：

| 单元 | 方向 | 职责 |
|---|---|---|
| `agent-manager` | **出站** | 向控制面 enroll 注册、周期心跳（上报状态 + 真实已装版本）、同步知识包。仅 443 出站，带断路器与指数退避 |
| `agent-manager-webadmin` | **入站** | 本管理台的 REST API + Web UI，监听回环 |

常用命令：

```bash
systemctl status agent-manager
systemctl status agent-manager-webadmin

sudo journalctl -u agent-manager -f
sudo systemctl restart agent-manager
```

::: tip 心跳失败不会把进程搞挂
`agent-manager` 自带韧性：瞬时失败或网络抖动按断路器指数退避重试。看到日志里有几条心跳失败不必紧张，持续失败才需要查网络。
:::

## API 接口

全部端点有 **OpenAPI 3.1** 规范，在线获取：

```
https://<VM_IP>/manage/api/openapi.json
```

### 统一响应信封

**每个** JSON 响应（无论成功失败）都是同一个结构：

```json
{ "ok": true,  "data": { ... }, "error": null }
{ "ok": false, "data": null,    "error": "当前密码不正确" }
```

`error` 是给人看的中文消息，**不要拿它做控制流判断** —— 用 HTTP 状态码。

### 端点一览

| 端点 | 作用 | 主要状态码 |
|---|---|---|
| `GET /api/status` | agent 安装 / 服务状态 | 200 · 401 · 429 |
| `GET /api/version` | agent 与 manager 版本 | 200 · 401 |
| `GET /api/versions` | 当前 / 已装 / 可拉取版本 | 200 · 401 |
| `POST /api/upgrade` | 拉取并升级到目标版本 | 200 · 400 · 401 · 409 |
| `POST /api/rollback` | 回滚到已装版本 | 200 · 401 · 409 |
| `POST /api/credentials` | 改密码（OS + Web 同步） | 200 · 400 · 401 · 429 · 500 |
| `GET /api/openapi.json` | 本规范 | 200 |

### 状态查询

```bash
curl -sk -u agent:'<密码>' https://<VM_IP>/manage/api/status
```

返回 `data`：

| 字段 | 含义 |
|---|---|
| `present` | 是否已安装 agent（`current` 符号链接是否解析成功） |
| `running` | agent 的 systemd 单元是否 active |
| `state` | systemd ActiveState：`active` / `inactive` / `failed` / `unknown` |
| `version` | 已装版本，未安装时为 `unknown` |

### 升级

```bash
curl -sk -u agent:'<密码>' -X POST https://<VM_IP>/manage/api/upgrade \
  -H 'Content-Type: application/json' \
  -d '{"target":"1.3.0"}'
```

| 参数 | 说明 |
|---|---|
| `target`（必填） | 目标版本，格式 `^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$` |
| `sha256`（可选） | 期望的包摘要（64 位 hex）。**镜像地址是明文 `http://` 时服务端强制要求**；`ftp://` / `https://` 下可选，填了等于多一道校验 |

成功时 `data.status` 是 `upgraded` 或 `already-current`。

`409` 表示：另一个升级 / 回滚正在进行中，或升级失败且已自动回滚。

### 回滚

```bash
curl -sk -u agent:'<密码>' -X POST https://<VM_IP>/manage/api/rollback \
  -H 'Content-Type: application/json' -d '{}'
```

`target` 留空 = 回到**上一个**已安装版本。成功时 `data.status` 是 `rolled-back` 或 `already-current`；`409` 表示没有可回滚的目标，或有其他操作在进行。

### 改密码

```bash
curl -sk -u agent:'<旧密码>' -X POST https://<VM_IP>/manage/api/credentials \
  -H 'Content-Type: application/json' \
  -d '{"current":"<旧密码>","new":"<新密码>","confirm":"<新密码>"}'
```

| 状态码 | 含义 |
|---|---|
| 200 | 成功，`data` 里是新凭据的**不可逆指纹** |
| 400 | 策略不通过（长度 / 字符 / 两次不一致 / 与当前密码相同） |
| 401 | 当前密码错误，或请求未认证 |
| 429 | 失败次数过多，被节流 |
| 500 | 意外错误（例如沙箱化的 `nginx -t` 失败）；详情在 journal 里 |

::: tip 在工具里看接口文档
把 `https://<VM_IP>/manage/api/openapi.json` 导入任何 OpenAPI 工具即可 —— editor.swagger.io 的 *File ▸ Import file*、VS Code 的 OpenAPI 扩展都行。
:::

## 常见问题

| 现象 | 处理 |
|---|---|
| 打不开 `/manage/` | 确认用 `https://`、路径带尾斜杠；确认 VM 在运行；`systemctl status nginx` |
| 一直弹认证框 | 账号是 **OS 账户名**，密码是当前 OS 密码；连续失败会被限流（429） |
| 提示证书不受信 | 正常，VM 使用自签证书 |
| 改密码 400 | 新密码不满足策略，或两次不一致，或与当前密码相同 |
| 改密码 500 | 极少见，通常是 `nginx -t` 在沙箱下失败；看 `journalctl -u agent-manager-webadmin` |
| 升级 / 回滚返回 409 | 有另一个操作在跑，等它结束；或本次升级失败已自动回滚 |
| 页面显示 agent 服务未运行 | `sudo systemctl restart agent-manager`，仍失败看 `journalctl -u agent-manager` |
| 心跳一直失败 | VM 能否出站访问控制面 443；断路器退避期间会自动重试 |
