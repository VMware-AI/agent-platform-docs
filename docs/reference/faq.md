# 常见问题

## 关于版本

**Q：v0.0.1 包含哪些部署形态？**
只发布 **docker-compose 单机（`dc-standalone`）** 与配套的 `linux/amd64` 离线镜像包。`dc-distribution`、`k8s-standalone`、`k8s-ha` 的脚手架已在仓库里，但本次不发布。

**Q：支持 arm64 吗？**
v0.0.1 只提供 amd64 离线镜像包。装在 aarch64 主机上 preflight 会告警，容器无法启动。

**Q：能装在 k8s 上吗？**
本版本不行，等后续 minor 版本发布 Helm 形态。

## 关于安装

**Q：必须联网吗？**
不必须。离线镜像包 + 自包含安装脚本可在完全离网的主机上安装。唯一必需的外部连接是**平台主机到 vCenter 的 443**。

**Q：`install.sh` 说 `EXTERNAL_IP` 非法？**
必须填浏览器真正会输入的地址。不接受空值、`0.0.0.0`、`localhost`、`127.x.x.x`、`::1`。

**Q：为什么访问 `https://<IP>:80/` 打不开？**
安装横幅在 v0.0.1 会显示 `:80`，这是文案问题。实际 HTTPS 在 443，直接访问 `https://<EXTERNAL_IP>/` 即可。

**Q：能改控制台端口吗？**
`.env` 里的 `CONSOLE_PORT` 在本形态下不改变实际映射。需要换端口只能改 `manifests/docker-compose.yml` 里 console 的 `ports:`，然后 `./install.sh up`。

**Q：可以用自己的证书吗？**
可以。把 `SSL_CERT_PATH` / `SSL_KEY_PATH` 指向你的文件，重跑 `./install.sh up`。见 [网络与证书](/install/network-tls)。

## 关于登录

**Q：初始账号密码是什么？**
`admin@platform.local` / `.env` 里的 `ADMIN_BOOTSTRAP_PASSWORD`（默认 `ChangeMe123!`，请立即改掉）。

**Q：浏览器提示证书不受信？**
正常，默认是自签名证书。点「高级 → 继续访问」。

**Q：登录后所有请求都失败？**
多半是 CORS。`.env` 的 `ALLOWED_ORIGINS` 要包含你正在使用的 URL，改完 `docker compose -p agent-platform restart backend`。

**Q：忘记管理员密码？**
改 `.env` 里的 `ADMIN_BOOTSTRAP_PASSWORD` 后 `docker compose -p agent-platform restart backend`。

## 关于智能体

**Q：一台 VM 能跑几个 agent？**
设计上是 **1 用户 = 1 隔离 VM = 1 agent**。隔离性与成本归属都建立在这个前提上。

**Q：智能体一直停在「部署中」？**
两个高频原因：① 静态 IP 配错，VM 拿不到网络；② VM 无法出站访问控制面 443。

**Q：升级 agent 会丢数据吗？**
不会。升级在 VM 内完成，装到独立的版本目录再切符号链接，工作数据不受影响。见 [升级与回滚](/agent-vm/upgrade)。

**Q：删除的实例还在列表里？**
删除后转「已回收」，保留记录用于审计与历史账单。要彻底清除用「彻底删除」。

**Q：能给已有的实例换模板吗？**
不能。换模板族需要重新部署。日常版本迭代请用「版本更新」。

## 关于模型与密钥

**Q：智能体调用报 401？**
虚拟密钥被禁用 / 过期 / 超预算，或请求的模型不在密钥作用域内。到[密钥管理](/console/keys)查看。

**Q：调用报「模型不存在」？**
请求里应该写**路由名**，不是上游模型原名。见[网关路由](/console/routes)。

**Q：控制台测试网关正常，但 agent 调不通？**
两者用的是不同地址。控制台测的是「网关地址」，agent 用的是「Agent 访问地址」。排查后者的连通性。

**Q：模型显示「熔断」怎么恢复？**
修好上游后到[模型管理](/console/models)点「解除熔断」。熔断不会自动恢复。

**Q：密钥明文丢了？**
无法找回。删掉旧密钥重新颁发一把，并更新到 VM 里。

## 关于计量与账单

**Q：有 Token 但费用是 0？**
模型没配单价。到[模型管理](/console/models)补上。

**Q：计量中心和网关账单对不上？**
以「网关记录（litellm）」数据源为准，它是计费源头。平台记录可能因采集延迟略有差异。

**Q：为什么很多记录归到「未归属」？**
这些调用用的密钥没绑定智能体，或对应实例已被彻底删除。建议一机一密钥并在部署时完成绑定。

**Q：请求日志一直是空的？**
检查 `otel-collector` 容器是否 running，以及 backend 日志里的摄入报错。

## 关于安全

**Q：数据会离开企业内网吗？**
不会 —— 只要上游模型也部署在内网。所有调用经内网网关代理，控制面不主动外联。

**Q：平台保存智能体 VM 的登录密码吗？**
不保存明文。密码在部署时经 guestinfo 注入，VM 本地也只存指纹。

**Q：谁能看审计日志？**
`admin` 与 `read_only`。审计记录只增不改，平台不提供编辑 / 删除入口。

**Q：备份需要保留什么？**
最关键的是 `.secrets_encryption_key` 和 `.env`，其次是两个数据库。见 [升级与卸载 → 备份清单](/install/upgrade#备份清单)。

## 还是没解决？

按 [故障排查](/install/troubleshooting) 收集诊断信息后联系支持，附上「关于」对话框里的平台版本号。
