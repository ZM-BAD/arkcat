# Spec 044: Issue/PR 元数据编排（Labels / Assignees / Milestone / Projects）

> BFS Level: 3
> 关联截图: 官方 Issue 右侧边栏「Labels/Assignees/Milestones/Projects」展开面板；Issue timeline 变更事件
> 上游 Spec: 030（IssueDetail）、031（PrDetail）、020（Projects）
> 状态: ✅ implemented（2026-09-16，PrDetail info 页五段 EDIT 全部落地：Assignees/Labels/Milestone/Projects 走真实 GraphQL 读写，Linked items 因站内能力无公开 API 只做选人 UI + 「仅网页端」提示；Issue 侧入口沿用同一组件待接）

---

## 一、页面/功能概述

详情页的「元数据编排」：Labels（加/删/新建留桌面）、Assignees（多选/移除）、Milestone（单选）、Projects（项目添加/字段更新，v2 项）、以及 Issue「关闭为重复」（duplicate）。入口在详情页标题行下方/More 菜单（与 043 的生命周期操作分开，互不影响）。目标：让移动端成为「轻度 Triager」而不是只读观察者——官方 v1.0 的核心卖点之一（“Organize Issues with labels, assignees, projects”）。

---

## 二、整体 UI 结构

IssueDetail / PrDetail 页面结构：
1. 标题行 · 状态徽章 · 动作区（关闭/编辑/更多）
2. 元数据区（现有“无渲染”）→ 增强为卡片：
   - Labels: `bug`/`enhancement` 标签（点击 → 编辑器）
   - Assignees: 头像组（点击 → 编辑器）
   - Milestone: 当前/未设置
   - Projects: 命中项目列表（→ 020 项目页）
3. 编辑器（半屏 Sheet/全屏）：
   - Labels: 仓库 labels 全部（分色 chip，多选）
   - Assignees: assignableUsers 搜索列表（多选）
   - Milestone: 开/关里程碑列表（单选）
   - Projects: 项目项添加/状态（简化：项目下拉 + 状态子菜单）
4. 保存即 mutation，底部 toast 反馈 + timeline 事件刷新

**落地形态（2026-09-16，官方编辑器截图对齐）**：编辑器是 info 底部整页里的第二层（点 EDIT 进入、`←` 返回列表；Assignees 用 `✕` 直接关整页），
统一骨架 = 白色头块（`✕/←` + 标题 + 右侧 SAVE）→ 搜索行（Milestone 无）→ 白段「Selected」→ 8vp 灰带 → 白段候选区 → 余下露灰底；
行形态统一（`EditorRow`）：头像 / 彩色标签胶囊 / issue 状态字形 三选一做行首，候选行尾蓝色 ⊕，已选行尾灰底白 ✕。
搜索为**客户端过滤**（`filterTriageByKeyword`，候选一次取 50 条）；SAVE 置灰判据 = 选择集与打开时不一致（`diffSelection` 做标签差异推送、`singlePickId` 做里程碑单选/清除）。
候选源：`assignableUsers(first:50)` / `labels(first:50, NAME ASC)` / `milestones(first:30, states:OPEN)` / `issues(最近更新 20，排除 PR 自身)` / `repository|viewer.projectsV2(first:20)`（RECENT/USER 双页签）。

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | 详情页 | Labels 展示 | 详情查询补 labels 节点，自动换行 chip（官方色 w/ 白字），点击进入编辑器 | ✅ | 见四 | 030 查询已有 labels 但未渲染，本 Spec 补 UI |
| 2 | 编辑器 | Labels 编辑 | 仓库 labels（前 50）多选 chip；`addLabelsToLabelable` / `removeLabelsFromLabelable` | ✅ | 见四 | 差异推送一次一 mutation |
| 3 | 编辑器 | 新建 Label | 移动端无官方入口；GraphQL `createLabel` 需要 admin 且桌面专属 | ❌ | createLabel | 不提供；提示「请在 web 端创建」 |
| 4 | 详情页 | Assignees 展示 | assignees 头像行（+进编辑器） | ✅ | assignees(first:10) | —— |
| 5 | 编辑器 | Assignees 编辑 | `assignableUsers(first:100)` 查询 + 搜索过滤（与 041 mention 复用服务） | ✅ | assignableUsers（depth 2） | 多选增删 |
| 6 | 编辑器 | Milestone 选择 | repository.milestones(open/closed 分档) 单选；`updateIssue.milestoneId` / `updatePullRequest.milestoneId`（若有） | ✅ | 见四 | 未设置显示「No milestone」 |
| 7 | 编辑器 | Projects 拉入 | projectsV2 项添加（addProjectV2ItemById）；当前项显示在详情元数据区 | ⚠️ | 见四 | 项目项需要 organization/account 上下文循环；状态字段更新（updateProjectV2ItemFieldValue）复杂度高，先做「添加到项目」，状态子菜单 P1 |
| 8 | 详情页 | 关闭为重复 | 关闭流程带「重复」标记（关联原 issue 链接） | ⚠️ | closeIssue + 边界 | GraphQL stateReason 无 DUPLICATE；用 closeIssue(stateReason: NOT_PLANNED) + 备注链接正文说明；若 API（IssueStateReason.DUPLICATE 出现）则原生支持（探测点） |
| 9 | 详情页 | 变更反馈 | 保存后 timeline/元数据局部刷新 + toast | ✅ | 无 | —— |
| 10 | 详情页 | 子 Issue（Sub-issues） | 官方 2025-2026 力推（1.264 sub-issues）；GraphQL 字段（Issue.subIssues / parentIssue）勘探 | ⚠️ | 勘探后补 | 探测结论归档后可拆独立小任务 |
| 11 | 编辑器 | 权限/错误 | 无权限 403 / 限流 429 错误文案 | ✅ | 无 | 双层 i18n |

