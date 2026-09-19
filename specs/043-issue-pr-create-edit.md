# Spec 043: Issue/PR 创建与编辑（生命周期）

> BFS Level: 3
> 关联截图: 官方「New Issue」表单；官方「Compare changes / Choose Branch / Choose head ref」创建 PR 动线（2026-09-19）；Issue/PR 标题行 pencil 编辑入口
> 上游 Spec: 030（IssueDetail）、031（PrDetail）、007（IssuesList）、027（RepoPrs）
> 状态: implemented（2026-09-18 基于 develop 同名重建批；2026-09-19 PR 创建动线按官方截图推倒重做）

---

## 一、页面/功能概述

把 App 从「管理别人的 Issue/PR」补到「创建并维护自己的 Issue/PR」：新建 Issue（支持官方 Issue 模板导入）、新建 PR（base/head 分支选择）、编辑标题/正文、关闭/重开（含关闭原因 COMPLETED / NOT_PLANNED）、PR draft ↔ ready 切换。这是官方验证过的写路径次序「能看 → 能回 → 能建 → 能精修」中的「能建」环节。

---

## 二、整体 UI 结构

1. 入口：Home「+」＝顶栏弹出菜单（Create Issue / New repository〔repo octicon，端侧未接入占位，sentence case〕，无 PR 项）；RepoDetail「+」＝顶栏弹出菜单（Create Issue / New Pull Request）；IssuesList / RepoPrs 顶栏「+」→ Issue/PR 表单。**Create Issue 全部入口统一先过模板判定（hasTemplateChooser）**：经典模板/issue forms/联系链接任一存在 → Choose Template 页；无 → 直达表单（2026-09-19 仓库内 Issues 列表 hypit 实测定案）
2. Home → Create Issue 第一跳：**Choose a repository 整页选仓库**（两行头部：灰小字 Create Issue + 粗体 Choose a repository + 右上 🔍 内联搜索〔就地变搜索框：placeholder=Search；✕ 有输入才出现，点击=清空〕；行 = owner 头像 + login 灰字 + 仓库名两行行）
3. 选中仓库有官方模板 → **Choose Template 选模板页**（两行头部：owner/name + 粗体 Choose Template；行 = 模板 name（黑）+ about（灰），行数随 issueTemplates 自适应；固定尾行 No template/Create a blank issue；仓库有安全政策时追加独立分组 Security 行〔外链图标 → securityPolicyUrl 应用内浏览器〕）；无模板直达表单。**模板校验覆盖三类机制（2026-09-19 hypit 实测定案）**：①经典模板（.md，GraphQL issueTemplates，原生预填）②issue forms（.yml，GraphQL 不返回——REST contents 读 .github/ISSUE_TEMPLATE 目录，移动端外链跳 issues/new?template=文件名）③config.yml 联系链接（外链）；任一存在即入选模板页，页序 = 模板+No template → 联系链接 → 表单 → Security
4. Create Issue 表单（官方截图形态）：两行头部（`owner/name` 灰字 + 粗体标题 + 右上纸飞机发送）→ Title/Body 原生占位（Insert title / Insert optional description）→ 底部属性芯片行 Assignee/Label/Milestone/Project（灰底描边阴影小胶囊；键盘弹起随底部栈贴键盘上端；正文聚焦时键盘上方灰底 Markdown 工具条；官方无 Write/Preview 页签）；带模板进入自动回填标题/正文并按模板 YAML 自动带 Assignee/Label（多选芯片；GitHub 模板无 milestone/project，保持未选）
5. New PR 动线（官方截图驱动 2026-09-19 推倒重做）：RepoDetail「+」/ RepoPrs「+」→ **Compare changes 整页**：✕ 关闭 + `owner/name` 灰字 + 粗体 Compare changes 两行头部；Choose branches 区块 = base:（默认落 defaultBranchRef，浅蓝 mono 分支芯片 + chevron-down）+ compare:（未选时 SELECT BRANCH 蓝字入口，选中后同款芯片）；未选 compare 时区块下方展示空态卡（绿圈 git-pull-request 图标 + 「Choose a branch to compare changes」）；选定后 Changes 区块 = file-diff 行「N files changed +A -D」+ git-commit 行「N commits + 相对时间」，页底绿色 CREATE PULL REQUEST 主按钮 + 灰字说明行。分支选择走 **Choose Branch（base）/ Choose head ref（compare）整页选择器**（🔍 内联搜索 + 分支浅蓝 mono 芯片行 + 默认分支 Default 描边徽标 + 选中蓝底白勾；页面标题字面复刻官方大小写差异）。CREATE PULL REQUEST → **Start pull request 表单**（Title/Description + 绿色创建主按钮），创建成功详情压栈并自移除表单与 Compare 页
6. 详情页关闭/重开（见元素 9）；详情页标题行 ⇄ 编辑（pencil）→ 同表单头部（Edit Issue）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | 各列表页 | 「+」新建入口 | 替换现有 coming-soon toast；Issue 入口 on repo；PR 入口 on repo | ✅ | 无 | Home 入口按当前账号仓库列表跳转 |
| 2 | 表单 | Issue 模板 | 读取 `repository.issueTemplates`（title/body/file），模板选择器 + 预填 | ✅ | 见四 | 无模板则隐藏栏；YAML front matter 由 API 结构字段返回 |
| 3 | 表单 | 标题/正文输入 | 061 风格的 TextArea + 常用（043 里用 MarkdownView 预览按钮，正文同 041 工具栏） | ✅ | 无 | 草稿 @Local 保存 |
| 4 | 提交 | 创建 Issue | `createIssue`（repositoryId/title/body）→ 成功后进详情 | ✅ | 见四 | error 422/429 反馈不丢草稿 |
| 5 | Compare changes 页 | base/compare 分支选择 + Changes 汇总 | base 默认 defaultBranchRef；compare 未选显示 SELECT BRANCH；选定后展示 files changed/+additions/-deletions/commits 与 tip 相对时间 | ✅ | 见四 | 汇总走 REST compare 单请求（GraphQL 无文件级 compare，平台上限见五）；未选 compare 展示空态卡 |
| 6 | 分支选择器 | Choose Branch / Choose head ref 整页 | 🔍 内联搜索 + Default 徽标（默认分支）+ 选中蓝底白勾；head 仅限现有分支列表 | ✅ | 见四 | 页面标题字面复刻官方大小写差异（Choose head ref / Choose Branch）；自建分支不在移动端提供（⚠️ 见五） |
| 7 | 提交 | 创建 PR | Start pull request 表单 → `createPullRequest`（baseRefName/headRefName）→ 进 PrDetail | ✅ | 见四 | head=base/空标题提交前校验；无差异 422 反馈保留表单 |
| 8 | 详情页 | 编辑标题/正文 | 标题行 pencil + 正文菜单「Edit」→ 回填表单 → `updateIssue` / `updatePullRequest` | ✅ | 见四 | 仅查看者权限具备时显示（viewerCanUpdate） |
| 9 | 详情页 | 关闭/重开 | `closeIssue(stateReason: COMPLETED/NOT_PLANNED)` / `reopenIssue`；PR 侧 `closePullRequest`/`reopenPullRequest` | ✅ | 见四 | 关闭原因选择器（官方两档） |
| 10 | 详情页 | PR draft 切换 | `convertPullRequestToDraft` / `markPullRequestReadyForReview` | ✅ | 见四 | draft 徽章展示（031 已有则补切换入口） |
| 11 | —— | 删除 Issue/PR | GraphQL 无删除 mutation；官方 App 无该入口 | ❌ | 无 | 与官方对齐：不提供删除；web 侧归档/删除走桌面端 |
| 12 | 表单 | 校验与错误 | 标题为空/超长（255）/4xx 错误 → 行内提示 | ✅ | 无 | i18n 双份 |

