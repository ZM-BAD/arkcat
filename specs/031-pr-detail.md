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
3. 正文卡片：作者头（头像 40 + `author · 相对时间` + 关联角色胶囊 + ⋯ 菜单）+ 正文（MarkdownView）+ **正文反应行**（圆轮廓笑脸钮弹 8 种反应选择面板 + 已反应的芯片）
4. Changes 卡片：📄 文件数（3 files changed）+ 增减行数（+249 −49）+ commit 数（1 commit · 20h ago）
5. Status 卡片：👁 Reviews · None requested（可展开 → REQUEST REVIEWS）+ ✓ All checks have passed + ⇄ Branch merged（eb43eaa…）；点击展开内联 checks 列表（statusCheckRollup.contexts 归一化 CheckRun/StatusContext；无时长/步骤/重跑）
6. Conversation 区块 = **时间轴**（官方形态）：左侧一条竖直连线，节点按时间序排列——事件行（提交/标签/指派/审阅请求/合并/关闭/重开/草稿/可审阅：行首 16vp 图标压在线上，文案为「人物/对象主色加粗 + 其余灰」）+ 评论/审阅整卡（白卡不透明，自然把连线遮断）；轴尾留一小段线头；>30 条 Load more，末尾 [DELETE BRANCH] 按钮
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
| 9 | Conversation | **会话时间轴**：事件行（commit/label/assign 等 14 类）+ 评论卡 + 审阅卡，左侧竖直连线 | 展示 | ✅ | `timelineItems(first:30, after:, itemTypes:[…])` → `{__typename}` + 各事件字段 | 一次请求拿全时间轴（单一游标分页）；连线贯穿「事件行」、被不透明白卡遮断（同官方）；Bot 操作者显示 `login[bot]`（`actorDisplayLogin`） |
| 10 | Conversation | Status 卡 merged 行（mergedAt/mergeOid/mergedBy）+ refer 事件（后续时间线）+ DELETE BRANCH | 展示 | ✅ | `mergedAt/mergeCommit{abbreviatedOid}/mergedBy` | 按钮提示 |
| 11 | 底部 | 悬浮 COMMENT + info（元数据底部整页） | 占位 | ✅ | `assignees/labels/milestone` | 五段展示已接数；EDIT 编辑器随 044 接入（当前占位） |
| 12 | 正文卡 | 正文反应行（圆轮廓笑脸钮 + 反应芯片） | 交互 | ✅ | `reactionGroups{content/viewerHasReacted/reactors}` + `addReaction/removeReaction`（subjectId = PR 节点 id） | 笑脸钮弹 8 种官方反应 2×4 全集（ReactionBar `pickerFull`，与 release 变体的 6 种正向子集区分）；芯片整颗可点翻转（已反应 -1）、长按进 Reactees 整页；无反应时只留笑脸钮 |

> 可行性比例声明：12/12 可行。

---

## 四、核心 GraphQL 片段

