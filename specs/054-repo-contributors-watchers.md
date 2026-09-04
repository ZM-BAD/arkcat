# Spec 054: 仓库 Contributors / Watchers 列表页

> BFS Level: 2
> 关联截图: 三图批次第 1 张（ponytail Contributors）、第 2 张（ponytail Watchers）
> 上游 Spec: 006（仓库详情页 More 折叠区 Contributors/Watchers 入口）
> 状态: draft

---

## 一、页面/功能概述

点击仓库详情页 More 折叠区中「Contributors」/「Watchers」入口行进入对应列表页：
两页共用「仓库名（粗体）+ 副标题（灰）」自绘 AppBar 模式，与 Stargazers 列表页同款行样式
（56vp 圆头像 / 粗体显示名 / 灰 login / 灰 bio 两行）。行点击进入用户主页。

---

## 二、整体 UI 结构

```text
Contributors / Watchers（两页结构一致，仅副标题与数据源不同）
┌─────────────────────────┐
│ ←  ponytail             │
│    Contributors(灰)      │
├─────────────────────────┤
│ (savatar) DietrichGebert│  ← 无显示名：仅灰 login 单行
│ (avatar) Lakshya Sharma │
│          Lakshya77089   │
│    bio…（2行灰省略）    │
│ (avatar) {…}            │
│ …（加载更多/空态/错误） │
└─────────────────────────┘
```

行间无分隔线，纯留白（参考截图）；Scroll + StateView（loading/错误重试），沿用 Stargazers 页骨架。

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
|---|------|------|------|--------|------|------|
| 1 | AppBar | ← + 仓库名（粗体 20fp）+ 副标题（灰 16fp） | 返回 / 标题 | ✅ | — | 副标题文案复用 repo_contributors/repo_watchers；参数 owner/name |
| 2 | 行 | 56vp 圆头像 + 显示名（粗体）/login（灰·无@）/bio（灰 2 行省略） | 展示 | ✅ | Watchers: repository.watchers(first:50) nodes{login name bio avatarUrl}；Contributors: REST /contributors 取 login 序 + GraphQL user(login) 批量补 name/bio/avatarUrl | bio 为空隐藏；无显示名时仅灰 login 单行（与 Stargazers 行一致）；行点击 → userProfile |
| 3 | 行 | 无头像占位：底色 + oct_person_16 灰 icon | 展示（官方灰人形近似） | ✅ | — | 与现有头像底色占位共存：Image 加载中/失败时叠 person 图标 |
| 4 | 列表 | 分页（hasNextPage → 加载更多文字钮） | 翻页 | ✅ | Watchers: pageInfo{hasNextPage endCursor}；Contributors: REST page=N 且返回长度=50 近似 | 沿用 Stargazers 加载更多模式 |
| 5 | 列表 | 空态 / StateView | 展示 | ✅ | — | social_contributors_empty / social_watchers_empty；REST 404（无贡献者）→ 空态 |

---

## 四、核心接口

```graphql
query RepoWatchers($owner: String!, $name: String!, $first: Int = 50, $after: String) {
  repository(owner: $owner, name: $name) {
    watchers(first: $first, after: $after) {
      pageInfo { hasNextPage endCursor }
      nodes { login name bio avatarUrl }
    }
  }
}

# Contributors 元信息批量补全（单请求多 alias；login 列表由 REST /contributors 提供）
query ContributorsMeta {
  u0: user(login: "dietrichgebert") { login name bio avatarUrl }
  u1: user(login: "lakshya77089") { login name bio avatarUrl }
}
```

```text
REST：GET /repos/{owner}/{repo}/contributors?per_page=50&page={n}&anon=0
响应数组原序即贡献数降序（官方语义）；字段仅 login/avatar_url → 需与上表 GraphQL 合并。
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
|----|------|-------------------|
| GraphQL 无 repository.contributors 字段 | 贡献者列表为 REST 专属端点 | 走 REST /contributors（官方 App 同源路径）+ GraphQL 批量补全 name/bio |
| 批量 GraphQL 补全失败/超限 | 单请求多 alias 仍受成本限制 | 降级：仅用 REST login+avatarUrl 渲染（name/bio 空），不阻断列表 |
| 匿名贡献者（anon） | 无 GitHub 账号 | anon=0 排除，仅展示 GitHub 用户（官方 App 同） |
| contributors 分页无 cursor | REST Link 头不在 RawResponse 中 | 近似判断：返回长度=50 → hasNextPage=true；下一页 page+1 |
| contributors 404（空仓库） | 无 commit 记录时 REST 返回 404 | 视为空态，展示 social_contributors_empty |
| 无头像用户 | avatarUrl 为默认 identicon 或 null | oct_person_16 灰 icon 叠底色占位（官方灰人形近似） |

---

## 六、TDD 验收标准

- [x] 测试 1：mapWatcherPage：完整连接（nodes/pageInfo）→ users/hasNextPage/endCursor 映射正确
- [x] 测试 2：mapContributorPage：REST 数组 + GraphQL 补全合并 → 顺序保持 REST 原序、name/bio 覆盖正确
- [x] 测试 3：mapContributorPage：GraphQL 节点缺失（null user）→ 用 REST 字段（name='' bio='' 头像保留）
- [x] 测试 4：mapContributorPage：REST 长度<50 → hasNextPage=false（末页）

---

## 七、备注

- 行样式完全对照 Stargazers 页（Spec 053）现有实现，不新造布局；页面骨架为 RepoPeopleView 单组件，
  由路由 kind（contributors/watchers）分派副标题、数据源与空态文案。
- 两张截图与 Stargazers 页特征一致：无分隔线、行间距约 10vp 留白、底部四 tab 常驻遮挡（延续现状）。
- 保持与「体验级复刻」一致：功能入口位置（More 折叠区）、列表结构、交互逻辑对齐官方；
  贡献数不展示（截图无计数）。
