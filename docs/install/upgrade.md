# 升级与卸载

## 停 / 卸载各档位的差异

| 命令 | 容器 | 数据卷 | 镜像 | `.env` / 密钥 / 证书 | 同级镜像包目录 |
|---|---|---|---|---|---|
| `./install.sh down` | 删除 | 保留 | 保留 | 保留 | 保留 |
| `./install.sh status` | 仅查看 | — | — | — | — |
| `./uninstall.sh` | 删除 | **清空** | 保留 | 保留 | 保留 |
| `./uninstall.sh --purge` | 删除 | 清空 | **删除** | **删除** | 保留 |
| `./uninstall.sh --purge -y` | 同上，跳过确认 | | | | |

::: danger `--purge` 会删除 `.secrets_encryption_key`
这是有意为之且具破坏性：丢失该文件后，`platform_secrets` 表里所有加密凭据（vCenter 口令、上游 API Key 等）都将**无法解密**。数据库还在，但里面的密钥全部报废。

**执行前务必先备份。**
:::

关于数据卷的三点：

- 数据卷存在 docker 的命名卷里，**不在安装目录下**。`uninstall.sh` 会带 `--volumes` 执行 `docker compose down`，所以会被清掉。
- 如果你把 `pg_data` 改成了宿主机 bind mount，需要手工 `rm -rf` —— `--purge` 不会动宿主 bind mount。
- 同级的 `agent-platform-images-*/` 是运维的部署资产，`--purge` **不会**删它，留着下次 `install.sh` 直接复用。

```bash
docker volume ls | grep agent-platform
# agent-platform_pg_data
# agent-platform_redis_data
# agent-platform_litellm_prom_data
# agent-platform_grafana_data
```

## 备份清单

| 对象 | 怎么备份 | 重要性 |
|---|---|---|
| `SECRETS_ENCRYPTION_KEY` | 复制 `.secrets_encryption_key` | 🔴 **最关键** |
| `.env` | 直接复制；含 master key、DB 口令、admin 初始口令 | 🔴 关键 |
| 控制面数据库 | 见下方命令 | 🔴 关键 |
| 网关数据库 | 见下方命令 | 🟡 重要（账单历史） |
| TLS 证书 | 复制 `certs/` | 🟡 可重新生成 |
| Grafana / Prometheus 数据 | 卷 `agent-platform_grafana_data`、`agent-platform_litellm_prom_data` | 🟢 可选 |

```bash
cd /opt/agent-platform/agent-platform-dc-standalone-0.0.1
BK=/backup/agent-platform/$(date +%Y%m%d)
mkdir -p "$BK"

# 配置与密钥
cp .env .secrets_encryption_key "$BK"/
cp -r certs "$BK"/

# 两个数据库
docker compose -p agent-platform exec -T postgres \
  pg_dump -U agentplatform_user agentplatform > "$BK"/agentplatform.sql
docker compose -p agent-platform exec -T postgres \
  pg_dump -U agentplatform_user litellm      > "$BK"/litellm.sql

chmod 600 "$BK"/.env "$BK"/.secrets_encryption_key
```

::: danger 备份文件本身就是密钥
`.env` 与 `.secrets_encryption_key` 是明文的。存进企业密钥库或加密卷，别丢在共享盘上 —— 拿到这两个文件等于拿到平台里的全部凭据。
:::

::: tip 做一次恢复演练
备份有没有用，只有恢复过才知道。在测试环境走一遍：新装一套 → 放回两份文件 + 恢复数据库 → 确认控制台里 vCenter 凭据仍能「测试连接」通过。

能通过，说明 `SECRETS_ENCRYPTION_KEY` 与库里的密文是配套的 —— 这是备份有效的唯一硬证据。
:::

## 保留数据升级到新版本

