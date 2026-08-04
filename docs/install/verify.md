# 健康检查

`install.sh` 结尾会自动跑一次 `./verify.sh`。任何时候都可以手工重跑：

```bash
cd /opt/agent-platform/agent-platform-dc-standalone-0.0.1
./verify.sh
```

它检查三类目标：**容器状态**、**HTTP 探针**、**Prometheus 抓取状态**。全部通过时静默退出 0。

::: tip 把 verify.sh 当作分诊工具
它全绿 = 平台自身健康，后续问题基本都在配置层（vCenter、网关地址、密钥、静态 IP）。它有红 = 先把平台修好，别急着查业务。
:::

## 一、容器层

```bash
docker compose -p agent-platform ps
```

8 个容器都应为 `running` / `healthy`：

| 容器 | 期望状态 | 挂了会怎样 |
|---|---|---|
| `agent-platform-console` | running | 控制台完全打不开 |
| `agent-platform-backend` | running | 控制台白屏 / `/query` 502 |
| `litellm` | running | 所有模型调用失败 |
| `postgres` | healthy | backend 起不来 |
| `redis` | healthy | 缓存与限流失效 |
| `litellm-prometheus` | running | 实时监控无数据 |
| `grafana` | running | 内置仪表盘打不开（不影响业务） |
| `otel-collector` | running | 请求日志采不到（不影响调用本身） |

看某个容器为什么退出：

```bash
docker compose -p agent-platform ps -a          # 含已退出的
docker compose -p agent-platform logs --tail=100 <服务名>
```

## 二、HTTP 探针

```bash
# 数据面网关
curl -fsS http://localhost:4000/health/liveliness

# 控制面后端
curl -fsS "http://localhost:${BACKEND_PORT:-8080}/healthz"

# 控制台 SPA（自签证书 → 加 -k）
curl -fsSk "https://${EXTERNAL_IP}/"

# Prometheus
curl -fsS "http://${EXTERNAL_IP}:9090/-/ready"

# Grafana
curl -fsS "http://${EXTERNAL_IP}:3000/api/health"

# OTel collector（OTLP/HTTP 接收端口，返回 4xx 即视为在监听）
curl -sS -o /dev/null -w '%{http_code}\n' http://localhost:4318/v1/traces
```

::: tip 宿主到 EXTERNAL_IP 不通、但容器其实正常
在 Mac / OrbStack 等环境下偶尔会出现宿主访问不到 `EXTERNAL_IP` 的情况。从容器内部再验一次就能区分：

```bash
docker exec grafana wget -qO- --timeout=3 http://console:443/
```
:::

## 三、Prometheus 是否真的在抓 litellm

只 ready 不够，还要确认目标处于 `up`：

```bash
curl -fsS "http://${EXTERNAL_IP}:9090/api/v1/targets?state=active" | grep '"health":"up"'
```

应当至少有 **2 个 up 目标**（litellm + prometheus 自身）。

::: warning 抓取失败通常是密钥不同步
`prometheus.yml` 由 `prometheus.yml.tmpl` 在每次 `install.sh` 时渲染，把 `LITELLM_MASTER_KEY` 代入 Bearer 凭据。手工改过 master key 却没重跑 `install.sh`，抓取就会 401。

修法：重跑 `./install.sh`（会重新渲染），或直接 `./install.sh up`。
:::

## 四、端到端 GraphQL

验证「浏览器 → console → backend」整条链路：

```bash
curl -fsS -X POST "http://localhost:${BACKEND_PORT:-8080}/query" \
  -H 'Content-Type: application/json' \
  -d '{"query":"{ __typename }"}'
```

应返回：

```json
{"data":{"__typename":"Query"}}
```

再验一次经由 console 反代的路径（这才是浏览器真正走的）：

```bash
curl -fsSk -X POST "https://${EXTERNAL_IP}/query" \
  -H 'Content-Type: application/json' \
  -H "Origin: https://${EXTERNAL_IP}" \
  -d '{"query":"{ __typename }"}'
```

::: tip 带 Origin 头验 CORS
第二条命令加了 `Origin` 头 —— 如果返回 CORS 错误，说明 `.env` 的 `ALLOWED_ORIGINS` 没包含这个 URL。这比在浏览器里点半天更快定位。
:::

## 五、数据库连通

```bash
# 平台库
docker compose -p agent-platform exec postgres \
  psql -U agentplatform_user -d agentplatform -c '\dt' | head

# 网关库
docker compose -p agent-platform exec postgres \
  psql -U agentplatform_user -d litellm -c '\dt' | head
```

两个库都应该有表 —— 平台库空表说明迁移没跑成功。

## 六、日志速查

```bash
# 单服务
docker compose -p agent-platform logs -f --tail=100 backend
docker compose -p agent-platform logs -f --tail=100 litellm
docker compose -p agent-platform logs -f --tail=100 console

# 全部
docker compose -p agent-platform logs -f --tail=50

# 进容器
docker compose -p agent-platform exec backend sh
docker compose -p agent-platform exec postgres psql -U agentplatform_user agentplatform
```

## 七、从平台自身看健康

装完之后也可以从控制台看，两个视角互补：

| 视角 | 看什么 |
|---|---|
| [总览仪表盘](/console/overview) | 平台组件健康、实例状态分布、异常与待处理事项 |
| [实时监控](/observability/monitor) | 上游健康（各网关的健康 / 异常端点清单） |

## 日常巡检建议

| 频率 | 做什么 |
|---|---|
| 每天 | 看总览仪表盘的「异常与待处理事项」，空的就没事 |
| 每周 | 跑一次 `./verify.sh`；看[计量中心](/observability/metering)本周花费是否异常 |
| 每月 | 导出[审计日志](/observability/audit-log)归档；检查磁盘余量；确认备份文件仍在 |
| 变更后 | 任何 `.env` 改动或升级之后，重跑 `./verify.sh` |

排查具体故障 → [故障排查](/install/troubleshooting)
