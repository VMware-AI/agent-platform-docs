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

**建议同时改一项**：

```bash
ADMIN_BOOTSTRAP_PASSWORD=<你自己的强口令>
```

::: warning 默认管理员口令是 `ChangeMe123!`
`.env.example` 里预置了这个值。因为它非空，`install.sh` **不会**替你重新生成。生产环境请在安装前改掉，或在首次登录后立刻修改。
:::

其余变量都有安全默认值或由 `install.sh` 自动生成，通常不需要动。完整清单见 [环境变量](/reference/env)。

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
<li><strong>拉起容器</strong> —— <code>docker compose -p agent-platform up -d</code>。</li>
<li><strong>冒烟测试</strong> —— 自动调用 <code>./verify.sh</code>。</li>
</ol>

**预计耗时 60–120 秒**（含首次 postgres 初始化与后端迁移）。

## 4. 读安装横幅

脚本结尾会打印一段 banner，其中三行最重要：

```
 Console access — open in your browser:
   URL:               https://<EXTERNAL_IP>/
   Username:          admin@platform.local
   Password:          <ADMIN_BOOTSTRAP_PASSWORD>
```

::: warning banner 里的端口可能显示为 `:80`
这是 v0.0.1 的显示问题。实际映射是**硬编码**的：`443` 提供 HTTPS，`80` 只做 301 跳转到 443。请直接访问 `https://<EXTERNAL_IP>/`（不带端口），或访问 `http://<EXTERNAL_IP>/` 让它自动跳转。`.env` 里的 `CONSOLE_PORT` 在本形态下**不改变实际端口映射**。
:::

banner 同时会打印 LiteLLM 的 master key、Prometheus / Grafana 地址与数据库连接信息，建议整段保存到运维记录里。

## 5. 常用生命周期命令

```bash
./install.sh          # 安装 / 应用改动（重新 up -d）
./install.sh up       # 同上
./install.sh down     # 停容器，保留数据卷与配置
./install.sh status   # 查看容器状态
./verify.sh           # 重新跑一次冒烟测试
./uninstall.sh        # 停容器 + 清空数据卷
```

停 / 卸载各档位的差异见 [升级与卸载](/install/upgrade)。

## 6. 从源码树安装（在线）

有出口网络时也可以直接从仓库跑：

```bash
git clone https://github.com/VMware-AI/agent-platform-deployment.git
cd agent-platform-deployment/docker-compose/standalone
./install.sh
```

`install.sh` 会自动识别布局，改走 `docker compose pull` 从镜像仓库拉取（需能访问 `quay.io/vmware-ai/*`），其余流程与离线安装一致。

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
│   ├── grafana/
│   └── otel-collector/
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

下一步 → [首次登录](/install/first-login)
