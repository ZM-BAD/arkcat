# Spec 031: PR 详情页（Changes / Status / Conversation）

> BFS Level: 3
> 关联截图: GitHub 官方 App PR 详情（DAG-chat #82，深色，用户提供 2026-08-31）
> 上游 Spec: 008/018/027（列表入口）/ 009（本 Spec 即 009 的实现）
> 状态: ✅ implemented（2026-08-31，构建通过 / 仪器测试 30/30 / 模拟器双主题验收通过）

---

## 一、页面/功能概述

PR 详情页三区块：**Changes 卡片**（N files changed · +A −D · commit 数 · 相对时间）、**Status 卡片**（Reviews 计数、Checks 状态、Branch merged 时间线）、**Conversation**（正文、Bot/真人评论、referenced/merged 事件行、DELETE BRANCH 按钮占位）。行点击来自仓库内/工作区 PR 列表。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + `owner/repo #N` + 分享（share）+ 更多菜单（⋯）
2. 标题区：标题（2 行省略）+ [Merged] 徽章 + 分支胶囊 + 作者行（🀫 头像 + 作者登录名 + Owner 标记 + 相对时间 + 更多菜单 ⋯）
3. Changes 卡片：📄 文件数（3 files changed）+ 增减行数（+249 −49）+ commit 数（1 commit · 20h ago）
4. Status 卡片：👁 Reviews · None requested + ✓ All checks have passed + ⇄ Branch merged（eb43eaa…）
5. Conversation 区块：正文/评论列表（codecov 等）+ [DELETE BRANCH] 按钮
6. 底部：[COMMENT] 输入 + 表情按钮（😊）

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar | ← 返回 + `owner/repo #N` | 导航 | ✅ | —（纯 UI） | — |
| 2 | 标题 | Merged/Open 徽章 + 标题 + 分支胶囊 | 展示 | ✅ | `state/merged/headRefName` | — |
| 3 | 作者行 | 头像/登录名/Owner/时间 | 展示 | ✅ | `author/createdAt` | — |
| 4 | Changes | files changed + additions/deletions | 展示 | ✅ | `files.totalCount/additions/deletions` | +绿 −红 |
| 5 | Changes | commit 数 + 相对时间 | 展示 | ✅ | `commits.totalCount/createdAt` | — |
| 6 | Status | Reviews · None requested | 展示 | ✅ | `reviews.totalCount` | — |
| 7 | Status | Checks 状态 + Branch merged 时间线 | 展示 | ✅ | `statusCheckRollup/mergeCommit/mergedAt` | — |
| 8 | Conversation | 正文 + 评论列表（含 Bot） | 展示 | ✅ | `body/comments` | 纯文本 |
| 9 | Conversation | refer/merged 事件行 + DELETE BRANCH | 展示 | ✅ | `mergedAt/mergeCommit` | 按钮提示 |
| 10 | 底部 | COMMENT + 表情 | 占位 | ✅ | —（纯 UI） | 提示后续 |

> 可行性比例声明：10/10 可行。

---

## 四、核心 GraphQL 片段

```graphql
query PullRequestDetail($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      id title state merged isDraft body createdAt mergedAt
      additions deletions
      author { login avatarUrl }
      headRefName baseRefName
      mergeCommit { abbreviatedOid oid }
      files { totalCount }
      commits { totalCount }
      reviews { totalCount }
      statusCheckRollup { state }
      comments(first: 15) { totalCount nodes { id body createdAt author { login avatarUrl } } }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| Diff 视图（Files Changed 内页） | Spec 010 独立 | 「3 files changed」点击提示后续 |
| Markdown/富文本 | 渲染器后续 | 纯文本 |
| 评论回复/表情 | 写操作 | 提示 |

---

## 六、TDD 验收标准

- [x] 测试 1：`mapPrDetail` 纯函数：Changes/Status/评论映射正确
- [x] 测试 2：构建 + 模拟器实测：深色三区块与截图对齐
- [x] 测试 3：grep 页面无中文字符串字面量；check-spec.sh 通过

---

## 七、备注

- 复用 018 的 Checks 图标/配色；merged 徽章蓝紫 `#2E5FC7`/`#8250DF` 系（官方深色截图为蓝底圆徽章 + 白字）。
- i18n 新增：`pr_files_changed`（%1$s files changed）、`pr_reviews_none`、`pr_merge_branch`、`pr_delete_branch` 等。
