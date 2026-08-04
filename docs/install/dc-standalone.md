# 离线安装（单机）

`dc-standalone` 是 v0.0.1 发布的形态：一台主机、8 个容器、完全离网可装。

## 1. 落盘

把**两个 tarball 解压到同级目录** —— 安装脚本按相对路径 `../agent-platform-images-*/images/images.tar.gz` 找镜像包。

```bash
mkdir -p /opt/agent-platform && cd /opt/agent-platform

tar -xzf /path/to/agent-platform-images-0.0.1-amd64.tar.gz
tar -xzf /path/to/agent-platform-dc-standalone-0.0.1.tar.gz

ls
# agent-platform-images-0.0.1-amd64/
# agent-platform-dc-standalone-0.0.1/
```

::: warning 两个包必须是同级目录
不是「镜像包放进安装包里」，而是**并排**。放错位置时 `install.sh` 会找不到镜像包，可以用 `--images=<path>` 显式指定。
:::

安装前建议校验：

```bash
sha256sum -c SHA256SUMS
```

## 2. 写 `.env`

```bash
cd agent-platform-dc-standalone-0.0.1
cp .env.example .env
$EDITOR .env
```

**必填一项**：

```bash
EXTERNAL_IP=192.168.1.42
```

`install.sh` 会拒绝空值、`0.0.0.0`、`localhost`、`127.x.x.x`、`::1` —— 必须是浏览器真正会输入的那个地址（IP 或 DNS 名）。

**强烈建议同时改一项**：

```bash
ADMIN_BOOTSTRAP_PASSWORD=<你自己的强口令>
```

::: danger 默认管理员口令是 `ChangeMe123!`
`.env.example` 里预置了这个值。因为它非空，`install.sh` **不会**替你重新生成。生产环境请在安装前改掉，或在首次登录后立刻修改。
:::

其余变量都有安全默认值或由 `install.sh` 自动生成，通常不需要动。完整清单见[环境变量](/reference/env)。

## 3. 安装

```bash
./install.sh
```

脚本按顺序做这些事：

<ol class="ap-steps">
<li><strong>校验 <code>EXTERNAL_IP</code></strong> —— 空值 / 回环地址直接报错退出。</li>
<li><strong>生成密钥</strong> —— 为空的 <code>LITELLM_MASTER_KEY</code>（<code>sk-local-&lt;hex&gt;</code>）、<code>LITELLM_SALT_KEY</code>、<code>POSTGRES_PASSWORD</code>、<code>SECRETS_ENCRYPTION_KEY</code>（32 字节 hex）自动补齐；<strong>已填的非空值不会被覆盖</strong>。<code>SECRETS_ENCRYPTION_KEY</code> 同时镜像写入同级 <code>.secrets_encryption_key</code> 供备份。</li>
<li><strong>补默认值</strong> —— compose 引用但 <code>.env</code> 缺失的变量（如 <code>POSTGRES_USER</code>、<code>POSTGRES_DB</code>）补上，避免传空串。</li>
<li><strong>自举 TLS</strong> —— <code>SSL_CERT_PATH</code> / <code>SSL_KEY_PATH</code> 指向的证书不存在时，生成 365 天自签证书，SAN 含 <code>EXTERNAL_IP</code>、<code>127.0.0.1</code>、<code>localhost</code>。已放置自有证书则原样复用。</li>
<li><strong>维护 <code>ALLOWED_ORIGINS</code></strong> —— 空值时设为 <code>https://${EXTERNAL_IP}</code>；非空但缺该 URL 则追加。<strong>不要手工编辑这一项。</strong></li>
<li><strong>preflight</strong> —— 检查 docker、compose 插件、架构、磁盘空间。</li>
<li><strong>加载离线镜像</strong> —— 先按 <code>SHA256SUMS</code> 校验镜像包，再 <code>docker load</code>。（源码树模式则走 <code>docker compose pull</code>。）</li>
<li><strong>渲染 <code>prometheus.yml</code></strong> —— 把 <code>LITELLM_MASTER_KEY</code> 代入 Bearer 凭据，使 prometheus 能抓 litellm 的 <code>/metrics</code>。每次安装都重新渲染，密钥轮换后自动生效。</li>
<li><strong>渲染 OTel collector 配置</strong> —— 供请求日志采集使用。</li>
<li><strong>拉起容器</strong> —— <code>docker compose -p agent-platform up -d</code>。</li>
<li><strong>冒烟测试</strong> —— 自动调用 <code>./verify.sh</code>。</li>
</ol>

**预计耗时 60–120 秒**（含首次 postgres 初始化与后端迁移）。

### install.sh 的参数

