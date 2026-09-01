# Spec 008: PR List（PR 列表页）

> BFS Level: 3
> 关联截图: Repo Detail → PRs Tab
> 上游 Spec: 006
> 状态: deprecated（2026-09-01 由 Spec 027 实现：仓库 PR 列表，见 RepoPrs.ets）

---

## 一、页面/功能概述

仓库的 Pull Request 列表页，展示 Open/Closed PR，支持 Reviewed/Mentions 快速筛选、Label 筛选，点击进入 PR 详情。

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│  ←   Pull requests       +  ···     │
├─────────────────────────────────────┤
│  [ Reviewed ]  [ Mentions ]         │
├─────────────────────────────────────┤
│  [ Open ]  [ Closed ]               │
├─────────────────────────────────────┤
│  🟠 Add network layer                │
│  zm_bad/starraft#1 · bug            │
│  @zm_bad · d1 · 💬 2                 │
│  ──────────────────────────────────  │
│  🟠 Bump gradle version              │
│  zm_bad/starraft#1 · deps           │
│  @zm_bad · d2 · 💬 0                 │
│  ...                                │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
|---|------|------|------|--------|-------------|------|
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ 纯 UI | — | — |
| 2 | App Bar 中 | 标题「Pull requests」 | 展示 | ✅ 纯 UI | — | — |
| 3 | App Bar 右 | + 新建按钮 | 跳转创建页 | ✅ 纯 UI | — | — |
| 4 | App Bar 右 | ··· 更多菜单 | 筛选/排序 | ✅ 客户端 | — | — |
| 5 | 筛选 chips | `[Reviewed]` `[Mentions]` | 快速筛选 | ✅ | 客户端过滤 | — |
| 6 | 状态 Tab | `[Open]` `[Closed]` | 切换 | ✅ | `states: [OPEN]` / `[CLOSED]` `[MERGED]` | — |
| 7 | PR 卡片 | PR 标题 | 点击进入详情 | ✅ | `pullRequest.title` | — |
| 8 | PR 卡片 | PR 编号 `#N` | 展示 | ✅ | `pullRequest.number` | — |
| 9 | PR 卡片 | 仓库名 `owner/repo` | 展示 | ✅ | `pullRequest.repository.nameWithOwner` | — |
| 10 | PR 卡片 | Label 标签 | 点击筛选 | ✅ | `pullRequest.labels { name color }` | — |
| 11 | PR 卡片 | 作者 `@user` | 进入 Profile | ✅ | `pullRequest.author.login` | — |
| 12 | PR 卡片 | 时间 | 展示 | ✅ | `pullRequest.createdAt` | — |
| 13 | PR 卡片 | 评论数 💬 | 展示 | ✅ | `pullRequest.comments.totalCount` | — |
| 14 | PR 卡片 | Review 状态 🟠🟢🔴 | 展示 | ✅ | `pullRequest.reviews { state author }` | — |
| 15 | PR 卡片 | Merge 状态 | 展示 | ✅ | `pullRequest.merged` / `mergeable` | — |
| 16 | PR 卡片 | Draft 标识 | 展示 | ✅ | `pullRequest.isDraft` | — |

---

## 四、核心 GraphQL 片段

```graphql
query PullRequestsList(
  $owner: String!, $name: String!,
  $states: [PullRequestState!] = [OPEN],
  $orderBy: PullRequestOrder = { field: CREATED_AT, direction: DESC },
  $first: Int = 25, $after: String
) {
  repository(owner: $owner, name: $name) {
    pullRequests(states: $states, orderBy: $orderBy, first: $first, after: $after) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        id number title state isDraft merged mergeable
        createdAt updatedAt closedAt mergedAt
        author { login avatarUrl }
        labels(first: 5) { nodes { name color } }
        comments { totalCount }
        assignees(first: 3) { nodes { login avatarUrl } }
        milestone { title }
        reviews(first: 10) {
          totalCount
          nodes { state author { login avatarUrl } createdAt }
        }
        closingIssuesReferences(first: 5) {
          nodes { number title repository { nameWithOwner } }
        }
      }
    }
  }
}

mutation CreatePullRequest(
  $repositoryId: ID!, $baseRefName: String!,
  $headRefName: String!, $title: String!, $body: String
) {
  createPullRequest(input: {
    repositoryId: $repositoryId, baseRefName: $baseRefName,
    headRefName: $headRefName, title: $title, body: $body
  }) {
    pullRequest { number title url }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
|----|------|-------------------|
| Review 状态图标聚合 | `reviews` 需与 `totalCount` 同一字段集，避免参数冲突 | 合并为一个 `reviews(first: 10)` 选择集 |

---

## 六、TDD 验收标准

- [ ] PR 列表能展示
- [ ] Open/Closed 筛选正确切换
- [ ] Review 状态图标正确展示
- [ ] 点击 PR 跳转到详情页

---

## 七、备注

- 16/16 全部可行
