# Spec 019: Discussions（工作区 Discussion 列表页）

> BFS Level: 3
> 关联截图: GitHub 官方 App「Discussions」页（Home My Work 入口，用户提供，2026-08-31）
> 上游 Spec: 013（入口）
> 状态: ✅ implemented（2026-08-31，构建通过 / 仪器测试 29/29 / 模拟器验收通过）

---

## 一、页面/功能概述

Home My Work「Discussions」入口进入的跨仓库 Discussion 列表页。按状态（All/Open/Closed）、归属（Created by me / Commented）与 Unanswered 快捷标筛选；行内展示状态图标、`owner/repo #编号`、相对时间、标题、分类标签与回复数。空态为官方蓝色猫插画 + 「There aren't any discussions.」+ RESET ALL FILTERS（仅激活筛选时，无副文案；截图所示即为此空态）。数据源 `search(type: DISCUSSION)`。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回、「Discussions」标题、搜索（🔍）、更多菜单（⋯）
2. 筛选行：漏斗徽标 + 激活数、「All」状态下拉、「Created by me」归属下拉、「Unanswered」快捷标
3. Discussion 行：状态图标（✔）+ `owner/repo #编号`（owner/repo #12）+ 相对时间（3d）+ 标题（Could we support multi-arch?）+ 分类胶囊（[Announcement]）+ 回复数（💬4）
4. 列表底部分页：Load more
5. 空态：🐱 插图 + 标题「There aren't any discussions.」+ 「RESET ALL FILTERS」按钮（仅在激活筛选时出现，无副文案）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ | —（纯 UI） | — |
| 2 | App Bar 中 | 「Discussions」标题 | 页面标题 | ✅ | —（纯 UI） | — |
| 3 | App Bar 右 | 🔍 就地搜索 | 页内 TextInput 客户端过滤 | ✅ | —（纯 UI） | 按标题/仓库全名过滤已加载列表 |
| 4 | App Bar 右 | ⋯ 更多 | 菜单入口 | ✅ | —（纯 UI） | bindMenu（筛选重置等） |
| 5 | 筛选行 | 漏斗徽标 + 激活数 | 展示激活筛选数 | ✅ | —（纯 UI） | 客户端计数；筛选行另含 Sort by 下拉（New / Top 时间窗 6 项） |
| 6 | 筛选行 | 状态下拉（All/Open/Closed） | 状态筛选 | ✅ | `is:open / is:closed` | 默认 All |
| 7 | 筛选行 | 归属下拉（Created by me / Commented） | 归属筛选 | ✅ | `author:@me / commenter:@me` | 默认 Created by me |
| 8 | 筛选行 | Unanswered 快捷标 | 未解答筛选 | ✅ | `is:unanswered` | 开关式 chip |
| 9 | Discussion 行 | 状态图标（discussion 气泡 oct_comment_discussion_16，open 紫 / closed 灰） | 状态展示 | ✅ | `state` | — |
| 10 | Discussion 行 | `owner/repo #N` + 相对时间 | 仓库与时间 | ✅ | `repository.nameWithOwner / createdAt` | 年粒度 |
| 11 | Discussion 行 | 标题（加粗，2 行截断） | 展示 | ✅ | `title` | — |
| 12 | Discussion 行 | 分类胶囊 | 展示 | ✅ | `category { name }` | — |
| 13 | Discussion 行 | 回复数 💬 N | 展示 | ✅ | `comments.totalCount` | — |
| 14 | 空态 | 插图 + 标题 + RESET ALL FILTERS | 空态引导；重置筛选 | ✅ | —（纯 UI） | RESET ALL FILTERS 仅在激活筛选时出现；无副文案 |
| 15 | 列表底部 | Load more 分页 | 翻页 | ✅ | `search.pageInfo` | — |

> 可行性比例声明：15/15 可行。

---

## 四、核心 GraphQL 片段

```graphql
query WorkDiscussions($query: String!, $first: Int = 25, $after: String) {
  search(query: $query, type: DISCUSSION, first: $first, after: $after) {
    pageInfo { hasNextPage endCursor }
    nodes {
      ... on Discussion {
        id number title state createdAt
        repository { nameWithOwner }
        category { name }
        comments { totalCount }
      }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 官方猫插画素材 | 无官方矢量素材 | 用占位字形（🐱）替代，文案一致（体验级复刻） |
| 分类筛选（按 category 过滤） | 截图未展示，搜索 qualifier 需分类名枚举 | MVP 仅展示分类，不做分类筛选 |

---

## 六、TDD 验收标准

- [x] 测试 1：`buildWorkDiscussionsQuery(state, scope, unanswered, sortKey)`：`is:unanswered` 组合正确
- [x] 测试 2：`mapDiscussion` / `mapWorkDiscussionsPage` 纯函数：分类、回复数、分页字段正确
- [x] 测试 3：模拟器实测 — Unanswered 开关切换触发重查；空态 RESET ALL FILTERS 清空筛选
- [x] 测试 4：grep 检查 Discussions.ets 无中文字符串字面量残留
- [x] 测试 5：`bash scripts/check-spec.sh` 通过
- [x] 测试 6：`devecocli build` 全量构建通过

---

## 七、备注

- `search(type: DISCUSSION)` 为 GraphQL 官方支持的搜索类型（与 ISSUE/PR 同族），无需 REST 兜底。
- 入口复用 013 的 Discussions 彩色图标（紫 `#8250DF`）。
- 相对时间复用 017 扩展后的 timeParts（含年粒度）。

- 模拟器实测：Discussions 页渲染 + Unanswered chip 展示；空态（There aren’t any discussions.）需无数据账号复验。
