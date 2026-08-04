# 故障排查

## 排查顺序

遇到问题按这个顺序缩小范围，通常两三步就能定位：

<ol class="ap-steps">
<li><code>./verify.sh</code> —— 一次跑完全部探针，看哪一项先红。</li>
<li><code>docker compose -p agent-platform ps</code> —— 是容器没起来，还是起来了但不健康。</li>
<li><code>docker compose -p agent-platform logs --tail=100 &lt;服务&gt;</code> —— 看具体报错。</li>
<li>控制台<a href="/observability/audit-log">审计日志</a> —— 如果是某个操作失败，这里有操作者、动作、资源、结果与失败原因。</li>
</ol>

::: tip 先分清是「平台的问题」还是「配置的问题」
`verify.sh` 全绿 = 平台本身健康。这时候的故障几乎都在**配置层**（vCenter 权限、网关地址、密钥作用域、静态 IP 冲突），去对应的控制台页面查，不要再翻容器日志。
:::

## 安装与访问

| 现象 | 第一手排查 |
|---|---|
| `install.sh` 报 `EXTERNAL_IP` 非法 | 必须填真实网卡 IP 或 DNS 名，不接受空值 / `0.0.0.0` / `localhost` / `127.x.x.x` / `::1` |
| preflight 告警架构不匹配 | 下载与主机架构一致的镜像包；v0.0.1 只发布 amd64 |
| preflight 告警磁盘不足 | `/var` 需 ≥ 5 GB 空闲 |
| `docker compose version` 报错 | 装的是老的 `docker-compose` 独立二进制，需要 compose **插件** |
| 浏览器完全打不开控制台 | ① 防火墙放行 443 ② `docker compose ps` 看 console 是否 running ③ 确认用的是 `https://` |
| 浏览器提示证书不受信 | 正常 —— 自签名证书。点「高级 → 继续访问」，或换自有证书（[网络与证书](/install/network-tls)） |
| 控制台白屏 / 登录后请求全红 | 多半是 CORS：`.env` 的 `ALLOWED_ORIGINS` 不含你正在用的 URL。追加后 `docker compose -p agent-platform restart backend` |
| console `/query` 返回 502 | `docker compose logs backend` —— 通常是数据库迁移未完成或 `DATABASE_URL` 有问题 |
| backend 起不来 | `docker compose logs backend` —— 多为 `DATABASE_URL` 或 `SECRETS_ENCRYPTION_KEY` 缺失 / 不匹配 |
| litellm `/key/generate` 返回 500 | `docker compose logs litellm` —— 首次启动时 DB schema 还在迁移，约需 10 秒 |
| prometheus 抓取 401 / 502 | `prometheus.yml` 的 Bearer 凭据与当前 master key 不一致，重跑 `./install.sh` 重新渲染 |
| 端口被占用 | 用 `ss -lntp` 找占用者；改 compose 的宿主端口或停掉占用进程 |
| 忘记管理员密码 | 改 `.env` 的 `ADMIN_BOOTSTRAP_PASSWORD` 后 `docker compose -p agent-platform restart backend` |

## 资源池 / vCenter

