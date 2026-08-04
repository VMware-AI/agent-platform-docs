# 智能体管理平台 · 使用手册（离线包）

这是**智能体管理平台**官方使用手册的离线发布包。解压后是一套纯静态站点，部署到任意 nginx 即可在内网离线阅读 —— 目标机**不需要 node、不需要联网**。

## 包内有什么

```
agent-platform-docs-<版本>/
├── site/          # 构建好的静态站点（全部内容 + 本地搜索索引 + 字体）
├── nginx.conf     # nginx 配置示例（含 HTTPS / 子路径部署注释）
├── install.sh     # 一键部署脚本
├── VERSION
└── README.md      # 本文件
```

## 一键部署

```bash
tar -xzf agent-platform-docs-<版本>.tar.gz
cd agent-platform-docs-<版本>
sudo ./install.sh
```

默认部署到 `/var/www/agent-platform-docs`，监听 **8080** 端口。完成后浏览器打开 `http://<本机IP>:8080/`。

常用参数：

```bash
sudo ./install.sh --port=80                     # 换端口
sudo ./install.sh --root=/data/www/docs         # 换站点目录
sudo ./install.sh --server-name=docs.corp.lan   # 换域名
sudo ./install.sh --no-nginx-conf               # 只铺静态文件，nginx 配置自己写
./install.sh --dry-run                          # 先看看它要做什么，不改任何东西
```

脚本会自动识别 `conf.d` 还是 `sites-available` 布局，写完配置后跑 `nginx -t` 校验并 reload。

## 手工部署

不想用脚本时：

```bash
# 1) 铺静态文件
sudo mkdir -p /var/www/agent-platform-docs
sudo cp -R site/. /var/www/agent-platform-docs/

# 2) 装配置
sudo cp nginx.conf /etc/nginx/conf.d/agent-platform-docs.conf
sudo $EDITOR /etc/nginx/conf.d/agent-platform-docs.conf   # 改 server_name / root / listen

# 3) 生效
sudo nginx -t && sudo systemctl reload nginx
```

> **⚠️ 关键点**
>
> 站点开启了 **cleanUrls**（链接不带 `.html`），nginx 必须配：
>
> ```nginx
> location / {
>     try_files $uri $uri.html $uri/index.html /404.html;
> }
> ```
>
> 漏了这一段，**除首页外所有页面都会 404**。

## 部署到子路径

想挂在 `https://portal.corp.lan/docs/` 这种子路径下时，静态包本身是按**根路径**构建的，需要回源码仓改 `docs/.vitepress/config.ts` 的 `base: '/docs/'` 后重新出包。

如果不方便重新构建，也可以给它单独一个端口或子域名 —— 这是最省事的做法。

## 更新到新版本

拿到新版 tarball，重复一次部署即可：

```bash
tar -xzf agent-platform-docs-<新版本>.tar.gz
cd agent-platform-docs-<新版本>
sudo ./install.sh --root=/var/www/agent-platform-docs
```

`install.sh` 会先清空站点目录再铺新文件（用 `rsync --delete` 或等价的清空+拷贝），不会残留旧页面。

## 离线特性

| 能力 | 离线可用 |
|---|---|
| 全部文档页面 | ✅ |
| 站内搜索（⌘K / Ctrl+K） | ✅ 索引在本地，纯客户端 |
| 深色 / 浅色主题切换 | ✅ |
| 字体 | ✅ 随包分发，不拉 CDN |
| 页面内的外部链接（GitHub release 等） | ❌ 需要外网才能点开 |

页面运行时**不发起任何外部请求**，适合完全隔离的内网环境。

## 校验

发布包附带 `.sha256`：

```bash
sha256sum -c agent-platform-docs-<版本>.tar.gz.sha256
```

## 排障

| 现象 | 处理 |
|---|---|
| 首页能开，点任何链接都 404 | nginx 缺 `try_files`，见上方「关键点」 |
| `nginx -t` 报 conflicting server name | 已有同 `server_name` + 端口的 server 块，改 `--port` 或 `--server-name` |
| 403 Forbidden | 站点目录权限不足；确保 nginx 运行用户可读 `--root` 指向的目录 |
| 页面样式全丢 | 站点目录铺得不完整，确认 `site/assets/` 一并拷过去了 |
| 搜索框点开没反应 | 同上，`assets/` 下的搜索索引缺失 |
| 端口占用 | 用 `ss -lntp` 看谁占了该端口，换 `--port` 重装 |

## 源码

站点由 [VitePress](https://vitepress.dev) 构建，源码仓库：`VMware-AI/agent-platform-docs`。
