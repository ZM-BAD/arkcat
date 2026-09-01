# StarRaft — 纯血鸿蒙版 GitHub 客户端

> 🌐 [English Version](README.md) | 简体中文
> 一个基于 HarmonyOS NEXT（纯血鸿蒙）开发的 GitHub 客户端应用

---

## 📋 项目概述

| 项目 | 说明 |
|------|------|
| **应用名称** | StarRaft |
| **包名** | `me.zmbad.starraft` |
| **目标平台** | HarmonyOS 7.0（API 26.0.0） |
| **最低兼容** | HarmonyOS 5.0（API 12） |
| **应用类型** | GitHub 第三方客户端 |
| **开发语言** | ArkTS / ArkUI |
| **构建工具** | hvigor（DevEco Studio 内置） |
| **测试框架** | Hypium |

---

## 🎨 设计理念 —「体验级复刻」

> 目标：成为最接近 GitHub 官方 APP 体验的第三方客户端。

**不是像素级复刻，而是体验级复刻**，类比 Ubuntu 与 macOS 设置菜单的关系：

- **复刻的**：信息架构、页面层级、导航模式、功能分区、按钮位置、交互反馈逻辑
- **不复刻的**：平台特有控件样式（不用 iOS 毛玻璃 / Material 涟漪）、字体图标风格

**核心原则**：用过 GitHub 官方 APP 的用户，打开 StarRaft 立即感受到「这就是换皮」，但底层全部使用纯血鸿蒙原生 ArkUI 组件。

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
- 认证方式：GitHub Personal Access Token（用户自行生成，客户端本地存储）
- GraphQL Client：纯手工封装（自研轻量 GraphQL Client）

### 待确认
- 路由管理方案选型

---

## 📊 Spec 拆解策略：BFS（广度优先）

> 先遍历所有 Tab 和页面，建立完整 IA 全貌，再按优先级逐路径深入。
> 避免一开始陷入某个子页面的细节。

**BFS 层级规划：**
- **Level 0**：底部 Tab 结构（Home / Inbox / Explore / Copilot）
- **Level 1**：每个 Tab 的页面元素拆解
- **Level 2**：每个元素对应的 GraphQL 接口 + 可行性标注
- **Level 3**：子页面（仓库详情、Issue 详情、PR 详情...）
- **Level 4**：子页面内的交互元素

**Spec 文件位于 `specs/` 目录**，详见 [specs/README.md](specs/README.md)。

### Spec 进度

| 页面 | Spec 文件 | 状态 |
|------|----------|------|
| Home Tab | `specs/001-home-tab.md` | ✅ 完成 |
| Inbox Tab | `specs/002-inbox-tab.md` | ✅ 完成 |
| Explore Tab | `specs/003-explore-tab.md` | ✅ 完成 |
| Copilot Tab | `specs/004-copilot-tab.md` | ✅ 完成 |
| User Profile | `specs/005-user-profile.md` | ✅ 完成 |
| Repo Detail | `specs/006-repo-detail.md` | ✅ 完成 |
| Issues List | `specs/007-issues-list.md` | ✅ 完成 |
| PR List | `specs/008-pr-list.md` | ✅ 完成 |
| PR Detail | `specs/009-pr-detail.md` | ✅ 完成 |
| PR Diff | `specs/010-pr-diff.md` | ✅ 完成 |
| Code Viewer | `specs/011-code-viewer.md` | ✅ 完成 |

**覆盖率：~95% 核心场景（按用户使用频率加权）**

---

## 🚀 快速开始

### 环境要求
- macOS 14+（Apple Silicon / Intel）
- DevEco Studio 26.0.0+（已安装）
- HarmonyOS SDK 26.0.0（已安装）

### 开发步骤

```bash
# 1. 克隆项目
git clone https://github.com/zm_bad/starraft.git
cd starraft

# 2. 安装 Git hooks
bash scripts/install-hooks.sh

# 3. 用 DevEco Studio 打开项目
#    File → Open → 选择 starraft 目录

# 4. 构建运行
#    DevEco Studio → Build → Build Project (Ctrl/Cmd + F9)
#    DevEco Studio → Run → Run 'entry' (Ctrl/Cmd + R)
```

---

## 📄 许可证

**StarRaft 是一款免费、开源、非商业用途的纯血鸿蒙 GitHub 客户端。它与 GitHub, Inc. 无任何关联，未获得其认可或赞助。GitHub 及 GitHub 徽标是 GitHub, Inc. 的商标。StarRaft 不包含任何 GitHub 官方素材或美术资源。**

- 项目代码：[GPL-3.0](./LICENSE)
- 图标（Octicons，位于 [`assets/octicons/`](assets/octicons/README.md)）：MIT 许可 —— 详见 [`assets/octicons/LICENSE`](assets/octicons/LICENSE)
