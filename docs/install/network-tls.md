# 网络与证书

## 三个地址变量的区别

安装时最容易混淆的是这三个，它们控制的是完全不同的东西：

| 变量 | 控制什么 | 典型值 |
|---|---|---|
| `EXTERNAL_IP` | **运维在浏览器里输入的地址**。用于 CORS 白名单、自签证书 SAN、安装横幅 | `192.168.1.42` |
| `BIND_IP` | **docker 把端口发布到哪张网卡**上 | `0.0.0.0`（默认，全部网卡） |
| `ALLOWED_ORIGINS` | 后端接受的 CORS 来源白名单，由 `install.sh` 自动维护 | `https://192.168.1.42` |

| 场景 | 怎么填 |
|---|---|
| 单网卡服务器 | `EXTERNAL_IP` = 该网卡 IP，`BIND_IP` 保持 `0.0.0.0` |
| 双网卡，只想在管理网对外 | `EXTERNAL_IP` 与 `BIND_IP` 都填管理网那张网卡的 IP |
| 用 DNS 名访问 | `EXTERNAL_IP` 填 FQDN，`BIND_IP` 保持 `0.0.0.0` |
| macOS / Docker Desktop / OrbStack | `BIND_IP` **必须**保持 `0.0.0.0` —— docker 在 Mac 上无法可靠绑定指定宿主 IP |

## 端口映射的真实行为

`dc-standalone` 的 console 容器**硬编码**发布两个端口：

```yaml
- "${BIND_IP:-0.0.0.0}:443:443"   # HTTPS 入口，TLS 由 console 镜像终结
- "${BIND_IP:-0.0.0.0}:80:80"     # 明文监听，301 跳转到 443
```

`SSL_ENABLE` 与 `SSL_REDIRECT` 也硬编码为 `true`。也就是说：

- 本形态**总是**提供 HTTPS，不能关
- `.env` 里的 `CONSOLE_PORT` **不会改变实际端口映射**（只影响安装横幅文案）
- v0.0.1 的正确访问地址就是 `https://<EXTERNAL_IP>/`
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

### 证书要求

| 项 | 要求 |
|---|---|
| SAN | 必须覆盖你实际访问的域名或 IP |
| 私钥 | **不要加密码短语** —— nginx 启动时无法交互输入 |
| 证书链 | 完整（中间 CA 一并拼进 crt，服务器证书在前） |
| 格式 | PEM |
| 权限 | nginx 容器需可读 |

自查：

```bash
# 看 SAN 里有没有你要访问的地址
openssl x509 -in /etc/ssl/corp/agent-platform.crt -noout -text \
  | grep -A1 'Subject Alternative Name'

# 证书与私钥是不是一对（两个 md5 应相同）
openssl x509 -noout -modulus -in agent-platform.crt | openssl md5
openssl rsa  -noout -modulus -in agent-platform.key | openssl md5

# 有效期
openssl x509 -in agent-platform.crt -noout -dates
```

### 换证书后别忘了 CORS

如果访问地址也变了（IP → 域名），同步更新：

```bash
EXTERNAL_IP=agent.corp.example.com
ALLOWED_ORIGINS=https://agent.corp.example.com
```

```bash
docker compose -p agent-platform restart backend
```

::: tip 自签证书也有到期问题
`install.sh` 生成的自签证书有效期 **365 天**。一年后会突然全员告警。长期运行的环境建议一开始就换成企业 CA 签发的证书，或把「一年后换证」写进运维日历。
:::

## 智能体 VM 的网络前提

智能体 VM 从 vCenter 克隆出来后，需要能够：

| 目标 | 端口 | 用途 |
|---|---|---|
| 控制面 `EXTERNAL_IP` | 443 | agent-manager 注册 + 心跳 + 知识包拉取（**仅出站**） |
| 模型网关的「Agent 访问地址」 | 443 或网关端口 | agent 运行时调用模型 |
| 离线技能 / 安装包仓库 | 依配置 | 技能与 agent 版本包下载（FTP 或 HTTP/S） |

反向不需要：控制面**不主动连**智能体 VM，全部靠 VM 出站心跳。使用者访问 VM 走 SSH（22）与 VM 自身的 nginx（443，路径 `/manage/`）。

### VM 侧自检

新部署的 VM 起不来时，SSH 进去跑这几条：

```bash
# 到控制面
curl -sk -o /dev/null -w 'console=%{http_code}\n' https://<EXTERNAL_IP>/

# 到网关（走 console 反代）
curl -sk -o /dev/null -w 'gw=%{http_code}\n' \
  https://<EXTERNAL_IP>/litellm/health/liveliness

# 本机网络
ip -4 addr; ip route; cat /etc/resolv.conf
```

::: danger 自签证书 + VM 侧校验
VM 内的 agent-manager 访问控制面时，如果控制面用的是自签证书，需要证书被 VM 信任或跳过校验。换成企业 CA 证书能一劳永逸地避免这类问题。
:::

## 反向代理在前面时

如果在平台前面再放一层企业反代（F5、nginx、Ingress）：

<ol class="ap-steps">
<li>反代到 <code>https://&lt;平台主机&gt;:443</code>。后端是自签证书时需要 <code>proxy_ssl_verify off</code>，或先把平台换成受信证书。</li>
<li>透传 <code>Host</code> 头。</li>
<li>把用户实际访问的 URL 加进 <code>ALLOWED_ORIGINS</code>，然后 <code>restart backend</code>。</li>
<li>智能体侧的「Agent 访问地址」也要相应改成经反代的地址（如果 VM 走的是同一条路径）。</li>
</ol>

WebSocket 不是必需的 —— 控制台使用轮询刷新，不依赖 WS。

nginx 反代示例：

```nginx
server {
    listen 443 ssl;
    server_name agent.corp.example.com;

    ssl_certificate     /etc/ssl/corp/agent.crt;
    ssl_certificate_key /etc/ssl/corp/agent.key;

    location / {
        proxy_pass              https://192.168.1.42:443;
        proxy_ssl_verify        off;          # 后端是自签证书时
        proxy_set_header Host   $host;
        proxy_set_header X-Real-IP        $remote_addr;
        proxy_set_header X-Forwarded-For  $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        client_max_body_size    64m;          # 技能包上传
    }
}
```

::: warning 别忘了上传大小
[技能管理](/console/skills)支持上传离线包，反代默认的 `client_max_body_size`（1m）会把上传拦掉。按你的包大小调。
:::

## 参考

- 全部端口清单与微分段建议 → [端口与网络](/reference/ports)
- 全部环境变量 → [环境变量](/reference/env)
- 访问不通时 → [故障排查](/install/troubleshooting)
