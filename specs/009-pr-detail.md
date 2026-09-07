# Spec 009: PR Detail（PR 详情页）

> BFS Level: 3
> 关联截图: PR List → 点击 PR
> 上游 Spec: 008
> 状态: deprecated（2026-09-01 由 Spec 031 实现：PR 详情，见 PrDetail.ets）

---

## 一、页面/功能概述

PR 详情页，展示 PR 标题/分支信息/操作按钮（Merge/Review/Update branch 等）/时间线（Comment/Commit/Merge 事件）/Review 区块/评论输入框。包含 Conversation / Commits / Checks / Files changed 四个子 Tab。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + Pull request #1 标题 + ⋯ 更多菜单
2. 标题区：📝 标题（Update UI design）+ 元信息行（#1 · 3af9c11 → main）+ 状态/时间行（· requested review · 1d ago）
3. 内容子 Tab：[ Conversation ] / [ Commits ] / [ Checks ] / [ Files changed ]
4. 操作按钮：🔀 Merge pull request / ✖️ Remove request review / ⚠️ Show checks failure / 🔄 Update branch / 📝 Add your review / 🔁 Re-request
5. 时间线/活动记录：📅 时间线 + 💬 评论/Review/Commit/Merge 事件
6. Review 区块：👤 started a review 1d ago + [Review 内容]
7. 评论输入：💬 Add a comment... + 📎 附件 + 📤 发布

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ 纯 UI | — | — |
| 2 | App Bar 中 | 标题「Pull request #N」 | 展示 | ✅ 纯 UI | — | — |
| 3 | App Bar 右 | ··· 更多菜单 | Edit/Close/Reopen | ⚠️ | 部分 mutation | — |
| 4 | 标题区 | PR 标题 | 展示 | ✅ | `pullRequest.title` | — |
| 5 | 标题区 | 分支信息 `hash → main` | 展示 | ✅ | `baseRefName` / `headRefName` | — |
| 6 | 标题区 | 作者 + 时间 | 展示 | ✅ | `pullRequest.author` / `createdAt` | — |
| 7 | 内容 Tab | Conversation/Commits/Checks/Files | 切换 | ⚠️ | 见下 | — |
| 8 | 操作按钮 | Merge pull request | 合并 | ✅ | `mergePullRequest` | — |
| 9 | 操作按钮 | Remove request review | 取消 review | ✅ | `deleteReviewRequest` | — |
| 10 | 操作按钮 | Show checks failure | 查看 CI | ⚠️ | `commits.last.status` | — |
| 11 | 操作按钮 | Update branch | 更新分支 | ✅ | `updatePullRequestBranch` | — |
| 12 | 操作按钮 | Add your review | 提交 Review | ✅ | `addPullRequestReview` | — |
| 13 | 操作按钮 | Re-request | 重新请求 review | ✅ | `requestReviews` | — |
| 14 | 时间线 | 评论/Review/Commit/Merge 事件 | 展示 | ✅ | `pullRequest.timelineItems(...)` | — |
| 15 | Review 区块 | Review 内容 + 状态 | 展示 | ✅ | `pullRequest.reviews { body state }` | — |
| 16 | 评论输入 | Add a comment | 提交评论 | ✅ | `addComment` | — |
| 17 | 评论输入 | 附件按钮 📎 | 上传图片 | ⚠️ | REST Asset Upload | — |
| 18 | 时间线 | 关联事件 | 展示 | ✅ | `pullRequest.timelineItems` | — |

---

## 四、核心 GraphQL 片段

```graphql
query PullRequestDetail($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      id number title body state isDraft merged mergeable
      mergedAt closedAt createdAt updatedAt
      author { login avatarUrl }
      baseRefName headRefName baseRefOid headRefOid
      baseRepository { nameWithOwner }
      headRepository { nameWithOwner }
      comments { totalCount }
      reviews { totalCount }
      reviewDecision
      labels(first: 10) { nodes { name color } }
      assignees(first: 5) { nodes { login avatarUrl } }
      milestone { title }
      closingIssuesReferences(first: 5) { nodes { number title } }

      timelineItems(first: 50, itemTypes: [
        CLOSED_EVENT MERGED_EVENT PULL_REQUEST_COMMIT
        PULL_REQUEST_REVIEW ISSUE_COMMENT REOPENED_EVENT
        READY_FOR_REVIEW_EVENT HEAD_REF_FORCE_PUSHED_EVENT
      ]) {
        nodes {
          ... on MergedEvent { createdAt actor { login } commit { oid } }
          ... on PullRequestCommit { commit { oid messageHeadline committedDate author { name } } }
          ... on PullRequestReview { id state body author { login avatarUrl } createdAt comments { totalCount } }
          ... on IssueComment { id body author { login avatarUrl } createdAt reactionGroups { content users { totalCount } } }
        }
      }

      commits(last: 1) {
        totalCount
        nodes { commit { oid messageHeadline committedDate author { name email } } }
      }

      commits(last: 1) {
        nodes { commit {
          status { state contexts { state description } }
          checkSuites { nodes { status conclusion workflowRun { workflow { name } } } }
        } }
      }

      files(first: 100) {
        totalCount
        nodes { path additions deletions changeType viewerViewedState }
      }
    }
  }
}

mutation MergePullRequest($pullRequestId: ID!) {
  mergePullRequest(input: { pullRequestId: $pullRequestId }) { pullRequest { merged mergedAt } }
}

mutation AddReview($pullRequestId: ID!, $event: PullRequestReviewEvent!, $body: String) {
  addPullRequestReview(input: { pullRequestId: $pullRequestId, event: $event, body: $body }) {
    pullRequestReview { id state }
  }
}

mutation AddComment($subjectId: ID!, $body: String!) {
  addComment(input: { subjectId: $subjectId, body: $body }) { commentEdge { node { id body } } }
}

mutation UpdateBranch($pullRequestId: ID!, $expectedHeadOid: GitObjectID!) {
  updatePullRequestBranch(input: { pullRequestId: $pullRequestId, expectedHeadOid: $expectedHeadOid }) {
    pullRequest { headRefOid }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| Checks Tab | API 复杂 | MVP 只展示状态摘要 |
| 附件上传 | 需 REST Asset Upload | 暂不实现 |
| ··· 更多菜单 | 部分操作需特殊权限 | Merge/Close/Reopen 支持 |

---

## 六、TDD 验收标准

- [ ] PR 详情能展示（标题/分支/作者/时间）
- [ ] 时间线能展示（Comment/Commit/Merge 事件）
- [ ] Merge 操作正常
- [ ] Review 提交正常
- [ ] 评论提交正常

---

## 七、备注

- 14/18 可行
- Diff 内容需 REST 兜底（见 Spec 010）