> 可行性: 7/11 可行（Projects 拉入、duplicate、子 Issue 为 ⚠️；新建 Label 为 ❌ 桌面专属）

---

## 四、核心 GraphQL 片段

```graphql
# 详情补充
issue(number: $n) {
  labels(first: 20) { nodes { id name color description } }
  assignees(first: 10) { nodes { id login avatarUrl } }
  milestone { id title state url }
}

# 仓库元数据源
query TriageMeta($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    id
    labels(first: 50, orderBy: { field: NAME, direction: ASC }) {
      nodes { id name color description }
    }
    assignableUsers(first: 100) { nodes { id login avatarUrl } }
    milestones(first: 30, states: OPEN) { nodes { id title state dueOn } }
    openMilestones: milestones(first: 10, states: CLOSED) { nodes { id title } }
  }
}

# 增删
mutation AddLabels($labelableId: ID!, $labelIds: [ID!]!) {
  addLabelsToLabelable(input: { labelableId: $labelableId, labelIds: $labelIds }) {
    labelable { ... on Issue { labels(first: 20) { nodes { id } } } }
  }
}
mutation RemoveLabels { removeLabelsFromLabelable(input: { labelableId: $id, labelIds: $ids }) { clientMutationId } }
mutation AddAssignees { addAssigneesToAssignable(input: { assignableId: $id, assigneeIds: $ids }) { clientMutationId } }
mutation RemoveAssignees { removeAssigneesFromAssignable(input: { assignableId: $id, assigneeIds: $ids }) { clientMutationId } }
mutation SetMilestone { updateIssue(input: { id: $id, milestoneId: $mid }) { issue { id } } }

# 项目拉入（v2）
mutation AddProjectItem($projectId: ID!, $contentId: ID!) {
  addProjectV2ItemById(input: { projectId: $projectId, contentId: $contentId }) {
    item { createdAt }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 新建 Label / Milestone | 桌面/web 专属，移动端无入口 | 编辑器内提示「web 端创建」；不做 mutation |
| Duplicate 关闭 | GraphQL `IssueStateReason` 无 DUPLICATE 枚举（2026-02 官方 1.218 上线，API 探测点：若 v4 已扩枚举则直接支持） | 先探测；不可行则降级为「NOT_PLANNED 关闭 + 正文 @引用原 issue」并在边界表留记录 |
| Projects 状态位编辑 | UpdateProjectV2ItemFieldValue 需要 field 查询链（Iteration/Status 单选链） | P1：只做「加入项目」；状态编辑待勘探后 P2 |
| Sub-issues（2025 新 API） | GraphQL 字段变化频繁 | 单列探测任务，结果写回本 Spec 备注 |
| 权限（repo 只读 token） | PAT 无 repo write 时全部 403 | 编辑入口按权限隐藏（检查 viewerCanEdit? 用「403 兜底」策略：写操作错误提示） |

---

## 六、TDD 验收标准

- [ ] 测试 1：详情页渲染 labels chips（名字/颜色），点击进入多选编辑器并回显已有
- [ ] 测试 2：勾选/取消 label 触发 add/remove mutation，保存后 chips 更新
- [ ] 测试 3：assignees 头像行 + 编辑器多选；搜索「li」过滤出仓库成员列表
- [ ] 测试 4：milestone 编辑器只列 open 里程碑，选中后详情显示「Milestone: x」（null 归零显示 No milestone）
- [ ] 测试 5：项目拉入选择项目下拉（projectsV2 列表复用 020 查询），成功后出现「已加入项目」toast
- [ ] 测试 6：duplicate 关闭流程按探测结果执行；若降级则正文插入引用原 issue 链接
- [ ] 测试 7：无权限仓库下编辑入口隐藏/错误文案正确（无崩溃）
- [ ] 测试 8：所有新 UI 用 Primer token 颜色（无硬编码）；i18n 双份；check-spec 通过
- [ ] 测试 9：被移除的 assignee 出现 Local 空态（头像占位替代）不崩溃

---

## 七、备注

- 与 043 的分界：043 负责「创建/生命周期动作（close/reopen/draft）」，044 负责「元数据编辑」——两者入口并列，可并行开发（043 先完成也 OK）。
- 官方 1.219+ 的「Close as duplicate」桌面端 = `stateReason` 弹层（重复/未计划/完成）——移动端对齐官方移动端行为（检查官方 App 实机 2.2x 表现后定稿，验收前做一次实机留样）。
- Labels 颜色来自 GitHub API（hex），UI 需与 Primer token 对比度校验（黑/白字判定用 API 的 `color` 亮度计算）。
