# Spec 037: 仓库列表页（通用，owner 参数化）

> BFS Level: 4
> 关联截图: GitHub 官方 App Repositories 列表页（dragonflyoss，用户提供 2026-09-01）
> 上游 Spec: 006（Repo Detail）/ 036（组织主页 Repositories 行）/ 035（Profile Repositories 入口）
> 状态: implemented（2026-09-01，构建通过 / 模拟器冒烟 + 真实数据验证通过）

---

## 一、页面/功能概述

通用仓库列表二级页（用户/组织共用，owner 参数化）：顶栏灰 login + 粗体标题 + 🔍；筛选条三个胶囊下拉（All/Language/Sort），**全部真实筛选**（GraphQL `privacy`/`filterByLanguage`/`orderBy`）；行 = 粗体仓库名 + 描述 + ⭐ 星数 + 语言点/语言名；行点击进入仓库详情；first:25 + endCursor 加载更多。

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│ ←  dragonflyoss        🔍           │
│     Repositories                    │
├─────────────────────────────────────┤
│ [All ▾] [Language ▾] [Sort: Recent…]│
│ nydus                               │
│ Nydus – a reliable, high-perf…      │
│ ⭐ 1.6k  ● Rust                     │
│ dragonfly                           │
│ Delivers efficient, stable…         │
│ ⭐ 3.3k  ● Go                       │
│ ……（加载更多）                       │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar | ← + login（灰，上）+ Repositories（粗体，下）+ 🔍 | 导航 | ✅ | —（纯 UI） | 自绘头部 hideTitleBar；🔍 → 现有 Search 页 |
| 2 | 筛选条 | All ▾ 下拉（All / Public / Private） | 真实筛选 | ✅ | `privacy` | 私密仅对有权用户有效，越权为空 |
| 3 | 筛选条 | Language ▾ 下拉（All + 常用语言清单） | 真实筛选 | ✅ | `filterByLanguage` | 预置 ~14 常用语言 |
| 4 | 筛选条 | Sort: ▾ 下拉（Recently pushed / Stars / Name / Updated） | 真实筛选 | ✅ | `orderBy { field { PUSHED_AT/STARS/NAME/UPDATED_AT } }` | 默认 Recently pushed |
| 5 | 行 | 仓库名（粗体） | 展示 | ✅ | `name` | — |
| 6 | 行 | 描述（灰，最多 3 行） | 展示 | ✅ | `description` | — |
| 7 | 行 | ⭐ 星数（compactCount 缩写） | 展示 | ✅ | `stargazerCount` | — |
| 8 | 行 | 语言色点 + 语言名 | 展示 | ✅ | `primaryLanguage` | — |
| 9 | 行 | 整行点击 → 仓库详情 | 导航 | ✅ | —（纯 UI） | pushPathByName('repoDetail', nameWithOwner) |
| 10 | 列表底 | 加载更多（first:25 + endCursor） | 请求 | ✅ | `pageInfo` | — |

> 可行性比例声明：10/10 可行。

---

## 四、核心 GraphQL 片段

```graphql
query OrgRepositories($login: String!, $first: Int = 25, $after: String,
  $orderBy: RepositoryOrder = { field: PUSHED_AT, direction: DESC },
  $privacy: RepositoryPrivacy, $lang: String) {
  organization(login: $login) {
    repositories(first: $first, after: $after, orderBy: $orderBy, privacy: $privacy,
      filterByLanguage: $lang) {
      pageInfo { hasNextPage endCursor }
      nodes { ... on Repository {
        id nameWithOwner description stargazerCount forkCount
        primaryLanguage { name color }
      } }
    }
  }
}

query UserRepositories($login: String!, $first: Int = 25, $after: String,
  $orderBy: RepositoryOrder = { field: PUSHED_AT, direction: DESC },
  $lang: String) {
  user(login: $login) {
    repositories(first: $first, after: $after, orderBy: $orderBy,
      filterByLanguage: $lang) {
      pageInfo { hasNextPage endCursor }
      nodes { ... on Repository {
        id nameWithOwner description stargazerCount forkCount
        primaryLanguage { name color }
      } }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 私密仓库 | 越权访问无数据 | 「Private」选项对无权限用户自然返回空 + 空态提示 |
| 语言清单完整化 | GitHub 语种庞大 | 预置常用语言；「All」覆盖全部 |
| 搜索框内联搜索（输入过滤） | 官方为页内搜索 | 本轮 🔍 跳现有 Search 页（Spec 015） |
| 页内 Favorites/收藏操作 | 截图无 | 不实现 |

---

## 六、TDD 验收标准

- [ ] 测试 1：筛选三个下拉均真实生效（语言/排序/公开私密切换列表变化）；默认排序 = Recently pushed
- [ ] 测试 2：行样式（名/描述/星数/语言点）按截图对齐；行点击进仓库详情
- [ ] 测试 3：≥25 条出现加载更多并正常翻页；空态正常
- [ ] 测试 4：组织入口（组织主页 Repositories 行）与用户入口（Profile Repositories）共用本页
- [ ] 测试 5：构建 + 模拟器实测；grep 无中文字符串字面量；check-spec.sh 通过

---

## 七、备注

- compactCount 复用 `utils/Format`；语言色点复用 RepoCard 同款色值。
- 常用语言清单（预置常量）：Go / Rust / TypeScript / JavaScript / Python / Java / C / C++ / C# / Ruby / Shell / Kotlin / Swift / Dart。
- i18n 新增：`repos_list_title`、`repos_filter_all/public/private`、`repos_sort_recent/stars/name/updated`、`repos_lang_all`、`repos_list_empty` 等。
