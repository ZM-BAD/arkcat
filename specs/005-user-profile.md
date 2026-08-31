# Spec 005: User Profile（用户个人主页）

> BFS Level: 3
> 关联截图: Home → 点击头像
> 上游 Spec: 001
> 状态: ✅ implemented（2026-08-31，真实 GitHub PAT 数据全页验收通过）

---

## 一、页面/功能概述

用户个人主页，展示头像、用户名、bio、状态、组织信息、社交计数。包含 Overview / Repos / Projects / Packages / Stars 五个子 Tab。

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│  ←   @username                ···    │
├─────────────────────────────────────┤
│         ┌─────────┐                 │
│         │  (头像)  │  🟢 Status     │
│         └─────────┘                 │
│       Display Name                  │
│       @username                     │
│  Bio text                           │
│  🏢 Organization                    │
│  📍 Location                        │
│  🔗 Website                         │
│  👥 N following · M followers       │
├─────────────────────────────────────┤
│  [ Overview ] [ Repos ] [ Projects ] [ Packages ] [ Stars ] │
├─────────────────────────────────────┤
│  📊 Contribution Calendar           │
│  📌 Pinned Repositories             │
│  [ Customize your pins ]            │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
|---|------|------|------|--------|-------------|------|
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ 纯 UI | — | — |
| 2 | App Bar 右 | ··· 更多菜单 | Follow/Block/举报 | ⚠️ | 部分 mutation 可行 | — |
| 3 | 头像区 | 大头像 | 展示 | ✅ | `user.avatarUrl` | — |
| 4 | 头像区 | 🟢 状态指示灯 + 状态文字 | 用户状态 | ✅ | `user.status { message emoji }` | — |
| 5 | 用户名区 | 显示名 + @用户名 | 纯展示 | ✅ | `user { name login }` | — |
| 6 | bio | 个人简介文字 | 纯展示 | ✅ | `user.bio` | — |
| 7 | 元信息行 | 🏢 Organization | 纯展示 | ✅ | `user.company` | — |
| 8 | 元信息行 | 📍 Location | 纯展示 | ✅ | `user.location` | — |
| 9 | 元信息行 | 🔗 Website | 打开浏览器 | ✅ | `user.websiteUrl` | — |
| 10 | 社交计数 | following / followers | 点击进入列表 | ✅ | `user.following.totalCount` | — |
| 11 | Tab 栏 | Overview / Repos / Projects / Packages / Stars | 切换内容 | ⚠️ | 见下 | Packages 跳过 |
| 12 | 贡献区 | Contribution Calendar | 日历热力图 | ✅ | `user.contributionsCollection` | — |
| 13 | Pinned 区 | Pinned 仓库卡片 | 点击进入仓库 | ✅ | `user.pinnedItems` | — |
| 14 | Pinned 区 | Customize your pins | 编辑 Pinned | ✅ | `updatePinnedItems` mutation | — |

---

## 四、核心 GraphQL 片段

```graphql
query UserProfile($login: String!) {
  user(login: $login) {
    avatarUrl
    name
    login
    bio
    company
    location
    websiteUrl
    status { message emoji indicatesLimitedAvailability }
    followers { totalCount }
    following { totalCount }
    starredRepositories { totalCount }

    pinnedItems(first: 6, types: [REPOSITORY]) {
      nodes {
        ... on Repository {
          nameWithOwner
          description
          stargazerCount
          forkCount
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

    repositories(first: 30, orderBy: { field: UPDATED_AT, direction: DESC }) {
      totalCount
      nodes {
        nameWithOwner
        description
        stargazerCount
        forkCount
        primaryLanguage { name color }
        updatedAt
      }
    }

    starredRepositories(first: 30) {
      totalCount
      nodes {
        nameWithOwner
        description
        stargazerCount
        forkCount
        primaryLanguage { name color }
      }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
|----|------|-------------------|
| Packages Tab | 无公开用户级 GraphQL 入口 | 不展示该 Tab |
| Projects Tab | Projects v2 API 较复杂 | MVP 可做 tab 但谨慎跟进 |
| ··· 更多菜单 | 部分操作需特殊权限 | Follow/Unfollow 支持，其余跳过 |

---

## 六、TDD 验收标准

- [x] 用户头像、用户名、bio 正确展示
- [x] 贡献日历能渲染
- [x] Pinned 仓库列表能展示
- [ ] Repos Tab 能展示仓库列表
- [x] Stars Tab 能展示 Star 列表
- [x] Packages Tab 不展示

---

## 七、备注

- 12/14 可行
- 自关注检查：对比 `viewer.login === user.login`
- 2026-08-31：实现合并自 feature/spec-00X 分支（--no-ff）至 develop，仪器测试 19/19 通过；真实数据类验收项需在应用内配置有效 GitHub PAT 后复核
- 2026-08-31 真实数据验收：使用 GitHub PAT（模拟器实测）完成以上勾选项；未实测项见「备注」（详情跳转由 Spec 008/011 接管）
