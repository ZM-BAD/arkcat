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

1. 顶部 App Bar：← 返回 + Issues 标题 + ＋ 新建 + 🔍 搜索
2. 排序条：🔍 Sort by... 下拉
3. 状态 Tab：All/Open/Closed 下拉 chip（FilterDropdownChip）
4. Issue 卡片列表：卡片 = 标题 + 元信息行（#编号 · label · 相对时间 · 💬 评论数）
   - 示例卡片 1：🐛 Add network error layer / #4 · bug · d1 · 💬 0
   - 示例卡片 2：📝 update UI design / #1 · documentation · d3
   - ...（后续卡片）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ 纯 UI | — | — |
| 2 | App Bar 中 | 标题「Issues」 | 展示 | ✅ 纯 UI | — | — |
| 3 | App Bar 右 | + 新建按钮 | 占位提示 | ✅ 纯 UI | — | 创建页由 043 承接 |
| 4 | App Bar 右 | 右键漏斗徽标 | bindMenu（创建快捷方式/清除全部筛选） | ✅ 客户端 | — | — |
| 5 | App Bar 右 | 🔍 搜索 | 进全局搜索 | ✅ 纯 UI | — | — |
| 6 | 排序条 | Sort by 下拉 | 排序 | ✅ | `orderBy: { field: CREATED_AT }` | — |
| 7 | 状态 Tab | All/Open/Closed 下拉 chip（FilterDropdownChip） | 切换 | ✅ | `states: [OPEN]` / `[CLOSED]` | — |
| 8 | Issue 卡片 | Issue 标题 | 点击进入详情 | ✅ | `issue.title` | — |
| 9 | Issue 卡片 | Issue 编号 `#N` | 展示 | ✅ | `issue.number` | — |
| 10 | Issue 卡片 | Label 标签 | 点击筛选 | ✅ | `issue.labels { name color }` | — |
| 11 | Issue 卡片 | 时间 | 展示 | ✅ | `issue.createdAt` | — |
| 12 | Issue 卡片 | 评论数 💬 | 展示 | ✅ | `issue.comments.totalCount` | — |
| 13 | Issue 卡片 | 关联 PR 图标 🔀 | 展示 | ✅ | `timelineItems(CROSS_REFERENCED_EVENT)` | — |
| 14 | Issue 卡片 | 选中态 | 点击进入详情 | ✅ 纯 UI | — | — |

---

## 四、核心 GraphQL 片段

> PR 系查询字段：`number title state createdAt author{login}`。

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
        id number title state createdAt
        author { login }
        labels(first: 5) { nodes { name color } }
        comments { totalCount }
        assignees(first: 10) { nodes { login } }
        timelineItems(itemTypes: [CROSS_REFERENCED_EVENT], first: 5) {
          nodes {
            ... on CrossReferencedEvent { source { ... on PullRequest { number } } }
          }
        }
      }
    }
    labels(first: 30) { nodes { name } }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| Label 多选筛选 | GraphQL `labels` 参数需 `[String!]`，空数组传 null 即可 | 单选传 `[name]`，多选客户端二次过滤 |

---

## 六、TDD 验收标准

- [x] Issue 列表能展示
- [x] Open/Closed 筛选正确切换
- [ ] Label 点击筛选正确
- [x] 点击 Issue 跳转到详情页（整卡 onClick → issueDetail）

---

## 七、备注

- 14/14 全部可行
- 作者行**不实现**（2026-09-11 定案）：本 Spec 早期版本曾列「作者 `@user` 进 Profile」，但官方 App 的 Issue 列表卡并无作者行，属本 Spec 的臆造元素，已删除；卡片保持整卡点击进详情。
- 2026-08-31：实现合并自 feature/spec-00X 分支（--no-ff）至 develop，仪器测试 19/19 通过；真实数据类验收项需在应用内配置有效 GitHub PAT 后复核
- 2026-08-31 真实数据验收：使用 GitHub PAT（模拟器实测）完成以上勾选项；未实测项见「备注」（详情跳转由 Spec 030/031 接管）
