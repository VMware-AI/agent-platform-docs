# 故障排查

## 排查顺序

遇到问题时按这个顺序缩小范围，通常两三步就能定位：

<ol class="ap-steps">
<li><code>./verify.sh</code> —— 一次跑完全部探针，看哪一项先红。</li>
<li><code>docker compose -p agent-platform ps</code> —— 是容器没起来，还是起来了但不健康。</li>
<li><code>docker compose -p agent-platform logs --tail=100 &lt;服务&gt;</code> —— 看具体报错。</li>
<li>控制台「审计日志」 —— 如果是某个操作失败，这里有操作者、动作、结果与失败原因。</li>
</ol>

## 安装与访问

| 现象 | 第一手排查 |
|---|---|
| `install.sh` 报 `EXTERNAL_IP` 非法 | 必须填真实网卡 IP 或 DNS 名，不接受空值 / `0.0.0.0` / `localhost` / `127.x.x.x` / `::1` |
| 浏览器完全打不开控制台 | 确认防火墙放行 443；`docker compose ps` 看 console 容器是否 running；确认用的是 `https://` |
| 浏览器提示证书不受信 | 正常 —— 自签名证书。点「高级 → 继续访问」，或换自有证书（[网络与证书](/install/network-tls)） |
| 控制台白屏 / 登录后请求全红 | 多半是 CORS：`.env` 的 `ALLOWED_ORIGINS` 不含你正在用的 URL。追加后 `docker compose restart backend` |
| console `/query` 返回 502 | `docker compose logs backend` —— 通常是数据库迁移未完成或 `DATABASE_URL` 有问题 |
| backend 起不来 | `docker compose logs backend` —— 多为 `DATABASE_URL` 或 `SECRETS_ENCRYPTION_KEY` 缺失/不匹配 |
| litellm `/key/generate` 返回 500 | `docker compose logs litellm` —— 首次启动时 DB schema 还在迁移，约需 10 秒 |
| prometheus 抓取返回 401 / 502 | `prometheus.yml` 里的 Bearer 凭据与当前 master key 不一致，重跑 `./install.sh` 重新渲染 |
| preflight 告警架构不匹配 | 下载与主机架构一致的镜像包；v0.0.1 只发布 amd64 |
| preflight 告警磁盘不足 | `/var` 需 ≥ 5 GB 空闲 |

## 资源池 / vCenter

| 现象 | 排查 |
|---|---|
| 「测试连接」失败 | 平台主机能否 `curl -k https://<vc>/`；账号口令是否正确；自签 vCenter 需勾选「跳过 TLS 验证」 |
| 内容库下拉为空 | 先点「测试连接」，成功后才会加载内容库列表；确认该 vCenter 上确实有 Content Library |
| 资产（集群 / 网络 / 数据存储）为空 | 资源池尚未同步，在列表里点「立即同步」，稍后刷新 |
| 部署对话框里资源池 / 端口组 / 数据存储下拉为空 | 同上；同步完成前这些下拉都取不到值 |
| OVA 模板列表为空 | 内容库里没有可用的 OVF/OVA 模板，或选错了内容库 |

## 模型网关 / 模型

| 现象 | 排查 |
|---|---|
| 网关「测试连接」失败 | 网关地址是否控制面可达；Master Key 是否正确 |
| 网关状态「未同步」 | 点「立即同步」；看「同步日志概要」里的失败原因 |
| 模型健康状态「熔断」 | 上游不可达或 API Key 失效。在模型管理里重新「探测」；确认无误后可「解除熔断」 |
| 模型健康状态「未探测」 | 尚未触发过探测，点「检测健康」 |
| 智能体调用模型 401 | 虚拟密钥被禁用 / 过期 / 超预算，或作用域不含该模型。到[密钥管理](/console/keys)查看状态与消费进度 |
| 智能体调用模型超时 | 检查 VM 到「Agent 访问地址」的网络连通性，而不是控制面到网关的连通性 —— 两个地址不同 |

## 智能体部署

| 现象 | 排查 |
|---|---|
| 部署立即失败 | 看审计日志的失败原因；常见为 vCenter 权限不足、名称冲突、目标数据存储空间不足 |
| 长时间停在「部署中」 | VM 已克隆开机但没能注册。检查：① VM 是否拿到 IP（静态 IP 配错很常见）② VM 能否出站访问控制面 443 |
| 状态变「异常」 | 心跳超时。VM 是否关机、网络是否中断、agent-manager 服务是否在跑（`systemctl status agent-manager`） |
| 批量部署部分成功 | 逐台看实例状态；失败的实例可删除后重试，成功的不受影响 |
| 拿不到访问信息 | 实例需处于运行中且已上报 IP；异常状态实例不支持配置操作 |

## 日志与观测

| 现象 | 排查 |
|---|---|
| 请求日志一直为空 | 确认智能体确实通过网关调用了模型；确认 otel-collector 容器在跑；查 backend 日志里 requestlog 摄入相关行 |
| 计量中心无数据 | 换「数据源」为「网关记录（litellm）」对比；放宽时间范围；确认所选智能体 / 模型筛选没有过窄 |
| 实时监控图表空白 | 该时间窗内确实没有调用；或 prometheus 抓取异常（见上文 401 条目） |
| 仪表盘费用为 0 | 模型未配置单价。到[模型管理](/console/models)补价格，或在[计量设置](/observability/metering-settings)里选择价格缺失时的处理策略 |

## 权限

| 现象 | 排查 |
|---|---|
| 页面点进去被弹回总览 | 当前角色无权访问该页。见 [角色与权限矩阵](/reference/roles) |
| 按钮点了提示「你没有权限执行此操作」 | 该操作需要 `admin`；`read_only` 只能看 |
| 新建用户后对方登录失败 | 确认账户「启用状态」为已启用；自动生成的密码只显示一次，遗失需重置密码 |

## 收集诊断信息

需要向支持人员求助时，一次性打包这些：

```bash
cd /opt/agent-platform/agent-platform-dc-standalone-0.0.1

./verify.sh                                             > /tmp/verify.txt 2>&1
docker compose -p agent-platform ps -a                  > /tmp/ps.txt
docker compose -p agent-platform logs --tail=500        > /tmp/logs.txt
grep -vE 'PASSWORD|KEY|SECRET' .env                     > /tmp/env-sanitized.txt

tar -czf /tmp/agent-platform-diag.tar.gz -C /tmp verify.txt ps.txt logs.txt env-sanitized.txt
```

::: warning 脱敏
`.env` 含 master key、数据库口令与管理员初始口令。上面的 `grep -v` 已过滤常见字段，发送前请再人工确认一遍。
:::
