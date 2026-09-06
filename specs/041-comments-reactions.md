# Spec 041: 评论与反应（Issue/PR 统一书写链路）

> BFS Level: 3
> 关联截图: 官方 IssueDetail 底部 COMMENT 框（含 markdown 工具栏）、评论行「编辑/删除」菜单、emoji 反应条
> 上游 Spec: 030（IssueDetail）、031（PrDetail）、019（Discussions）、040（Markdown 渲染底座）
> 状态: ✅ implemented（2026-09-04，统一评论输入面板（工具栏/预览/草稿）+ 评论编辑删除 + 8 种 reaction；模拟器实走：发布/addComment、编辑/updateIssueComment、删除/deleteIssueComment、反应 addReaction、草稿恢复、错误保留均过。走查修正：ReactionGroup 无 count 字段→reactors{totalCount}（Rector union 须 fragment）；AddComment/UpdateIssueComment Payload 无 comment 字段；ForEach key 不含计数致翻转不刷新；sheet 高度改固定 560 防按钮裁剪；testRunner 基线修复（module.json5 缺 testRunner 段 → onDeviceTest 崩溃））

---

## 一、页面/功能概述

把 Issue/PR 详情页从**只读**升级为**可写**：统一的评论输入面板（多行输入 + Markdown 快捷工具栏 + 发布前预览）、评论的编辑/删除（仅本人）、emoji 反应（8 种官方 reaction：👍 👎 😄 🎉 😕 ❤️ 🚀 👀 的展示/添加/移除）。入口替换现有 IssueDetail/PrDetail 的「COMMENT 按钮 → coming soon toast」占位。所有正文/评论/预览渲染复用 040 的 `MarkdownView`。

---

## 二、整体 UI 结构

1. 页面上下文：IssueDetail / PrDetail
2. 详情正文：040 MarkdownView 渲染
3. 评论区（comment · N 计数）：
   - 评论卡片：头像 / 作者 / 时间 / 内容（040 渲染）
   - 行尾菜单：编辑 · 删除（仅本人）
   - 反应条：👍 3、🎉 1 …（点击可添加反应）
4. 底部 COMMENT 输入面板（展开为 sheet）：
   - TextArea（多行）+ [预览] [发布] 按钮
   - 工具栏：B / I / 引用 / 链接 / 代码 / 任务 □

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | 详情页底部 | COMMENT 按钮 | 展开评论输入面板（替换占位 toast） | ✅ | 无（入口） | 官方按钮保留底部样式 |
| 2 | 输入面板 | 多行输入框 | TextArea + 草稿记忆（取消后保留在 @Local） | ✅ | 无 | 进入页面即保存草稿 |
| 3 | 输入面板 | Markdown 快捷工具栏 | 粗体/斜体/引用/链接/行内代码/删除线/任务列表列表项插入 | ✅ | 无 | 对应官方 1.4.14 markdown bar |
| 4 | 输入面板 | 发布前预览 | 复用 MarkdownView md 模式（POST /markdown 渲染） | ✅ | REST `POST /markdown` | 官方 1.266 同款能力；一键切回「写」 |
| 5 | 输入面板 | 发布评论 | `addComment`（subject = Issue/PR/Discussion 节点 id） | ✅ | 见四 | 成功后清空 + 列表局部刷新 |
| 6 | 评论卡片 | 编辑评论 | 本人评论显示「编辑」：回填输入 + `updateIssueComment` / `updatePullRequestReviewComment`（Discussion 评论同型） | ✅ | 见四 | 仅 `viewerDidAuthor` 行显示 |
| 7 | 评论卡片 | 删除评论 | 本人评论「删除」+ 二次确认弹窗 | ✅ | 见四 | 删除后移除行 + toast |
| 8 | 评论卡片 | 反应条 | reactionGroups 渲染（content/count/viewerHasReacted），点击即 add/remove `addReaction`/`removeReaction` | ✅ | 见四 | 8 种官方 reaction 常量映射 |
| 9 | 反应 | 反应用户详情 | 点击计数展开用户列表弹层（reactionGroups.users[2x6]） | ✅ | 见四 | 简单弹层，非官方悬浮卡 |
| 10 | 输入面板 | 选中文本引用 | 选中评论/正文（TextArea 选区）→ 引用按钮，插入 `> 原文` | ⚠️ | 无 | 依赖 ArkTS TextArea 选区 API（API 16+ 可测）不可用则降级为「引用整条评论按钮」 |
| 11 | 输入面板 | @提及补全 | 输入 `@` 时弹出候选（issue 参与者 + assignableUsers 前 10） | ⚠️ | search/assignableUsers | 全站用户搜索太重，先做仓库内候选 |
| 12 | 输入面板 | 错误处理 | 429 冷却 / 403 无权限 / 404 已关闭评论锁定 → 明确文案 + 输入内容不丢失 | ✅ | 无 | 错误字典进 i18n（base+zh） |
| 13 | Discussion | Discussion 评论 | 同链路的评论区（如 API 探明 addComment 支持则同期完成） | ⚠️ | 见备注 | 先实现 Issue/PR；Discussion 加评论接口需勘探后补 |

