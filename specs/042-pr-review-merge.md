# Spec 042: PR 代码审阅与合并（review threads + merge 选项）

> BFS Level: 3
> 关联截图: 官方 PR「Files Changed」行内评论与「Review changes」面板；Merge 下拉（squash/merge/rebase）
> 上游 Spec: 010（PR Diff，已 implemented）、031（PrDetail）、041（评论基础，复用输入面板）
> 状态: implemented（2026-09-14；模型/服务/三态审阅面板/Merge 区块/ReviewThreads 卡/行内评论落地，宿主单测覆盖映射与合并门纯函数。合并 mutation 的枚举类型为 `PullRequestMergeMethod`）

---

## 一、页面/功能概述

在 010（PR Diff / Files Changed）之上补齐**审阅与合并**两件事：① 代码行内评论（点击 diff 行 → 评论 thread）、thread 回复与解析、**提交审阅**（Approve / Request changes / Comment 汇总）；② **合并 PR**（merge 方式选择 squash/merge/rebase、mergable 冲突状态展示、合并后状态切换）。这是「读代码」到「改代码流的决策点」的关键闭环。

---

## 二、整体 UI 结构

PrDetail 页面结构：
1. Changes 卡（现有）：010 Files Changed 列表 → DiffView（行内可点）
   - 每次点击行号行尾（评论图标）弹出：评论 thread（041 输入面板），点击 Comment 即可提交 thread
2. Review 状态：Approve / Request changes / Comment 三态按钮组
   - 汇总输入框（可选 body）→ Submit
3. Status 卡：mergeable（MERGEABLE / CONFLICTING）+ Merge 分段按钮（主段 MERGE + 右段 ▾）
   - 主段 MERGE：官方确认对话框 → 按**当前方式**合并（当前方式未选过时取服务端默认，见下）
   - 右段 ▾：**Merge options 底部整页**（页内无确认钮）：`←` + 标题、Merge method（Create a merge commit / Squash and merge / Rebase and merge，各带说明与官方圆形单选）、全幅灰带分组、提交信息（`Commit message · Default|Custom` + EDIT，未编辑态显示粗体 headline + 等宽 body）
   - 默认选中与默认提交信息取自服务端：`Repository.viewerDefaultMergeMethod`、`PullRequest.viewerMergeHeadlineText/BodyText`（后者无 `mergeMethod` 参数，只按默认方式口径返回；切换方式时按官方口径本地推导：squash/rebase=PR 标题、merge=固定句式）
4. Conversation：已提交审阅卡 + ReviewThreads（Resolved 标记）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | DiffView | 行内评论入口 | 点击未变更/变更行 → 弹评论 thread（支持 010 的行定位上下文） | ✅ | `addPullRequestReviewThread` | 需 010 先给出 path+line+side |
| 2 | Thread | 提交 thread 评论 | 输入 body 创建 thread（未提交 review 时为 pending review 模式） | ✅ | 见四 | 与 041 输入面板组件复用 |
| 3 | Thread | thread 回复 | 已有 thread 内追加评论 | ✅ | `addPullRequestReviewComment`（pendingReviewId + threadId 或 inReplyTo） | —— |
| 4 | Conversation | 审阅列表 | reviews(first) 渲染（author/state/body/时间）+ reviewThreads pending/全部 | ✅ | 见四 | 现有 Reviews 计数升级为列表 |
| 5 | 汇总面板 | 提交审阅 | 三态（APPROVE / REQUEST_CHANGES / COMMENT）+ body → `submitPullRequestReview` | ✅ | 见四 | 官方「Review changes」面板样式 |
| 6 | 汇总面板 | 编辑已提交审阅 | 需修改 body 时 `updatePullRequestReview` | ✅ | 见四 | 仅本人未过期审阅 |
| 7 | Thread | 解析/未解析 | `resolveReviewThread` / `unresolveReviewThread` + 状态标签 | ✅ | 见四 | 官方标记「已解决」 |
| 8 | Status 卡 | Merge 分段按钮 | 权限门通过时启用；主段 = 官方确认对话框后按当前方式合并，右段 ▾ = 打开 Merge options 页（页内无确认钮） | ✅ | `mergePullRequest(input: { mergeMethod })` | 未选过时当前方式 = `viewerDefaultMergeMethod`（非固定 squash）；合并期间按钮禁用（页面 mergeSending） |
| 9 | Merge options | 方法单选 + 提交信息 | 三方法单选（含 commit 数说明）、`· Default/Custom` + EDIT | ✅ | `viewerDefaultMergeMethod` / `viewerMergeHeadlineText` / `viewerMergeBodyText` | 切换方式时未编辑态才重算默认信息，避免覆盖用户改动；选完回 Status 卡按主段 MERGE 执行 |
| 10 | Status 卡 | 冲突状态 | mergeable 字段：CONFLICTING → 红色提示「存在冲突，请在当地解决」 | ✅ | PR.mergeable / mergeStateStatus | 官方文案对齐；冲突时禁用合并 |
| 11 | Merge | 失败原因提示 | merge 失败（合并队列/skip CI/过时检查）显示 mergeStateStatus 具体原因并禁用 | ⚠️ | mergeStateStatus（BEHIND/DIRTY/UNKNOWN…） | 枚举本地映射；未知值降级通用文案 |
| 12 | Conversation | 已合并后状态 | merge 成功后 merged badge/时间刷新，输入区禁用 | ✅ | —— | 局部刷新即可 |
| 13 | 页面 | 合并队列/排队状态 | merge queue 条目加入排队（官方 web 支持） | ⚠️ | mergeQueue 相关字段勘探 | 移动端仅展示，不做操作 |

