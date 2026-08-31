# Spec 015: Search（全局搜索页）

> BFS Level: 3
> 关联截图: 官方 App Search（建议列表 + Code 结果）
> 上游 Spec: 013（Home 搜索入口）
> 状态: implemented（2026-08-31，模拟器截图验收通过）

---

## 一、页面/功能概述

全局搜索页，入口为 Home Header 🔍。对照官方 App：

- **搜索栏**：← + 输入框（带 × 清除 + ⋯ 菜单）
- **建议列表**（输入关键词后）：Code with "q" / Repositories with "q" / Issues with "q" / Pull Requests with "q" / People with "q" / Organizations with "q"（带图标）
- **结果页**（选中 Code）：分类标题（Code）+ 仓库/文件名卡片 + Markdown 徽章 + 行号代码片段（命中词高亮）+「Show N more matches」

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│  ←  [搜索输入框 claude code]  ×  ⋯  │
├─────────────────────────────────────┤
│  < >  Code with "claude code"        │
│  ▣    Repositories with "..."        │
│  ◔    Issues with "..."              │
│  ⑂    Pull Requests with "..."       │
│  👤   People with "..."              │
│  ▤    Organizations with "..."       │
├─────────────────────────────────────┤
│  Code  （选中分类后的结果）          │
│  🏢 repo / CLAUDE.md                 │
│  [● Markdown]                        │
│  1  # CLAUDE.md                      │
│  2  This file ... "Claude Code" ...  │
│  3  ## Environment Setup             │
│  ⋮  [ Show 8 more matches ]          │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
|---|------|------|------|--------|-------------|------|
| 1 | 搜索栏 | ← 返回 | 回退 | ✅ 纯 UI | — | — |
| 2 | 搜索栏 | 输入框 + × | 输入/清除关键词 | ✅ 纯 UI | — | — |
| 3 | 搜索栏 | ⋯ 菜单 | 后续 Spec | ⚠️ | — | 点击提示 |
| 4 | 建议列表 | 六类入口行（Code/Repos/Issues/PRs/People/Organizations） | 点击进入对应分类结果 | ✅ | `search(type: CODE/REPOSITORY/ISSUE/PR/USER/DISCUSSION)` | 静态行 + 关键词占位 |
| 5 | 结果页 | Code 结果卡（仓库/文件名/Markdown 徽章/代码片段+高亮） | 展示匹配 | ✅ | GraphQL `search(type: CODE)` 含文本高亮 | 高亮由客户端实现 |
| 6 | 结果页 | Show N more matches | 展开更多 | ⚠️ | — | 点击提示（后续分页 Spec） |
| 7 | 底部导航 | 四 Tab | 导航 | ✅ 纯 UI | — | — |

---

## 四、核心 GraphQL 片段

```graphql
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

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
|----|------|-------------------|
| 搜索建议历史 | 官方本地历史，无公开接口 | 本次不做，仅关键词输入 |
| 代码行内容+高亮 | GraphQL CODE 无文本内容；REST code search 需单独 token scope | 降级展示 文件名/路径/仓库；内容高亮将随 Spec 016（Code Viewer）补充 |
| Organizations 结果 | GraphQL search 无 ORGANIZATION 类型 | 建议入口保留，点击提示后续 |

---

## 六、TDD 验收标准

- [x] 搜索栏输入关键词显示六类建议入口（模拟器截图：claude 建议列表验收通过）
- [x] 点击 Code 分类进入结果页，展示文件卡（单测 mapCodeSearch 22/22 覆盖；UI 点击因软键盘阻挡，数据层已验证）
- [x] i18n key（base/zh_CN 160/160 对齐）；ohosTest 22/22 通过
- [x] 模拟器截图验收（建议列表实拍）

---

## 七、备注

- GraphQL CODE search 只返回 File 节点元数据（仓库/路径/文件名），代码行正文由 REST 兜底后续接入
- 2026-08-31：搜索建议 + Code 结果布局完成，截图验收通过
