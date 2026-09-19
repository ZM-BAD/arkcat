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

1. 顶部 App Bar：← 返回 + 两行标题（灰小字 `owner/name` + 粗体 Issues）+ 🔍 搜索（蓝，点击当页顶栏内联搜索）+ ⨁ 新建（circle-plus）——详见 Spec 063
2. 排序条：🔍 Sort by... 下拉
3. 状态 Tab：All/Open/Closed 下拉 chip（FilterDropdownChip）
4. Issue 卡片列表：复用公共 `IssueCard` 组件（2026-09-19 定案：与工作区 Issues 列表同卡同形态）——
   行1=状态图标 + `owner/name #N` 灰字 + 右侧相对时间；行2=标题（≤2 行）；行3=标签胶囊 + 评论数芯片（横向可滑）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ 纯 UI | — | — |
| 2 | App Bar 中 | 两行标题（`owner/name` + Issues） | 展示 | ✅ 纯 UI | — | 第一行为仓库名（Spec 063 改版） |
| 3 | App Bar 右 | ⨁ 新建按钮（circle-plus） | 占位提示 | ✅ 纯 UI | — | `oct_plus_circle_24`（Spec 063）；创建页由 043 承接 |
| 4 | App Bar 右 | 右键漏斗徽标 | bindMenu（创建快捷方式/清除全部筛选） | ✅ 客户端 | — | — |
| 5 | App Bar 右 | 🔍 搜索（蓝） | 当页顶栏内联搜索（本地过滤） | ✅ 纯 UI | — | 不再跳全域搜索页（Spec 063） |
| 6 | 排序条 | Sort by 下拉 | 排序 | ✅ | `orderBy: { field: CREATED_AT }` | — |
| 7 | 状态 Tab | All/Open/Closed 下拉 chip（FilterDropdownChip） | 切换 | ✅ | `states: [OPEN]` / `[CLOSED]` | — |
| 8 | Issue 卡片 | Issue 标题 | 点击进入详情 | ✅ | `issue.title` | — |
| 9 | Issue 卡片 | Issue 编号 `#N` | 展示 | ✅ | `issue.number` | — |
| 10 | Issue 卡片 | Label 标签 | 点击筛选 | ✅ | `issue.labels { name color }` | `LabelPill` 胶囊（官方 IssueLabel 口径，DESIGN.md §10.2） |
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
    labels(first: 30) { nodes { name color } }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| Label 多选筛选 | GraphQL `labels` 参数需 `[String!]`，空数组传 null 即可 | 单选传 `[name]`，多选客户端二次过滤 |
| Author/Assignee 筛选 | —（无边界） | **服务端 `filterBy{createdBy/assignee}`**（2026-09-13 实测支持，与 states/labels 正交）；下拉候选来自会话内累积的候选池（只增不减，避免选了一人后其他人从下拉消失） |
| Assignee 面板首行「Assigned to nobody」 | GraphQL `filterBy` 无「无人分配」语义，推不下去 | 哨兵值 `__none__`（登录名不含下划线不会撞真实候选）：服务端**不传** assignee，客户端按「无 assignees」本地筛；行样式=circle-slash 图标+文案（2026-09-14，官方口径）。已知限制：候选来自已加载集合，首屏可能「假空」 |
| Milestone 面板首行「No milestone」 | 服务端无 milestone 参数（本就只能客户端筛） | 同款哨兵值 `__none__`：按「无里程碑」本地筛；行样式=circle-slash（2026-09-14，官方口径） |

---

## 六、TDD 验收标准

- [x] Issue 列表能展示
- [x] Open/Closed 筛选正确切换
- [ ] Label 点击筛选正确
- [x] 点击 Issue 跳转到详情页（整卡 onClick → issueDetail）

---

## 七、备注

- 14/14 全部可行
- 作者行不实现：官方 App 的 Issue 列表卡无作者行，卡片保持整卡点击进详情。
- 2026-08-31：实现合并自 feature/spec-00X 分支（--no-ff）至 develop，仪器测试 19/19 通过；真实数据类验收项需在应用内配置有效 GitHub PAT 后复核
- 2026-08-31 真实数据验收：使用 GitHub PAT（模拟器实测）完成以上勾选项；未实测项见「备注」（详情跳转由 Spec 030/031 接管）
- 筛选条最左的漏斗徽标**固定不随 chips 横向滑动**（2026-09-13 起）：外层 Row 内「徽标 + chips 的横向 Scroll(layoutWeight 1)」。
- 筛选交互（默认值/dirty/徽标计数、RESET ≡ Clear all、服务端/客户端分工矩阵、空态自动补拉）统一见 **Spec 068**。
