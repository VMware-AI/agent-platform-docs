import { defineConfig } from 'vitepress'

// 站点版本 —— 与 agent-platform-deployment 的 release tag 对齐。
const PLATFORM_VERSION = '0.0.1'

export default defineConfig({
  lang: 'zh-CN',
  title: '智能体管理平台',
  description: 'VCF 上的私有 AI Agent 平台 — 安装、配置、运维与使用手册',
  // 部署到 nginx 子路径时改这里（例如 '/docs/'），并同步 nginx 的 location。
  base: '/',
  cleanUrls: true,
  lastUpdated: true,
  ignoreDeadLinks: false,

  head: [
    ['meta', { name: 'theme-color', content: '#007B8C' }],
    ['meta', { name: 'format-detection', content: 'telephone=no' }],
    ['link', { rel: 'icon', href: '/logo.svg', type: 'image/svg+xml' }],
  ],

  markdown: {
    lineNumbers: false,
    container: {
      tipLabel: '提示',
      warningLabel: '注意',
      dangerLabel: '危险',
      infoLabel: '说明',
      detailsLabel: '展开细节',
    },
  },

  themeConfig: {
    logo: '/logo.svg',
    siteTitle: '智能体管理平台',

    nav: [
      { text: '开始使用', link: '/guide/introduction', activeMatch: '/guide/' },
      { text: '安装部署', link: '/install/requirements', activeMatch: '/install/' },
      { text: '控制台', link: '/console/overview', activeMatch: '/console/' },
      { text: '可观测性', link: '/observability/metering', activeMatch: '/observability/' },
      { text: '智能体 VM', link: '/agent-vm/access', activeMatch: '/agent-vm/' },
      { text: '参考', link: '/reference/runbook', activeMatch: '/reference/' },
      {
        text: `v${PLATFORM_VERSION}`,
        items: [
          {
            text: '下载安装包',
            link: 'https://github.com/VMware-AI/agent-platform-deployment/releases/download/release-v0.0.1/agent-platform-dc-standalone-0.0.1.tar.gz',
          },
          {
            text: '发布说明',
            link: 'https://github.com/VMware-AI/agent-platform-deployment/releases/tag/release-v0.0.1',
          },
        ],
      },
    ],

    sidebar: {
      '/guide/': [
        {
          text: '开始使用',
          items: [
            { text: '平台简介', link: '/guide/introduction' },
            { text: '架构与组成', link: '/guide/architecture' },
            { text: '核心概念', link: '/guide/concepts' },
            { text: '快速开始', link: '/guide/quickstart' },
          ],
        },
      ],
      '/install/': [
        {
          text: '安装部署',
          items: [
            { text: '环境要求', link: '/install/requirements' },
            { text: '离线安装（单机）', link: '/install/dc-standalone' },
            { text: '首次登录', link: '/install/first-login' },
            { text: '网络与证书', link: '/install/network-tls' },
            { text: '健康检查', link: '/install/verify' },
            { text: '升级与卸载', link: '/install/upgrade' },
            { text: '故障排查', link: '/install/troubleshooting' },
          ],
        },
      ],
      '/console/': [
        {
          text: '控制台入门',
          items: [
            { text: '总览仪表盘', link: '/console/overview' },
            { text: '初始化四步走', link: '/console/bootstrap' },
          ],
        },
        {
          text: '系统配置',
          items: [
            { text: '资源池接入', link: '/console/resource-pools' },
            { text: '模型网关接入', link: '/console/gateway-connections' },
            { text: '用户与权限', link: '/console/users' },
            { text: '平台设置', link: '/console/settings' },
          ],
        },
        {
          text: '模型调度台',
          items: [
            { text: '模型管理', link: '/console/models' },
            { text: '密钥管理', link: '/console/keys' },
            { text: '网关路由', link: '/console/routes' },
          ],
        },
        {
          text: '智能体中心',
          items: [
            { text: '智能体市场', link: '/console/marketplace' },
            { text: '部署智能体', link: '/console/deploy' },
            { text: '智能体实例', link: '/console/agents' },
            { text: '技能管理', link: '/console/skills' },
            { text: '配置与知识包', link: '/console/agent-config' },
          ],
        },
      ],
      '/observability/': [
        {
          text: '可观测性',
          items: [
            { text: '计量中心', link: '/observability/metering' },
            { text: '计量设置', link: '/observability/metering-settings' },
            { text: '实时监控', link: '/observability/monitor' },
            { text: '请求日志', link: '/observability/request-log' },
            { text: '审计日志', link: '/observability/audit-log' },
          ],
        },
      ],
      '/agent-vm/': [
        {
          text: '智能体 VM',
          items: [
            { text: '访问智能体', link: '/agent-vm/access' },
            { text: 'VM 自服务管理台', link: '/agent-vm/webadmin' },
            { text: '升级与回滚', link: '/agent-vm/upgrade' },
          ],
        },
      ],
      '/reference/': [
        {
          text: '参考',
          items: [
            { text: '日常运维手册', link: '/reference/runbook' },
            { text: '安全基线', link: '/reference/security' },
            { text: '角色与权限矩阵', link: '/reference/roles' },
            { text: '规格与限制', link: '/reference/limits' },
            { text: '环境变量', link: '/reference/env' },
            { text: '端口与网络', link: '/reference/ports' },
            { text: '离线部署本手册', link: '/reference/offline-docs' },
            { text: '常见问题', link: '/reference/faq' },
          ],
        },
      ],
    },

    outline: { level: [2, 3], label: '本页目录' },

    search: {
      provider: 'local',
      options: {
        translations: {
          button: { buttonText: '搜索文档', buttonAriaLabel: '搜索文档' },
          modal: {
            noResultsText: '未找到相关结果',
            resetButtonTitle: '清除查询条件',
            displayDetails: '显示详情',
            footer: { selectText: '选择', navigateText: '切换', closeText: '关闭' },
          },
        },
      },
    },

    docFooter: { prev: '上一篇', next: '下一篇' },
    returnToTopLabel: '回到顶部',
    sidebarMenuLabel: '目录',
    darkModeSwitchLabel: '主题',
    lightModeSwitchTitle: '切换到浅色模式',
    darkModeSwitchTitle: '切换到深色模式',
    lastUpdatedText: '最后更新',

    socialLinks: [{ icon: 'github', link: 'https://github.com/VMware-AI/agent-platform-docs' }],

    footer: {
      message: '安全、合规、可控地，把 AI Agent 生产力交付到每个人。',
      copyright: `© ${new Date().getFullYear()} 智能体管理平台 · 保留所有权利`,
    },
  },
})
