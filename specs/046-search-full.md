# Spec 046: 搜索全类型与最近搜索（Search 五类详情）

> BFS Level: 3
> 关联截图: 官方 Explore 搜索页（类型 tab + 结果列表 + 最近搜索历史）
> 上游 Spec: 015（Search，未排期子页）
> 状态: draft（2026-09-02 规划；仅做搜索类型补齐与结果接通，不扩大搜索范围）
> 09-04 补充：六类结果页 + 聚合结果页（回车直进）已在 feature/ui-polish 分支实现（搜索批;未 push）；GraphQL `search` 无 CODE 类型 → code 走 REST /search/code + 内容级行号/高亮；组织用 `type:org` 限定词（USER 搜索返回 Organization 节点）、`type:user` 同理分型；label 徽章/Checks/Reviews/评论/反应计数由 SEARCH_ALL_QUERY 补字段

---

## 一、页面/功能概述

现有 Search 只有 CODE 类型可用（015 的「结果详情子页」未排期）。本 Spec 补齐：**仓库 / Issue / PR / 用户 / 组织** 五类搜索的结果列表 + 点击结果进入已有详情页（RepoDetail/IssueDetail/PrDetail/Profile/OrgProfile，路由已存在，只需接通参数）；代码搜索结果升级为「点击 → CodeViewer 对应文件/行」；增加**最近搜索**（本地持久化，官方 2026 年 1.254 附近新增的「Clear recent searches」同款）。两类细节统一用 GraphQL `search`（type 枚举：ISSUE/REPOSITORY/USER/CODE；PR 用 ISSUE + `is:pr`；组织用 USER + `in:org` 或组织库映射）。

---

## 二、整体 UI 结构