> 可行性: 11/12 可行（自建分支不在移动端提供，见五；删除为 ❌ 与官方对齐）

---

## 四、核心 GraphQL 片段

```graphql
# 模板与分支（实测字段：模板文件名是 filename 非 file；2026-09-18 gh 探针证实）
query RepoForm($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    id defaultBranchRef { name }
    issueTemplates { name title body filename }
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

# 分支选择器候选（fetchAllPages 翻全，客户端排序 = 默认分支优先 + 字母序）
query BranchRefs($owner: String!, $name: String!, $after: String) {
  repository(owner: $owner, name: $name) {
    defaultBranchRef { name }
    refs(refPrefix: "refs/heads/", first: 100, after: $after) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes { name }
    }
  }
}

# head 分支 tip 提交时间（Changes 行右侧相对时间）
query RefTip($owner: String!, $name: String!, $qualified: String!) {
  repository(owner: $owner, name: $name) {
    ref(qualifiedName: $qualified) { target { ... on Commit { committedDate } } }
  }
}
```

```typescript
// Changes 汇总数据源：GraphQL 无文件级 compare，走 REST（graphql-usage：REST 为 GraphQL 缺口兜底）。
// GET /repos/{owner}/{repo}/compare/{base}...{head}（单请求）
// files[] 累加 files/additions/deletions；commits 用 total_commits 精确值。
// ⚠️ 平台上限（2026-09-19 gh 实测）：files 硬上限 300 条且不可翻页——per_page 只作用于
// commits 数组，page≥2 返回 files=null（Link 头为误导性通用分页）。
```

