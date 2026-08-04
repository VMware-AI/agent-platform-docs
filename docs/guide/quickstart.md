# 快速开始

从一台空白 Linux 主机到「第一个智能体跑起来」，大约 60–90 分钟，其中安装本身只需 1–2 分钟。

::: tip 你需要准备
- 一台已装 Docker 的 Linux 主机（详见 [环境要求](/install/requirements)）
- 一套 vCenter 的地址与账号（用来克隆智能体 VM）
- 一个可用的 LiteLLM 网关地址与 Master Key（可与平台同机部署）
- v0.0.1 的两个 tarball：安装包 + amd64 离线镜像包
:::

## 一、装平台

```bash
mkdir -p /opt/agent-platform && cd /opt/agent-platform

# 两个 tarball 解到同级目录
tar -xzf /path/to/agent-platform-images-0.0.1-amd64.tar.gz
tar -xzf /path/to/agent-platform-dc-standalone-0.0.1.tar.gz

cd agent-platform-dc-standalone-0.0.1
cp .env.example .env
```

编辑 `.env`，**必填一项**：

```bash
EXTERNAL_IP=192.168.1.42   # 浏览器访问用的真实服务器 IP
```

然后安装：

```bash
./install.sh
```

安装脚本会自动生成所有密钥、自签 TLS 证书、加载离线镜像、拉起 7 个容器，并在最后跑一次 smoke test。全程 60–120 秒。

→ 细节见 [离线安装（单机）](/install/dc-standalone)

## 二、首次登录

安装结束的 banner 会打印访问地址与初始凭据：

- 地址：`https://<EXTERNAL_IP>/`
- 用户名：`admin@platform.local`
- 密码：`.env` 里的 `ADMIN_BOOTSTRAP_PASSWORD`

```bash
grep ^ADMIN_BOOTSTRAP_PASSWORD .env
```

自签名证书会触发浏览器告警，点「高级 → 继续访问」。首次登录后系统会要求修改密码。

→ 细节见 [首次登录](/install/first-login)

## 三、接上底座（管理员四步）

<ol class="ap-steps">
<li><strong>接入资源池。</strong> 系统配置 → 资源池接入 → 接入资源池，填 vCenter 地址 / 账号 / 口令，<em>测试连接</em>通过后选择内容库，保存。→ <a href="/console/resource-pools">详解</a></li>
<li><strong>接入模型网关。</strong> 系统配置 → 模型网关接入 → 接入模型网关，填网关地址、Master Key、Agent 访问地址，<em>测试连接</em>后保存。→ <a href="/console/gateway-connections">详解</a></li>
<li><strong>登记模型。</strong> 模型调度台 → 模型管理 → 新建模型，填供应商分类、上游模型原名、API Base 与 API Key，测试连接后启用。→ <a href="/console/models">详解</a></li>
<li><strong>建一条路由。</strong> 模型调度台 → 网关路由 → 新建路由，选网关、选策略、把刚才的模型挑进「已选定的模型」。→ <a href="/console/routes">详解</a></li>
</ol>

::: tip 顺序不能颠倒
路由依赖模型，模型依赖网关；部署智能体依赖资源池 + 内容库里的 OVA 模板。缺哪一步，下一步的下拉框就是空的。
:::

## 四、部署第一个智能体

1. 智能体中心 → **智能体市场**。如果卡片列表为空，先点「新增智能体模版」，选资源池 → 内容库 → OVA 模板，登记一个模板族。
2. 在目标卡片上点 **部署智能体**。
3. 按向导填三段：
   - **基础运行环境** —— 版本、vSphere 放置资源池、目标端口组、目标数据存储、克隆模式（全量 / 即时）
   - **全局安全与认证** —— VM 登录密码（两次确认）、可选 SSH 公钥
   - **实例配置清单** —— 单台或批量；批量时填名称前缀、数量、起始 IP，点「生成清单」
4. 每个实例选一个**网关密钥绑定**（没有就先去[密钥管理](/console/keys)颁发一个）。
5. 点 **部署**。

实例会先进入「部署中」，克隆 + 开机 + 注册完成后转为「运行中」，通常 5–10 分钟。

→ 细节见 [部署智能体](/console/deploy)

## 五、交付给使用者

在 **智能体实例** 列表里点该实例的「访问信息」，把这几项发给使用者：

- IP 地址与 SSH 连接命令
- OS 账户与登录密码
- VM 自服务管理台地址：`https://<VM_IP>/manage/`

使用者拿到后按 [访问智能体](/agent-vm/access) 连接即可开始工作。

## 六、看一眼数据

- **总览仪表盘** —— 平台健康度、活跃智能体、总请求量、P95 延迟、本月费用
- **[计量中心](/observability/metering)** —— 按智能体 / 模型 / 密钥看 Token 与成本
- **[请求日志](/observability/request-log)** —— 逐条调用记录，可按模型、状态码、时间窗筛选
- **[审计日志](/observability/audit-log)** —— 谁在什么时候做了什么

## 常见首日问题

| 现象 | 处理 |
|---|---|
| 浏览器打不开控制台 | 确认 `EXTERNAL_IP` 填的是真实网卡 IP，且防火墙放行 `CONSOLE_PORT`（默认 443） |
| 部署对话框里资源池 / 网络下拉为空 | 资源池尚未同步完成，回资源池列表点「立即同步」 |
| 智能体一直停在「部署中」 | 检查 VM 能否出站访问控制面 443；见 [故障排查](/install/troubleshooting) |
| 模型探测显示「熔断」 | 上游不可达或 API Key 失效，在模型管理里重新「测试连接」 |

完整清单见 [故障排查](/install/troubleshooting) 与 [常见问题](/reference/faq)。
