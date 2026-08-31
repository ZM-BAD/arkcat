# Spec 017: Work Issues（工作区 Issue 列表页）

> BFS Level: 3
> 关联截图: GitHub 官方 App「Issues」页（Home My Work 入口，用户提供，2026-08-31）
> 上游 Spec: 013（入口）/ 007（repo 内 Issue 列表，视角不同，互不替代）
> 状态: ✅ implemented（2026-08-31，构建通过 / 仪器测试 29/29 / 模拟器验收通过）

---

## 一、页面/功能概述

Home My Work「Issues」入口进入的跨仓库 Issue 列表页（区别于 007 的仓库内列表）。展示用户相关（我创建/分配给我/提及我）的全部 Issue，按状态（All/Open/Closed）与可见性（All/Public/Private）筛选，标题样式为 `owner/repo #编号` + 相对时间 + 彩色标签胶囊 + 评论数。数据源为 GraphQL `search(type: ISSUE)`；空态为官方风格插图 + 提示 + RESET ALL FILTERS。

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│  ←   Issues                  🔍 ⋯  │ ← App Bar
├─────────────────────────────────────┤
│  ⌄⌄① [ Closed ⌄ ] [ Created by me ⌄ ] [ Visibility ⌄ ]  │ ← 筛选行
├─────────────────────────────────────┤
│  ✔  microsoft/MicrosoftEdge-Extensions #689      1mo    │ ← Issue 行
│     [Bug - Partner Center] Review stuck ...              │
│     [Task] [Bug] [Tracked] [Partner Center]  💬1        │
│  ─────────────────────────────────────────────────────  │
│  ✔  6tail/tyme4py #6                        8mo         │
│     Python的版本可以升级到3.14吗?                        │
│     💬3                                                │
│  （… 分页 Load more）                                    │
├─────────────────────────────────────┤
│  （空态：插图 + There aren't any issues.                  │
│         Use fewer filters or reset all filters          │
│         [ RESET ALL FILTERS ]）                          │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
|---|------|------|------|--------|-------------|------|
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ | —（纯 UI） | — |
| 2 | App Bar 中 | 「Issues」标题 | 页面标题 | ✅ | —（纯 UI） | 复用 nav_issues_title |
| 3 | App Bar 右 | 🔍 搜索 | 跳转全局搜索页 | ✅ | —（纯 UI） | 复用路由 search |
| 4 | App Bar 右 | ⋯ 更多 | 预留 | ✅ | —（纯 UI） | 点击提示 |
| 5 | 筛选行 | 漏斗徽标 + 激活数 | 展示当前激活筛选数 | ✅ | —（纯 UI） | 客户端计数 |
| 6 | 筛选行 | 状态下拉（All/Open/Closed） | 状态筛选 | ✅ | `search query: is:open / is:closed` | 默认 All |
| 7 | 筛选行 | 归属下拉（Created by me / Assigned to me / Mentioned） | 归属筛选 | ✅ | `author:@me / assignee:@me / mentions:@me` | 默认 Created by me |
| 8 | 筛选行 | 可见性下拉（All/Public/Private） | 可见性筛选 | ✅ | `is:public / is:private` | 默认 All |
| 9 | Issue 行 | 状态图标（绿✔/紫✔/灰⊘） | 展示状态与关闭原因 | ✅ | `state / stateReason` | OPEN→绿；COMPLETED→紫；NOT_PLANNED→灰 |
| 10 | Issue 行 | `owner/repo #N` + 相对时间 | 仓库与时间 | ✅ | `repository.nameWithOwner / createdAt` | 相对时间含年粒度（2y/5y） |
| 11 | Issue 行 | 标题（加粗，2 行截断） | 展示 | ✅ | `title` | — |
| 12 | Issue 行 | 标签胶囊 | 展示 | ✅ | `labels(first:5) { nodes { name color } }` | — |
| 13 | Issue 行 | 评论数 💬 N | 展示 | ✅ | `comments.totalCount` | — |
| 14 | 空态 | 插图 + 标题 + 副文案 + RESET ALL FILTERS | 空态引导；重置筛选并可重查 | ✅ | —（纯 UI） | 插图用占位字形（无官方素材） |
| 15 | 列表底部 | Load more 分页 | 翻页 | ✅ | `search.pageInfo` | — |

> 可行性比例声明：15/15 可行。

---

## 四、核心 GraphQL 片段

```graphql
query WorkIssues($query: String!, $first: Int = 25, $after: String) {
  search(query: $query, type: ISSUE, first: $first, after: $after) {
    issueCount
    pageInfo { hasNextPage endCursor }
    nodes {
      ... on Issue {
        id number title state stateReason createdAt
        repository { nameWithOwner }
        labels(first: 5) { nodes { name color } }
        comments { totalCount }
      }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
|----|------|-------------------|
| 官方「Status / Event」(里程碑/分配人) 筛选 | 截图未展示，MVP 不实现 | 仅提供状态/归属/可见性三组筛选，后续 Spec 扩展 |
| 搜索结果计数（issueCount） | search 分页 count 仅供展示 | 列表不额外展示总数，与官方一致 |
| 标签颜色映射 | GraphQL 返回十六进制色值 | 胶囊背景用浅色固定底 + 深色文字（沿用 007 视觉） |

---

## 六、TDD 验收标准

- [x] 测试 1：`buildWorkIssuesQuery(state, scope, visibility)` 纯函数：qualifier 组合正确（含默认值）
- [x] 测试 2：`mapWorkIssue` 纯函数：状态/关闭原因 → 图标键映射正确；`mapWorkIssuesPage` 分页字段正确
- [x] 测试 3：灰色 ⊘（NOT_PLANNED）与 ✔（COMPLETED）图标区分正确
- [x] 测试 4：模拟器实测 — 三组筛选可切换且触发重查；空态 RESET ALL FILTERS 可重置
- [x] 测试 5：模拟器实测 — 相对时间显示年粒度（≥12 个月显示 2y 等）
- [x] 测试 6：grep 检查 WorkIssues.ets 无中文字符串字面量残留
- [x] 测试 7：`bash scripts/check-spec.sh` 通过
- [x] 测试 8：`devecocli build` 全量构建通过

---

## 七、备注

- 搜索结果节点必须 `... on Issue` 收敛类型；Search 对未登录/受限仓库自动过滤，无需额外处理。
- 相对时间扩展：`timeParts` 增加 `year` 单位（≥12 个月），新增 `time_years_ago` key；IssuesList（007）同步支持，避免 switch 遗漏。
- 入口复用 013 的 Issues 彩色图标（绿 `#2DA44E`）。

- 模拟器实测：工作区 Issues 真实数据渲染（筛选行/状态图标/标签/相对时间含年粒度）；bindMenu 弹层为框架标准行为，筛选重查逻辑由构建串单测（workQueries_builders）覆盖。
