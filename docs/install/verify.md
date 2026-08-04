# 健康检查

`install.sh` 结尾会自动跑一次 `./verify.sh`。任何时候都可以手工重跑：

```bash
cd /opt/agent-platform/agent-platform-dc-standalone-0.0.1
./verify.sh
```

它检查三类目标：**容器状态**、**HTTP 探针**、**Prometheus 抓取状态**。全部通过时静默退出 0。

## 一、容器层

```bash
docker compose -p agent-platform ps
```

8 个容器都应为 `running` / `healthy`：

| 容器 | 期望状态 |
|---|---|
| `agent-platform-console` | running |
| `agent-platform-backend` | running |
| `litellm` | running |
| `postgres` | healthy |
| `redis` | healthy |
| `litellm-prometheus` | running |
| `grafana` | running |
| `otel-collector` | running |

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

## 三、Prometheus 是否真的在抓 litellm

只 ready 不够，还要确认目标处于 `up`：

```bash
curl -fsS "http://${EXTERNAL_IP}:9090/api/v1/targets?state=active" | grep '"health":"up"'
```

应当至少有 2 个 up 目标（litellm + prometheus 自身）。

::: warning 抓取失败通常是密钥问题
`prometheus.yml` 由 `prometheus.yml.tmpl` 在每次 `install.sh` 时渲染，把 `LITELLM_MASTER_KEY` 代入 Bearer 凭据。手工改过 master key 却没重跑 `install.sh`，抓取就会 401。
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

## 五、日志速查

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

## 六、平台自身的健康视图

安装后也可以从控制台看：**总览仪表盘 → 平台组件健康**，展示后端服务、网关、数据库等组件的实时状态，以及智能体实例的运行 / 停止 / 异常分布。

排查具体故障 → [故障排查](/install/troubleshooting)
