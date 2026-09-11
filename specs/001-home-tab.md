# Spec 001: Home Tab（首页）

> BFS Level: 1
> 关联截图: Home Tab 底部导航第一个 Tab
> 状态: deprecated（2026-08-31 由 Spec 013 整体替换：官方布局为 My Work / Favorites / Shortcuts）

---

## 一、页面/功能概述

GitHub 客户端启动后默认展示的首页 Tab，位于底部导航最左侧。包含 App Bar（Logo/搜索/铃铛）、用户卡片、贡献日历、动态 Feed 列表。

---

## 二、整体 UI 结构

1. 顶部 App Bar：Logo（点击回顶/刷新）、搜索、通知（红角标→Inbox）
2. 用户卡片区：头像 + 用户名 + bio + followers
3. 贡献日历：绿色方块热力图（横向滑动全年）
4. Activity Feed 动态流：动态卡（repo/name + PR 标题 + 状态/时间），无限滚动
5. 底部导航：Home / Inbox / Explore / 我的主页 四个 Tab（tab4 图标为账号头像，见 Spec 060）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
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

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 未读通知角标 | `notificationThreads` 仅 Enterprise Server 提供，公网 GraphQL 无此字段 | 改用 REST `GET /notifications?per_page=1` 取未读数兜底 |

---

## 六、TDD 验收标准

- [x] Home 页能展示登录用户头像和用户名
- [x] 未读通知角标正确显示数量
- [x] 贡献日历能渲染绿色方块热力图
- [x] Pinned 仓库列表能展示
- [x] 点击头像跳转到 User Profile 页

---

## 七、备注

- Feed 动态流的统一聚合接口在公开 GraphQL 未文档化，MVP 用 Pinned + Starred 拼接
- 后续抓包官方 App 补全
- 2026-08-31：实现合并自 feature/spec-00X 分支（--no-ff）至 develop，仪器测试 19/19 通过；真实数据类验收项需在应用内配置有效 GitHub PAT 后复核
- 2026-08-31 真实数据验收：使用 GitHub PAT（模拟器实测）完成以上勾选项；未实测项见「备注」（详情跳转由 Spec 008/011 接管）
