# Spec 006: Repo Detail（仓库详情页）

> BFS Level: 3
> 关联截图: 点击任意仓库进入（官方截图：headroom）
> 状态: implemented（2026-08-31，官方布局对齐验收通过）

---

## 一、页面/功能概述

仓库详情页，对照官方 App 布局：

- **顶栏**：← 返回 + ＋（新建）+ ⋯ 菜单
- **头部**：业主头像+名字 / 仓库名 / 描述 / ★ stars · ⑂ forks
- **操作区**：`STAR` 大按钮 + fork/铃铛两个圆形按钮
- **计数入口**：Issues / Pull Requests / Actions / Releases（彩块 + 计数）
- **More 折叠区**：Contributors / Watchers / License（见 053-055）；Current branch main ✓ / Code / Commits 为独立分支区卡片
- **README**：富文本渲染（Markdown 标题/图片/链接/列表）

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + ＋ 新建 + ⋯ 更多菜单
2. 头部：👤 业主（ZM-BAD）+ 仓库名（headroom）+ 描述（Know when your AI is...）+ ★ 43 stars · ⑂ 3 forks
3. 操作区：[ STAR ] 大按钮 + [⑂] fork 圆钮 + [🔔] 铃铛圆钮（← 操作区）
4. 计数入口：🟩 Issues 1 / 🟦 Pull Requests 1 / 🟧 Actions 0 / ⬛ Releases 2（点击进列表，见 029）
5. More 折叠区：··· More + ▾ 下拉（Contributors / Watchers / License，见 053-055）
   - 分支区卡（独立于 More）：⑂ Current branch main ✓ + CHANGE · ▣ Code · ▤ Commits
6. README：📖 富文本渲染（标题/图片/链接）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | 顶栏左 | ← 返回 | 回退 | ✅ 纯 UI | — | — |
| 2 | 顶栏右 | ＋ / ··· | 新建/更多 | ⚠️ | — | 点击提示 |
| 3 | 头部 | 业主头像+名/仓库名/描述 | 纯展示 | ✅ | `repository { owner { avatarUrl login } name description }` | — |
| 4 | 头部 | ★ stars / ⑂ forks | 进入 Stargazers/Forks | ✅ | `stargazerCount/forkCount` | 点击进入（见 053） |
| 5 | 操作区 | STAR 大按钮 | Star/取消 | ✅ | `addStar/removeStar` | 已实现 |
| 6 | 操作区 | fork 圆钮 | Fork | ✅ | `createFork` | 已实现 |
| 7 | 操作区 | 🔔 圆钮 | 订阅 | ⚠️ | `updateSubscription` | 点击提示 |
| 8 | 计数区 | Issues/PR/Actions/Releases 行 | 进入对应列表 | ✅ | `issues.totalCount/pullRequests.totalCount/actions.totalCount/releases.totalCount` | Actions 无 API 时显示 0 |
| 10 | More 区 | Current branch main ✓ · CHANGE | 分支切换 | ⚠️ | `defaultBranchRef.name` | CHANGE 提示 |
| 11 | 分支区 | Code/Commits 行 | 进入文件树/提交列表 | ✅ | — | 路由 Code（038）/ Commits（028） |
| 13 | README | 富文本渲染 | 展示 | ✅ | `object(expression: "HEAD:README.md")` | REST /readme 官方 HTML + MarkdownView 直渲（040） |

---

## 四、核心 GraphQL 片段

```graphql
query RepositoryDetail($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    nameWithOwner
    description
    stargazerCount
    forkCount
    issues { totalCount }
    pullRequests { totalCount }
    releases(first: 5) { totalCount nodes { tagName publishedAt isLatest } }
    defaultBranchRef { name }
    object(expression: "HEAD:README.md") { ... on Blob { text } }
    languages(first: 10, orderBy: { field: SIZE, direction: DESC }) {
      totalSize edges { size node { name color } }
    }
    licenseInfo { name spdxId }
    repositoryTopics(first: 10) { nodes { topic { name } } }
    object(expression: "HEAD:") { ... on Tree { entries { name type } } }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| Actions 计数 | GraphQL 无 actions 状态公开接口 | 显示 0（保留入口） |
| README 富文本（图片/表格） | Markdown 解析降级 | 简化渲染：标题加粗/链接/纯文本行 |
| 分支切换 CHANGE | 切换分支需页面级交互 | 显示 main ✓，点击提示 |
| 铃铛订阅 | 订阅变更 UI 复杂 | 圆钮保留，点击提示 |
| 原文件列表/语言占比 | 官方新版布局取消（收进 Code/Commits） | 从详情页移除，保留查询供后续 |

---

## 六、TDD 验收标准

- [x] 头部（业主/仓库名/描述/stars/forks）正确渲染（n8n 实测：★202919 ⑂60470）
- [x] STAR/fork/🔔 操作区按钮组渲染
- [x] Issues/PR/Actions/Releases 计数入口渲染（实测 10165/26942/0/782）
- [x] More 折叠区（Contributors/Watchers/License）展开验证通过
- [x] README 简化富文本渲染（图片/标题/正文行）
- [x] ohosTest 22/22；模拟器截图验收

---

## 七、备注

- 原 Spec 006 的「文件列表/语言占比」从详情页收进 More 区（官方布局），GraphQL 查询保留
- 2026-08-31：官方布局对齐完成，截图验收通过
