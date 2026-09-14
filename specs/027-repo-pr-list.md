# Spec 027: 仓库内 PR 列表页（Repo Detail → PRs Tab）

> BFS Level: 3
> 关联截图: GitHub 官方 App「Pull Requests」页（DAG-chat，深色，用户提供 2026-08-31）
> 上游 Spec: 006（入口）/ 008（本 Spec 即 008 的实现）
> 状态: ✅ implemented（2026-08-31，构建通过 / 仪器测试 30/30 / 模拟器双主题验收通过）

---

## 一、页面/功能概述

仓库维度的 PR 列表（区别于 Spec 018 工作区跨仓库列表）。顶部副标题为仓库 owner，筛选行为漏斗徽标 + 状态下拉（All/Open/Closed/Merged）+ Label + Author + Assignee（Label 走 GraphQL；Author/Assignee **服务端无参数**——`pullRequests` 无 author/assignee、REST `/pulls` 忽略 `creator`——故保持客户端过滤 + 空态自动补拉）；行含状态图标、标题、`owner/repo #编号`、相对时间、Label 胶囊、Checks/评论数/作者头像。行点击进入 PR 详情（Spec 031）。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + 副标题仓库名（DAG-chat）+ 主标题「Pull Requests」+ 搜索（🔍）+ 新建（＋）
2. 筛选行：标签徽标（⏲①）+「All」状态下拉 +「Label」下拉 +「Author」下拉 +「Assignee」
3. PR 行一：状态图标（⑂）+ 标题（fix(backend): use $addToSet…）+ 编号（#82）+ 标签（dependencies）+ Checks 胶囊（✓ Checks）+ 评论数（💬1）+ 作者头像（🀫）
4. PR 行二：状态图标（⑂）+ 标题（chore(deps): …）+ 编号（#81）+ 标签（dependencies）+ Checks 胶囊（✓ Checks）+ 评论数（💬1）+ 作者头像（🀫）

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar | ← 返回 + 副标题 owner | 导航 | ✅ | —（纯 UI） | — |
| 2 | App Bar | 🔍 搜索 / ＋ 新建 | 跳转/提示 | ✅ | —（纯 UI） | 复用路由 search |
| 3 | 筛选行 | 漏斗徽标（激活数） | 计数 | ✅ | —（纯 UI） | — |
| 4 | 筛选行 | 状态下拉 All/Open/Closed/Merged | 状态筛选 | ✅ | `pullRequests(states:)` | **默认 Open**（2026-09-14 与官方/仓库内 Issues 对齐；非默认值计 dirty） |
| 5 | 筛选行 | Label 底部面板 | 标签筛选 | ✅ | `pullRequests(labels:)` | 面板双态搜索 + LabelPill 胶囊（与 007 Issues 同款，Spec 068 §二.4） |
| 6 | 筛选行 | Author 底部面板 | 作者筛选 | ⚠️ | **客户端过滤**（GraphQL/REST 均无该参数；see §五） | 面板双态搜索（占位 Filter users）；候选取服务端返回的作者集合；空态自动补拉最多 5 页 |
| 7 | 筛选行 | Assignee 底部面板 | 分配人筛选 | ⚠️ | **客户端过滤**（同上） | 首行=官方「Assigned to nobody」（哨兵 `__none__` 筛无 assignees 行，circle-slash 图标）；空态自动补拉最多 5 页 |
| 7a | 筛选行 | Milestone 底部面板 | 里程碑筛选 | ⚠️ | **客户端过滤**（`pullRequests` 无 milestone 参数） | 首行=官方「No milestone」（哨兵同上）；候选池从已加载 PR 聚合只增不减（2026-09-14 新增） |
| 7b | 筛选行 | Reviews 底部面板（占位） | 评审筛选 | ⚠️ | —（待详设） | chip 先挂官方同款占位，点击 toast；**不计数 dirty**（无值） |
| 7c | 筛选行 | Sort 底部面板 | 排序 | ✅ | `pullRequests(orderBy:)` | WorkFilterSortSheet 6 键 → `IssueOrder`（schema 中 pullRequests 复用 Issue 的排序类型；字段枚举同构，复用 `repoIssueOrder`）；排序计入 dirty |
| 8 | PR 行 | 状态图标 + 标题 + `#N` + 时间 | 展示 | ✅ | `state/merged/isDraft/createdAt` | 沿用 018 图标规范；draft 灰图标 oct_git_pull_request_draft_16；closed=danger 红 `oct_git_pull_request_closed_16`（2026-09-14 以官方为准，DESIGN.md §10.1） |
| 9 | PR 行 | Label 胶囊 + Checks 胶囊 | 展示 | ✅ | `labels/statusCheckRollup` | — |
| 10 | PR 行 | 💬 / 作者头像 | 展示 | ✅ | `comments/author` | — |
| 11 | 列表 | Load more 分页 | 翻页 | ✅ | `pullRequests.pageInfo` | 客户端过滤时首页 50 条 |

> 可行性比例声明：9/11 可行。

---

## 四、核心 GraphQL 片段

```graphql
query RepoPullRequests($owner: String!, $name: String!, $states: [PullRequestState!], $labels: [String!], $first: Int = 50, $after: String, $orderBy: IssueOrder!) {
  repository(owner: $owner, name: $name) {
    pullRequests(states: $states, labels: $labels, first: $first, after: $after, orderBy: $orderBy) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        id number title state merged isDraft createdAt
        labels(first: 8) { nodes { name color } }
        comments { totalCount }
        reviewRequests(first: 10) { totalCount }
        statusCheckRollup { state }
        author { login avatarUrl }
        assignees(first: 10) { nodes { login } }
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
| Author/Assignee 服务端过滤 | `repository.pullRequests` 无 author/assignee 参数；REST `/repos/{o}/{r}/pulls` 忽略 `creator`（实测）；唯一出口 `/search/issues` 需换分页模型 + 补 `assignees/merged` 字段 + 吃 30 req/min 限流 | **保持客户端过滤** + 空态自动补拉最多 5 页（`utils/FilterLoading`）；若后续要求精确结果再评估 search 方案 |
| 行内头像加载失败 | 网络异常 | 圆形底色占位 |

---

## 六、TDD 验收标准

- [x] 测试 1：`filterPrsByAuthor`/`filterPrsByAssignee` 纯函数（客户端过滤）正确
- [x] 测试 2：`mapRepoPrPage` 纯函数：节点/分页/标签/作者映射正确
- [x] 测试 3：构建 + 模拟器实测：深色下四筛选行/行样式与截图对齐
- [x] 测试 4：grep 页面无中文字符串字面量；check-spec.sh 通过

---

## 七、备注

- 复用 018 的 PR 图标/Checks 胶囊逻辑；行深色配色统一走 Spec 026 语义色。
- 筛选交互（默认值/dirty/徽标计数、RESET ≡ Clear all、服务端/客户端分工矩阵、空态自动补拉）统一见 **Spec 068**。