<ol class="ap-steps">
<li><strong>备份。</strong> 按上方清单做一次完整备份。</li>
<li><strong>停容器。</strong> <code>./install.sh down</code> —— 保留数据卷与配置文件。</li>
<li><strong>换目录。</strong> 解压新版本 tarball，作为新的 install-root。</li>
<li><strong>恢复密钥。</strong> 把备份的 <code>.env</code> 与 <code>.secrets_encryption_key</code> 放回新目录。<strong>这一步不能跳过</strong> —— 否则 install.sh 会生成新的 <code>SECRETS_ENCRYPTION_KEY</code>，与库里已加密的数据对不上。</li>
<li><strong>安装。</strong> <code>cd &lt;新目录&gt; && ./install.sh</code>。</li>
<li><strong>验证。</strong> <code>./verify.sh</code>；登录控制台确认资源池能「测试连接」、模型能「探测」。</li>
</ol>

### 只换镜像 tag

不改 compose 结构时可以更轻：

```bash
# 在 .env 里 pin 新 tag，例如：
# BACKEND_IMAGE=agent-platform-backend:v0.0.2
docker compose -p agent-platform pull
docker compose -p agent-platform up -d
./verify.sh
```

离线环境下先 `docker load` 新镜像包，再 `up -d`。

### 升级前的检查清单

- [ ] 备份已完成，且 `.secrets_encryption_key` 在里面
- [ ] 已阅读新版本的 CHANGELOG，确认没有破坏性变更
- [ ] 已通知使用者一个短暂的控制台中断窗口（智能体 VM 本身不受影响）
- [ ] 磁盘有足够空间放新镜像
- [ ] 手里有回退方案（旧目录别急着删）

::: tip 升级控制面不影响运行中的智能体
控制面停机期间，已部署的智能体 VM 照常运行、照常调模型（网关容器如果一起重启会有短暂中断）。受影响的只是控制台管理操作与心跳上报 —— 心跳失败会自动退避重试，控制面回来后自愈。
:::

## 配置改动的重载范围

| 配置项 | 重载方式 |
|---|---|
| `EXTERNAL_IP`、`BIND_IP` | `docker compose up -d`（重建容器） |
| `BACKEND_PORT` | `docker compose up -d` |
| `ALLOWED_ORIGINS` | `docker compose restart backend` |
| `ADMIN_BOOTSTRAP_PASSWORD` | `docker compose restart backend` |
| 后端调优项（`LITELLM_RECONCILE_*`、`POOL_SYNC_*`、`DB_MAX_*`、`SECRETS_*`、`*_CACHE_TTL_*`） | `docker compose restart backend` |
| `LITELLM_MASTER_KEY`、`LITELLM_SALT_KEY` | `docker compose restart litellm`，并重跑 `./install.sh`（重新渲染 prometheus.yml） |
| `SSL_CERT_PATH` / `SSL_KEY_PATH` | `./install.sh up` |
| OTel 相关（`OTEL_*`、`REQUESTLOG_INGEST_MODE`） | `./install.sh up`（重新渲染 collector 配置） |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | **不支持热更新**，需重装 |
| `IMAGE_REGISTRY`、各 `*_IMAGE` | `docker compose pull && docker compose up -d` |

任何改动之后重新跑一次 `./verify.sh`。

## 回退

升级出问题要回退时：

<ol class="ap-steps">
<li><code>./install.sh down</code>（在新目录里）。</li>
<li><code>cd</code> 回旧版本目录。</li>
<li>确认旧目录里的 <code>.env</code> 与 <code>.secrets_encryption_key</code> 还在。</li>
<li><code>./install.sh</code>。</li>
</ol>

::: warning 数据库迁移通常不可逆
新版本如果跑过 schema 迁移，回退到旧版本可能读不了新 schema。这种情况下要从备份恢复数据库：

```bash
docker compose -p agent-platform exec -T postgres \
  psql -U agentplatform_user -d agentplatform < /backup/.../agentplatform.sql
```

所以「升级前先备份」不是走过场。
:::

## 智能体侧的升级

平台升级与智能体升级是两条独立路径。智能体版本升级由控制台下发、VM 内 agent-manager 执行，见[升级与回滚](/agent-vm/upgrade)。

| | 平台升级（本页） | 智能体升级 |
|---|---|---|
| 对象 | 控制面 8 个容器 | 各 VM 里的 agent |
| 影响 | 控制台短暂不可用 | 单台 agent 重启几秒 |
| 回退 | 换回旧目录 + 恢复数据库 | 一键回滚到上一版本 |
