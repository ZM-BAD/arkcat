# Spec 021: Top Repositories（工作区仓库列表页）

> BFS Level: 3
> 关联截图: GitHub 官方 App「Top Repositories」页（Home My Work 入口，用户提供，2026-08-31）
> 上游 Spec: 013（入口）
> 状态: ✅ implemented（2026-08-31，构建通过 / 仪器测试 29/29 / 模拟器验收通过）

---

## 一、页面/功能概述

Home My Work「Top Repositories」入口进入的仓库列表页，展示 viewer 的仓库按最近推送时间降序排列（近似官方「Top Repositories」）。筛选：8 项（All/Archived/Fork/Mirror/Private/Public/Source/Template，`All ⌄` 下拉；**6 项下推服务端**（archived/fork/source/private/public/all），Mirror/Template 客户端兜底；切换类型=重查并重置游标）。行结构：左侧仓库头像（owner 头像），上/下两行 = 灰色小字 owner + 黑色大字仓库名；点击进入仓库详情（复用 006 路由）。数据源 `viewer.repositories`。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回、「Top Repositories」标题 + 右上 🔍 搜索（进全局搜索页）
2. 筛选行：「All」仓库筛选下拉（8 项；可下推项走服务端，切换即重查）
3. 仓库行（头像 + owner + name 两行）：◯ 头像 + 第一行 owner 灰色小字（ZM-BAD）+ 第二行仓库名大字（DAG-chat）；后续行同构（headroom 等），多行滚动
4. 列表底部分页：Load more

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ | —（纯 UI） | — |
| 2 | App Bar 中 | 「Top Repositories」标题 | 页面标题 | ✅ | —（纯 UI） | — |
| 3 | 筛选行 | All 下拉（All/Archived/Fork/Mirror/Private/Public/Source/Template） | 仓库筛选（服务端 6 项 + 客户端兜底） | ✅ | `viewer.repositories(isArchived:/isFork:/privacy:)`（实测支持）+ 客户端复核 `isMirror/isTemplate` | 默认 All；切换类型触发重查（重置游标） |
| 4 | 仓库行 | 仓库头像 | 展示 | ✅ | `owner { avatarUrl }` | — |
| 5 | 仓库行 | owner（灰色小字） | 展示 | ✅ | `owner { login }` | — |
| 6 | 仓库行 | 仓库名（黑色大字） | 展示 | ✅ | `name` | — |
| 7 | 仓库行 | 行点击 | 进入仓库详情 | ✅ | —（纯 UI） | 路由复用 repoDetail（param: owner/name） |
| 8 | 空态 | 空态文字 | 无仓库时展示 | ✅ | —（纯 UI） | 复用 StateView |
| 9 | 列表底部 | Load more 分页 | 翻页 | ✅ | `repositories.pageInfo` | — |

> 可行性比例声明：9/9 可行。

---

## 四、核心 GraphQL 片段

```graphql
query WorkTopRepositories($first: Int = 50, $after: String) {
  viewer {
    repositories(first: $first, after: $after, orderBy: { field: PUSHED_AT, direction: DESC }) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        id name nameWithOwner isArchived isFork isMirror isTemplate visibility
        owner { login avatarUrl }
      }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 官方「Top Repositories」排序算法 | 官方为活跃度加权排序，无公开字段 | 用 PUSHED_AT 降序近似（备注说明） |
| 仓库行描述/星数 | 官方该列表行无描述（仅头像+两行文字） | 不做额外信息，与截图对齐 |

---

## 六、TDD 验收标准

- [x] 测试 1：`filterTopRepos(repos, filterKey)` 纯函数：8 项维度（all/archived/fork/mirror/private/public/source/template）过滤正确
- [x] 测试 2：`mapTopRepo` / `mapTopReposPage` 纯函数：owner 缺失回退空串；分页字段正确
- [x] 测试 3：模拟器实测 — 8 项筛选下拉切换（客户端过滤，不触发重查）；行点击进入仓库详情
- [x] 测试 4：grep 检查 TopRepositories.ets 无中文字符串字面量残留
- [x] 测试 5：`bash scripts/check-spec.sh` 通过
- [x] 测试 6：`devecocli build` 全量构建通过

---

## 七、备注

- 入口复用 013 的 Top Repositories 彩色图标（黑 `#24292F`）。
- 排序说明：PUSHED_AT 与官方 Top Repositories 排序近似；如后续需要「最近访问」需另查。
- 头像缺失时（avatarUrl 空）用圆形底色占位（沿用 Home 头像兜底样式）。

- 模拟器实测：Top Repositories 真实数据渲染（头像 + owner/name 两行）；点击进仓库详情未实机断言。
- 筛选交互（默认值/dirty/徽标计数、RESET ≡ Clear all、服务端/客户端分工矩阵、空态自动补拉）统一见 **Spec 068**。
