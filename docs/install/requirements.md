# 环境要求

v0.0.1 发布 **4 个安装包**（`dc-standalone` / `dc-distribution` / `k8s-standalone` / `k8s-ha`），各自的 `install.sh` 各自完成安装。本页以 `dc-standalone` 为主说明主机要求，其他形态的差异在对应章节补述。

> **离线安装的语义变了**
>
> v0.0.1 **不再随 release 发布离线镜像包**。`install.sh` 默认直接从 `quay.io/vmware-ai/<image>` 拉取 —— 目标机需要能访问 `quay.io`。
>
> 完全离网 / 气隙环境请先用部署仓库的 `make package-images-amd64`（或 `package-images-arm64`）造一个同名同结构的镜像包，作为同级目录放好后 `install.sh` 会自动 `docker load`，网络要求归零。详见 [离线安装（单机）](/install/dc-standalone#离线安装可选气隙环境)。

## 平台主机

| 项目 | 要求 |
|---|---|
| 操作系统 | Linux（x86_64 / amd64 或 aarch64 / arm64）。`install.sh` 自动匹配主机架构 |
| Docker | Docker Engine + **compose 插件**（`docker compose version` 可用，不是老的 `docker-compose`） |
| 磁盘 | `/var` 至少 **5 GB** 空闲（preflight 会告警）；**建议 100 GB 以上** |
| 内存 | 建议 8 GB 以上 |
| CPU | 4 核以上 |
| 网络（默认在线安装） | 一张有固定 IP 的网卡；**目标机需要能访问 `quay.io`** |
| 网络（气隙安装） | 仅需访问平台主机自身的本地回环（`docker load` 走本地镜像包） |
| 权限 | 能执行 docker 命令；使用 1024 以下端口需 root 或 `CAP_NET_BIND_SERVICE` |

### 容量规划

单机形态下磁盘主要被这几样吃掉：

| 项目 | 量级 |
|---|---|
| 镜像（`docker load` 或 `docker pull` 后） | 约 5–8 GB |
| PostgreSQL（平台元数据 + 网关账单） | 起步几百 MB，随请求日志与账单线性增长 |
| Prometheus 时序 | 按抓取密度，月级几 GB |
| Grafana / Redis | 很小 |

::: tip 请求日志是主要增长源
调用量大的环境里，`agentplatform` 库的请求日志表增长最快。规划时按「每天多少次调用 × 保留多久」估算，并定期做归档导出（[审计日志](/observability/audit-log)与[请求日志](/observability/request-log)都支持 CSV 导出）。
:::

::: warning 架构必须匹配
`install.sh` / preflight 会检查主机架构并选择对应的镜像。如果用自造的镜像包，必须选跟主机架构一致的那个（amd64 ↔ `linux/amd64`、arm64 ↔ `linux/arm64`）。

### 装之前先自查

```bash
# 系统与架构
uname -m                      # 期望 x86_64
cat /etc/os-release

# docker 与 compose 插件
docker version
docker compose version        # 必须能跑通

# 磁盘
df -h /var                    # ≥ 5 GB 空闲

# 端口是否被占
ss -lntp | grep -E ':(80|443|3000|9090)\b'

# 本机 IP —— 这个值待会要填进 EXTERNAL_IP
hostname -I
```

## 需要放行的主机端口

| 端口 | 服务 | 绑定 | 用途 |
|---|---|---|---|
| **443** | console | `${BIND_IP}`（默认 `0.0.0.0`） | 控制台 HTTPS —— **必须放行** |
| 80 | console | `${BIND_IP}` | HTTP → HTTPS 跳转 |
| 9090 | prometheus | `${BIND_IP}` | 抓取状态（可选对外） |
| 3000 | grafana | `${BIND_IP}` | 内置仪表盘（可选对外） |
| 8080 | backend | `127.0.0.1` | 仅回环，由 console 反代 |
| 4000 | litellm | `127.0.0.1` | 仅回环 |
| 5433 / 6379 | postgres / redis | `127.0.0.1` | 仅回环 |
| 4317 / 4318 | otel-collector | `127.0.0.1` | 仅回环，请求日志采集 |

::: tip 只对外开 443 就够
9090 和 3000 默认也绑在对外网卡上。安全要求高的环境可以把 `BIND_IP` 指到管理网段的网卡，或用主机防火墙只放行 443。
:::

完整清单见[端口与网络](/reference/ports)。

## vCenter（部署智能体所需）

| 项目 | 要求 |
|---|---|
| vSphere | 支持 Content Library 的版本；接入时平台会显示探测到的 vSphere 版本 |
| 内容库 | 已导入智能体 OVA/OVF 模板的 Content Library |
| 网络 | 平台主机能访问 vCenter 443；智能体 VM 所在端口组能出站访问**控制面 443** 与**模型网关地址** |
| 证书 | 自签名 / 内网 CA 的 vCenter 可在接入时勾选「跳过 TLS 验证」，生产环境建议保持验证 |

### vCenter 账号权限

| 操作 | 需要的权限 |
|---|---|
| 读清单（集群 / 主机 / 数据存储 / 网络 / 文件夹 / 存储策略） | 只读 |
| 从内容库部署 | 内容库项读取、部署 OVF 模板 |
| 克隆虚拟机 | 虚拟机 → 置备 → 克隆 |
| 注入 guestinfo / vApp 属性 | 虚拟机 → 配置 → 高级配置、修改设备设置 |
| 开关机、重启 | 虚拟机 → 交互 |
| 调整 CPU / 内存 / 磁盘 | 虚拟机 → 配置 |
| 删除虚拟机 | 虚拟机 → 清单 → 移除 |
| 快照与回滚 | 虚拟机 → 快照管理 |

::: tip 用专用角色，别用 administrator
建一个专用角色按上表授权，作用域限定在承载智能体的集群 / 文件夹上。出问题时爆炸半径可控，审计也说得清。
:::

## 模型网关

平台通过 **LiteLLM Proxy** 代理全部模型调用。`dc-standalone` 已内置一个 litellm 容器（回环 4000），也可以接入外部已有实例。接入时需要：

| 项 | 单机形态下的典型值 |
|---|---|
| 网关地址（控制面用） | `http://litellm:4000` |
| **Agent 访问地址**（VM 用） | `https://<EXTERNAL_IP>/litellm/` |
| Master Key | 安装 banner 会打印，或 `grep ^LITELLM_MASTER_KEY .env` |

::: danger 为什么要单独填 Agent 访问地址
控制面和智能体 VM 处在不同网络位置：控制面可以走容器网络内的 `http://litellm:4000`，而 VM 只能走对外的 HTTPS 入口。两个地址分开填，避免把内部地址下发到 VM 里 —— 那会导致「控制台一切正常，agent 却调不通模型」。
:::

## 上游模型

至少准备一个可用的上游模型，用于在[模型管理](/console/models)中登记：

| 项 | 说明 |
|---|---|
| 供应商分类 | `custom`（任意 OpenAI 兼容端点）/ `openai` / `anthropic` / `deepseek` / `minimax` / `moonshot` / `openrouter` |
| 上游模型原名 | 厂商侧的真实模型名 |
| API Base | 上游服务地址，内网私有模型服务也可以 |
| API Key | 后端加密入库 |
| **单价** | 输入 / 输出 token 单价 —— 不填就算不出成本 |

::: tip 内网推理服务选 custom
vLLM、SGLang、Xinference、Ollama 等基本都提供 OpenAI 兼容接口，选 `custom` 并把 API Base 指过去即可。
:::

## 交付物清单

从 [release v0.0.1](https://github.com/VMware-AI/agent-platform-deployment/releases/tag/v0.0.1) 下载对应形态的 tarball（每个 tarball 自带 `SHA256SUMS`）：

| 文件 | 说明 |
|---|---|
| `agent-platform-dc-standalone-0.0.1.tar.gz` | docker-compose 单机，自包含：脚本 + compose + 配置 + 文档 |
| `agent-platform-dc-distribution-0.0.1.tar.gz` | docker-compose 多服务（控制面 + 网关 DB 分离），自包含 |
| `agent-platform-k8s-standalone-0.0.1.tar.gz` | k8s 小集群（自带 PG/Redis StatefulSet），Helm chart 自包含 |
| `agent-platform-k8s-ha-0.0.1.tar.gz` | k8s 生产 HA（外部 PG/Redis，≥2 副本），Helm chart 自包含 |

::: tip 离线镜像包不再随 release 发布
默认安装由 `install.sh` 从 `quay.io/vmware-ai/*` 拉镜像。**如果目标机无法访问 `quay.io`**，先在能访问的机器上从 `agent-platform-deployment` 仓库跑 `make package-images-amd64`（或 `package-images-arm64`），把产出的 `agent-platform-images-<ver>-amd64.tar.gz` 作为同级目录放到目标机后，`install.sh` 会自动走 `docker load`。
:::

## 安装前检查清单

- [ ] Linux 主机（amd64 或 arm64），`docker compose version` 可用
- [ ] `/var` 空闲 ≥ 5 GB（建议 100 GB）
- [ ] 确定了 `EXTERNAL_IP`（真实网卡 IP 或 DNS 名，不是 `127.0.0.1`）
- [ ] 443 / 80 端口没被占用，防火墙已放行 443
- [ ] 目标机到 `quay.io` 443 通（默认安装）；或离线镜像包已同级备好（气隙安装）
- [ ] 拿到 vCenter 地址与专用账号，权限按上表配好
- [ ] 内容库里已导入智能体 OVA 模板
- [ ] 准备好至少一个上游模型的 API Base + API Key + 单价
- [ ] 安装包已下载并校验 SHA256

齐了就可以开始 → [离线安装（单机）](/install/dc-standalone)
