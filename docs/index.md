---
layout: home

hero:
  name: 智能体管理平台
  text: VCF 上的私有 AI Agent 平台
  tagline: 私有内网 · 统一治理 · Agent 中立。一个控制台交付、管理、观测企业内部所有 AI 智能体 —— 代码、数据与模型不出域。
  image:
    src: /logo.svg
    alt: 智能体管理平台
  actions:
    - theme: brand
      text: 快速开始
      link: /guide/quickstart
    - theme: alt
      text: 平台简介
      link: /guide/introduction
    - theme: alt
      text: 下载 v0.0.1 安装包
      link: https://github.com/VMware-AI/agent-platform-deployment/releases/tag/release-v0.0.1

features:
  - icon: 🚀
    title: 一键交付智能体
    details: 从 OVA 模板批量克隆智能体虚拟机，单台或成批部署，5–10 分钟交付到人，凭据与模型接入自动注入。
    link: /console/deploy
    linkText: 部署智能体
  - icon: 🔀
    title: 统一模型网关
    details: 接入 LiteLLM 网关，集中管理供应商模型、虚拟密钥与路由策略，支持限流、预算上限与多级降级。
    link: /console/models
    linkText: 模型调度台
  - icon: 📊
    title: 全链路可观测
    details: 计量中心、实时监控、请求日志与审计日志四张视图，Token、成本、延迟、操作轨迹一处看全。
    link: /observability/metering
    linkText: 可观测性
  - icon: 🔒
    title: 完全离网可运行
    details: 离线镜像包 + 自包含安装脚本，目标主机无需访问任何镜像仓库；密钥本地加密入库，数据不出企业边界。
    link: /install/dc-standalone
    linkText: 离线安装
---

<div class="ap-section">
<div class="ap-kicker">如何阅读本手册</div>

## 按角色找到你的入口

<p class="ap-lead">本手册覆盖从零安装到日常运维的完整路径。三类读者可以直接跳到对应章节，不必通读。</p>

<div class="ap-rule-list">

<div class="ap-rule-row">
<div class="num">01</div>
<div>
<strong>平台运维 / 部署工程师</strong>
<span>在一台 Linux 主机上离线拉起整套平台：<a href="/install/requirements">环境要求</a> → <a href="/install/dc-standalone">离线安装</a> → <a href="/install/first-login">首次登录</a> → <a href="/install/verify">健康检查</a>。日常运维看 <a href="/install/upgrade">升级与卸载</a>、<a href="/install/troubleshooting">故障排查</a>。</span>
</div>
</div>

<div class="ap-rule-row">
<div class="num">02</div>
<div>
<strong>平台管理员</strong>
<span>装完之后按 <a href="/console/bootstrap">初始化四步走</a> 接入 vCenter 资源池与模型网关，然后开始 <a href="/console/deploy">部署智能体</a>、<a href="/console/keys">发放密钥</a>、<a href="/console/users">分配账号</a>。成本与配额在 <a href="/observability/metering">计量中心</a>。</span>
</div>
</div>

<div class="ap-rule-row">
<div class="num">03</div>
<div>
<strong>智能体使用者</strong>
<span>拿到管理员发的 IP 与账号后，看 <a href="/agent-vm/access">访问智能体</a> 连上自己的 VM，用 <a href="/agent-vm/webadmin">VM 自服务管理台</a> 改密码、查版本、<a href="/agent-vm/upgrade">升级或回滚</a> agent。</span>
</div>
</div>

</div>
</div>

<div class="ap-section" style="margin-top: 48px">
<div class="ap-kicker">当前版本</div>

## v0.0.1 —— 首个正式可用版本

<p class="ap-lead">本版本发布 <strong>docker-compose 单机（dc-standalone）</strong> 形态与配套的 linux/amd64 离线镜像包。两个 tarball 解到同级目录，执行 <code>./install.sh</code>，整套系统即可在完全离网的环境里跑起来。</p>

| 内容 | 说明 |
|---|---|
| 安装包 | [`agent-platform-dc-standalone-0.0.1.tar.gz`](https://github.com/VMware-AI/agent-platform-deployment/releases/download/release-v0.0.1/agent-platform-dc-standalone-0.0.1.tar.gz) |
| 镜像包 | `agent-platform-images-0.0.1-amd64.tar.gz`（随 release 发布） |
| 校验 | `SHA256SUMS`（发布页同目录） |
| 其他形态 | `dc-distribution` / `k8s-standalone` / `k8s-ha` 脚手架已就绪，本次不发布 |

</div>
