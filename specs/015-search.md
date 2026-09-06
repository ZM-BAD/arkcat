# Spec 015: Search（全局搜索页）

> BFS Level: 3
> 关联截图: 官方 App Search（入口页 5 张：空态/键盘 chips/建议列表/Jump to/历史搜素）
> 上游 Spec: 013（Home 搜索入口）
> 状态: implemented（v1 2026-08-31 建议列表+Code 结果验收通过；v2 2026-09-03 官方入口页 5 图批次实现+模拟器走查通过）

---

## 一、页面/功能概述

全局搜索页，入口为 Home Header 🔍。对照官方 App：

- **搜索栏**：← + 输入框（占位「Search GitHub」，带 × 清除 + 下划线）+ ⋯ 竖三点菜单（蓝色）
- **空态**（无输入且无历史）：居中大标题「Find your stuff.」+ 灰色说明（People / Repositories / Organizations / Issues / Pull Requests 五类）
- **qualifier chips**（输入框聚焦、键盘弹出时）：底部横排快捷限定词 chip：repo / user / org / path / symbol…，点击插入限定词前缀
- **建议列表**（输入关键词后）：Code / Repositories / Issues / Pull Requests / People / Organizations with "q"（带图标）+ 末行 **→ Jump to "q"**
- **搜索历史**（清空输入后）：「Recent searches」+ CLEAR；点击历史词回填
- **结果页**（选中入口行）：统一 SearchResults 列表页（复用现有卡片组件），Code 沿用 v1 结果卡

---

## 二、整体 UI 结构

1. 顶部导航头（自绘）：← 返回 + 搜索输入框（占位 Search GitHub，× 清除）+ ⋮ 竖三点菜单（蓝色）（← 自绘导航头）
2. 空态（无输入且无历史时）：「Find your stuff.」+ 说明文案（Search all of GitHub for People, Repositories, Organizations, Issues, and Pull Requests.）（← 空态（无历史时））
3. 空态（有历史时）：Recent searches + CLEAR，历史行 cli + ↗（← 空态（有历史时））
4. 建议列表（输入关键词后）（← 输入关键词后）：每行 = 图标 + 入口名
   - < > Code with "q"
   - ▣ Repositories with "q"
   - ◔ Issues with "q"
   - ⑂ Pull Requests with "q"
   - 👤 People with "q"
   - ▤ Organizations with "q"
   - → Jump to "q"
5. qualifier chips（键盘弹起时底部）：repo / user / org / path / sy…（← 键盘弹起时底部 chips）
6. 底部 Tab：Home（蓝，选中态）/ Inbox / Explore / Copilot（← 官方保留底部 Tab，见边界）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | 导航头 | ← 返回 | 回退 | ✅ 纯 UI | — | — |
| 2 | 导航头 | 输入框（占位 Search GitHub + 下划线 + × 清除） | 输入/清除关键词 | ✅ 纯 UI | — | × 仅在有关键词时显示 |
| 3 | 导航头 | ⋯ 竖三点（蓝色） | 菜单入口 | ✅ 纯 UI | — | 菜单项后续 Spec，暂点击提示 |
| 4 | 空态 | 「Find your stuff.」+ 五类说明 | 引导 | ✅ 纯 UI | — | 无输入且无历史时显示 |
| 5 | chips | qualifier 快捷 chip（repo/user/org/path/symbol） | 点击插入限定词前缀 | ✅ 纯 UI | — | 聚焦且键盘弹出时显示；第 5 项「sy…」截图截断，按 symbol 推断 |
| 6 | 建议列表 | 六类入口行 | 点击进入结果页 | ✅ | `search(type: CODE/REPOSITORY/ISSUE/PR/USER)` | Organizations 无 search type，REST 兜底 |
| 7 | 建议列表 | Jump to "q" | 跳转首个匹配实体 | ✅ | `search(type: REPOSITORY)` 探测 | 首个匹配仓库 → RepoDetail；无匹配 toast |
| 8 | 空态 | Recent searches + CLEAR + 历史行(↗) | 本地历史回填/清除 | ✅ 纯 UI | — | preferences 持久化，最多 10 条 |
| 9 | 结果页 | 六类结果列表（复用卡片：RepoCard/Issue/PR/User/Org/Code 卡） | 展示与翻页 | ✅ | 同 6；分页 `pageInfo` | Code 沿用 v1 结果卡 |
| 10 | 底部导航 | 四 Tab | 导航 | ✅ 纯 UI | — | 官方保留；本实现为 Navigation 覆盖式二级页，不追（见边界） |

