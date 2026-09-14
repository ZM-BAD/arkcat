# Spec 065: Share Feedback → 仓库 Discussions

> BFS Level: 3
> 关联截图: Settings → Share feedback 行
> 上游 Spec: 014（Settings）
> 状态: implemented

---

## 一、页面/功能概述

Settings → Share feedback 不再用浏览器：直接压栈到 App 内 Discussions 列表页，并限定为 ArkCat 仓库（ZM-BAD/arkcat）的讨论——作为 GitHub 客户端，反馈入口就是仓库自身的 Discussions。仓库 Discussions 已通过 GitHub API 开启（has_discussions=true）。

实现方式：复用工作区 Discussions 页（Discussion search），新增可选 `repo` 参数——非空时搜索串追加 `repo:owner/name` 并跳过个人归属 qualifier（author:@me 等），同时隐藏归属筛选 chip（对单仓库无意义）；空参时行为与原全局模式完全一致。

---

## 二、整体 UI 结构

与工作区 Discussions 页一致（Spec 016 系），仅三处差异：

1. 数据范围：仅 ZM-BAD/arkcat 的 discussions（repo: 搜索限定）
2. 筛选行：无「归属」（created/assigned/…）chip；状态 / **Author / Label（新增，位置在状态与 Unanswered 之间）** / Unanswered / 排序保留
3. Author/Label 为弹层选择（官方同款）：Author=用户行弹层（头像+login+name+搜索）；Label=彩色标签弹层（Unlabeled 行 + GitHub 色标签 chip + 搜索），qualifier 分别为 `author:login` 与 `label:"name"`/`no:label`（Unlabeled）；选项来源：Author=已加载讨论作者去重，Label=repository.labels 全集（首次打开弹层时拉取）
4. **Category 为弹层选择（2026-09-14 官方同款，chip 位于 Author 与 Label 之间）**：标题「Filter by category」，双态头部（点 🔍 标题就地变搜索框，✕ 变 ←，框内 ✕ 清词）；行=emoji + 分类名 + 描述两行；qualifier=`category:名称`（**用分类名本身**，大小写不敏感、带空格/标点加引号——实测 deno：category:Q&A=458、category:"show and tell"=13、dash-slug 形式无效）；选项来源=`repository.discussionCategories`（首次打开拉取）；emoji 为 GitHub shortcode（':mega:'），经 `emojiFromShortcode` 映射 unicode（覆盖官方默认六分类）；计入漏斗徽标

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | Settings | Share feedback 行 | push discussions 路由，参数 'ZM-BAD/arkcat' | ✅ | 无 | 原 comingSoon 接通 |
| 2 | Discussions 页 | repo 参数 | 搜索限定单仓库 | ✅ | search(query: "is:discussion repo:…") | buildWorkDiscussionsQuery 扩展 |
| 3 | Discussions 页 | 归属 chip 隐藏 | repo 模式不显示 | ✅ | 无 | 全局模式不受影响 |
| 4 | 筛选行 | Author chip | 开作者弹层、author: 过滤 | ✅ | search(query: "… author:…") | 单仓库模式显示 |
| 5 | 筛选行 | Label chip | 开标签弹层、label:/no:label 过滤 | ✅ | repository.labels + search | 同上；Unlabeled=no:label |
| 5a | 筛选行 | Category chip | 开分类弹层、category: 过滤 | ✅ | `repository.discussionCategories` + search | 位于 Author 与 Label 之间；行=emoji+名称+描述 |

> 可行性图例：✅ 可直接实现 ｜ ⚠️ 部分可行/降级 ｜ ❌ 不可实现

---

## 四、核心 GraphQL 片段

```graphql
query {
  search(query: "is:discussion is:open repo:ZM-BAD/arkcat sort:created-desc", type: ISSUE, first: 25) {
    nodes { ... }
  }
}
```

（沿用 WORK_DISCUSSIONS_QUERY，仅 query 变量构造变化）

---

## 五、边界 / 不可行项

1. 仓库 Discussions 未开启时搜索为空 → 走 Discussions 页既有空态（已通过 API 开启，正常态不会出现）。
2. 路由不带参数（未来其他入口）→ repo=''，回退全局工作区语义，零行为变化。

---

## 六、TDD 验收标准

- [x] buildWorkDiscussionsQuery：repo 模式产出 `repo:` qualifier 且无 author:@me；全局模式串不变（宿主单测）
- [x] Settings → Share feedback 进入 ZM-BAD/arkcat 讨论列表，归属 chip 不显示（人工走查）
- [x] 从 Settings 进入时底部 tab 栏隐藏（discussions 加入 TAB_BAR_HIDDEN_ROUTES，人工走查）

---

## 七、备注

1. 系统开屏改版与开源库页（Spec 064）同批交付；X 品牌标注按用户 2026-09-12 裁定移除。
2. Terms of Service 行同批接通应用内浏览器（github-terms-of-service 文档页）。
