# Spec 053: 仓库 Stargazers / Forks 列表页

> BFS Level: 2
> 关联截图: 微信图片_20260903232059_50_181.jpg（DAG-chat Stargazers）、微信图片_20260903232100_51_181.jpg（DAG-chat Forks）
> 上游 Spec: 006（仓库详情页头部 stars/forks 计数）
> 状态: implemented（2026-09-07 漂移复核：双页/服务/模型完整实现）

---

## 一、页面/功能概述

点击仓库详情页头部的「N stars」/「N forks」（含图标+计数，可点区域）进入对应列表页：
两页共用「仓库名（粗体）+ 副标题（灰）」自绘 AppBar 模式。
Stargazers = 用户行（圆头像/显示名/login/两行简介）；Forks = 分叉仓库行（owner 头像/owner login/仓库名/描述/
「Forked from 上游」/星数/语言），Forks 右上另有搜索（就地过滤）与 + 按钮（沿用 RepoDetail 惯例，暂 toast）。

---

## 二、整体 UI 结构

**Stargazers 页：**
1. App Bar：返回按钮 + 仓库名 DAG-chat（粗体）+ 副标题 Stargazers（灰）
2. 用户行一：圆形头像 + 显示名 Xiaoqiang Wang + login Robert-xiaoqiang（灰）+ 简介（2 行灰省略）
3. 用户行二：圆形头像 + 显示名 Yangwu Chen + login chenyang50
4. 列表尾部：加载更多 / 空态 / 错误

**Forks 页：**
1. App Bar：返回按钮 + 仓库名 DAG-chat（粗体）+ 副标题 Forks（灰）+ 搜索按钮 + 加号按钮（＋）
2. 仓库行一：属主头像（20vp）+ login yjnzen（灰）+ 仓库名 DAG-chat + 描述 2 行 + fork 图标 + Forked from ZM-BAD…（灰）+ 星数 0 + 语言点 ● + TypeScript
3. 列表尾部：加载更多 / 空态；搜索框在 App Bar（搜索态替换标题行）

Stargazers 行间无分隔线；Forks 行间有 Divider。两页均 Scroll + 保留 StateView（loading/错误重试）。

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | AppBar | ← + 仓库名（粗体 20fp）+ 副标题（灰 14fp（body_font_size）） | 返回 / 标题 | ✅ | — | 参数为 nameWithOwner；副标题=Stargazers/Forks |
| 2 | Stargazers 行 | 56vp 圆头像 + 显示名（粗体）/login（灰·无@）/bio（灰 2 行省略） | 展示 | ✅ | repository.stargazers(first:50) nodes{login name avatarUrl bio} | bio 为空隐藏；整行点击 → userProfile |
| 3 | Stargazers | 分页（hasNextPage → 触底自动加载） | 翻页 | ✅ | 同上 pageInfo | 列表尾部 spinner（ListLoadingFooter），非文字钮 |
| 4 | Stargazers | 空态 / StateView | 展示 | ✅ | — | 复用现有文案模式 |
| 5 | Forks 行 | 属主头像（20vp）+ login（灰） | 展示属主 | ✅ | repository.forks(first:50) nodes{ owner{login avatarUrl} } | — |
| 6 | Forks 行 | 仓库名（粗体）+ 描述（2 行）+ ⑂ Forked from {上游}(灰) | 展示 | ✅ | 同上 parent{name owner{login}} | 上游可空（parent=null）→ 隐藏该行 |
| 7 | Forks 行 | ★ 星数（黄）+ ● 语言色 + 语言名 | 展示 | ✅ | 同上 stargazerCount primaryLanguage{name color} | 行点击 → repoDetail |
| 8 | Forks 行 | 分页 / 空态 / StateView | 展示 | ✅ | — | — |
| 9 | Forks 右上 | 🔍 搜索（蓝色） | 就地搜索已加载列表 | ⚠️ | — | 客户端按名称/描述过滤（forks 连接无服务端关键词参数，与五页就地搜索模式一致） |
| 10 | Forks 右上 | ＋（蓝圈） | 官方语义未知 | ⚠️ | — | 沿用 RepoDetail 惯例 toast「敬请期待」，确认语义后接入 |

---

## 四、核心 GraphQL 片段

```graphql
query RepoStargazers($owner: String!, $name: String!, $first: Int = 50, $after: String) {
  repository(owner: $owner, name: $name) {
    stargazers(first: $first, after: $after) {
      pageInfo { hasNextPage endCursor }
      nodes { login name bio avatarUrl }
    }
  }
}

query RepoForks($owner: String!, $name: String!, $first: Int = 50, $after: String) {
  repository(owner: $owner, name: $name) {
    forks(first: $first, after: $after) {
      pageInfo { hasNextPage endCursor }
      nodes {
        name description stargazerCount
        primaryLanguage { name color }
        parent { name owner { login } }
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
| Stargazers/Forks 总数不展示 | 参考截图标题无计数 | 不查询/不展示 |
| parent 可能为 null | 上游仓库被删除/不可见 | 隐藏「Forked from」行 |
| forks 无服务端关键词搜索 | 连接不支持 search/filter 参数 | 客户端就地过滤已加载分页 |
| Forks 右上 ＋ | 官方语义未确认 | 暂 comingSoon toast |
| 星标者隐私（隐藏头像） | 匿名用户头像为 identicon | 官方 CDN 原样展示（无需处理） |

---

## 六、TDD 验收标准

- [x] 测试 1：mapFork：完整片段（owner/语言色/parent）→ 全字段映射正确
- [x] 测试 2：mapFork：parent = null → parentNameWithOwner = ''（行隐藏由 UI 判空）
- [x] 测试 3：mapFork：primaryLanguage = null → 语言为 ''（UI 隐藏语言点；断言见 LogicTest.test.ets `mapFork_nullParent`）

---

## 七、备注

- 行样式对照参考截图：Stargazers 行间距约 16vp 白留白、无卡片底；Forks 行同（flat 列表，bg_page 底）。
- 星数用 oct_star_16（黄 星金）而非 fill（截图轮廓星）；语言点为 languageColor。
- 「Forked from」行与 Stargazers 行的骨架复用现有 RepoCard/ListDetail 模式，不新造布局风格。
- 两页为同批次：共用 RepoService 新增 fetchStargazers/fetchForks（GraphQL 优先，无 REST 兜底——两连接均公开可查，仅需 repo scope 只读）。
