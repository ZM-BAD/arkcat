# Spec 001: Home Tab（首页）

> BFS Level: 1
> 关联截图: Home Tab 底部导航第一个 Tab
> 状态: ✅ implemented

---

## 一、页面/功能概述

GitHub 客户端启动后默认展示的首页 Tab，位于底部导航最左侧。包含 App Bar（Logo/搜索/铃铛）、用户卡片、贡献日历、动态 Feed 列表。

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│  (Logo)                   🔍    🔔  │  ← App Bar
├─────────────────────────────────────┤
│  [用户卡片区]                        │
│  头像 + 用户名 + bio + followers    │
├─────────────────────────────────────┤
│  📊 贡献日历                         │
│  [ 绿色方块热力图 ]                   │
├─────────────────────────────────────┤
│  📰 Activity Feed（动态流）          │
│  ┌─────────────────────────────┐   │
│  │ 📦 repo/name  "PR title"    │   │
│  │    PR · Merged · 2h ago     │   │
│  └─────────────────────────────┘   │
│  ...                                │
├─────────────────────────────────────┤
│  🏠    🔔      🧭      🤖           │
│  Home  Inbox  Explore  Copilot       │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
|---|------|------|------|--------|-------------|------|
| 1 | App Bar 左 | GitHub Logo (Octocat) | 点击回到顶部/刷新 | ✅ 纯 UI | — | — |
| 2 | App Bar 中右 | 🔍 放大镜图标 | 跳转 Search 页 | ✅ | `search(...)` | — |
| 3 | App Bar 右 | 🔔 铃铛 + 红色角标 | 未读通知数 → 进入 Inbox | ✅ | REST `GET /notifications?per_page=1` | 通知无公开 GraphQL，REST 兜底 |
| 4 | 用户卡片 | 头像 + 用户名 + bio + followers/following | 点击进入个人主页 | ✅ | `viewer { avatarUrl login name bio followers following }` | — |
| 5 | 贡献日历 | 绿色方块热力图 | 左右滑动查看全年 | ✅ | `viewer.contributionsCollection.contributionCalendar` | — |
| 6 | Feed 列表 | 动态卡片流 | 无限滚动 | ✅ | `viewer { starredRepositories / following / ... }` | — |

---

## 四、核心 GraphQL 片段

```graphql
# Home 页主查询
query HomePage {
  viewer {
    avatarUrl
    login
    name
    bio
    followers { totalCount }
    following { totalCount }
    starredRepositories { totalCount }
    status { message emoji }

    # 未读通知角标：公网 API 无 notificationThreads，用 REST GET /notifications?per_page=1 兜底
    pinnedItems(first: 6, types: [REPOSITORY]) {
      nodes {
        ... on Repository {
          nameWithOwner
          description
          stargazerCount
          primaryLanguage { name color }
        }
      }
    }

    contributionsCollection {
      contributionCalendar {
        totalContributions
        weeks { contributionDays { date contributionCount color } }
      }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
|----|------|-------------------|
| 未读通知角标 | `notificationThreads` 仅 Enterprise Server 提供，公网 GraphQL 无此字段 | 改用 REST `GET /notifications?per_page=1` 取未读数兜底 |

---

## 六、TDD 验收标准

- [ ] Home 页能展示登录用户头像和用户名
- [ ] 未读通知角标正确显示数量
- [ ] 贡献日历能渲染绿色方块热力图
- [ ] Pinned 仓库列表能展示
- [ ] 点击头像跳转到 User Profile 页

---

## 七、备注

- Feed 动态流的统一聚合接口在公开 GraphQL 未文档化，MVP 用 Pinned + Starred 拼接
- 后续抓包官方 App 补全
