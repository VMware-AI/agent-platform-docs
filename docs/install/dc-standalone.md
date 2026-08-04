# 安装单机形态（dc-standalone）

`dc-standalone` 是 v0.0.1 发布的入门形态：一台主机、一份 compose、`./install.sh` 拉起整套控制面。本页覆盖从 tarball 安装、`.env` 配置、到气隙环境离线安装与开发模式的所有路径。

> v0.0.1 同时发布另外 3 个形态：`dc-distribution`（多服务开发）、`k8s-standalone`（k8s 小集群）、`k8s-ha`（k8s 生产 HA）。它们的安装方式与本页 90% 相同（`install.sh` 同款行为），差异只在形态专属的 `manifest.yaml` / `.env.example` 与 Helm chart overlay。本手册后续会补对应章节，目前请参考 [部署仓库 README](https://github.com/VMware-AI/agent-platform-deployment/blob/main/README.md)。

> **v0.0.1 的离线语义变了**
>
> release **不再带离线镜像包**。`install.sh` 默认从 `quay.io/vmware-ai/<image>` 拉取 —— 目标机需要能访问 `quay.io`。
>
> 完全离网 / 气隙环境按本文 [§6 离线安装（可选：气隙环境）](#6-离线安装可选气隙环境) 走 —— 先在能上网的机器上用 `make package-images-amd64` 造一个镜像包，再带到目标机作为同级目录放好。

## 1. 落盘

```bash
mkdir -p /opt/agent-platform && cd /opt/agent-platform

tar -xzf /path/to/agent-platform-dc-standalone-0.0.1.tar.gz

ls
# agent-platform-dc-standalone-0.0.1/
```

安装前建议校验：

```bash
cd agent-platform-dc-standalone-0.0.1
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
<li><strong>获取镜像</strong> —— 优先扫描同级 <code>agent-platform-images-*/images/images.tar.gz</code>，找到则按 <code>SHA256SUMS</code> 校验后 <code>docker load</code>；否则 <code>docker compose pull</code> 从 <code>quay.io/vmware-ai/&lt;image&gt;</code> 拉取（需能访问 <code>quay.io</code>）。<code>--skip-image-load</code> 可跳过整个步骤。</li>
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
| `--images=<path>` | 指定离线镜像包路径（默认扫描同级目录 `../agent-platform-images-*/images/images.tar.gz`，找不到则从 `quay.io` 拉） |
| `--skip-image-load` | 跳过镜像获取步骤（镜像已在本地、且不打算让脚本拉任何东西时用） |
| `--namespace=<name>` | 仅 k8s-* 形态生效（默认 `agent-platform`），dc-* 忽略 |

::: tip 重复执行是安全的
`install.sh` 设计成可反复执行：已生成的密钥不会被覆盖、已有的证书不会被替换、容器会被 `up -d` 平滑重建。改完 `.env` 之后直接再跑一次就是「应用改动」。
:::

::: tip 想看 `install.sh` 干了哪些步骤
跑 `./install.sh up --dry-run`（如果该版本支持）或者直接 `bash -x ./install.sh up` 看 trace —— 所有密钥生成、证书签发、镜像加载、compose up 都是带日志的步骤，定位哪一步出错很方便。
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

## 6. 离线安装（可选：气隙环境）

只给**目标机完全无法访问 `quay.io`**的场景用。多一步「在能上网的机器上造镜像包」，传到目标机后 `install.sh` 会自动 `docker load`。

### 步骤 1：在能访问 `quay.io` 的机器上造镜像包

```bash
git clone https://github.com/VMware-AI/agent-platform-deployment.git
cd agent-platform-deployment

# 按目标机的 CPU 架构选 amd64 / arm64
case "$(uname -m)" in
  x86_64)  make package-images-amd64 ;;
  aarch64|arm64) make package-images-arm64 ;;
  *) echo "unknown arch" >&2; exit 1 ;;
esac