> 可行性: 11/13 可行（其余 2 项为 ⚠️：失败原因枚举映射、合并队列展示）

---

## 四、核心 GraphQL 片段

```graphql
# 详情查询补充
pullRequest(number: $n) {
  id number title mergeable mergeStateStatus
  viewerCanMerge
  reviews(first: 20) {
    totalCount
    nodes { id author { login } state body bodyHTML submittedAt viewerDidAuthor }
  }
  reviewThreads(first: 50) {
    nodes {
      id isResolved isOutdated
      path line
      comments(first: 30) {
        totalCount
        nodes { id author { login avatarUrl } body bodyHTML createdAt viewerDidAuthor }
      }
    }
  }
}

# 行内 thread（line 基于 diff；side: LEFT/RIGHT）
mutation NewThread($prId: ID!, $body: String!, $path: String!, $line: Int!) {
  addPullRequestReviewThread(input: {
    pullRequestId: $prId, body: $body, path: $path, line: $line
  }) { thread { id } }
}

# 审阅汇总提交
mutation SubmitReview($prId: ID!, $body: String!, $event: PullRequestReviewEvent!) {
  submitPullRequestReview(input: {
    pullRequestId: $prId, body: $body, event: $event
  }) { pullRequestReview { id state submittedAt } }
}

# thread 回复（pendingReviewId 在未提交前）
mutation ReplyThread($threadId: ID!, $body: String!) {
  addPullRequestReviewComment(input: { threadId: $threadId, body: $body }) {
    comment { id }
  }
}

# 解析 thread
mutation Resolve { resolveReviewThread(input: { threadId: $tid }) { thread { isResolved } } }
mutation Unresolve { unresolveReviewThread(input: { threadId: $tid }) { thread { isResolved } } }

# 合并
mutation Merge($prId: ID!, $method: PullRequestMergeMethod!) {
  mergePullRequest(input: { pullRequestId: $prId, mergeMethod: $method }) {
    pullRequest { merged state mergedAt }
  }
}

# Merge options 页默认值（详情查询内）
repository {
  viewerDefaultMergeMethod        # Merge/Squash/Rebase（默认选中项）
  pullRequest {
    viewerMergeHeadlineText       # 默认提交信息标题（按默认方式口径，无 mergeMethod 参数）
    viewerMergeBodyText           # 默认提交信息正文
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 他人审阅不可编辑 | API 限制 | 仅展示，编辑入口仅 `viewerDidAuthor` |
| 合并分支保护 / 检查失败阻塞 | mergeable=CONFLICTING 等 | 展示官方枚举文案并禁用按钮 |
| 正在排队（merge queue） | 移动端不做入队操作 | 仅展示状态文本（⚠️ 勘探后补字段） |
| 过时线程（isOutdated） | 代码变更后行号失效 | 显示「已过期」灰标，不可回复（与官方一致），跳转最新 diff |
| 移动端无“强制合入 admin override” | 官方仅桌面有 | 不做 |

---

## 六、TDD 验收标准

- [ ] 测试 1：010 DiffView 点击行号弹 thread 输入面板：提交后 thread 出现在 Conversation 且带 path/行号
- [ ] 测试 2：thread 回复追加成功，评论数 +1
- [ ] 测试 3：submitPullRequestReview 三态按钮组：APPROVE 提交后审阅卡显示「Approved」状态
- [ ] 测试 4：resolve/unresolve 后线程标签翻转移位（Resolved 折叠）
- [ ] 测试 5：mergeable=MERGEABLE + 仓库写权限（`viewerPermission ∈ ADMIN/MAINTAIN/WRITE`）时 Merge 可用；三种方式各触发一次 mutation（入参断言 mergeMethod）
- [ ] 测试 6：mergeable=CONFLICTING 时按钮禁用且显示冲突文案
- [ ] 测试 7：merge 成功后 merged badge 更新、输入区禁用
- [ ] 测试 8：merge 失败（BEHIND/DIRTY）显示对应原因且不崩溃（未知枚举有兜底文案）
- [ ] 测试 9：isOutdated thread 显示灰态禁回复
- [x] 测试 10：新文案 base/zh_CN 双份，check-spec 通过（35 键双语文案；check-spec 0 错；宿主单测 89/89）
- [x] 测试 11：合并方式默认值——未选过时取 `Repository.viewerDefaultMergeMethod`（`resolveMergeMethod` 宿主单测：用户已选优先 / 服务端三种默认 / 字段缺失兜底 MERGE）
- [x] 测试 12：Bot 标识口径——审阅卡与 thread 评论按 `author.__typename` 显示 `login[bot]`（宿主单测断言映射与显示）

---

## 七、备注

- 依赖链：010（Diff 视图）已于 2026-09-04 implemented，前置解除。行内评论落地时若行级 line 不可得，可将「行内评论」降为「整行文件评论」（thread.path 无 line）先行。
- 官方参照：审阅/合并是 v1.0 就有的能力（官方最低优先级）；行内评论 2026 增强为「未变更行也可评论」（1.245）；thread 解析状态在官方移动端与 web 一致。
- Review 里程碑、多用户提议的「建议修改」行级建议（suggestion/apply）不在本 Spec 范围（❌ 桌面专属，备注留档）。
- 合并权限门：`PullRequest` **没有** `viewerCanMerge` 字段，改用 `Repository.viewerPermission ∈ {ADMIN, MAINTAIN, WRITE}`（`canMergePr` 第三参即权限串）。`viewerCanUpdate` / `viewerCanClose` / `viewerCanReopen` 三个 PR 权限位有效可用。