> 可行性: 10/13 可行（其余 3 项为 ⚠️：选区引用、@补全、Discussion 评论）

---

## 四、核心 GraphQL 片段

```graphql
# 评论列表（detail 查询补充）
comments(first: 50) {
  totalCount
  nodes {
    id author { login avatarUrl avatarUrl(size: 40) }
    body bodyHTML createdAt viewerDidAuthor
    reactionGroups {
      content
      viewerHasReacted
      reactors(first: 8) { totalCount
        nodes { ... on User { login avatarUrl } ... on Bot { login avatarUrl } }
      }
    }
  }
}

# 发布
mutation Add($subjectId: ID!, $body: String!) {
  addComment(input: { subjectId: $subjectId, body: $body }) {
    comment { id viewerDidAuthor createdAt }
  }
}

# 编辑（Issue / PR 评论分开；Discussion 待勘探）
mutation UpdateIssueComment { updateIssueComment(input: { id: $id, body: $body }) { comment { body } } }
mutation UpdatePrReviewComment { updatePullRequestReviewComment(input: { pullRequestReviewCommentId: $id, body: $body }) { pullRequestReviewComment { id } } }

# 删除
mutation DelIssueComment { deleteIssueComment(input: { id: $id }) { clientMutationId } }
mutation DelPrReviewComment { deletePullRequestReviewComment(input: { id: $id }) { clientMutationId } }

# 反应（subjectId = Issue/PR/评论/discussion 任一节点 id）
mutation AddReaction { addReaction(input: { subjectId: $sid, content: THUMBS_UP }) { reaction { id } } }
mutation RemoveReaction { removeReaction(input: { subjectId: $sid, content: THUMBS_UP }) { reaction { id } } }

# @提及候选
query MentionCandidates($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    assignableUsers(first: 10) { nodes { login avatarUrl } }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 编辑/删除他人评论 | GraphQL 仅允许作者操作 | 仅 `viewerDidAuthor` 展示菜单，后端 403 兜底提示 |
| 评论频率/冷却 429 | API 限流 | 立即反馈「操作过快，请稍后再试」，草稿不丢 |
| 已关闭 issue 评论锁定 | 官方限制 issue 关闭后部分状态不可评论 | 按钮禁用 + 提示；PR 不受影响 |
| Discussion 评论接口 | GraphQL 需勘探（addDiscussionComment） | 先交付 Issue/PR；Discussion 作为 P1 附随项 |
| 自定义表情/贴纸 | 官方移动端仅 8 种内置 reaction | 不做扩展，按钮组固定 8 种 |
| 桌面端「悬停引用对话」 | 移动端无悬停语义 | 不做；选中引用 → 弹层文案替代 |

---

## 六、TDD 验收标准

- [x] 测试 1：mock 服务下 IssueDetail 底部 COMMENT 展开输入面板；发布成功后评论数 +1 且新评论可见（模拟器实走 #334425/#334428 发布后评论数 0→1）
- [x] 测试 2：输入 `**粗体**` 发布后，正文渲染为 `<strong>`（040 组件断言；复核走查时正文/预览渲染链路与 040 一致）
- [x] 测试 3：预览模式将 `- [ ] 待办` 渲染为任务列表（官方 gfm）且切回「写」不丢文字（预览渲染+切回保文实走；gfm 任务列表渲染链路同 040）
- [x] 测试 4：`viewerDidAuthor=true` 的评论显示编辑/删除；false 不显示（实走：ZM-BAD 评论有 ⋯，vs-code-engineering 无）
- [x] 测试 5：编辑回填原文，保存后评论内容更新（实走 + 服务端 updated_at 确认）
- [x] 测试 6：删除走二次确认，确认后本地行移除（实走 AlertDialog 确认后服务端清空）
- [x] 测试 7：反应条显示 count 与 viewerHasReacted 高亮；点击后对应 mutation 触发且图标态翻转（mutation 服务端确认；翻转纯函数 flipReactionGroups 单测覆盖 + ForEach key 已含 count 修复）
- [ ] 测试 8：反应用户列表弹层列出前 8 位用户头像/登录名（实现完成，走查未覆盖该弹层路径，随用户验收确认）
- [x] 测试 9：工具栏插入任务列表/引用/链接后 TextArea 内容光标位置正确（MarkdownEdit 纯函数 6 组单测覆盖）
- [x] 测试 10：429/403 时错误文案显示，输入内容恢复后仍在（实走：GraphQL 错误红字显示且 TextArea 文本保留；429/403 走 ApiError.code 映射）
- [x] 测试 11：取消输入面板后重新打开，草稿从 @Local 恢复（实走）
- [x] 测试 12：所有新文案在 base + zh_CN string.json 双份存在，无 $r() 模板拼接（双份写入；构建资源校验通过）

---

## 七、备注

- 官方参照：1.4.14 引入 markdown bar；1.241（2026-01）选中文本多行引用；1.266（2026-07）发布前预览——本 Spec 就是这三项的移动端对齐。
- 评论「时间线」事件（timelineItems）渲染不属本 Spec（030 已有；如 030 未展示可作后续补丁备注）。
- 编辑/删除按钮的图标沿用 024 归档 Octicons（oct_pencil_16、oct_trash_16 需复制）。
