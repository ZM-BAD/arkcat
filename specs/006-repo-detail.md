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
- **More 折叠区**：Contributors / Watchers / License（见 053-055），行尾右侧值与计数行同构（贡献者数 / Watchers 数 / 协议名，2026-09-14）；Current branch main ✓ / Code / Commits 为独立分支区卡片
- **README**：官方 HTML 渲染（REST /readme + MarkdownView，040）

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + ＋ 新建 + ⋯ 更多菜单
2. 头部：👤 业主（ZM-BAD）+ 仓库名（headroom）+ 描述（Know when your AI is...）+ ★ 43 stars · ⑂ 3 forks
3. 操作区：[ STAR ] 大按钮 + [⑂] fork 圆钮 + [🔔] 铃铛圆钮（← 操作区）
4. 计数入口：🟩 Issues 1 / 🟦 Pull Requests 1 / 🟧 Actions 0 / ⬛ Releases 2（点击进列表，见 029）
5. More 折叠区：··· More + ▾ 下拉（Contributors / Watchers / License，见 053-055），行尾右侧值=计数（协议名文字）右对齐
   - 分支区卡（独立于 More）：⑂ Current branch main ✓ + CHANGE · ▣ Code · ▤ Commits
6. README：📖 官方 HTML 渲染（MarkdownView）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | 顶栏左 | ← 返回 | 回退 | ✅ 纯 UI | — | — |
| 2 | 顶栏右 | ＋ / ··· | 新建/更多 | ⚠️ | — | 点击提示 |
| 3 | 头部 | 业主头像+名/仓库名/描述/主页链接 | 纯展示 + 链接行可点 | ✅ | `repository { owner { avatarUrl login } name description homepageUrl }` | 主页链接行在 bio 下（2026-09-14）：`oct_link_16` 图标与个人 Profile 链接行同款 + 文字 `text_primary` 单行，与 bio 间隔一行空档（margin 16+列距 8）；无链接不显示；点击拉起系统浏览器（协议缺失补 `https://`） |
| 4 | 头部 | ★ stars / ⑂ forks | 进入 Stargazers/Forks | ✅ | `stargazerCount/forkCount` | 点击进入（见 053）；数字 `text_primary`（2026-09-14），图标/单位文字保持 `text_secondary` |
| 5 | 操作区 | STAR 大按钮 / 已加星金星钮+列表钮 | 加星/取消星标 | ✅ | `addStar/removeStar` + `viewer.lists`（成员切换 `updateUserListsForItem`） | 未加星=STAR 大按钮（白底描边）直接加；已加星=金星钮（`oct_star_fill_16` 灰底描边可点）+ 列表钮（未入列=`+ ADD TO LIST` 白底描边；已入列=列表 icon+首个列表名灰底描边，官方四钮布局）+ fork/🔔（未点击白底描边）；列表钮点开 StarredListSheet 成员弹层（Starred 页 ⋯ 同构）；取消星标先弹确认：title `Unstar {repoName}`、正文 removal from lists 提示、CANCEL/UNSTAR 双蓝钮（2026-09-15） |
| 6 | 操作区 | fork 圆钮 | Fork | ✅ | `createFork` | 白底描边；本人仓库图标置灰（icon `text_tertiary`）禁 fork，点击 toast「You can't fork your own repository.」（2026-09-15） |
| 7 | 操作区 | 🔔 圆钮 | 订阅 | ⚠️ | `updateSubscription` | 点击提示 |
| 8 | 计数区 | Issues/PR/Discussions/Actions/Releases 行 | 进入对应列表 | ✅ | `issues(states:OPEN).totalCount/pullRequests(states:OPEN).totalCount/hasDiscussionsEnabled+discussions.totalCount/releases.totalCount` | Issues/PR 计数=列表页默认筛选（State=Open）下的数量（2026-09-14 官方口径）；**Discussions 行仅仓库开启时显示**（`hasDiscussionsEnabled`；图标=`oct_comment_discussion_16` 与 Home 页 Discussions 同字形，色块口径与 Issues/PRs 行同构=**实底紫 `shortcut_purple_fg` + 白图标**，点入 repoDiscussions 路由）；**Actions 行无数字**（countRow 负数哨兵=无计数，点击 toast 占位） |
| 9 | More 区 | Contributors/Watchers/License 行 | 进入对应页 + 行尾右侧值 | ✅ | `watchers.totalCount` / `licenseInfo.name`；贡献者数无 GraphQL 字段 | 右侧值与计数行同构右对齐（2026-09-14）：Contributors=贡献者数（REST `/contributors?per_page=1&anon=0` Link 头 last 页码，与 054 列表同口径；未加载/失败不显示数字）、Watchers=`watcherCount`、License=`licenseInfo.name`（无许可证行尾留空）；行内 label `layoutWeight(1)`、右侧值 `text_secondary` |
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
    openIssues: issues(states: OPEN) { totalCount }
    openPullRequests: pullRequests(states: OPEN) { totalCount }
    hasDiscussionsEnabled
    discussions { totalCount }
    releases(first: 5) { totalCount nodes { tagName publishedAt isLatest } }
    defaultBranchRef { name }
    object(expression: "HEAD:README.md") { ... on Blob { text } }
    languages(first: 10, orderBy: { field: SIZE, direction: DESC }) {
      totalSize edges { size node { name color } }
    }
    licenseInfo { name spdxId }
    homepageUrl
    repositoryTopics(first: 10) { nodes { topic { name } } }
    object(expression: "HEAD:") { ... on Tree { entries { name type } } }
  }
}
```

> 贡献者计数（More 区 Contributors 行）GraphQL 无对应字段：REST `/repos/{owner}/{repo}/contributors?per_page=1&anon=0`，Link 头 `rel="last"` 页码即总数（复用 Explore `contributorCount` 纯函数）。

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| Actions 计数 | GraphQL 无 actions 状态公开接口 | 显示 0（保留入口） |
| 本人仓库 fork | 官方不允许 fork 自己的仓库 | 按钮置灰，点击仅 toast 提示 |
| 取消星标 | 取消会同步把仓库移出 lists | 先弹确认（双蓝钮）再执行 unstar |
| README 富文本（图片/表格） | — | REST /readme 官方 HTML + MarkdownView 渲染（040） |
| 分支切换 CHANGE | 切换分支需页面级交互 | 显示 main ✓，点击提示 |
| 铃铛订阅 | 订阅变更 UI 复杂 | 圆钮保留，点击提示 |
| 原文件列表/语言占比 | 官方新版布局取消（收进 Code/Commits） | 从详情页移除，保留查询供后续 |

---

## 六、TDD 验收标准

- [x] 头部（业主/仓库名/描述/stars/forks）正确渲染（n8n 实测：★202919 ⑂60470）
- [x] STAR/fork/🔔 操作区按钮组渲染
- [x] Issues/PR/Actions/Releases 计数入口渲染（实测 10165/26942/0/782）
- [x] More 折叠区（Contributors/Watchers/License）展开验证通过
- [x] README 官方 HTML 渲染（MarkdownView + REST /readme）
- [x] ohosTest 22/22；模拟器截图验收

---

## 七、备注

- 原 Spec 006 的「文件列表/语言占比」从详情页收进 More 区（官方布局），GraphQL 查询保留
- 2026-08-31：官方布局对齐完成，截图验收通过
- 2026-09-14：More 区 Contributors/Watchers/License 行尾右侧值落地（计数/协议名，与计数行同构），见元素 9
- 2026-09-14：头部 bio 下主页链接行落地（link 图标 + 黑色链接文字 + 系统浏览器打开），见元素 3；stars/forks 数字改黑色，见元素 4
- 2026-09-15：操作区已加星改官方四钮布局（金星钮+列表钮），本人仓库 fork 置灰提示，取消星标确认弹窗，见元素 5/6
