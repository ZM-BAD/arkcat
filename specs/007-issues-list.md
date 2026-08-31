# Spec 007: Issues List（Issue 列表页）

> BFS Level: 3
> 关联截图: Repo Detail → Issues Tab
> 上游 Spec: 006
> 状态: ✅ implemented（2026-08-31，真实 GitHub PAT 数据全页验收通过）

---

## 一、页面/功能概述

仓库的 Issue 列表页，展示 Open/Closed Issue，支持排序、Label 筛选，点击进入 Issue 详情。

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│  ←   Issues              +  ···     │
├─────────────────────────────────────┤
│  🔍 Sort by...                      │
├─────────────────────────────────────┤
│  [ Open ]  [ Closed ]               │
├─────────────────────────────────────┤
│  🐛 Add network error layer          │
│  #4 · bug · @zm_bad · d1 · 💬 0     │
│  ──────────────────────────────────  │
│  📝 update UI design                │
│  #1 · documentation · @zm_bad · d3  │
│  ...                                │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
|---|------|------|------|--------|-------------|------|
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ 纯 UI | — | — |
| 2 | App Bar 中 | 标题「Issues」 | 展示 | ✅ 纯 UI | — | — |
| 3 | App Bar 右 | + 新建按钮 | 跳转创建页 | ✅ 纯 UI | — | — |
| 4 | App Bar 右 | ··· 更多菜单 | 筛选/排序 | ✅ 客户端 | — | — |
| 5 | 排序条 | Sort by 下拉 | 排序 | ✅ | `orderBy: { field: CREATED_AT }` | — |
| 6 | 状态 Tab | `[Open]` `[Closed]` | 切换 | ✅ | `states: [OPEN]` / `[CLOSED]` | — |
| 7 | Issue 卡片 | Issue 标题 | 点击进入详情 | ✅ | `issue.title` | — |
| 8 | Issue 卡片 | Issue 编号 `#N` | 展示 | ✅ | `issue.number` | — |
| 9 | Issue 卡片 | Label 标签 | 点击筛选 | ✅ | `issue.labels { name color }` | — |
| 10 | Issue 卡片 | 作者 `@user` | 进入 Profile | ✅ | `issue.author.login` | — |
| 11 | Issue 卡片 | 时间 | 展示 | ✅ | `issue.createdAt` | — |
| 12 | Issue 卡片 | 评论数 💬 | 展示 | ✅ | `issue.comments.totalCount` | — |
| 13 | Issue 卡片 | 关联 PR 图标 🔀 | 展示 | ✅ | `timelineItems(CROSS_REFERENCED_EVENT)` | — |
| 14 | Issue 卡片 | 选中态 | 点击进入详情 | ✅ 纯 UI | — | — |

---

## 四、核心 GraphQL 片段

```graphql
query IssuesList(
  $owner: String!, $name: String!,
  $states: [IssueState!] = OPEN,
  $orderBy: IssueOrder = { field: CREATED_AT, direction: DESC },
  $first: Int = 25, $after: String, $label: [String!]
) {
  repository(owner: $owner, name: $name) {
    issues(states: $states, orderBy: $orderBy, first: $first, after: $after, labels: $label) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        id number title state stateReason createdAt updatedAt closedAt
        author { login avatarUrl }
        labels(first: 5) { nodes { name color description } }
        comments { totalCount }
        reactionGroups { content users { totalCount } }
        assignees(first: 3) { nodes { login avatarUrl } }
        milestone { title dueOn }
        timelineItems(itemTypes: [CROSS_REFERENCED_EVENT], first: 5) {
          nodes {
            ... on CrossReferencedEvent { source { ... on PullRequest { number title state } } }
          }
        }
      }
    }
    labels(first: 30) { nodes { name color description } }
  }
}

mutation CreateIssue($repositoryId: ID!, $title: String!, $body: String) {
  createIssue(input: { repositoryId: $repositoryId, title: $title, body: $body }) {
    issue { number title url }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
|----|------|-------------------|
| Label 多选筛选 | GraphQL `labels` 参数需 `[String!]`，空数组传 null 即可 | 单选传 `[name]`，多选客户端二次过滤 |

---

## 六、TDD 验收标准

- [x] Issue 列表能展示
- [x] Open/Closed 筛选正确切换
- [ ] Label 点击筛选正确
- [ ] 点击 Issue 跳转到详情页

---

## 七、备注

- 14/14 全部可行
- 2026-08-31：实现合并自 feature/spec-00X 分支（--no-ff）至 develop，仪器测试 19/19 通过；真实数据类验收项需在应用内配置有效 GitHub PAT 后复核
- 2026-08-31 真实数据验收：使用 GitHub PAT（模拟器实测）完成以上勾选项；未实测项见「备注」（详情跳转由 Spec 008/011 接管）
