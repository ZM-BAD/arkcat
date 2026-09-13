# Spec 037: 仓库列表页（通用，owner 参数化）

> BFS Level: 4
> 关联截图: GitHub 官方 App Repositories 列表页（dragonflyoss，用户提供 2026-09-01）
> 上游 Spec: 006（Repo Detail）/ 036（组织主页 Repositories 行）/ 035（Profile Repositories 入口）/ 056（语言面板组件共用）
> 状态: implemented（2026-09-01，构建通过 / 模拟器冒烟 + 真实数据验证通过）

---

## 一、页面/功能概述

通用仓库列表二级页（用户/组织共用，owner 参数化）：顶栏灰 login + 粗体标题 + 🔍；筛选条三件——**Type = 官方 8 项胶囊下拉**（All/Archived/Fork/Mirror/Private/Public/Source/Template）、**Language = 底部面板**（全量语言清单 + 内联搜索，与 Trending 同款）、**Sort = 底部面板官方 8 项**（服务端 orderBy：PUSHED_AT/CREATED_AT/NAME/STARGAZERS × ASC/DESC）；**语言/类型筛选=客户端页内过滤**（仅已加载页；`filterByLanguage`/`privacy` 参数 schema 不存在）；行 = 粗体仓库名 + 描述 + ⭐ 星数 + 语言点/语言名；行点击进入仓库详情；first:25 + endCursor 加载更多。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + login dragonflyoss（灰）+ 标题 Repositories（粗体）+ 搜索（🔍）
2. 筛选条（整条横向可滑）：Type 胶囊下拉 [All ▾] + Language 胶囊 [Language ▾] + Sort 胶囊 [Sort: Recently pushed ▾]（后两者点击拉起底部面板）；有激活筛选时最左出现漏斗计数 chip（点开 Clear all filters）
3. 底部语言面板：✕ + Filter by language + 🔍（展开内联搜索框）+ 语言行列表（色点 + 语言名 + 选中蓝勾）
4. 底部排序面板：✕ + Sort by + 单选行列表（4 组 × 2，组间 16vp 灰带分隔；右侧单选圆钮，选中=蓝描边 + 蓝实心点）
5. 仓库行列表（整行点击进仓库详情）：
   - 仓库名 nydus + 描述 Nydus – a reliable, high-perf… + 星数 ⭐ 1.6k + 语言 ● Rust
   - 仓库名 dragonfly + 描述 Delivers efficient, stable… + 星数 ⭐ 3.3k + 语言 ● Go
   - ……（加载更多）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar | ← + login（灰，上）+ Repositories（粗体，下）+ 🔍 | 导航 | ✅ | —（纯 UI） | 自绘头部 hideTitleBar；🔍 → 现有 Search 页 |
| 2 | 筛选条 | Type ▾ 下拉（All / Archived / Fork / Mirror / Private / Public / Source / Template） | **服务端为主 + 客户端兜底** | ✅ | `repositories(isArchived:/isFork:/privacy:)`（实测支持）；Mirror/Template 无参数 → 客户端 | 6 项下推服务端（archived/fork/source/private/public/all）；Mirror/Template 与 source 的 mirror 部分由 `filterReposByType` 客户端复核 |
| 3 | 筛选条 | Language 胶囊 → 底部面板（全量语言清单 + 内联搜索） | 客户端过滤 | ✅ | `primaryLanguage`；语言清单 GET /languages | 与 Spec 056 Trending 共用 LanguageFilterSheet 组件；仅已加载页；再点选中项=取消筛选 |
| 4 | 筛选条 | Sort 胶囊 → 底部面板（Recently pushed / Least recently pushed / Newest / Oldest / Name ascending / Name descending / Most starred / Least starred） | 服务端排序 | ✅ | `orderBy { field: PUSHED_AT/CREATED_AT/NAME/STARGAZERS, direction: ASC/DESC }` | 默认 Recently pushed；Newest/Oldest = 创建时间 |
| 5 | 筛选条 | 漏斗徽标 chip（激活筛选数 + Clear all filters） | 清除筛选 | ✅ | —（纯 UI） | 三个下拉取非默认值各计 1（含 Sort）；Clear all 与空态 RESET 同一函数：全部回默认 |
| 6 | 行 | 仓库名（粗体）+ 🔒 lock 图标（private 仓库） | 展示 | ✅ | `name/isPrivate` | private 仓库行首显示 lock 图标 |
| 7 | 行 | 描述（灰，最多 3 行） | 展示 | ✅ | `description` | — |
| 8 | 行 | ⭐ 星数（compactCount 缩写） | 展示 | ✅ | `stargazerCount` | — |
| 9 | 行 | 语言色点 + 语言名 | 展示 | ✅ | `primaryLanguage` | — |
| 10 | 行 | 整行点击 → 仓库详情 | 导航 | ✅ | —（纯 UI） | pushPathByName('repoDetail', nameWithOwner) |
| 11 | 列表底 | 加载更多（first:25 + endCursor） | 请求 | ✅ | `pageInfo` | — |

> 可行性比例声明：11/11 可行。

---

## 四、核心 GraphQL 片段

```graphql
query OrgRepositories($login: String!, $first: Int = 25, $after: String,
  $orderBy: RepositoryOrder = { field: PUSHED_AT, direction: DESC }) {
  organization(login: $login) {
    repositories(first: $first, after: $after, orderBy: $orderBy) {
      pageInfo { hasNextPage endCursor }
      nodes { ... on Repository {
        id name nameWithOwner description stargazerCount forkCount isPrivate
        isArchived isFork isMirror isTemplate
        primaryLanguage { name color }
      } }
    }
  }
}

query UserRepositories($login: String!, $first: Int = 25, $after: String,
  $orderBy: RepositoryOrder = { field: PUSHED_AT, direction: DESC }) {
  user(login: $login) {
    repositories(first: $first, after: $after, orderBy: $orderBy) {
      pageInfo { hasNextPage endCursor }
      nodes { ... on Repository {
        id name nameWithOwner description stargazerCount forkCount isPrivate
        isArchived isFork isMirror isTemplate
        primaryLanguage { name color }
      } }
    }
  }
}
```