```graphql
query PullRequestDetail($owner: String!, $name: String!, $number: Int!, $after: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      id title state merged isDraft body bodyHTML createdAt mergedAt
      additions deletions
      authorAssociation
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
      # 会话时间轴（官方 Conversation）：事件 + 评论 + 审阅按时间序，单一游标分页。
      # itemTypes 限定为客户端已渲染的 14 类（GH 共 78 种 PullRequestTimelineItems，未列入的暂不取）。
      timelineItems(first: 30, after: $after, itemTypes: [
        PULL_REQUEST_COMMIT, ISSUE_COMMENT, PULL_REQUEST_REVIEW,
        LABELED_EVENT, UNLABELED_EVENT, ASSIGNED_EVENT, UNASSIGNED_EVENT,
        REVIEW_REQUESTED_EVENT, REVIEW_REQUEST_REMOVED_EVENT,
        MERGED_EVENT, CLOSED_EVENT, REOPENED_EVENT, CONVERT_TO_DRAFT_EVENT, READY_FOR_REVIEW_EVENT
      ]) {
        totalCount
        pageInfo { hasNextPage endCursor }
        nodes {
          __typename
          ... on PullRequestCommit { id commit { oid abbreviatedOid messageHeadline author { name avatarUrl } } }
          ... on IssueComment { id body bodyHTML createdAt viewerDidAuthor
            author { __typename login avatarUrl } reactionGroups { … } }
          ... on PullRequestReview { id state body bodyHTML submittedAt viewerDidAuthor
            author { __typename login avatarUrl } }
          ... on LabeledEvent { id createdAt actor { __typename login avatarUrl } label { name color } }
          ... on AssignedEvent { id createdAt actor { … } assignee { __typename … on User { login } … on Organization { name } } }
          ... on MergedEvent { id createdAt actor { … } commit { abbreviatedOid } mergeRefName }
          # 其余事件同构：Unlabeled/Unassigned/ReviewRequested/ReviewRequestRemoved/Closed/Reopened/
          # ConvertToDraft/ReadyForReview —— 均取 id createdAt actor{__typename login avatarUrl}(+目标对象)
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
| 评论回复/表情 | 写操作 | 已接：评论回复走 Quote reply + 输入面板（041），表情走 `reactionGroups` + add/removeReaction（041；正文反应行=元素 12） |

---

## 六、TDD 验收标准

- [x] 测试 1：`mapPrDetail` 纯函数：Changes/Status/评论映射正确
- [x] 测试 2：构建 + 模拟器实测：深色三区块与截图对齐
- [x] 测试 3：grep 页面无中文字符串字面量；check-spec.sh 通过
- [ ] 测试 4：长标题超 2 行省略（实现完成，待模拟器走查）
- [x] 测试 5：正文反应行——笑脸钮弹 8 种反应 2×4 面板；选一种 → 芯片出现且计数 1；再点芯片 → 移除（模拟器实测 + GitHub 侧 reactions total_count 归零核对）
- [x] 测试 6：会话时间轴——PR #83 实机实测 4 个节点（提交行/标签行/指派行/评论卡）+ 左侧连线贯穿事件行、被白卡遮断；`mapTimeline` 纯函数断言（含未识别类型丢弃、Bot 显示口径、文案拆段）
- [x] 测试 7：评论卡反应行——笑脸钮弹 8 种面板（原「+」chip 在镜像含全 8 组时被条件隐藏，故与官方对齐改为笑脸钮）
- [x] 测试 8：时间轴分页信息取自 `pageInfo`（宿主单测断言 hasNextPage/endCursor）；Checks 行 key 唯一（同名 check 不重键）
- [ ] 测试 9：会话超 30 条时滚到底续拉下一段（实现完成，待模拟器走查）

---

## 七、备注

- 复用 018 的 Checks 图标/配色；merged 徽章蓝紫 `#2E5FC7`/`#8250DF` 系（官方深色截图为蓝底圆徽章 + 白字）。
- i18n 新增：`pr_files_changed`（%1$s files changed）、`pr_reviews_none`、`pr_merge_branch`、`pr_delete_branch` 等。
- **时间轴事件覆盖度（2026-09-17 gh api 实测）**：GH 侧 `PullRequestTimelineItems` 共 **78 种**，本条只接入 14 类（会话高频）；未接入的（head ref 变动、改名、里程碑、项目/看板、交叉引用、锁定、置顶、重复标记、审阅撤销、base 改动、merge queue、自动合并、部署等）**不入查询**——将来扩表只需在 `itemTypes` 与 `mapTimeline` 各加一支，UI 侧 `TimelineRow` 按 kind 出兵（竖线/分段/文案模板均为通用机制）。
- 时间轴文案走 `tl_*` i18n 模板 + `phraseSegments` 拆段（`%1$s` 段主色加粗）——模板即整句，避免为加粗拆碎字符串；纯函数有宿主单测。
