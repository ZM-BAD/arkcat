# Spec 018: Work Pull Requests（工作区 PR 列表页）

> BFS Level: 3
> 关联截图: GitHub 官方 App「Pull Requests」页（Home My Work 入口，用户提供，2026-08-31）
> 上游 Spec: 013（入口）/ 008（repo 内 PR 列表，视角不同，互不替代）
> 状态: ✅ implemented（2026-08-31，构建通过 / 仪器测试 29/29 / 模拟器验收通过）

---

## 一、页面/功能概述

Home My Work「Pull Requests」入口进入的跨仓库 PR 列表页。展示用户相关 PR（我创建/分配给我/提及我），按状态（All/Open/Closed/Merged）与可见性筛选，行内展示状态图标（merged 紫✔ / open 绿⑂ / closed 灰✗）、Checks 状态胶囊（✓ Checks / ✗ Checks failed）、评论数与审查数。数据源 `search(type: PR)`；空态沿用官方风格 + RESET ALL FILTERS。

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│  ←   Pull Requests          🔍 ⋯   │ ← App Bar
├─────────────────────────────────────┤
│  ⌄⌄① [ All ⌄ ] [ Created by me ⌄ ] [ Visibility ⌄ ]  │ ← 筛选行
├─────────────────────────────────────┤
│  ⑂  ZM-BAD/DAG-chat #82                    12h      │ ← PR 行
│     fix(backend): use $addToSet for children   links │
│     ✔ Checks   💬1   👁1                          │
│  ─────────────────────────────────────────────────  │
│  ✗  ZM-BAD/DAG-chat #1                    7mo        │
│     Add files for GitHub Actions ...                 │
│     ✗ Checks failed  (avatar)                        │
│  （… 分页 Load more）                                  │
├─────────────────────────────────────┤
│  （空态：插图 + There aren't any pull requests.        │
│         Use fewer filters or reset all filters       │
│         [ RESET ALL FILTERS ]）                       │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ | —（纯 UI） | — |
| 2 | App Bar 中 | 「Pull Requests」标题 | 页面标题 | ✅ | —（纯 UI） | — |
| 3 | App Bar 右 | 🔍 搜索 | 跳转全局搜索页 | ✅ | —（纯 UI） | 复用路由 search |
| 4 | App Bar 右 | ⋯ 更多 | 预留 | ✅ | —（纯 UI） | 点击提示 |
| 5 | 筛选行 | 漏斗徽标 + 激活数 | 展示激活筛选数 | ✅ | —（纯 UI） | — |
| 6 | 筛选行 | 状态下拉（All/Open/Closed/Merged） | 状态筛选 | ✅ | `is:open / is:closed / is:merged` | 默认 All |
| 7 | 筛选行 | 归属下拉（Created by me / Assigned to me / Mentioned） | 归属筛选 | ✅ | `author:@me / assignee:@me / mentions:@me` | 默认 Created by me |
| 8 | 筛选行 | 可见性下拉（All/Public/Private） | 可见性筛选 | ✅ | `is:public / is:private` | 默认 All |
| 9 | PR 行 | 状态图标（merged 紫✔ / open 绿⑂ / closed 灰✗） | 状态展示 | ✅ | `state / merged` | — |
| 10 | PR 行 | `owner/repo #N` + 相对时间 | 仓库与时间 | ✅ | `repository.nameWithOwner / createdAt` | 年粒度 |
| 11 | PR 行 | 标题（加粗，2 行截断） | 展示 | ✅ | `title` | — |
| 12 | PR 行 | Checks 胶囊（✔ Checks / ✗ Checks failed / ⏳ Checks pending） | CI 状态展示 | ✅ | `statusCheckRollup { state }` | state 为空不显示胶囊 |
| 13 | PR 行 | 💬 评论数 + 👁 审查请求数 | 展示 | ✅ | `comments.totalCount / reviewRequests.totalCount` | — |
| 14 | 空态 | 插图 + 标题 + 副文案 + RESET ALL FILTERS | 空态引导；重置筛选 | ✅ | —（纯 UI） | 插图用占位字形 |
| 15 | 列表底部 | Load more 分页 | 翻页 | ✅ | `search.pageInfo` | — |

> 可行性比例声明：15/15 可行。

---

## 四、核心 GraphQL 片段

```graphql
query WorkPullRequests($query: String!, $first: Int = 25, $after: String) {
  search(query: $query, type: PR, first: $first, after: $after) {
    pageInfo { hasNextPage endCursor }
    nodes {
      ... on PullRequest {
        id number title state merged createdAt
        repository { nameWithOwner }
        comments { totalCount }
        reviewRequests(first: 10) { totalCount }
        statusCheckRollup { state }
      }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| undefined 状态的 Checks（未运行） | search 节点可能无 statusCheckRollup | 不显示胶囊，与官方一致 |
| 审查者头像行 | 截图第三行可见头像，GraphQL 可取 `reviewers` 头像 | MVP 仅显示 👁 数字，头像行后续 Spec 补充 |

---

## 六、TDD 验收标准

- [x] 测试 1：`buildWorkPrsQuery(state, scope, visibility)` 纯函数：含 is:merged 组合正确
- [x] 测试 2：`mapWorkPr` 纯函数：merged/open/closed → 图标键映射；状态缺失回退 open
- [x] 测试 3：`mapWorkPrsPage` 分页字段正确；statusCheckRollup 缺失时 checksState 为空串
- [x] 测试 4：模拟器实测 — 状态切换（含 Merged）触发重查；Checks 胶囊按 state 显示
- [x] 测试 5：grep 检查 WorkPrs.ets 无中文字符串字面量残留
- [x] 测试 6：`bash scripts/check-spec.sh` 通过
- [x] 测试 7：`devecocli build` 全量构建通过

---

## 七、备注

- 搜索节点必须 `... on PullRequest` 收敛类型；`statusCheckRollup.state` 取 SUCCESS/FAILURE/PENDING/ERROR，ERROR 按 FAILURE 处理。
- 入口复用 013 的 PR 彩色图标（蓝 `#3C78D8`）。
- 与 008 的分工：008 为「仓库内 PR 列表」（Repo Detail 进入，含 Reviewed/Mentions 快捷筛选）；018 为「跨仓库工作区列表」，两者功能互不重叠。

- 模拟器实测：工作区 PR 页渲染通过；Checks 胶囊与审查数依赖真实数据，映射逻辑由单测覆盖。