| 现象 | 排查 |
|---|---|
| 「测试连接」失败 | 平台主机能否 `curl -k https://<vc>/`；账号口令是否正确；自签 vCenter 需勾选「跳过 TLS 验证」 |
| 内容库下拉为空 | 必须先点「测试连接」；确认该 vCenter 上确实有 Content Library，且账号有读权限 |
| 资产（集群 / 网络 / 数据存储）为空 | 尚未同步，点「立即同步」后稍等 |
| 同步状态「部分同步」 | 账号对部分对象无读权限，或某数据中心不可达；看资产里缺哪一类，对照[权限表](/console/resource-pools#vcenter-账号需要的权限)补 |
| 同步状态「失败」 | 凭据过期或网络中断；编辑资源池重填密码后再同步 |
| 部署对话框里下拉为空 | 同上，资产没同步完成 |
| OVA 模板列表为空 | 内容库里没有 OVF/OVA 模板，或选错了内容库 |
| 部署报权限错误 | vCenter 账号缺克隆 / 改 vApp 属性 / 开关机 / 删除 VM 的权限 |

## 模型网关 / 模型

| 现象 | 排查 |
|---|---|
| 网关「测试连接」失败 | 网关地址是否**控制面**可达；Master Key 是否正确 |
| 网关状态「未同步」 | 点「立即同步」；看「同步日志概要」里的失败原因 |
| 网关状态「部分异常」 | 部分模型 / 策略推送失败，日志概要里有原因 |
| 后端模型数为 0 | 尚未登记模型，或推送全部失败 |
| 模型健康「熔断」 | 上游不可达或 API Key 失效。重新「探测」；修好后**手工「解除熔断」** |
| 模型健康「未探测」 | 尚未触发过探测，点「检测健康」 |
| 智能体调用 401 | 虚拟密钥被禁用 / 过期 / 吊销 / 超预算，或作用域不含该模型 |
| 智能体调用 403 | 请求的**接口类型**不在密钥的可调用接口作用域内 |
| 智能体调用 404 | 请求里写的不是**路由名** |
| 智能体调用 429 | 触发 RPM / TPM / 并发限制 |
| **控制台测试正常但 agent 调不通** | 两者用的是不同地址 —— 排查 VM 到「**Agent 访问地址**」的连通性 |

::: danger 「控制台正常但 agent 不通」是最高频的坑
控制台「测试连接」验的是**网关地址**（控制面视角）。agent 用的是**Agent 访问地址**（VM 视角）。这两个填成同一个内部地址，就会出现控制台全绿但 agent 全超时。

在 VM 里直接验一下最快：

```bash
curl -sk -o /dev/null -w '%{http_code}\n' https://<EXTERNAL_IP>/litellm/health/liveliness
```
:::

## 智能体部署

| 现象 | 排查 |
|---|---|
| 部署立即失败 | 看[审计日志](/observability/audit-log)（类别=智能体、动作=部署、结果=失败）的原因：vCenter 权限不足、名称冲突、数据存储空间不足 |
| 长时间停在「部署中」 | ① VM 是否拿到 IP（**静态 IP 配错最常见**）② VM 能否出站访问控制面 443 ③ vCenter Console 里看 VM 是否真的起来了 |
| 起来了但状态「异常」 | 心跳没通。VM 内 `systemctl status agent-manager`、`journalctl -u agent-manager -f` |
| 批量部署部分成功 | 逐台看状态；失败的删除后重试，成功的不受影响 |
| vCenter 里找不到那台 VM | 部署失败已自动 `vm.destroy` 回滚，不留半成品 |
| 拿不到访问信息 | 实例需运行中且已上报 IP；异常状态实例不支持配置操作 |
| 配置保存失败 | 看变更确认里的字段；常见为 vCenter 资源不足或权限不够 |
| 想缩 CPU / 内存但不让改 | 运行中只支持扩容，先停止实例；**磁盘任何状态下都只能扩** |

### 智能体「异常」的排查脚本

SSH 进那台 VM：

```bash
# 服务状态
systemctl status agent-manager agent-manager-webadmin

# 最近日志（找心跳失败原因）
sudo journalctl -u agent-manager -n 100 --no-pager

# 网络：能不能到控制面
curl -sk -o /dev/null -w '%{http_code}\n' https://<控制面IP>/

# 网络：能不能到网关
curl -sk -o /dev/null -w '%{http_code}\n' https://<控制面IP>/litellm/health/liveliness

# 本机 IP 与路由是否正常
ip -4 addr; ip route
```

## 日志与观测

| 现象 | 排查 |
|---|---|
| 请求日志一直为空 | ① 智能体是否真的调用过模型（看实时监控请求量）② `otel-collector` 容器是否 running ③ 在 backend 日志里搜 `requestlog` 相关报错 |
| 计量中心无数据 | 切换「数据源」对比；放宽时间范围；确认筛选没过窄 |
| 实时监控图表空白 | 该时间窗内确实没有调用；或 prometheus 抓取异常（见上文 401 条目） |
| 仪表盘费用为 0 | 模型未配置单价 → [模型管理](/console/models) |
| 大量记录「未归属」 | 密钥没绑定智能体，或实例已彻底删除 |
| 平台记录与网关记录差异大 | 请求日志采集有丢失，检查 otel-collector |

## 权限

| 现象 | 排查 |
|---|---|
| 页面点进去被弹回总览 | 当前角色无权访问该页，见[角色与权限矩阵](/reference/roles) |
| 按钮提示「你没有权限执行此操作」 | 该操作需要 `admin`；`read_only` 只能看 |
| 新建用户后对方登录失败 | 确认「启用状态」为已启用；自动生成的密码只显示一次，遗失需重置 |
| 审计里全是同一个 admin | 大家共用 bootstrap 账号，给每人建具名 admin |

## 收集诊断信息

需要向支持人员求助时，一次性打包：

```bash
cd /opt/agent-platform/agent-platform-dc-standalone-0.0.1

./verify.sh                                             > /tmp/verify.txt 2>&1
docker compose -p agent-platform ps -a                  > /tmp/ps.txt
docker compose -p agent-platform logs --tail=500        > /tmp/logs.txt
docker version; docker compose version                  > /tmp/docker.txt 2>&1
grep -vE 'PASSWORD|KEY|SECRET' .env                     > /tmp/env-sanitized.txt

tar -czf /tmp/agent-platform-diag.tar.gz -C /tmp \
  verify.txt ps.txt logs.txt docker.txt env-sanitized.txt
```

一并附上：

- 「关于」对话框里的**平台版本号**
- 问题的**具体时间点**（方便对日志和审计）
- 涉及的**智能体名称 / 请求 ID**（如果有）

::: warning 脱敏
`.env` 含 master key、数据库口令与管理员初始口令。上面的 `grep -v` 已过滤常见字段，发送前请再人工确认一遍。
:::

## 还是没解决

- 逐项对照 [健康检查](/install/verify) 确认平台自身健康
- 翻一遍 [常见问题](/reference/faq)
- 确认不是[网络与证书](/install/network-tls)里的地址配置问题
