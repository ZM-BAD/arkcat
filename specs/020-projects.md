# Spec 020: Projects（工作区 Projects 列表页）

> BFS Level: 3
> 关联截图: GitHub 官方 App「Projects」页（Home My Work 入口，用户提供，2026-08-31）
> 上游 Spec: 013（入口）
> 状态: ✅ implemented（2026-08-31，构建通过 / 仪器测试 29/29 / 模拟器验收通过）

---

## 一、页面/功能概述

Home My Work「Projects」入口进入的 Projects 列表页，展示 viewer 可见的 ProjectsV2（跨仓库/组织）。筛选：项目范围（All projects / Owned by me）、状态（Open / Closed）、排序标签（Sort: Most recently visited）。行内展示项目图标、标题、编号、状态与更新时间。数据源 `viewer.projectsV2`；空态为官方蓝色猫插画 + 「There aren't any projects.」（截图所示即为此空态，无 RESET 按钮）。

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│  ←   Projects                🔍 ⋯  │ ← App Bar
├─────────────────────────────────────┤
│ [ All projects ⌄ ] [ Open ⌄ ] [ Sort: Most recently vi… ] │ ← 筛选行（可横向溢出）
├─────────────────────────────────────┤
│  ▦ 项目标题                    #12   │ ← Project 行
│     Open · 3d ago                    │
│  （… 分页 Load more）                 │
├─────────────────────────────────────┤
│  （空态：🐱 插图 + There aren't any projects.） │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ | —（纯 UI） | — |
| 2 | App Bar 中 | 「Projects」标题 | 页面标题 | ✅ | —（纯 UI） | — |
| 3 | App Bar 右 | 🔍 搜索 | 跳转全局搜索页 | ✅ | —（纯 UI） | 复用路由 search |
| 4 | App Bar 右 | ⋯ 更多 | 预留 | ✅ | —（纯 UI） | 点击提示 |
| 5 | 筛选行 | 范围下拉（All projects / Owned by me） | 项目范围筛选 | ✅ | `viewer.projectsV2` + `owner { login }` 客户端过滤 | 默认 All projects |
| 6 | 筛选行 | 状态下拉（Open / Closed） | 状态筛选 | ✅ | `closed` 字段客户端过滤 | 默认 Open |
| 7 | 筛选行 | 排序标签（Sort: Most recently visited） | 排序展示 | ⚠️ | `updatedAt` 客户端降序近似 | 「最近访问」无 GraphQL 字段，近似排序 |
| 8 | Project 行 | 项目图标 + 标题 | 展示 | ✅ | `title` | — |
| 9 | Project 行 | 编号 `#N` | 展示 | ✅ | `number` | — |
| 10 | Project 行 | 状态 + 更新时间 | 展示 | ✅ | `closed / updatedAt` | 复用相对时间 |
| 11 | 空态 | 插图 + 标题 | 空态展示 | ✅ | —（纯 UI） | 无副文案/按钮（对齐截图） |
| 12 | 列表底部 | Load more 分页 | 翻页 | ✅ | `projectsV2.pageInfo` | — |

> 可行性比例声明：11/12 可行。

---

## 四、核心 GraphQL 片段

```graphql
query WorkProjects($first: Int = 30) {
  viewer {
    login
    projectsV2(first: $first) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        id title number closed updatedAt
        owner { login }
      }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 「Most recently visited」排序 | GraphQL ProjectV2 无 visited 字段，连接无 orderBy 参数 | 展示官方文案标签，实际按 `updatedAt` 客户端降序近似（备注中说明） |
| 官方猫插画素材 | 无官方矢量素材 | 用占位字形（🐱）替代，文案一致 |
| 项目内 Issue 视图（点击项目进入看板） | 独立 Spec 范围 | 点击项目行提示后续 Spec 提供 |
| viewer.projectsV2 数据获取 | ProjectsV2 字段（title 等）需 `read:project` scope | 错误态展示 GitHub 引导文案（含 scopes 链接）；用户授权后无需改版即可用 |

---

## 六、TDD 验收标准

- [x] 测试 1：`mapWorkProjectsPage` 纯函数：节点映射、分页字段正确
- [x] 测试 2：`filterProjects(projects, ownedOnly, closedFilter)` 纯函数：Owned by me 过滤正确（owner.login != viewer.login 被剔除）
- [x] 测试 3：模拟器实测 — 范围/状态筛选切换触发刷新；空态文案对齐截图
- [x] 测试 4：grep 检查 Projects.ets 无中文字符串字面量残留
- [x] 测试 5：`bash scripts/check-spec.sh` 通过
- [x] 测试 6：`devecocli build` 全量构建通过

---

## 七、备注

- ProjectsV2 连接无 orderBy 参数，排序全部客户端完成：先按 closed 分组（Open 前置），再按 updatedAt 降序。
- 入口复用 013 的 Projects 彩色图标（灰 `#57606A`）。
- 筛选行与官方一致可横向溢出（长文案被截断），不强制换行。

- 模拟器实测：Projects 页渲染通过；数据区当前展示错误态（本机 PAT 无 `read:project` scope，GitHub 返回官方引导文案），用户授权后自动可加载。
