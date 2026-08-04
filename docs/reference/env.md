# 环境变量

`dc-standalone` 的全部配置集中在安装目录下的 `.env`。绝大多数运维只需要设置 `EXTERNAL_IP`。

::: tip 三类变量
1. **必填** —— 只有 `EXTERNAL_IP`
2. **自动生成** —— 留空时 `install.sh` 首次运行自动填充，已填的非空值不会被覆盖
3. **自动管理** —— `ALLOWED_ORIGINS`，不要手工编辑
:::

## 必填

| 变量 | 说明 |
|---|---|
| `EXTERNAL_IP` | 浏览器 / 监控访问平台用的主机地址。可以是 IP 或 DNS 名。**拒绝**空值、`0.0.0.0`、`localhost`、`127.x.x.x`、`::1` |

## 管理员账号

| 变量 | 默认 | 说明 |
|---|---|---|
| `ADMIN_BOOTSTRAP_PASSWORD` | `ChangeMe123!` | 初始管理员密码。因为默认值非空，`install.sh` **不会**重新生成 —— 生产环境请务必改掉 |

登录用户名固定为 `admin@platform.local`。

## 网络与端口

| 变量 | 默认 | 说明 |
|---|---|---|
| `BIND_IP` | `0.0.0.0` | docker 把对外端口发布到哪张网卡。macOS 上必须保持 `0.0.0.0` |
| `CONSOLE_PORT` | `80` | **v0.0.1 下只影响安装横幅文案**，不改变实际端口映射（443/80 硬编码） |
| `BACKEND_PORT` | `8080` | backend 的宿主端口（仅回环） |
| `ALLOWED_ORIGINS` | 自动 | 后端 CORS 白名单。`install.sh` 自动维护，换访问地址时才需要手工追加 |

## TLS

| 变量 | 默认 | 说明 |
|---|---|---|
| `SSL_CERT_PATH` | `./certs/tls.crt` | 宿主侧证书路径。文件不存在时 `install.sh` 生成 365 天自签证书 |
| `SSL_KEY_PATH` | `./certs/tls.key` | 宿主侧私钥路径 |

容器内路径（`/etc/nginx/certs/…`）与 `SSL_ENABLE` / `SSL_REDIRECT` 都在 compose 里硬编码，本形态**总是**提供 HTTPS。

## 镜像

| 变量 | 默认 |
|---|---|
| `IMAGE_REGISTRY` | `quay.io/vmware-ai` |
| `LITELLM_IMAGE` | `litellm:v1.89.4` |
| `BACKEND_IMAGE` | `agent-platform-backend:latest` |
| `CONSOLE_IMAGE` | `agent-platform-console:latest` |
| `POSTGRES_IMAGE` | `postgres:16` |
| `REDIS_IMAGE` | `redis:7` |
| `PROMETHEUS_IMAGE` | `prometheus:v3.5.4` |
| `GRAFANA_IMAGE` | `grafana:10.4.0` |
| `OTEL_IMAGE` | `opentelemetry-collector-contrib:0.110.0` |

镜像切私有仓库只改 `IMAGE_REGISTRY` 一处即可；pin 具体版本改对应的 `*_IMAGE`。

## 首次运行自动生成

留空时由 `install.sh` 生成，**已有非空值不会被覆盖**：

| 变量 | 生成规则 |
|---|---|
| `LITELLM_MASTER_KEY` | `sk-local-<hex>` |
| `LITELLM_SALT_KEY` | 随机 |
| `POSTGRES_PASSWORD` | 随机 |
| `SECRETS_ENCRYPTION_KEY` | 32 字节 hex；同时镜像写入 `.secrets_encryption_key` |
| `SECRETS_ENCRYPTION_KEYS` | 仅密钥轮换等高级场景使用 |

::: danger `SECRETS_ENCRYPTION_KEY` 必须备份
它是解开 `platform_secrets` 表的唯一钥匙。丢失后所有加密凭据（vCenter 口令、上游 API Key）都无法解密。
:::

## 数据库与会话

| 变量 | 默认 | 说明 |
|---|---|---|
| `POSTGRES_USER` | `agentplatform_user` | 改动需重装，不支持热更新 |
| `POSTGRES_DB` | `agentplatform` | 同上 |
| `APP_ENV` | `prod` | 运行环境标识 |
| `DB_AUTO_MIGRATE` | `true` | 启动时自动迁移 |
| `SESSION_TTL_SECONDS` | `28800` | 会话有效期（8 小时） |

## Grafana

| 变量 | 默认 | 说明 |
|---|---|---|
| `GRAFANA_ADMIN_USER` | `admin` | 生产环境请覆盖 |
| `GRAFANA_ADMIN_PASSWORD` | `admin` | 生产环境请覆盖 |

## 后端运行时调优（可选）

留空时使用二进制内置默认值。改动后 `docker compose restart backend` 生效。

| 变量 | 用途 |
|---|---|
| `CONTROL_PLANE_URL` | 控制面对外 URL（下发给 VM） |
| `SECRETS_ROTATION_INTERVAL_SECONDS` | 密钥轮换周期 |
| `SECRETS_AUDIT_ENABLED` | 密钥操作审计开关 |
| `LITELLM_RECONCILE_INTERVAL_SECONDS` | 与网关的对账周期 |
| `PROVIDER_PROBE_INTERVAL_SECONDS` | 上游模型健康探测周期 |
| `OBS_SPEND_CACHE_TTL_SECONDS` | 计量聚合缓存 TTL |
| `PERM_CACHE_TTL_SECONDS` | 权限缓存 TTL |
| `POOL_SYNC_INTERVAL_SECONDS` | 资源池同步周期 |
| `POOL_SYNC_TIMEOUT_SECONDS` | 单次同步超时 |
| `POOL_SYNC_MAX_RETRIES` | 同步重试次数 |
| `POOL_SYNC_BREAKER_THRESHOLD` | 同步断路器阈值 |
| `POOL_SYNC_BREAKER_OPEN_SECONDS` | 断路器开启时长 |
| `DB_MAX_OPEN_CONNS` / `DB_MAX_IDLE_CONNS` / `DB_CONN_MAX_LIFETIME_MINUTES` | 连接池 |
| `AGENT_PKG_BASE_URL` | agent 版本包仓库地址（FTP 或 HTTP/S）；DB 平台设置优先，此处为兜底 |
| `AGENT_KEEP_VERSIONS` | VM 内保留的历史版本数 |
| `AGENT_USER` | VM 内默认运行账户 |
| `ENV_SCOPE_ENABLED` | 环境作用域开关 |

## 请求日志采集（可选）

| 变量 | 默认 | 说明 |
|---|---|---|
| `REQUESTLOG_INGEST_MODE` | `warn` | `warn` / `fail` / `off` |
| `OTEL_BATCH_TIMEOUT` | `1s` | 采集批处理超时 |
| `OTEL_BATCH_SIZE` | `1000` | 批大小 |
| `OTEL_FILE_MAX_MB` | `100` | 单文件上限 |
| `OTEL_FILE_MAX_DAYS` | `1` | 保留天数 |
| `OTEL_FILE_MAX_BACKUPS` | `3` | 保留份数 |

OTel 相关项改动后需重跑 `./install.sh up`（会重新渲染 collector 配置）。

## 改动后的重载范围

见 [升级与卸载 → 配置改动的重载范围](/install/upgrade#配置改动的重载范围)。
