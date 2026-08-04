# agent-platform-docs

**智能体管理平台**的官方使用手册 —— 基于 [VitePress](https://vitepress.dev) 的静态文档站，构建产物是纯静态文件，直接扔给 nginx 托管即可。

对应平台版本：**v0.0.1**（`dc-standalone` 形态）。变更记录见 [CHANGELOG.md](CHANGELOG.md)。

> **两个版本号别混**
> - **文档站版本**（`package.json` / 离线包文件名）—— 这套站点自身的迭代版本
> - **平台版本**（站点导航右上角的 `v0.0.1`，配置在 `docs/.vitepress/config.ts` 的 `PLATFORM_VERSION`）—— 手册所描述的 agent-platform 版本
>
> 平台没发新版时，手册也可能因为补充内容而发新版。

## 快速开始

**本地启动（改文档、看效果）** —— 需要 Node.js ≥ 18：

```bash
git clone https://github.com/VMware-AI/agent-platform-docs.git
cd agent-platform-docs
npm install
npm run dev
```

浏览器打开 **http://localhost:5173/** —— 改 markdown 会热更新，不用重启。

换端口：

```bash
npm run dev -- --port 4173
```

**离线部署（内网只读阅读）** —— 目标机只需要 nginx：

```bash
tar -xzf agent-platform-docs-<版本>.tar.gz
cd agent-platform-docs-<版本>
sudo ./install.sh
```

默认部署到 `/var/www/agent-platform-docs`，监听 **8080**。离线包从 [Releases](https://github.com/VMware-AI/agent-platform-docs/releases) 下载，详见下方[离线发布包](#离线发布包)。

## 本地开发

| 命令 | 作用 |
|---|---|
| `npm install` | 装依赖（首次或依赖变更后） |
| `npm run dev` | 启动开发服务器，热更新，http://localhost:5173/ |
| `npm run build` | 构建到 `docs/.vitepress/dist/` |
| `npm run preview` | 本地预览构建产物（验证最终效果） |
| `./deploy/package.sh` | 打离线发布包到 `dist/` |

> `npm run build` 开启了死链检查（`ignoreDeadLinks: false`），markdown 里指向不存在页面的链接会让构建失败。CI 依赖这一点做链接校验。

## 目录结构

```
docs/
├── index.md                     # 首页（hero + 特性卡 + 按角色导读）
├── .vitepress/
│   ├── config.ts                # 站点配置：导航、侧边栏、搜索、页脚
│   └── theme/
│       ├── index.ts             # 主题入口
│       └── custom.css           # 配色与排版（取自产品 deck 的主题色板）
├── public/logo.svg              # 站点 logo / favicon
├── guide/                       # 开始使用：简介 · 架构 · 概念 · 快速开始
├── install/                     # 安装部署：环境 · 离线安装 · 首登 · 证书 · 健康检查 · 升级 · 排障
├── console/                     # 控制台：总览 · 初始化 · 系统配置 · 模型调度台 · 智能体中心
├── observability/               # 可观测性：计量 · 计量设置 · 监控 · 请求日志 · 审计日志
├── agent-vm/                    # 智能体 VM：访问 · 自服务管理台 · 升级回滚
└── reference/                   # 参考：角色权限 · 环境变量 · 端口 · FAQ
```

## 离线发布包

给内网 / 气隙环境用的自包含 tarball：

```bash
./deploy/package.sh              # 版本号取 package.json
./deploy/package.sh 0.0.2        # 手工指定
```

产物 `dist/agent-platform-docs-<版本>.tar.gz`（约 1 MB）+ `.sha256`。包内是 `site/` + `nginx.conf` + `install.sh` + 离线部署说明，目标机**只需要 nginx**：

```bash
tar -xzf agent-platform-docs-<版本>.tar.gz
cd agent-platform-docs-<版本>
sudo ./install.sh                 # 默认 /var/www/agent-platform-docs，端口 8080
./install.sh --dry-run            # 先看它要做什么
```

打 tag 推上去会由 `.github/workflows/release.yml` 自动出包并挂到 GitHub Release：

```bash
git tag v0.0.1 && git push origin v0.0.1
```

## 部署到 nginx

### 方式一：脚本一键发布

```bash
./deploy/publish.sh deploy@docs.corp.example.com:/var/www/agent-platform-docs
```

脚本会 `npm ci` → `npm run build` → `rsync --delete` 同步到目标 webroot。

### 方式二：CI 产物 + 手工同步

1. GitHub Actions 的 `Build docs` 工作流在每次 push / PR 时构建，产出制品 `docs-dist`
2. 下载解包，同步到 webroot
3. nginx 配置参考 [`deploy/nginx.conf`](deploy/nginx.conf)

### nginx 关键配置

站点开启了 `cleanUrls`（链接不带 `.html`），nginx 必须配 `try_files`，否则除首页外全部 404：

```nginx
location / {
    try_files $uri $uri.html $uri/index.html /404.html;
}
```

完整示例见 [`deploy/nginx.conf`](deploy/nginx.conf)，含 gzip、缓存策略、HTTPS 与子路径部署。

### 部署到子路径

想挂在 `https://example.com/docs/` 下时：

1. 改 `docs/.vitepress/config.ts` 的 `base: '/docs/'`
2. 重新 `npm run build`
3. nginx 用 `alias` + `try_files`（见 nginx.conf 末尾注释）

### GitHub Pages（可选）

`.github/workflows/pages.yml` 提供了 Pages 发布流程，默认只允许手工触发（`workflow_dispatch`）。启用前需在仓库 Settings ▸ Pages 把 Source 选为 "GitHub Actions"；发布在子路径下时同样要改 `base`。

## 写作约定

- **中文正文**，命令、字段名、状态枚举保留原文
- 每页开头用引用块标注页面路径与所需角色，例如
  `> 系统配置 → 资源池接入 · 需要 <span class="ap-badge admin">admin</span>`
- 用 VitePress 的容器区分语气：`::: tip`（经验）、`::: warning`（易踩坑）、`::: danger`（不可逆 / 有破坏性）
- 页面结尾尽量带一张「常见问题」表，把排障入口收在正文里
- 内部链接一律用**绝对路径且不带扩展名**：`/console/deploy`

## 内容来源

文档内容与以下仓库的实现保持对齐，改动代码后请同步更新对应页面：

| 内容 | 来源 |
|---|---|
| 安装、环境变量、端口 | `agent-platform-deployment`（以 release tarball 内的实际脚本为准） |
| 控制台页面与字段 | `agent-platform-console` |
| 角色与权限矩阵 | `agent-platform-backend` |
| 智能体 VM 与自服务管理台 | `agent-manager-daemon` |

## 许可

内部文档，版权归项目所有者。