# 产物在 dist/ 下，名字形如 agent-platform-images-<ver>-amd64.tar.gz
ls -lh dist/
```

输出包含 `manifest.yaml` + `images/images.tar.gz` + `images/SHA256SUMS`，与镜像的源清单 [`origin-images-list.txt`](https://github.com/VMware-AI/agent-platform-deployment/blob/main/origin-images-list.txt) 对得上。**升级时 bump 这两个清单再重新打包**。

不想 / 不能用 Makefile 时，按同样的清单手搓一个：

```bash
# 在能访问 quay.io 的机器上
case "$(uname -m)" in
  x86_64)  IMG_ARCH=linux/amd64 ;;
  aarch64|arm64) IMG_ARCH=linux/arm64 ;;
  *) echo "unknown arch" >&2; exit 1 ;;
esac

# 逐行拉、按架构；空行与 # 起头的注释自动跳过
while read -r img; do
  [[ -z "$img" || "$img" == \#* ]] && continue
  docker pull --platform="${IMG_ARCH}" "$img"
done < origin-images-list.txt

# 一次性 save 成单个 tar.gz
mkdir -p images && cd images
docker save --platform="${IMG_ARCH}" \
  -o images.tar $(grep -v '^#' ../origin-images-list.txt | grep -v '^$')
gzip images.tar
sha256sum images.tar.gz > SHA256SUMS

# 打包成 install.sh 同款目录结构
cd .. && tar -czf agent-platform-images-<ver>-${IMG_ARCH#linux/}.tar.gz \
  manifest.yaml images/images.tar.gz images/SHA256SUMS
```

产物布局跟 Makefile 出的完全一致：`manifest.yaml` + `images/images.tar.gz` + `images/SHA256SUMS`，`install.sh` 不用任何修改就能识别。

### 步骤 2：把两个 tarball 一起搬到目标机

```bash
# 在目标机上 —— 镜像包作为安装包的同级目录放好
mkdir -p /opt/agent-platform && cd /opt/agent-platform

tar -xzf agent-platform-images-<ver>-amd64.tar.gz     # → ./agent-platform-images-<ver>-amd64/
tar -xzf agent-platform-dc-standalone-<ver>.tar.gz   # → ./agent-platform-dc-standalone-<ver>/
```

### 步骤 3：照常 `install.sh`

```bash
cd agent-platform-dc-standalone-<ver>
cp .env.example .env
$EDITOR .env      # 必须填 EXTERNAL_IP
./install.sh
```

`install.sh` 会扫描同级目录下的 `agent-platform-images-*/images/images.tar.gz`，找到就走 `docker load`，找不到才退化到 `docker compose pull`（也就是需要访问 `quay.io`）。

::: tip 自动发现不命中时手动指
目录名 / 布局跟约定对不上时（比如你把镜像包换了个名字），用 `--images=<path>` 显式指给 `install.sh`：

```bash
./install.sh --images=/srv/images/my-bundle/images.tar.gz
```
:::

::: tip 不想要自动扫描的语义
完全跳过镜像获取步骤（包括 `docker load` 和 `docker compose pull`）：`--skip-image-load`。用于镜像已经在本机、并且想用其他方式管理（自己 `docker load` / 用 `nerdctl` / 用 k8s 节点池导入）的场景。
:::

## 7. 从源码树安装（开发 / 评估）

只给开发或评估用：从仓库 clone 后直接跑 `install.sh`，效果跟 tarball 一致，但改动会被立刻跟进。

```bash
git clone https://github.com/VMware-AI/agent-platform-deployment.git
cd agent-platform-deployment/docker-compose/standalone
./install.sh
```

`install.sh` 检测到当前在源码树里、改走 `docker compose pull` 从 `quay.io/vmware-ai/<image>` 拉镜像（需能访问 `quay.io`），其余流程（密钥生成、TLS 自举、preflight、冒烟测试）跟 tarball 完全一样。

| | tarball 安装 | 源码树安装 |
|---|---|---|
| 镜像来源 | 默认 `docker compose pull`；同级有 `agent-platform-images-*/` 则 `docker load` | `docker compose pull`（镜像源从仓库 `manifest.yaml` 读） |
| 网络要求 | 能访问 `quay.io`；气隙则需要同级镜像包 | 能访问 `quay.io` |
| 适用 | 生产、评估、CI | 改镜像 / 改 compose / 改脚本的开发 |

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
