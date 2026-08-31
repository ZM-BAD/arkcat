# Spec 005: User Profile（用户个人主页）

> BFS Level: 3
> 关联截图: 官方 App 个人主页（share/gear 顶栏 + 状态行 + 元信息 + Pinned 横滑双列 + 三计数入口）
> 上游 Spec: 013（Home 头像进入）
> 状态: implemented（2026-08-31，官方布局对齐验收通过）

---

## 一、页面/功能概述

用户个人主页。对照官方 App 布局：

- **顶栏**：← 返回 + 分享/设置图标
- **Header 卡**：头像/名字/@login + 状态行（Focussing·编辑）+ bio + 元信息（位置/邮箱/链接/关注数）
- **Pinned 区**：横滑双列卡片
- **计数入口**：Repositories / Organizations / Starred 三个彩色入口（含计数）
- 原 Overview/Repos/Stars Tab 内容保留（日历+Pinned 收在 Overview 内），三计数入口点击展开对应列表

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│  ←  @ZM-BAD                🔗 ⚙      │  ← 返回/分享/设置
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐  │
│  │ 🖼 周铭   @ZM-BAD             │  │
│  │ ⚡ Focusing              ✏    │  │  ← 状态行+编辑
│  │ Backend developer...           │  │
│  │ 📍 Hangzhou                    │  │
│  │ ✉ prozm.bad@gmail.com          │  │
│  │ 🔗 https://zmbad.me            │  │
│  │ 🔗 @zm_bad                     │  │
│  │ 👥 33 followers · 61 following │  │
│  └───────────────────────────────┘  │
├─────────────────────────────────────┤
│  📌 Pinned  (横滑双列)               │
│  ┌─────┐ ┌─────┐                    │
│  │DAG  │ │kuan │  →                │
│  └─────┘ └─────┘                    │
├─────────────────────────────────────┤
│  ▶ Repositories            8        │  ← 计数入口
│  ▶ Organizations           0        │
│  ▶ Starred                93        │
├─────────────────────────────────────┤
│  展开内容（日历/Pinned/仓库列表/Star 列表）│
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
|---|------|------|------|--------|------|------|
| 1 | 顶栏左 | ← 返回 | 回退 | ✅ 纯 UI | — | — |
| 2 | 顶栏右 | 🔗 分享 | 分享用户主页 | ⚠️ | — | 点击提示（系统分享 API 后续） |
| 3 | 顶栏右 | ⚙ 设置 | 进入 Settings 页 | ✅ | — | 新路由 settings |
| 4 | Header | 头像/名字/@login | 纯展示 | ✅ | `user.avatarUrl/name/login` | — |
| 5 | Header | 状态行（emoji+message+编辑笔） | 观众可见状态 | ✅ | `user.status { emoji message }` | 编辑笔仅视图 |
| 6 | Header | bio | 纯展示 | ✅ | `user.bio` | — |
| 7 | Header | 元信息行：位置/链接/X 账号 | 纯展示 | ✅ | `user.location/websiteUrl/twitterUsername` | email 需 user:email scope 移出查询 |
| 8 | Header | followers/following 计数 | 纯展示 | ✅ | `user.followers/following.totalCount` | — |
| 9 | Pinned 区 | 横滑双列仓库卡 | 打开仓库 | ✅ | `user.pinnedItems` | Grid 横向滚动 |
| 10 | 计数入口 | Repositories/Organizations/Starred + 计数 | 展开对应列表 | ✅ | `user { repositories.totalCount organizations.totalCount starredRepositories.totalCount }` | 点击展开下方视图 |
| 11 | 正文区 | 展开视图（Overview=日历+Pinned / Repos / Stars） | 内容区 | ✅ | 现有查询 | Tab 改展开式 |
| 12 | ··· 菜单 | Follow/Unfollow | 关注动作 | ✅ | `user.viewerIsFollowing` + mutation | 保留原菜单 |

---

## 四、核心 GraphQL 片段

```graphql
query UserProfile($login: String!) {
  user(login: $login) {
    id
    avatarUrl name login bio company location websiteUrl email twitterUsername
    status { emoji message }
    followers { totalCount }
    following { totalCount }
    viewerIsFollowing
    pinnedItems(first: 6, types: [REPOSITORY]) { nodes { ... on Repository { id nameWithOwner description stargazerCount forkCount primaryLanguage { name color } } } }
    contributionsCollection { contributionCalendar { totalContributions weeks { contributionDays { date contributionCount color } } } }
    repositories(first: 30, orderBy: { field: UPDATED_AT, direction: DESC }) { totalCount nodes { id nameWithOwner description stargazerCount forkCount primaryLanguage { name color } } }
    starredRepositories(first: 30) { totalCount nodes { id nameWithOwner description stargazerCount forkCount primaryLanguage { name color } } }
    organizations(first: 30) { totalCount }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
|----|------|-------------------|
| Packages/Projects | 无公开用户级入口 / 超范围 | 不展示（原边界） |
| Achievements 徽章行 | 官方 App 专有，无公开 API | 不展示 |
| user.email 字段 | 需 `user:email` scope，普通 repo scope token 会报错 | 移出主查询，邮箱行不展示 |
| 系统分享 | 分享能力依赖系统能力集成 | 顶栏保留 🔗 图标，点击提示后续 |
| 编辑状态笔 | 编辑状态需页面级交互 | 图标展示（不触发编辑），后续 Spec |

---

## 六、TDD 验收标准

- [x] 顶栏 share/gear 图标渲染，gear 进入 Settings 页（截图验证）
- [x] 状态行、X 元信息行渲染，缺失字段隐藏（邮箱因 scope 边界不展示）
- [x] Pinned 横滑双列卡片
- [x] Repositories/Organizations/Starred 三计数入口渲染且计数正确（8/0/93 实测）
- [x] base/zh_CN key 对齐；ohosTest 21/21 通过
- [x] 模拟器截图验收

---

## 七、备注

- 状态笔、分享图标：交互为点击提示（后续 Spec），保持功能按钮位置对齐官方
- 2026-08-31：官方布局对齐完成，截图验收通过
