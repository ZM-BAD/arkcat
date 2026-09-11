<p align="center">
  <img src="assets/logo/arkcat-logo-appicon.svg" width="160" alt="ArkCat logo">
</p>

# ArkCat — 纯血鸿蒙版 GitHub 客户端

> 🌐 [English Version](README.md) | 简体中文
> 一个基于 HarmonyOS NEXT（纯血鸿蒙）开发的 GitHub 客户端应用

---

## 📋 项目概述

| 项目 | 说明 |
| ------ | ------ |
| **应用名称** | ArkCat |
| **包名** | `me.zmbad.arkcat` |
| **目标平台** | HarmonyOS 7.0（API 26.0.0） |
| **最低兼容** | HarmonyOS 5.0（API 12） |
| **应用类型** | GitHub 第三方客户端 |
| **开发语言** | ArkTS / ArkUI |
| **构建工具** | hvigor（DevEco Studio 内置） |
| **测试框架** | Hypium + node:test（宿主单元测试） |

---

## 🎨 设计理念 —「体验级复刻」

> 目标：成为最接近 GitHub 官方 APP 体验的第三方客户端。

**不是像素级复刻，而是体验级复刻**，类比 Ubuntu 与 macOS 设置菜单的关系：

- **复刻的**：信息架构、页面层级、导航模式、功能分区、按钮位置、交互反馈逻辑
- **不复刻的**：平台特有控件样式（不用 iOS 毛玻璃 / Material 涟漪）、字体图标风格

**核心原则**：用过 GitHub 官方 APP 的用户，打开 ArkCat 立即感受到「这就是换皮」，但底层全部使用纯血鸿蒙原生 ArkUI 组件。

---

## 🏗 技术方案

### 已确认
- 开发工具：DevEco Studio 26.0.0+
- 目标平台：HarmonyOS 7.0（API 26.0.0）
- **API 层：GitHub GraphQL API v4**（以 GraphQL 为主，REST 兜底）
- 网络库：@kit.NetworkKit（封装 GraphQL Client）
- UI 框架：ArkUI（原生组件）
- 设计系统：**GitHub Primer**（官方令牌与规范，见 [DESIGN.md](DESIGN.md)）
- 状态管理：V2（`@ComponentV2` / `@Local`，API 18+）
- **架构：纯端侧直连 GitHub GraphQL API**，无 BFF/后端服务
- 认证方式：**GitHub OAuth Device Flow**（主登录路径）+ PAT 兼容（客户端本地存储）
- 路由：**Navigation**（`NavPathStack` + `navDestination`；二级页自绘 AppBar）
- GraphQL Client：纯手工封装（自研轻量 GraphQL Client）

---

## ✨ 功能一览

- **Home**：My Work 分区工作区（Issues / PRs / Discussions / Projects / Top Repos / Organizations / Starred，支持编辑排序与可见性）
- **Inbox**：通知收件箱（类型 / 仓库 / 视图筛选、阅读态、合并 PR 检测）
- **Explore**：Trending / Awesome（语言、时间窗、口语筛选）
- **个人主页**：账号页（仓库 / 星标 / 组织，多账号切换；底栏头像入口）
- **仓库**：详情、PR / Commits / Releases 列表、Contributors / Watchers / License、README 与 Markdown 渲染、Stargazers / Forks、成就徽章
- **PR**：详情、Files Changed（diff hunk、行号开关、Reviewed 勾选、文件评论）、提交列表、Checks / Reviews
- **Issue**：详情、评论、反应（emoji 面板 / Reactees）、标签筛选
- **搜索**：六类结果（Code / Repos / Issues / PRs / People / Orgs）、qualifier 快捷词、最近搜索
- **全局**：三态暗黑模式、中英双语、GitHub Primer 视觉、下拉刷新与触底加载、GitHub 相对时间

> 各功能详细设计与进度见 [`specs/`](specs/)（完整索引：[specs/README.md](specs/README.md)）。

---

## 🚀 快速开始

### 环境要求
- macOS 14+（Apple Silicon / Intel）
- DevEco Studio 26.0.0+（已安装）
- HarmonyOS SDK 26.0.0（已安装）

### 开发步骤

```bash
# 1. 克隆项目
git clone https://github.com/ZM-BAD/arkcat.git
cd arkcat

# 2. 安装 Node 依赖（pre-commit 宿主单元测试门禁需要）
npm install

# 3. 安装 Git hooks
bash scripts/install-hooks.sh

# 4. 用 DevEco Studio 打开项目
#    File → Open → 选择 arkcat 目录

# 5. 构建运行
#    DevEco Studio → Build → Build Project (Ctrl/Cmd + F9)
#    DevEco Studio → Run → Run 'entry' (Ctrl/Cmd + R)
```

### 可选 CLI 命令（macOS）

```bash
bash scripts/ut/run-local-tests.sh   # 宿主单元测试（node:test，需 npm install）
bash scripts/run-local-test.sh    # 官方 Local Test + 覆盖率报告（需 DevEco Studio）
bash scripts/check-graphql.sh     # GraphQL 契约检查（需 gh 已登录）
devecocli build                   # 构建 debug HAP
```

---

## 📄 许可证

**ArkCat 是一款免费、开源、非商业用途的纯血鸿蒙 GitHub 客户端。它与 GitHub, Inc. 无任何关联，未获得其认可或赞助。GitHub 及 GitHub 徽标是 GitHub, Inc. 的商标。ArkCat 不包含任何 GitHub 官方素材或美术资源。**

- 项目代码：[GPL-3.0](./LICENSE)
- 图标（Octicons，位于 [`assets/octicons/`](assets/octicons/README.md)）：MIT 许可 —— 详见 [`assets/octicons/LICENSE`](assets/octicons/LICENSE)
