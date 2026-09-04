# Spec 010: PR Diff（Files Changed / Diff 视图）

> BFS Level: 3
> 关联截图: PR Detail → Files changed Tab
> 上游 Spec: 009
> 状态: ✅ implemented（2026-09-04，Spec 010 PR Diff 实现：GraphQL files 列表 + REST patch 兜底）

---

## 一、页面/功能概述

PR 的文件变更 Diff 视图，展示变更文件列表、每个文件的 diff hunk（新增/删除/上下文行）、行内评论入口。**Diff 内容需 REST API 兜底。**

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│  ←   Files changed (3)        ···    │
├─────────────────────────────────────┤
│  📁 changes from all commits         │
├─────────────────────────────────────────────────────────┐
│  📄 .harmony_backup/.idea/...zip   +4 -0  [↑][👁]       │
│  ─────────────────────────────────────────────────────  │
│  @@ -0,0 +1,2 @@                                    │
│  + Good good study               ← 新增行（绿色）       │
│  + Up up day                                            │
│  ─────────────────────────────────────────────────────  │
│  📄 README.md                     +174 -0  [↑][👁]       │
│  ─────────────────────────────────────────────────────  │
│  @@ -1,3 +1,8 @@                                    │
│    # starraft                    ← 上下文行（白色）      │
│  - Some old text                ← 删除行（红色）        │
│  + 鸿蒙 Next 原生 GitHub 客户端  ← 新增行（绿色）       │
│  ─────────────────────────────────────────────────────  │
│  📄 README_zh.md                 +271 -0  [↑][👁]       │
├─────────────────────────────────────┤
│  💬 Add a comment...         📎 📤  │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
|---|------|------|------|--------|------|------|
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ 纯 UI | — | — |
| 2 | App Bar 中 | 「Files changed (N)」 | 展示 | ✅ | GraphQL `files.totalCount` | — |
| 3 | App Bar 右 | ··· 更多菜单 | 文件查找 | ✅ 客户端 | — | — |
| 4 | 改动摘要 | changes from all commits | 展示 | ✅ | — | — |
| 5 | 文件头 | 📄 路径 + `+N -N` | 展示 | ✅ | GraphQL `files { path additions deletions }` | — |
| 6 | 文件头 | ↑ 折叠按钮 | 折叠/展开 | ✅ 纯 UI | — | — |
| 7 | 文件头 | 👁 查看按钮 | 跳转完整文件 | ⚠️ | 需额外请求 | — |
| 8 | Diff Hunk | `@@ -1,3 +1,8 @@` | 展示 | ✅ | REST patch | — |
| 9 | Diff 内容 | 绿色（新增行） | 展示 | ✅ | REST `GET /repos/.../pulls/{n}/files` | — |
| 10 | Diff 内容 | 红色（删除行） | 展示 | ✅ | 同上 | — |
| 11 | Diff 内容 | 白色（上下文行） | 展示 | ✅ | 同上 | — |
| 12 | 行内评论 | 💬 评论图标 | 添加行内评论 | ⚠️ | REST `POST /repos/.../pulls/{n}/comments` | — |
| 13 | 浮动评论 | Add a comment | 提交全局评论 | ✅ | GraphQL `addComment` | — |
| 14 | 附件上传 | 📎 按钮 | 上传图片 | ⚠️ | REST Asset Upload | — |

---

## 四、核心接口

### 1. 文件变更列表（GraphQL）

```graphql
query PullRequestFiles($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      files(first: 100) {
        totalCount
        nodes { path additions deletions changeType viewerViewedState }
      }
    }
  }
}
```

### 2. Diff 内容获取（REST 兜底）

```http
GET /repos/{owner}/{repo}/pulls/{number}/files

Response:
[
  {
    "filename": "README.md",
    "status": "modified",
    "additions": 174,
    "deletions": 0,
    "patch": "@@ -1,3 +1,8 @@\n # starraft\n+鸿蒙 Next...",
    "blob_url": "...",
    "raw_url": "..."
  }
]
```

### 3. 行内评论（REST）

```http
GET /repos/{owner}/{repo}/pulls/{number}/comments
POST /repos/{owner}/{repo}/pulls/{number}/comments
Body: { "body": "...", "path": "src/main.ets", "line": 42, "side": "RIGHT", "commit_id": "abc123" }
```

### 4. 标记文件已看（GraphQL）

```graphql
mutation MarkFileAsViewed($pullRequestId: ID!, $path: String!) {
  markFileAsViewed(input: { pullRequestId: $pullRequestId, path: $path }) {
    pullRequest { files { nodes { viewerViewedState } } }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
|----|------|-------------------|
| Diff 内容 | GraphQL 无直接 Diff 字段 | REST `pulls/{n}/files` 兜底 |
| 行内评论 | 需 REST API | 实现 REST 调用 |
| 附件上传 | 需 REST Asset Upload | 暂不实现 |
| Side-by-Side 视图 | 复杂度高 | MVP 只做 Inline 视图 |
| 图片 Diff | 特殊处理 | MVP 只展示文本 Diff |

---

## 六、TDD 验收标准

- [x] 文件变更列表能展示
- [x] Diff 内容能渲染（绿/红/白三色）
- [x] 折叠/展开文件 Diff 正常
- [x] 全局评论提交正常

---

## 七、备注

- 11/14 可行
- Diff 渲染是 GraphQL 的薄弱区，需同时封装 GraphQL + REST
- 客户端需写轻量 Diff parser（按 `@@` 分割 hunk）
