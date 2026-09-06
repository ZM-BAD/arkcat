# Spec 043: Issue/PR 创建与编辑（生命周期）

> BFS Level: 3
> 关联截图: 官方「New Issue」「New Pull Request」表单；Issue/PR 标题行 pencil 编辑入口
> 上游 Spec: 030（IssueDetail）、031（PrDetail）、007（IssuesList）、027（RepoPrs）
> 状态: draft（2026-09-02 规划）

---

## 一、页面/功能概述

把 App 从「管理别人的 Issue/PR」补到「创建并维护自己的 Issue/PR」：新建 Issue（支持官方 Issue 模板导入）、新建 PR（base/head 分支选择）、编辑标题/正文、关闭/重开（含关闭原因 COMPLETED / NOT_PLANNED）、PR draft ↔ ready 切换。这是官方验证过的写路径次序「能看 → 能回 → 能建 → 能精修」中的「能建」环节。

---

## 二、整体 UI 结构

```text
入口：Home「+」· RepoDetail「+」· IssuesList/RepoPrs 顶栏「+」
┌─────────────────────────────────────┐
│ App Bar：取消 · 标题（New Issue）· 创建 │
├─────────────────────────────────────┤
│ 表单（自定义自绘，贴合官方紧凑型）       │
│  ┌─────────────────────────────┐   │
│  │ 标题（单行输入，草稿占位）      │   │
│  │ 模板选择（如有）→ 填充正文       │   │
│  │ 正文（TextArea + 041 工具栏）  │   │
│  │ [预览] [正文]      字数/校验    │   │
│  └─────────────────────────────┘   │
├─────────────────────────────────────┤
│ 底部操作：关闭/重开（详情页）          │
│ 详情页标题行 ⇄ 编辑（pencil）→ 同上表单 │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | 各列表页 | 「+」新建入口 | 替换现有 coming-soon toast；Issue 入口 on repo；PR 入口 on repo | ✅ | 无 | Home 入口按当前账号仓库列表跳转 |
| 2 | 表单 | Issue 模板 | 读取 `repository.issueTemplates`（title/body/file），模板选择器 + 预填 | ✅ | 见四 | 无模板则隐藏栏；YAML front matter 由 API 结构字段返回 |
| 3 | 表单 | 标题/正文输入 | 061 风格的 TextArea + 常用（043 里用 MarkdownView 预览按钮，正文同 041 工具栏） | ✅ | 无 | 草稿 @Local 保存 |
| 4 | 提交 | 创建 Issue | `createIssue`（repositoryId/title/body）→ 成功后进详情 | ✅ | 见四 | error 422/429 反馈不丢草稿 |
| 5 | 表单 | New PR 表单 | base 分支选择（默认 defaultBranchRef）+ 标题/正文 | ✅ | repository.defaultBranchRef 与 branches 查询 | base 默认 default |
| 6 | 表单 | head 分支选择 | 仓库现有分支列表（含 fork）；自建分支入口（REST createRef，做「创建并推送」的移动端等价——仅创建 ref 需要 content 权限，提示用户需先有该分支） | ⚠️ | 见四 | 官方 1.267「自定义分支名」：mobile 上仅在已有分支列表内选择 + 备注；新建分支需要仓库权限，给出 REST createRef 兜底（待定） |
| 7 | 提交 | 创建 PR | `createPullRequest`（baseRefName/headRefName）→ 进 PrDetail | ✅ | 见四 | head 分支不存在时表单校验提示 |
| 8 | 详情页 | 编辑标题/正文 | 标题行 pencil + 正文菜单「Edit」→ 回填表单 → `updateIssue` / `updatePullRequest` | ✅ | 见四 | 仅查看者权限具备时显示（viewerCanUpdate） |
| 9 | 详情页 | 关闭/重开 | `closeIssue(stateReason: COMPLETED/NOT_PLANNED)` / `reopenIssue`；PR 侧 `closePullRequest`/`reopenPullRequest` | ✅ | 见四 | 关闭原因选择器（官方两档） |
| 10 | 详情页 | PR draft 切换 | `convertPullRequestToDraft` / `markPullRequestReadyForReview` | ✅ | 见四 | draft 徽章展示（031 已有则补切换入口） |
| 11 | —— | 删除 Issue/PR | GraphQL 无删除 mutation；官方 App 无该入口 | ❌ | 无 | 与官方对齐：不提供删除；web 侧归档/删除走桌面端 |
| 12 | 表单 | 校验与错误 | 标题为空/超长（255）/4xx 错误 → 行内提示 | ✅ | 无 | i18n 双份 |

> 可行性: 10/12 可行（head 分支自建为 ⚠️；删除为 ❌ 与官方对齐）

---

## 四、核心 GraphQL 片段

```graphql
# 模板与分支
query RepoForm($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    id defaultBranchRef { name }
    issueTemplates { title body file }
    refs(refPrefix: "refs/heads/", first: 100) {
      nodes { name target { oid } }
    }
  }
}