---

## 四、核心 GraphQL 片段

```graphql
# 通用搜索（Repository/Issue/PR/User 分派 type）
query SearchAll($query: String!, $type: SearchType!, $first: Int = 20, $after: String) {
  search(query: $query, type: $type, first: $first, after: $after) {
    searchCount
    pageInfo { hasNextPage endCursor }
    nodes {
      ... on Repository { id nameWithOwner description stargazerCount pushedAt }
      ... on Issue { id title state repository { nameWithOwner } }
      ... on PullRequest { id title state repository { nameWithOwner } }
      ... on User { id login name avatarUrl }
    }
  }
}

# Code 搜索（结果含文件名/路径/仓库 + 代码行文本）
query CodeSearch($query: String!, $first: Int = 10) {
  search(query: $query, type: CODE, first: $first) {
    codeCount
    nodes {
      ... on SearchResultItemEdge { node { ... on File { repository { nameWithOwner } path name } } }
    }
  }
}
```

> Code 搜索的代码行文本需 REST `/search/code?q=` 辅助（GraphQL File 节点无内容），降级：结果展示文件名+路径+仓库，代码片段后续 Spec。
> Organizations 走 REST `/search/users?q=...&type=organization`（官方移动端与 web 的 org 搜索页源）。

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| Organizations 结果（GraphQL） | GraphQL search 无 ORGANIZATION 类型 | 走 REST `/search/users?type=organization` 兜底；结果卡复用 UserCard/OrgSummary |
| 代码行内容+高亮 | GraphQL CODE 无文本内容；REST code search 需单独 token scope | 降级展示 文件名/路径/仓库；内容高亮随 Spec 011（Code Viewer）对应路线补充 |
| 底部 Tab 保留 | 官方搜索页保留底部 Tab（Home 激活）；本实现为 Navigation 覆盖式二级页，展示 Tab 需重构导航架构 | 不追此项（平台导航取舍），走查说明 |
| qualifier chips 位置 | 官方在键盘上方（页面底部）；HarmonyOS 无窗口级键盘压缩 API（keyboardAvoidMode 仅 Select/Sheet/Menu），页面不被压缩 | chips 置于输入栏下方、聚焦时显示（交互等价：输入辅助+随键盘出现）；后续官方图校准 |
| qualifier chips 第 5 项 | 截图「sy…」截断，无法确认完整词 | 按 GitHub 官方 code search `symbol:` 推断；后续官方图可校准 |
| Jump to 多实体探测 | 无法确认官方探测顺序 | 本实现先按 Repository 探测打开详情；Issue/PR 后续补充 |

---

## 六、TDD 验收标准

- [x] 搜索栏输入关键词显示六类建议入口（模拟器截图：claude 建议列表验收通过）
- [x] 点击 Code 分类进入结果页，展示文件卡（单测 mapCodeSearch 22/22 覆盖；UI 点击因软键盘阻挡，数据层已验证）
- [x] i18n key（base/zh_CN 对齐）；ohosTest 通过
- [x] 模拟器截图验收（建议列表实拍）
- [x] 空态（Find your stuff. / 五类说明）与清空后 Recent searches + CLEAR（有历史时）切换正确（v2 模拟器走查）
- [x] qualifier chips 聚焦显示/失焦隐藏、点击插入限定词前缀（纯函数单测 buildQualifierInsert 覆盖）
- [x] 历史持久化：写入/去重（置顶）/上限 10 条/CLEAR 清空（纯函数单测 + 模拟器走查）
- [x] 六类入口行均可进入对应结果页（Code/Repos/Issues/PR/People 实走查，Organizations 走 REST）
- [x] Jump to 打开首个匹配仓库详情（模拟器走查：cli → cli/cli 详情）

---

## 七、备注

- v1（2026-08-31）：搜索建议 + Code 结果布局完成，截图验收通过
- v2（2026-09-03）：按官方入口页 5 张图实现——空态「Find your stuff.」、qualifier chips（repo/user/org/path/symbol）、建议列表第 7 行 Jump to、Recent searches 历史（preferences 持久化、最多 10 条、CLEAR）、六类入口行进统一 SearchResults 结果页（Organizations 走 REST 兜底）
- GraphQL CODE search 只返回 File 节点元数据（仓库/路径/文件名），代码行正文由 REST 兜底后续接入
- 竖三点「⋮」蓝色菜单为新增资源 oct_kebab_vertical_24（官方 Octicon kebab-vertical 图形）