```text
Search（进入即历史/建议）
┌─────────────────────────────────────┐
│ 新增搜索入口框（复用现有搜索框）        │
│ 类型 chips: 仓库 | Issue | PR | 用户 | 组织 | 代码
├─────────────────────────────────────┤
│ 结果列表（按类型渲染）                 │
│  ├─ 仓库卡：名称/描述/星数/语言点       │
│  ├─ Issue/PR 卡：标题/仓库/状态徽章     │
│  ├─ 用户卡：头像/登录名/跟随按钮        │
│  └─ 代码结果：文件路径/高亮行（→ CodeViewer）
├─────────────────────────────────────┤
│ 最近搜索（本地列表 + Clear，无输入时显示）│
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | 搜索页 | 类型 chips 切换 | 五类结果类型切换（保留代码） | ✅ | search(type) 参数 | 各类型独立缓存/loading |
| 2 | 结果 | 仓库搜索 | `type: REPOSITORY` + qualifiers（in:name/description、user/org 域、language、sort:stars 等） | ✅ | 见四 | qualifiers chips 简化为一组常用过滤（language/owner） |
| 3 | 结果 | Issue 搜索 | `type: ISSUE`（is:issue）+ qualifier（state:open、label、is:public） | ✅ | 见四 | —— |
| 4 | 结果 | PR 搜索 | `type: ISSUE` + `is:pr`（复用 3 的渲染组，差异显示合并状态） | ✅ | 见四 | PR 徽章（merged 紫）沿用 018 规则 |
| 5 | 结果 | 用户搜索 | `type: USER`（in:username/name/email 或 login 前缀） | ✅ | 见四 | 官方输入 @ 也可触发 |
| 6 | 结果 | 组织搜索 | `type: USER` + `in:org` 限定组织（或 search 后过滤） | ✅ | 见四 | 与 5 结果合并展示（organizations tab） |
| 7 | 结果 | 点击路由 | repo→RepoDetail；issue/PR→详情；user→Profile；org→OrgProfile | ✅ | 无（LinkRouter by url） | 打通 045 的 LinkRouter |
| 8 | 代码 | 结果增强 | 代码结果点击 → CodeViewer（owner/repo/path/ref + 高亮选定行 hunk） | ✅ | 无 | 现有 CodeViewer 支持 path+ref，行号高亮为本项增量 |
| 9 | 历史 | 最近搜索历史 | 本地 @StorageLink 列表（最新 10 条）+ Clear all（~~单条删除~~ 裁剪：2026-09-05 review 拍板延后，当前无删除交互） | ✅ | 无 | 官方「Clear button in recent code searches」（1.273 bugfix 提及） |
| 10 | 排序 | 结果排序 | GraphQL search 无 orderBy；只能用 sort: 服务端 qualifier | ⚠️ | search + sort: | UI 提供「Stars/Recently updated」→ 追加 qualifier 重查 |
| 11 | 过滤 | 高级过滤面板 | 更多 qualifier（label:、author:、org:…）自由输入 | ⚠️ | 同 2-6 | 保留「语法提示」浮层，不做复杂表单 |
| 12 | 空态 | 无结果/错误 | 空态文案 + 错误重试；搜索无输入防抖 | ✅ | 无 | 首次搜索防抖 400ms |

> 可行性: 10/12 可行（排序、高级过滤面板两项 ⚠️）

---

## 四、核心 GraphQL 片段

```graphql
# 仓库
query SearchRepos($q: String!, $first: Int = 20) {
  search(query: $q, type: REPOSITORY, first: $first) {
    repositoryCount
    nodes { ... on Repository { id name nameWithOwner description url stargazerCount forkCount language { name } } }
  }
}
# issue / PR（PR 用 is:pr）
query SearchIssues($q: String!, $first: Int = 20) {
  search(query: $q, type: ISSUE, first: $first) {
    issueCount
    nodes {
      ... on Issue {
        id number title state url repository { nameWithOwner }
      }
      ... on PullRequest {
        id number title state merged url repository { nameWithOwner }
      }
    }
  }
}
# 用户 / 组织（组织 = 同查询 + in:org 或 is:org?）
query SearchUsers($q: String!) {
  search(query: $q, type: USER, first: 20) {
    userCount
    nodes { ... on User { id login name avatarUrl url followers { totalCount } } }
    edges { ... on SearchResultItemEdge { node { __typename ... on Organization { login name avatarUrl } } } }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 搜索排序 | GraphQL search 无 orderBy 参数 | 用服务端 qualifier `sort:stars` / `sort:updated` 重查；UI 标明「服务端排序」 |
| 代码搜索限流 | CODE 搜索每次请求消耗搜索配额（低配额警告） | 防抖 + 「还有 x 次」提示（配额取自响应 header） |
| 「在 org 中搜索」复合语法 | 支持有限 | 查询串透传（不做语法解析），用户可自写 qualifier |
| 结果分页 | 每页 20，滚动到底加载下一页 | 已有翻页组件（WorkService 模式） |
| 无标签建议/智能纠错 | 官方移动端也无 | 不做 |

---

## 六、TDD 验收标准

- [ ] 测试 1：输入关键词默认渲染「仓库」结果，卡片显示 名称/描述/星数/语言
- [ ] 测试 2：切换 Issue/PR 类型后请求参数含 is:issue / is:pr（断言 query 串）
- [ ] 测试 3：用户/组织类型结果点击 → Profile/OrgProfile 且参数正确
- [ ] 测试 4：issue/PR 结果点击 → IssueDetail/PrDetail
- [ ] 测试 5：代码结果点击 → CodeViewer 带 path/ref；高亮行参数生效（存在该行时）
- [ ] 测试 6：最近搜索：搜索 3 次后本地列表 3 条；Clear all 清空；再次进入搜索页显示历史
- [ ] 测试 7：防抖：连续输入 400ms 内只发一次请求
- [ ] 测试 8：代码搜索配额不足时提示且结果区不变白
- [ ] 测试 9：i18n 双份 + check-spec 通过

---

## 七、备注

- 015 的状态与本文关系：015 是「入口与框架」，本文是「详情子页」；实现后 015 转 implemented（由 046 承接），015 顶部备注更新指向 046。
- 代码搜索结果高亮：CodeViewer 当前文件视图已支持行号；行高亮建议用阅读位置组件（`scrollToLine` 或锚点高亮），若实现超界则降级为「进入文件不带行」。
- 与 049 多账号：最近搜索按账号隔离（key 含 login）。