# 创建
mutation NewIssue($repoId: ID!, $title: String!, $body: String!) {
  createIssue(input: { repositoryId: $repoId, title: $title, body: $body }) {
    issue { id number url title }
  }
}
mutation NewPr($repoId: ID!, $base: String!, $head: String!, $title: String!, $body: String!) {
  createPullRequest(input: {
    repositoryId: $repoId, baseRefName: $base, headRefName: $head,
    title: $title, body: $body
  }) { pullRequest { id number url } }
}

# 编辑
mutation UpdIssue($id: ID!, $title: String!, $body: String!) {
  updateIssue(input: { id: $id, title: $title, body: $body }) { issue { id } }
}
mutation UpdPr($prId: ID!, $title: String!, $body: String!) {
  updatePullRequest(input: { pullRequestId: $prId, title: $title, body: $body }) {
    pullRequest { id }
  }
}

# 关闭/重开
mutation CloseIssue($issueId: ID!, $reason: IssueStateReason!) {
  closeIssue(input: { issueId: $issueId, stateReason: $reason }) { issue { state stateReason } }
}
mutation ReopenIssue { reopenIssue(input: { issueId: $id }) { issue { state } } }
mutation ClosePr { closePullRequest(input: { pullRequestId: $prId }) { pullRequest { state } } }
mutation ReopenPr { reopenPullRequest(input: { pullRequestId: $prId }) { pullRequest { state } } }

# Draft ↔ Ready
mutation ToDraft { convertPullRequestToDraft(input: { pullRequestId: $prId }) { pullRequest { isDraft } } }
mutation ToReady { markPullRequestReadyForReview(input: { pullRequestId: $prId }) { pullRequest { isDraft } } }
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 新建分支（移动端无 commit 推送能力） | API 无“一步创建含 commit 的分支”能力 | head 分支仅在「现有分支列表」中选择；REST `POST /repos/{o}/{r}/git/refs` 建空 ref 作为 ⚠️ 待测项（需要 push 权限） |
| 无权编辑 | viewerCanUpdate=false / 403 | 隐藏编辑入口，防护后端错误提示 |
| 草稿/临时内容 | —— | @Local 草稿键 = `draft_new_issue_{repoId}` |
| 官方桌面「Assign to / Projects / Milestone」创建即选 | 官方移动端创建流程极简 | 高级项走 044 详情编辑器，创建表单保持最小 |
| issue 删除 | GitHub 平台无此操作（仅 REST hack） | 不提供 |

---

## 六、TDD 验收标准

- [ ] 测试 1：IssuesList「+」→ 表单渲染；有模板时模板选择器出现，选择后正文预填
- [ ] 测试 2：createIssue 成功入参断言（repositoryId/title/body），成功跳详情
- [ ] 测试 3：空标题/超长标题行内校验，提交阻塞
- [ ] 测试 4：New PR 表单 base 默认为 default branch；head 列表来自 refs 查询
- [ ] 测试 5：createPullRequest 提交后跳 PrDetail；head 不存在时提示
- [ ] 测试 6：详情页编辑回填、保存后标题/正文更新（updateIssue 入参断言）
- [ ] 测试 7：关闭选择 COMPLETED/NOT_PLANNED 两档，状态徽章与关闭原因展示更新
- [ ] 测试 8：draft 切换 mutation 触发且 isDraft 状态翻转
- [ ] 测试 9：所有 4xx 错误显示多语言文案，草稿保留
- [ ] 测试 10：hard-coded 颜色 0 处（Primer token），i18n 双份，check-spec 通过

---

## 七、备注

- 官方轨迹：创建 discussion（1.4.0，2021）→ 建仓（1.257，2026-05）；Issue/PR 创建则在 v1.x 早期即有。我们的顺序：有 041 评论后即可上本 Spec。
- 「创建仓库」在官方 2026-05 才上线，且需要模板选择器——本项目规模不追（❌ 规划备注：创建仓库依赖 write 能力 + 模板链，可放后续批观察）。
- 表单页复用 041 的 Markdown 工具栏组件（拆出 `MarkdownToolbar` 公共组件，041/043 共用）。