| 参数 | 说明 |
|---|---|
| `--env-file=<path>` | 指定 env 文件（默认找 `./.env`） |
| `--images=<path>` | 指定离线镜像包路径（默认 `../agent-platform-images-*/images/images.tar.gz`） |
| `--skip-image-load` | 跳过 `docker load`（镜像已在本机时用） |

::: tip 重复执行是安全的
`install.sh` 设计成可反复执行：已生成的密钥不会被覆盖、已有的证书不会被替换、容器会被 `up -d` 平滑重建。改完 `.env` 之后直接再跑一次就是「应用改动」。
:::

## 4. 读安装横幅

脚本结尾会打印一段 banner，其中这几行最重要：

```
 Console access — open in your browser:
   URL:               https://<EXTERNAL_IP>/
   Username:          admin@platform.local
   Password:          <ADMIN_BOOTSTRAP_PASSWORD>
```

banner 同时会打印：

| 信息 | 用途 |
|---|---|
| **LiteLLM master key** | 接入模型网关时要填 |
| Prometheus / Grafana 地址 | 观测入口 |
| Postgres / Redis 连接信息 | 排障用 |
| OTel collector 端口与共享 jsonl 路径 | 请求日志排障用 |
| `ALLOWED_ORIGINS` 建议值 | 跨机访问时对照 |

::: warning banner 里的端口可能显示为 `:80`
这是 v0.0.1 的显示问题。实际映射是**硬编码**的：`443` 提供 HTTPS，`80` 只做 301 跳转到 443。请直接访问 `https://<EXTERNAL_IP>/`（不带端口）。`.env` 里的 `CONSOLE_PORT` 在本形态下**不改变实际端口映射**。
:::

::: tip 把整段 banner 存进运维记录
里面的 master key 和数据库口令后面还会用到。虽然都能从 `.env` 里再查出来，但存一份省事。
:::

## 5. 常用生命周期命令

```bash
./install.sh          # 安装 / 应用改动（重新 up -d）
./install.sh up       # 同上
./install.sh down     # 停容器，保留数据卷与配置
./install.sh status   # 查看容器状态
./verify.sh           # 重新跑一次冒烟测试
./uninstall.sh        # 停容器 + 清空数据卷
./uninstall.sh --purge  # + 删镜像 + 删 .env / 证书 / 密钥（危险）
```

各档位差异见[升级与卸载](/install/upgrade#停--卸载各档位的差异)。

## 6. 从源码树安装（在线）

有出口网络时也可以直接从仓库跑：

```bash
git clone https://github.com/VMware-AI/agent-platform-deployment.git
cd agent-platform-deployment/docker-compose/standalone
./install.sh
```

`install.sh` 自动识别布局，改走 `docker compose pull` 从镜像仓库拉取（需能访问 `quay.io/vmware-ai/*`），其余流程与离线安装一致。

| | 离线（tarball） | 在线（源码树） |
|---|---|---|
| 镜像来源 | `docker load` 本地包 | `docker compose pull` |
| 网络要求 | 无 | 能访问 quay.io |
| 适用 | 生产、气隙环境 | 开发、评估 |

## 安装完成后的目录

```
agent-platform-dc-standalone-0.0.1/
├── .env                        # 由 cp .env.example .env 得到，install.sh 会补齐
├── .secrets_encryption_key     # ⚠️ 加密钥匙的镜像备份 —— 必须备份
├── certs/tls.crt + tls.key     # 自签或自有证书
├── install.sh · verify.sh · uninstall.sh
├── manifest.yaml
├── README.md · dc-standalone-operations.zh-CN.md
├── prometheus.yml.tmpl         # 渲染源
├── manifests/
│   ├── docker-compose.yml
│   ├── prometheus.yml          # 渲染产物，mode 600
│   ├── litellm-config.yaml
│   ├── init-db.sh
│   ├── grafana/                # 预置仪表盘与数据源
│   ├── otel-collector/         # collector 配置与 env
│   └── shared-spans/           # 请求日志中转 jsonl
└── scripts/preflight.sh · load-images.sh
```

数据卷不在这个目录里，而在 docker 的命名卷中：

```bash
docker volume ls | grep agent-platform
# agent-platform_pg_data
# agent-platform_redis_data
# agent-platform_litellm_prom_data
# agent-platform_grafana_data
```

::: danger 立刻备份两个文件
`.env` 和 `.secrets_encryption_key`。后者是解开 `platform_secrets` 表的唯一钥匙，丢了所有加密凭据都变成死数据。见[备份清单](/install/upgrade#备份清单)。
:::

## 下一步

→ [首次登录](/install/first-login)