```graphql
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

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 新建分支（移动端无 commit 推送能力） | API 无“一步创建含 commit 的分支”能力 | head 分支仅在「现有分支列表」中选择（官方移动端同口径）；REST createRef 建空 ref 的兜底不做——空分支无法发起有效比较 |
| Changes 汇总（files/additions/deletions） | GraphQL 无文件级 compare | REST `GET /repos/{o}/{r}/compare/{base}...{head}` 单请求汇总（commits 用 total_commits 精确值，tip 时间另走 GraphQL ref 查询）；**files 硬上限 300 条且不可翻页（2026-09-19 gh 实测）**，>300 文件的 files/+/- 为截断下限——与官方 App（内部接口全量）的平台能力差，见 §七 |
| 无权编辑 | viewerCanUpdate=false / 403 | 隐藏编辑入口，防护后端错误提示 |
| 草稿/临时内容 | —— | @Local 草稿键 = `draft_new_issue_{repoId}` |
| 官方桌面「Assign to / Projects / Milestone」创建即选 | 官方移动端创建流程极简 | 高级项走 044 详情编辑器，创建表单保持最小 |
| issue 删除 | GitHub 平台无此操作（仅 REST hack） | 不提供 |

---

## 六、TDD 验收标准

- [ ] 测试 1：IssuesList「+」→ 表单渲染；有模板时模板选择器出现，选择后正文预填
- [ ] 测试 2：createIssue 成功入参断言（repositoryId/title/body），成功跳详情
- [ ] 测试 3：空标题/超长标题行内校验，提交阻塞
- [ ] 测试 4：Compare 页 base 默认为 default branch；compare 未选显示 SELECT BRANCH 与空态卡；选定后 Changes 汇总（files/+additions/-deletions/commits/相对时间）正确
- [ ] 测试 5：分支选择器搜索过滤、Default 徽标与选中勾正确；createPullRequest 提交后跳 PrDetail；head=base 与无差异 422 均提示且表单保留
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
- 实现口径（2026-09-18）：REPO_FORM 单查询聚合仓库 id/默认分支/模板/分支；模板只填充正文（标题不动）；Home「+」无仓库上下文 → 表单内先选仓库（viewer.repositories，affiliations=[OWNER, COLLABORATOR, ORGANIZATION_MEMBER]，first 100 按最近推送序，客户端搜索）。编辑入口统一 viewerCanUpdate 门控：Issue=标题行 pencil + 顶栏 ⋯ 菜单 + 正文卡菜单；PR=顶栏 ⋯ 菜单 + 正文卡菜单。关闭原因面板两档 COMPLETED/NOT_PLANNED（圆形单选 + 红色关闭钮）；PR 关闭/重开/draft 切换挂顶栏 ⋯ 菜单（draft 项按 isDraft 换文案：Convert to draft ↔ Mark ready for review）。Issue/PR 详情查询补 viewerCanUpdate；GraphQL 契约同步至 scripts/graphql-contract.mjs（9 条 gh 实测）。
- 走查修正（2026-09-19）：Home/RepoDetail「+」由底部弹层改为**顶栏弹出菜单**（官方口径，AppBar 自绘 menuItems）——Home=Create Issue / New repository（repo octicon、sentence case；建仓端侧未接入走占位 toast，无 PR 项），RepoDetail=Create Issue / New Pull Request（Title Case）。仓库内 Issues 列表卡复用工作区公共 `IssueCard`（与 Home Issues 列表同卡同形态；仓库卡原有 linkedPrCount 芯片随同卡停显，数据链保留）。
- 走查重写（2026-09-19，官方截图驱动，Create Issue 动线整体重做）：①Home「+」Create Issue 先进 **Choose a repository 整页选仓库页**（新路由 `repoPicker`，viewer.repositories 100 条按最近推送序 + 🔍 客户端搜索，行 = owner 头像 40 + login 灰字 + 仓库名，选中压栈表单）；②表单页 = 两行头部（`owner/name` 灰字 + 粗体 Create Issue + 右上纸飞机发送，替代 Cancel/Create 文字头）+ Title/Body 原生占位（Insert title / Insert optional description）+ **底部属性芯片行**（Assignee/Label/Milestone/Project = octicon person-add/tag/milestone/table；灰底阴影胶囊；选择面板复用 044 Triage 候选与 FilterOptionSheet；createIssue 直收 assigneeIds/labelIds/milestoneId，Project 创建后走 addProjectV2ItemById 挂载；**单选简化**：芯片选中后显示所选项名，再点同项清除）+ 正文聚焦时键盘上方 Markdown 工具条（灰底阴影条，与 041 COMMENT 面板同一组件同一形态）；③**官方创建表单无 Write/Preview 页签 → 预览移除**（§二 旧稿的预览/字数行内校验口径作废，校验改 toast 静默拦截）；创建成功后详情压栈并移除表单与选仓库页。编辑表单同头部（Edit Issue），无芯片行；PrForm 头部同语言对齐、无 PR 属性芯片。
- 走查增量（2026-09-19 模板动线）：REPO_FORM_QUERY 扩 issueTemplates 的 about/labels/assignees 连接字段与 securityPolicyUrl（headroom 实测：三模板与官方截图逐行对应，模板 YAML 无 milestone/project）；Choose Template 页行数自适应 = templates.length + 固定 No template 行 + 可选 Security 行；表单内模板栏移除（选择上移到选模板页）；属性芯片 Assignee/Label 升级**多选**（FilterOptionSheet 加 multi/selectedKeys，勾选不关面板），芯片文案「首名 +N」；带模板进入自动回填标题/正文 + 按模板 YAML 匹配预置 Assignee/Label（login/name 大小写不敏感）。⚠️ 坑：@Builder 按值参数不刷新——芯片选中文案必须在 Builder 内直读状态（chipSelectedText），不能作参数传入。
- 走查重写（2026-09-19 官方截图驱动，New PR 动线整体重做）：①RepoDetail「+」/ RepoPrs「+」New Pull Request 改入 **prCompare 整页**（✕ + `owner/name` + Compare changes 两行头部）；base 默认 defaultBranchRef 芯片、compare 未选 = SELECT BRANCH 蓝字；未选 compare 时展示绿圈 git-pull-request 空态卡；选定后 Changes 区块 = 「N files changed +A -D」+「N commits + 相对时间」，页底绿色 CREATE PULL REQUEST 主按钮 + 灰字说明行（Discuss and review the changes in this comparison with others.）。②分支选择走 **branchPicker 整页**（页面标题字面复刻官方：base→Choose Branch、compare→Choose head ref；🔍 常驻内联搜索客户端过滤；分支行 = 浅蓝 mono 芯片，默认分支带 Default 描边徽标，当前选中带蓝底白勾；排序 = 默认分支优先 + 字母序，fetchBranches 翻全）。③数据：分支列表 GraphQL refs 翻页（BranchRefs）；tip 相对时间走 GraphQL ref→Commit.committedDate；Changes 汇总走 REST compare 单请求（GraphQL 无文件级 compare）。**平台能力差（偏离记录）**：REST compare files 硬上限 300 条且不可翻页（实测 page≥2 files=null、per_page 只作用于 commits），官方 App 走内部接口显示全量（如 arkcat main...develop = 1,171 files）——公开 API 无全量口，>300 文件时本页 files/+/- 为截断下限；不引入 Git Trees 客户端 diff 混搭（files 精确但 +/- 仍截断，混合口径更差且拉取重）。④CREATE PULL REQUEST → **Start pull request 表单**（prForm mode=new 改形态：✕ 两行头部 + Title/Description 原生占位 + 页底绿色创建主按钮，base/head 由路由带入不再显示分支行；该页官方截图未覆盖，按 Create Issue 表单骨架 + Compare 页按钮形态实现，⚠️ 待走查校形），创建成功 prDetail 压栈并自移除 prForm + prCompare；编辑模式（Edit Pull Request）形态不变。⑤head=base 与空标题提交前 toast 拦截；无差异 422（No commits between…）经 friendlyError 反馈且表单保留。
