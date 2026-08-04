# 网络与证书

## 三个地址变量的区别

安装时最容易混淆的是这三个，它们控制的是不同的东西：

| 变量 | 控制什么 | 典型值 |
|---|---|---|
| `EXTERNAL_IP` | **运维在浏览器里输入的地址**。用于 CORS 白名单、自签证书 SAN、安装横幅 | `192.168.1.42` |
| `BIND_IP` | **docker 把端口发布到哪张网卡**上 | `0.0.0.0`（默认，全部网卡） |
| `ALLOWED_ORIGINS` | 后端接受的 CORS 来源白名单，由 `install.sh` 自动维护 | `https://192.168.1.42` |

::: tip 双网卡场景
服务器有多张网卡、只想让控制台在其中一张上对外时：`EXTERNAL_IP` 填对外那张网卡的 IP，`BIND_IP` 同样填它。两者可以一致。
:::

::: warning macOS / Docker Desktop / OrbStack
`BIND_IP` 必须保持 `0.0.0.0` —— docker 在 Mac 上无法可靠地绑定到指定宿主 IP。
:::

## 端口映射的真实行为

`dc-standalone` 的 console 容器**硬编码**发布两个端口：

```yaml
- "${BIND_IP:-0.0.0.0}:443:443"   # HTTPS 入口，TLS 由 console 镜像终结
- "${BIND_IP:-0.0.0.0}:80:80"     # 明文监听，301 跳转到 443
```

`SSL_ENABLE` 与 `SSL_REDIRECT` 也是硬编码 `true`。也就是说：

- 本形态**总是**提供 HTTPS，不能关
- `.env` 里的 `CONSOLE_PORT` **不会改变实际端口映射**（它只影响安装横幅的文案），v0.0.1 的正确访问地址就是 `https://<EXTERNAL_IP>/`
- 需要换端口，只能改 `manifests/docker-compose.yml` 里 console 的 `ports:` 左侧宿主端口，然后 `./install.sh up`

## 换成自己的证书

把证书和私钥放到主机任意位置，然后在 `.env` 指向它们：

```bash
SSL_CERT_PATH=/etc/ssl/corp/agent-platform.crt
SSL_KEY_PATH=/etc/ssl/corp/agent-platform.key
```

重新应用：

```bash
./install.sh up
```

`install.sh` 看到文件已存在就不会覆盖，直接 bind-mount 进容器的 `/etc/nginx/certs/`。

要求：

- 证书需覆盖你实际访问的域名或 IP（SAN）
- 私钥不要加密码短语（nginx 启动时无法交互输入）
- 证书链完整（中间 CA 一并拼进 crt）

换证书后如果访问地址也变了（IP → 域名），记得同步 `ALLOWED_ORIGINS`：

```bash
ALLOWED_ORIGINS=https://agent.corp.example.com
docker compose -p agent-platform restart backend
```

## 智能体 VM 的网络前提

智能体 VM 从 vCenter 克隆出来后，需要能够：

| 目标 | 端口 | 用途 |
|---|---|---|
| 控制面 `EXTERNAL_IP` | 443 | agent-manager 注册 + 心跳 + 知识包拉取（**仅出站**） |
| 模型网关 Agent 访问地址 | 443 或网关端口 | agent 运行时调用模型 |
| 离线技能 / 安装包仓库 | 依配置 | 技能与 agent 版本包下载（FTP 或 HTTP/S） |

反向不需要：控制面**不主动连**智能体 VM，全部靠 VM 出站心跳。使用者访问 VM 走 SSH（22）与 VM 自身的 nginx（443，路径 `/manage/`）。

::: tip NSX 微分段
建议为智能体 VM 端口组配置 DFW 规则：只放行上表三条出站，禁止 VM 之间横向访问。
:::

## 反向代理在前面时

如果在平台前面再放一层企业反代（如 F5、nginx、Ingress）：

1. 反代到 `https://<平台主机>:443`，注意后端是自签证书时需要 `proxy_ssl_verify off` 或换成受信证书
2. 透传 `Host` 头
3. 把用户实际访问的 URL 加进 `ALLOWED_ORIGINS`
4. WebSocket 不是必需的（控制台使用轮询刷新，不依赖 WS）

## 参考

- 全部端口清单 → [端口与网络](/reference/ports)
- 全部环境变量 → [环境变量](/reference/env)