组织模式 REST 兜底（`/orgs/{owner}/repos`）同源字段：`archived` / `fork` / `mirror_url`（非空即镜像）/ `is_template` / `private`。

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 私密仓库 | 越权访问无数据 | 「Private」选项对无权限用户自然返回空 + 空态提示 |
| 语言筛选仅作用已加载页 | `repositories` 连接无 `filterByLanguage`（已移除）；`/search/repositories` 有 `language:` 但无 pushed 排序 + 1000 上限 | 客户端过滤；配合下方「空态自动补拉」缓解假空 |
| Type 的 Mirror / Template | `repositories` 连接无 `isMirror`/`isTemplate` 参数（2026-09-13 实测） | 客户端过滤（其余 6 项已下推服务端） |
| 客户端过滤页的「假空」 | 第一页可能全被过滤掉，服务端其实还有数据 | **空态自动补拉**：过滤后为空且还有下一页时自动续拉，最多 5 页（`utils/FilterLoading`）；仍空则在空态追加「已加载的内容中没有匹配」提示 |
| 组织模式 GraphQL 失败 | read:org 缺失或接口异常 | REST `/orgs/{owner}/repos?per_page=100&sort=…&direction=…` 兜底（一页 100，无翻页；`pushed/updated/created/full_name` 服务端排、STARGAZERS 与 NAME 客户端排；筛选仍在客户端） |
| 语言清单完整化 | GitHub 语种庞大 | 接 `GET /languages` 全量 833 项（免认证）；失败降级内置子集（常用 7 项置顶 + 字典序） |
| 搜索框内联搜索（输入过滤） | 官方为页内搜索 | 本轮 🔍 跳现有 Search 页（Spec 015） |
| 页内 Favorites/收藏操作 | 截图无 | 不实现 |

---

## 六、TDD 验收标准

- [ ] 测试 1：筛选三件均真实生效（Type 8 项切换 / 语言面板选与取消 / 排序面板 8 项切换列表顺序变化）；默认排序 = Recently pushed
- [ ] 测试 2：行样式（名/描述/星数/语言点）按截图对齐；行点击进仓库详情
- [ ] 测试 3：≥25 条出现加载更多并正常翻页；空态正常
- [ ] 测试 4：组织入口（组织主页 Repositories 行）与用户入口（Profile Repositories）共用本页
- [ ] 测试 5：构建 + 模拟器实测；grep 无中文字符串字面量；check-spec.sh 通过
- [x] 测试 6：宿主单测 `filterReposByType` 8 项语义（含 source=非 fork/镜像/归档、未知 key 不过滤）
- [x] 测试 7：宿主单测 `repoOrderFromKey` 8 项排序键 → orderBy 字段/方向（未知键回退 Recently pushed）

---

## 七、备注

- compactCount 复用 `utils/Format`；语言色点复用 RepoCard 同款色值。
- Type 8 项 = 官方仓库筛选清单（与 Spec 021 Top Repositories 同款），i18n 共用 `repos_filter_all/archived/fork/mirror/private/public/source/template` 一套键；过滤语义见 `models/GitHubModels.filterReposByType`（source = 非 fork/镜像/归档）。
- 语言面板 = 与 Spec 056 Trending 共用的 `components/LanguageFilterSheet`（✕ + 标题 + 🔍 内联搜索 + 色点行 + 选中蓝勾）；语言清单经 `ExploreService.fetchAllLanguages`（GET /languages）+ `sortLanguages`（常用 7 项置顶），失败降级 `PROGRAM_LANGUAGES`。
- 排序面板 = `components/SortBySheet`（✕ + Sort by + 单选行 56vp + 组间 16vp 灰带 `heat_empty`；单选圆钮 20 描边/10 实心，选中蓝）；8 项键 → orderBy 映射见 `services/ProfileListService.repoOrderFromKey`。
- 筛选交互统一口径（全库）：每个下拉有自己的默认值（可为空）；取非默认值即「有一项筛选条件」，漏斗徽标数字=条件个数（含排序）；徽标存在且列表为空时显示 RESET ALL FILTERS，其行为与漏斗菜单 Clear all filters 完全一致（所有下拉回默认 + 清多选 + 重查）；页内搜索不计入徽标、也不被两者清除。详见 Spec 068（筛选交互统一约定，全库跨页面）。
- 服务端/客户端分工（2026-09-13 调研定案）：Type 6 项与 Sort 走服务端；Language 与 Mirror/Template 客户端 + 自动补拉兜底。
- 两种筛选 chip 同款胶囊外形（高 32/圆角 16/12fp + chevron-down）：下拉型 `FilterDropdownChip`（自绘弹出卡片）、面板型 `FilterSheetChip`（点击拉起底部面板）；页面单 bindSheet + `sheetKind` 分派（同组件多 bindSheet 只有最后一个生效）。
- i18n：`repos_list_title`、`repos_filter_all/archived/fork/mirror/private/public/source/template`、`repos_filter_language`、`repos_sort_recent/least_recent/newest/oldest/name_asc/name_desc/most_stars/least_stars`、`repos_sort_format`、`repos_list_empty`、`filter_language_title`、`filter_sort_title`、`filter_no_results`、`search_placeholder`、`work_clear_all_filters`。
