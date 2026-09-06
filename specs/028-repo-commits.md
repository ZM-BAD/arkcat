# Spec 028: 仓库 Commits 列表页（Repo Detail → Commits）

> BFS Level: 3
> 关联截图: GitHub 官方 App「Commits」页（DAG-chat，深色，用户提供 2026-08-31）
> 上游 Spec: 006（入口）
> 状态: ✅ implemented（2026-08-31，构建通过 / 仪器测试 30/30 / 模拟器双主题验收通过）

---

## 一、页面/功能概述

展示仓库默认分支的提交历史。行 = 提交标题（单行省略）+ 相对时间 + 提交状态（statusCheckRollup 通过时绿✓）+ 作者行（头像 + 登录名 + `authored`）。无筛选行。分页游标加载。数据源 `repository.defaultBranchRef.target.history`。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + 「Commits」标题
2. 提交行一：提交标题（Merge pull request #82 from ZM-…，单行省略）+ 右侧状态绿✓ + 相对时间（20h），下方作者行：🀫 头像 + 登录名（ZM-BAD）+「authored」
3. 提交行二：提交标题（fix(backend): use $addToSet…）+ 状态绿✓ + 相对时间（20h），下方作者行：🀫 头像 + ZM-BAD +「authored」

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar | ← 返回 + 「Commits」标题 | 导航 | ✅ | —（纯 UI） | — |
| 2 | 提交行 | 提交标题（单行省略） | 展示 | ✅ | `messageHeadline` | — |
| 3 | 提交行 | 行状态图标（✓/✗/●） | CI 状态 | ✅ | `statusCheckRollup.state` | SUCCESS→绿✓；FAILURE/ERROR→红✗（oct_x_16）；PENDING→黄点（oct_dot_fill_16） |
| 4 | 提交行 | 相对时间 | 展示 | ✅ | `committedDate` | 年粒度 |
| 5 | 提交行 | 作者头像 + 登录名 + `authored` | 展示 | ✅ | `author { login avatarUrl }` | 缺失回退占位 |
| 6 | 列表 | Load more 分页 | 翻页 | ✅ | `history.pageInfo` | — |

> 可行性比例声明：6/6 可行。

---

## 四、核心 GraphQL 片段

```graphql
query RepoCommits($owner: String!, $name: String!, $first: Int = 40, $after: String) {
  repository(owner: $owner, name: $name) {
    defaultBranchRef {
      target {
        ... on Commit {
          history(first: $first, after: $after) {
            totalCount
            pageInfo { hasNextPage endCursor }
            nodes {
              oid messageHeadline committedDate
              author { login avatarUrl }
              statusCheckRollup { state }
            }
          }
        }
      }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 提交文件变更查看 | 属代码查看器 Spec 011 | 行点击进入 Commit 详情页（CHANGES 无文件 diff 与 DETAILS 双分区） |
| 无默认分支仓库 | 历史不存在 | 空态复用 StateView |

---

## 六、TDD 验收标准

- [x] 测试 1：`mapRepoCommitsPage` 纯函数：节点/分页/rollup 映射正确
- [x] 测试 2：构建 + 模拟器实测：深色下行结构/作者行与截图对齐
- [x] 测试 3：grep 页面无中文字符串字面量；check-spec.sh 通过

---

## 七、备注

- `authored` 为固定英文词（官方样式），i18n key `repo_commits_authored`（zh: 提交者）。
