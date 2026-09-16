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

1. 顶部 App Bar：← 返回 + 两行（`owner/repo #N` 小字灰色 + PR 标题，超长时头省略、结尾完整）+ 分享（share）+ 更多菜单（⋯）
2. 页头卡片：仓库上下文行（owner 头像 + `owner / repo #N`）→ 标题（2 行省略）→ 状态胶囊（StateLabel 填充变体：Open/Merged/Closed/Draft）+ 分支胶囊（head → base）
3. 正文卡片：作者头（头像 40 + `author · 相对时间` + 关联角色胶囊 + ⋯ 菜单）+ 正文（MarkdownView）
4. Changes 卡片：📄 文件数（3 files changed）+ 增减行数（+249 −49）+ commit 数（1 commit · 20h ago）
5. Status 卡片：👁 Reviews · None requested（可展开 → REQUEST REVIEWS）+ ✓ All checks have passed + ⇄ Branch merged（eb43eaa…）；点击展开内联 checks 列表（statusCheckRollup.contexts 归一化 CheckRun/StatusContext；无时长/步骤/重跑）
6. Conversation 区块：评论列表（codecov 等）+ [DELETE BRANCH] 按钮
7. 底部悬浮：黑 [COMMENT] 胶囊 + 圆形 info 钮 → **元数据底部整页**（拖拽条 + 白底 + 全高）：Assignees / Labels / Milestone / Linked items / Projects 五段，段头右侧蓝色大写 EDIT，段间全幅 1px 分隔线

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar | ← 返回 + 两行标题 + 分享（share）+ ⋯ | 导航 | ✅ | —（纯 UI） | 分享拉起系统分享面板分享 `pull/{number}`（Spec 061）；标题头省略按实测宽度裁剪（`headEllipsisByWidth`），结尾不省略 |
| 2 | 页头卡 | 状态胶囊 + 标题 + 分支胶囊 | 展示 | ✅ | `state/merged/isDraft/headRefName/baseRefName` | 状态胶囊=填充变体（字形/语义色见 DESIGN.md §10.1）；分支段单独横向滚动 |
| 3 | 页头卡 | 仓库上下文行（owner 头像 + `owner / repo #N`） | 展示 | ✅ | `repository.owner.avatarUrl` | 官方页头行是仓库上下文，非 PR 作者 |
| 4 | 正文卡 | 作者头（头像/登录名/相对时间/角色胶囊/⋯ 菜单） | 展示 | ✅ | `author/createdAt/authorAssociation` | 角色胶囊=AuthorAssociation 映射；菜单 Share / Quote reply |
| 5 | Changes | files changed + additions/deletions | 展示 | ✅ | `files.totalCount/additions/deletions` | +绿 −红；点击进 PrFiles（010） |
| 6 | Changes | commit 数 + 相对时间 | 展示 | ✅ | `commits.totalCount/createdAt` | 点击进 PR commits 列表 |
| 7 | Status | Reviews · None requested + REQUEST REVIEWS | 展示 | ✅ | `reviews.totalCount` | 行尾 chevron 展开，按钮动作随 Spec 044 元数据编排接入 |
| 8 | Status | Checks 状态 + Branch merged 时间线 | 展示 | ✅ | `statusCheckRollup{state/contexts}/mergeCommit{abbreviatedOid}/mergedAt/mergedBy` | 点击展开内联 checks 列表（statusCheckRollup.contexts 归一化 CheckRun/StatusContext；无时长/步骤/重跑） |
| 9 | Conversation | 评论列表（含 Bot） | 展示 | ✅ | `body/comments` | MarkdownView 渲染官方 HTML（040） |
| 10 | Conversation | Status 卡 merged 行（mergedAt/mergeOid/mergedBy）+ refer 事件（后续时间线）+ DELETE BRANCH | 展示 | ✅ | `mergedAt/mergeCommit{abbreviatedOid}/mergedBy` | 按钮提示 |
| 11 | 底部 | 悬浮 COMMENT + info（元数据底部整页） | 占位 | ✅ | `assignees/labels/milestone` | 五段展示已接数；EDIT 编辑器随 044 接入（当前占位） |

> 可行性比例声明：11/11 可行。

---

## 四、核心 GraphQL 片段

```graphql
query PullRequestDetail($owner: String!, $name: String!, $number: Int!, $after: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      id title state merged isDraft body bodyHTML createdAt mergedAt
      additions deletions
      author { login avatarUrl }
      headRefName baseRefName
      mergedBy { login }
      mergeCommit { abbreviatedOid }
      files { totalCount }
      commits { totalCount }
      reviews { totalCount }
      statusCheckRollup {
        state
        contexts(first: 20) {
          totalCount
          nodes {
            ... on CheckRun { name status conclusion }
            ... on StatusContext { context state }
          }
        }
      }
      comments(first: 20, after: $after) {
        totalCount
        pageInfo { hasNextPage endCursor }
        nodes {
          id body bodyHTML createdAt viewerDidAuthor
          author { login avatarUrl }
          reactionGroups {
            content viewerHasReacted
            reactors(first: 8) {
              totalCount
              nodes {
                ... on User { login avatarUrl }
                ... on Bot { login avatarUrl }
                ... on Mannequin { login avatarUrl }
                ... on Organization { login avatarUrl }
              }
            }
          }
        }
      }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| Diff 视图（Files Changed 内页） | Spec 010 独立 | 点击进 PrFiles（010）；N commits 行点击进 PR commits 列表 |
| Markdown/富文本 | 渲染器后续 | MarkdownView 渲染官方 HTML（040） |
| 评论回复/表情 | 写操作 | 提示 |

---

## 六、TDD 验收标准

- [x] 测试 1：`mapPrDetail` 纯函数：Changes/Status/评论映射正确
- [x] 测试 2：构建 + 模拟器实测：深色三区块与截图对齐
- [x] 测试 3：grep 页面无中文字符串字面量；check-spec.sh 通过
- [ ] 测试 4：长标题超 2 行省略（实现完成，待模拟器走查）

---

## 七、备注

- 复用 018 的 Checks 图标/配色；merged 徽章蓝紫 `#2E5FC7`/`#8250DF` 系（官方深色截图为蓝底圆徽章 + 白字）。
- i18n 新增：`pr_files_changed`（%1$s files changed）、`pr_reviews_none`、`pr_merge_branch`、`pr_delete_branch` 等。
