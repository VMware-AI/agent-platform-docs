# 安全基线

平台默认是「能跑起来」的配置，不是「已加固」的配置。这一页是一份可勾选的基线清单 —— 装完之后按它过一遍，能挡掉绝大多数常见问题。

## 装完当天必做（🔴 高）

- [ ] **改掉 bootstrap 管理员口令**。默认 `ChangeMe123!`，`install.sh` 不会替你重新生成。→ [首次登录](/install/first-login)
- [ ] **改掉 Grafana 默认口令**。默认 `admin/admin`，且对外暴露在 3000 端口。在 `.env` 设 `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD` 后 `./install.sh up`。
- [ ] **备份 `.secrets_encryption_key` 与 `.env`** 到企业密钥库。丢了前者，所有加密凭据变成死数据。→ [备份清单](/install/upgrade#备份清单)
- [ ] **确认防火墙只放行必要端口**。对外只需 443；9090 / 3000 按需收敛。→ [端口与网络](/reference/ports)
- [ ] **给每个管理员建具名账号**，停止共用 `admin@platform.local`。否则审计日志追不到人。→ [用户与权限](/console/users)

## 第一周内做（🟡 中）

- [ ] **换掉自签名证书**，用企业 CA 或 Let's Encrypt。自签证书有效期只有 365 天，且会让 VM 侧的校验变复杂。→ [网络与证书](/install/network-tls)
- [ ] **配置 NSX 微分段**，特别是**禁止智能体 VM 之间的横向流量**。→ [微分段建议](/reference/ports#nsx-微分段建议)
- [ ] **给 vCenter 建专用角色**，别用 administrator，作用域限定到承载智能体的集群 / 文件夹。→ [权限清单](/console/resource-pools#vcenter-账号需要的权限)
- [ ] **收紧虚拟密钥作用域**：可调用模型按需给，可调用接口能只给 `CHAT` 就别全开。→ [密钥管理](/console/keys)
- [ ] **给密钥设消费上限与有效期**，至少给非核心用途的密钥设上。
- [ ] **观测岗一律 `read_only`**，不要因为「他要看数据」就发 admin。→ [角色与权限矩阵](/reference/roles)
- [ ] **确认智能体 VM 没有公网出口**（除非确有需要）。

## 持续做（🟢 例行）

- [ ] **每月导出审计日志归档**到企业日志平台。平台侧不提供无限期留存。→ [审计日志](/observability/audit-log)
- [ ] **定期检查「上次登录」**，长期不登录的账号先禁用。
- [ ] **人员变动当天处理**：禁用账号 → 禁用其智能体绑定的密钥 → 回收实例。
- [ ] **做一次恢复演练**，验证备份真的能用。→ [恢复演练](/install/upgrade#备份清单)
- [ ] **关注证书到期**（自签 365 天 / 企业证书按签发周期）。
- [ ] **关注许可到期**（试用 90 天）。

## 平台自带的安全设计

这些不需要你配置，但值得知道 —— 出问题时能少走弯路。

### 凭据

| 设计 | 说明 |
|---|---|
| 上游 API Key | 加密存 `platform_secrets` 表，用 `SECRETS_ENCRYPTION_KEY` 加密，**前端永不回显** |
| vCenter 口令 | 同上；编辑时留空即不修改 |
| 网关 Master Key | 仅随请求提交，不回显、不存浏览器 |
| VM 登录密码 | 部署时经 guestinfo / vApp 属性注入，**平台不存明文** |
| VM 本地状态 | `/var/lib/agent-manager/state.json`（`0600`）只存密码**指纹**与 VM token |
| 虚拟密钥明文 | 颁发时一次性展示，之后只有掩码 |
| 用户初始密码 | 自动生成时一次性展示 |

### 网络

| 设计 | 说明 |
|---|---|
| 单一入站面 | backend / litellm / pg / redis / otel 全部绑回环，只有 console 对外 |
| 强制 HTTPS | console 的 `SSL_ENABLE` / `SSL_REDIRECT` 硬编码为 true，80 端口只做跳转 |
| CORS 白名单 | `ALLOWED_ORIGINS` 由 install.sh 维护，未列入的来源一律拒绝 |
| 控制面不连 VM | 全部靠 VM 出站心跳，控制面 → VM 方向可以整个关掉 |
| VM 唯一入口 | 管理台经 nginx `/manage/` 反代，TLS + Basic Auth，进程本身只绑回环 |
| 双重认证 | nginx 查 htpasswd 后，应用再验一次透传的 Authorization 头 |

### 会话与认证

| 设计 | 说明 |
|---|---|
| 会话载体 | httpOnly cookie，JS 读不到 |
| 会话有效期 | 默认 8 小时（`SESSION_TTL_SECONDS`） |
| 强制改密 | 首次使用 bootstrap 口令或被重置后，登录即强制改密 |
| VM 改密节流 | 连续认证失败返回 429 |
| VM 密码自动轮换 | 默认 30 天，心跳时排队，同一时刻只允许一条在飞 |

### 写操作的边界

| 设计 | 说明 |
|---|---|
| 权限矩阵 | `read_only` 只有两个 view 权限，**写操作按构造只对 admin 开放** |
| 前端守卫 | 只是提前拦截，真正的判定在后端 GraphQL 层 |
| 破坏性操作 | 删除资源池 / 网关 / 模板 / 用户 / 密钥都要求手工输入名称二次确认 |
| 审计不可改 | 审计日志只增不改，平台不提供编辑 / 删除入口 |
| 部署失败回滚 | 任一步失败 `vm.destroy`，不留半成品 |

### 供应链与完整性

| 设计 | 说明 |
|---|---|
| 镜像包完整性（气隙安装时） | 自造镜像包用 `make package-images-amd64` 出，内含 `images/SHA256SUMS`，`install.sh` 自动校验 |
| 知识包 | sha256 三重校验 + 防路径穿越解压 + 原子切换 |
| agent 版本包 | sha256 校验；**明文 `http://` 源强制要求提供摘要** |
| 升级失败 | 自动回滚到上一版本 |

## 常见的错误做法

::: danger 这几件事别做
| 做法 | 后果 |
|---|---|
| 给「想看数据的领导」发 admin | 他能删资源池、吊销全部密钥 |
| 多台智能体共用一把密钥 | 成本无法归属，出事无法精确止血 |
| 把 `.env` / `.secrets_encryption_key` 放共享盘 | 等于把平台全部凭据放共享盘 |
| 一直用 `admin@platform.local` | 审计日志失去追责能力 |
| 不配微分段，VM 之间互通 | 一台被攻破 = 全部被攻破，「一人一 VM」白隔离 |
| 让 VM 直连公网 | 数据出域，平台的核心价值没了 |
| 人走了只删账号不管密钥和实例 | 密钥还能用，机器还在跑 |
:::

## 事件响应速查

发现某台智能体行为异常时的止血顺序：

<ol class="ap-steps">
<li><strong>禁用它绑定的虚拟密钥</strong> —— 一秒生效，该实例所有模型调用立刻 401。这是最快的刹车。</li>
<li><strong>停止实例</strong> —— 在<a href="/console/agents">智能体实例</a>页停机，保留磁盘用于取证。</li>
<li><strong>查调用记录</strong> —— <a href="/observability/request-log">请求日志</a>按该智能体 ID 筛，确认影响面与时间窗。</li>
<li><strong>查操作轨迹</strong> —— <a href="/observability/audit-log">审计日志</a>看这台机器与这把密钥的全部变更，含操作者与 IP。</li>
<li><strong>查成本</strong> —— <a href="/observability/metering">计量中心</a>按智能体下钻，看是否有异常消耗。</li>
<li><strong>处置</strong> —— 确认后回收实例、吊销密钥、必要时禁用相关账号。</li>
</ol>

::: tip 先禁密钥，别先删机器
删掉机器会让实例转「已回收」，取证材料就没了。正确顺序是**先切断能力（禁密钥），再停机保留现场，最后才处置**。
:::
