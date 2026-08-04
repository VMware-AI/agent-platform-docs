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
这是有意为之且具破坏性：丢失该文件后，`platform_secrets` 表里所有加密凭据（vCenter 口令、上游 API Key 等）都将无法解密。**执行前务必先备份。**
:::

关于数据卷的两点说明：

- 数据卷存在 docker 的命名卷里，不在安装目录下。`uninstall.sh` 会带 `--volumes` 执行 `docker compose down`，所以会被清掉。
- 如果你把 `pg_data` 改成了宿主机 bind mount，需要手工 `rm -rf` —— `--purge` 不会动宿主 bind mount。
- 同级的 `agent-platform-images-*/` 是运维的部署资产，`--purge` **不会**删它，留着下次 `install.sh` 直接复用。

## 保留数据升级到新版本

<ol class="ap-steps">
<li><strong>备份。</strong> 至少备份 <code>.env</code> 和 <code>.secrets_encryption_key</code>；建议同时 dump 数据库。</li>
<li><strong>停容器。</strong> <code>./install.sh down</code> —— 保留数据卷与配置文件。</li>
<li><strong>换目录。</strong> 解压新版本 tarball，替换 install-root。</li>
<li><strong>恢复密钥。</strong> 把备份的 <code>.env</code> 与 <code>.secrets_encryption_key</code> 放回新目录。<strong>这一步不能跳过</strong> —— 否则 install.sh 会生成新的 <code>SECRETS_ENCRYPTION_KEY</code>，与库里已加密的数据对不上。</li>
<li><strong>安装。</strong> <code>cd &lt;新目录&gt; && ./install.sh</code>，结束后跑 <code>./verify.sh</code>。</li>
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

## 备份清单

| 对象 | 怎么备份 |
|---|---|
| `SECRETS_ENCRYPTION_KEY` | 复制 `.secrets_encryption_key`（**最关键**） |
| `.env` | 直接复制；含 master key、DB 口令、admin 初始口令 |
| 控制面数据库 | `docker compose -p agent-platform exec postgres pg_dump -U agentplatform_user agentplatform > agentplatform.sql` |
| 网关数据库 | 同上，库名换成 `litellm` |
| TLS 证书 | 复制 `certs/` |
| Grafana / Prometheus 数据 | 卷 `agent-platform_grafana_data`、`agent-platform_litellm_prom_data`（可选） |

::: tip 备份验证
把 `.env` 与 `.secrets_encryption_key` 存进企业密钥库，并定期在测试环境做一次「恢复演练」：新装一套 → 放回两份文件 + 恢复数据库 → 确认控制台里 vCenter 凭据仍能测试连接通过。这是唯一能证明备份有效的方法。
:::

## 配置改动的重载范围

| 配置项 | 重载方式 |
|---|---|
| `EXTERNAL_IP`、`BIND_IP` | `docker compose up -d`（重建容器） |
| `BACKEND_PORT` | `docker compose up -d` |
| `ALLOWED_ORIGINS` | `docker compose restart backend` |
| `ADMIN_BOOTSTRAP_PASSWORD` | `docker compose restart backend` |
| 后端调优项（`LITELLM_RECONCILE_*`、`POOL_SYNC_*`、`DB_MAX_*`、`SECRETS_*`） | `docker compose restart backend` |
| `LITELLM_MASTER_KEY`、`LITELLM_SALT_KEY` | `docker compose restart litellm`，并重跑 `./install.sh`（重新渲染 prometheus.yml） |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | **不支持热更新**，需重装 |
| `IMAGE_REGISTRY`、各 `*_IMAGE` | `docker compose pull && docker compose up -d` |

任何改动之后重新跑一次 `./verify.sh`。

## 智能体侧的升级

平台升级与智能体升级是两条独立的路径。智能体版本升级由控制台下发、VM 内 agent-manager 执行，见 [升级与回滚](/agent-vm/upgrade)。
