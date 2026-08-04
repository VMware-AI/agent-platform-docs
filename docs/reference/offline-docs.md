# 离线部署本手册

本手册本身就是一套**纯静态站点**，可以打包带进内网，部署到自己的 nginx 上离线阅读 —— 目标机不需要 node、不需要联网。这对气隙环境下的运维和交付现场特别有用。

## 一、拿到离线包

从文档仓库的 [Releases](https://github.com/VMware-AI/agent-platform-docs/releases) 下载：

| 文件 | 说明 |
|---|---|
| `agent-platform-docs-<版本>.tar.gz` | 离线包（约 1 MB） |
| `agent-platform-docs-<版本>.tar.gz.sha256` | 校验和 |

校验：

```bash
sha256sum -c agent-platform-docs-<版本>.tar.gz.sha256
```

::: tip 也可以自己出包
在有网的机器上克隆源码仓，执行 `./deploy/package.sh`，产物在 `dist/`。适合改过内容、需要发内部定制版的场景。

```bash
git clone https://github.com/VMware-AI/agent-platform-docs.git
cd agent-platform-docs
npm install
./deploy/package.sh          # 产物在 dist/
```
:::

::: tip 想先在本地看看 / 改内容
源码仓自带开发服务器，改 markdown 热更新：

```bash
npm run dev                  # http://localhost:5173/
npm run dev -- --port 4173   # 换端口
```

改完 `npm run build` 会顺带做死链检查，再 `./deploy/package.sh` 出包。
:::

## 二、包里有什么

```
agent-platform-docs-<版本>/
├── site/          # 构建好的静态站点（全部页面 + 本地搜索索引 + 字体）
├── nginx.conf     # nginx 配置示例（含 HTTPS / 子路径部署注释）
├── install.sh     # 一键部署脚本
├── VERSION
└── README.md      # 离线部署说明
```

## 三、一键部署

```bash
tar -xzf agent-platform-docs-<版本>.tar.gz
cd agent-platform-docs-<版本>
sudo ./install.sh
```

默认部署到 `/var/www/agent-platform-docs`，监听 **8080**。完成后浏览器打开 `http://<本机IP>:8080/`。

脚本做四件事：铺静态文件 → 写 nginx 配置（自动识别 `conf.d` 还是 `sites-available` 布局）→ `nginx -t` 校验 → reload。

### 常用参数

```bash
sudo ./install.sh --port=80                     # 换端口
sudo ./install.sh --root=/data/www/docs         # 换站点目录
sudo ./install.sh --server-name=docs.corp.lan   # 换域名
sudo ./install.sh --no-nginx-conf               # 只铺静态文件，配置自己写
./install.sh --dry-run                          # 先看它要做什么，不改任何东西
```

::: tip 先 dry-run
`--dry-run` 不需要 root、不改任何文件，会把将要执行的命令逐条打印出来。上生产前先跑一次。
:::

## 四、手工部署

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

::: danger nginx 必须配 try_files
站点开启了 **cleanUrls**（链接不带 `.html`），所以：

```nginx
location / {
    try_files $uri $uri.html $uri/index.html =404;
}
error_page 404 /404.html;
```

漏了这一段，**首页能开、点任何链接都 404**。这是离线部署最常见的一个坑。
:::

## 五、离线能力边界

| 能力 | 离线可用 |
|---|---|
| 全部文档页面 | ✅ |
| 站内搜索（⌘K / Ctrl+K） | ✅ 索引随包分发，纯客户端检索 |
| 深色 / 浅色主题切换 | ✅ |
| 字体 | ✅ 随包分发，不拉 CDN |
| 页面里指向 GitHub 的外部链接 | ❌ 需要外网 |

页面运行时**不发起任何外部请求**，适合完全隔离的内网。

## 六、更新到新版本

```bash
tar -xzf agent-platform-docs-<新版本>.tar.gz
cd agent-platform-docs-<新版本>
sudo ./install.sh --root=/var/www/agent-platform-docs
```

`install.sh` 会先清空站点目录再铺新文件（`rsync --delete` 或等价的清空+拷贝），不会残留旧页面。

## 七、部署到子路径

离线包是按**根路径**构建的。想挂在 `https://portal.corp.lan/docs/` 这种子路径下，需要回源码仓改 `docs/.vitepress/config.ts` 的 `base: '/docs/'` 后重新出包。

不方便重新构建时，最省事的做法是给它单独一个端口或子域名。

## 八、和平台装在同一台机器上

平台的 console 占了 443 和 80，所以文档站要换个端口：

```bash
sudo ./install.sh --port=8080
```

注意别和平台已占用的端口冲突（443 / 80 / 9090 / 3000 / 8080 后端…）。查一下再定：

```bash
ss -lntp
```

::: warning 8080 可能被后端占用
平台的 backend 默认映射在 `127.0.0.1:8080`。虽然绑的是回环、和文档站监听 `0.0.0.0:8080` 不一定冲突，但为了省事建议文档站直接换到 `8081` 或别的空闲端口。
:::

## 九、排障

| 现象 | 处理 |
|---|---|
| 首页能开，点任何链接都 404 | nginx 缺 `try_files`，见第四节 |
| `nginx -t` 报 conflicting server name | 已有同 `server_name` + 端口的 server 块，换 `--port` 或 `--server-name` |
| 403 Forbidden | 站点目录权限不足，确保 nginx 运行用户可读 |
| 页面样式全丢 / 搜索点开没反应 | `site/assets/` 没完整拷过去，重新部署一次 |
| 端口占用 | `ss -lntp` 看谁占了，换端口重装 |
