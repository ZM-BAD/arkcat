# Spec 036: 组织主页（Organization Profile）

> BFS Level: 4
> 关联截图: GitHub 官方 App 组织主页（dragonflyoss，用户提供 2026-09-01，完整版）
> 上游 Spec: 035（组织列表页进入）
> 状态: implemented（2026-09-01，构建通过 / 模拟器冒烟 + 真实数据验证通过）

---

## 一、页面/功能概述

组织列表行点击进入的组织主页：头部（logo/名称/login）、简介、官网/邮箱/X 三信息行、通栏 FOLLOW 真实关注按钮、README.md 区块（`.github` 仓库 README，Read more 展开/收起）、Pinned 置顶仓库横滑卡片、Repositories 计数行（进入 Spec 037 仓库列表页）。

---

## 二、整体 UI 结构

1. App Bar：← 返回 + 分享（🔗）+ 更多菜单（⋯）
2. 头部：logo + 组织名 dragonflyoss（粗体）+ login dragonflyoss（灰）
3. 简介段落
4. 信息行：官网 d7y.io（🔗）、邮箱 dragonfly-…@googlegroups.com（✉️）、X 账号 dragonfly_oss（𝕏）
5. 关注按钮：通栏 [+ FOLLOW] 描边按钮
6. README 区块（标题行 dragonflyoss/README.md + 右侧滚动条）：
   - Welcome to Dragonfly（正文首行）
   - [徽章群]
   - 正文…（折叠）+ Read more 展开按钮（📥）
7. Pinned 置顶区（📍 标题）：横滑卡片 dragonflyoss / dragonfly 3.3k Go …
8. Repositories 区（▤ 图标）：Repositories 计数行 31 + ›

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar | ← + 🔗 分享 + ⋯ | 导航 | ✅ | —（纯 UI） | 自绘头部，hideTitleBar；分享拉起系统分享面板（Spec 061）；⋯ 提示后续 |
| 2 | 头部 | logo + 组织名（粗体）+ login（灰） | 展示 | ✅ | `name/login/avatarUrl` | avatar 圆角 12 |
| 3 | 头部 | 简介段落（灰色，多行） | 展示 | ✅ | `description` | — |
| 4 | 信息行 | 🔗 官网 / ✉️ 邮箱 / 𝕏 X 账号 | 展示 | ✅ | `websiteUrl/twitterUsername` + REST mailbox | 邮箱直接取组织 REST 字段 |
| 5 | 按钮 | [+ FOLLOW] 通栏描边按钮 | 真实关注 | ✅ | REST `PUT/DELETE /user/follows/{login}` | 切换关注；初始态 `GET /user/follows` 探测；失败 toast；已有 `user:follow` scope |
| 6 | README | 标题行 `{login}/README.md` + 右侧滚动条 | 展示 | ✅ | —（纯 UI） | 固定格式文案 |
| 7 | README | 官方 HTML 渲染（MarkdownView） | 展示 | ✅ | REST `contents/{login}/.github/profile/README.md`（profile 优先）→ `/repos/{login}/.github/readme` 兜底 | 双 404 → 整区块隐藏；渲染管线与 006 一致（REST /readme + MarkdownView，040） |
| 8 | README | Read more 展开/收起 | 交互 | ✅ | —（纯 UI） | MarkdownView 折叠阈值 500 字符/240vp（040）；悬浮胶囊按钮 |
| 9 | Pinned | 📍 标题 + 横滑卡片（RepoCard 复用） | 展示/导航 | ✅ | `pinnedItems(first:6,types:[REPOSITORY])` | 卡点击 → repoDetail |
| 10 | Repositories | 图标 + 计数行（count 右侧 + ›） | 导航 | ✅ | REST `public_repos`（repositoriesCount） | pushPathByName('repositoriesList', login) |

> 可行性比例声明：10/10 可行。

---

## 四、核心 GraphQL 片段

主数据走 REST `GET /orgs/{login}`（blog→websiteUrl、public_repos→repositoriesCount、email 直取）；仅 Pinned 走 GraphQL（ORG_PINNED_QUERY，`pinnedItems(first: 6, types: [REPOSITORY])`）：

```graphql
query OrgPinned($login: String!) {
  organization(login: $login) {
    pinnedItems(first: 6, types: [REPOSITORY]) {
      nodes { ... on Repository {
        id nameWithOwner description stargazerCount forkCount
        primaryLanguage { name color }
      } }
    }
  }
}
```

REST：`GET /orgs/{login}`（主数据）、`GET /user/follows/{login}`（跟随态，204=是）、`PUT|DELETE /user/follows/{login}`（跟随/取关）。

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 组织 README 不存在 | `.github` 无 README | README 区块隐藏 |
| Markdown 完整渲染（表格/高亮/图片） | 复用简化渲染 | 标题/加粗/链接/正文行；徽章按纯文本行展示 |
| FOLLOW 需要 token scope | `user:follow` 缺失 | toast 提示操作失败原因 |
| ⋯ 菜单 | 更多操作未接入 | 点击提示后续（与仓库详情一致） |
| 组织私有仓库 | 数据依赖权限 | 仓库列表按权限自然过滤 |

---

## 六、TDD 验收标准

- [ ] 测试 1：组织主页头部/信息行/FOLLOW 按钮/README/Pinned/Repositories 行全部按截图对齐（模拟器对照 dragonflyoss）
- [ ] 测试 2：FOLLOW 点击真实切换（REST 204 验证 + 按钮态变化）；无 scope 时报错 toast
- [ ] 测试 3：README Read more 展开/收起；无 README 组织隐藏区块
- [ ] 测试 4：Pinned 卡点击进仓库详情；Repositories 行点击进仓库列表页
- [ ] 测试 5：构建通过；grep 无中文字符串字面量；check-spec.sh 通过

---

## 七、备注

- FOLLOW 按钮态约定：未关注 = 「+ FOLLOW」；已关注 = 「FOLLOWING」（继续可点击取消）。
- 复用：RepoCard（Pinned）、RepoService 的 README 简渲染逻辑（新建通用 `readmeText` 卡片为宜）。
- i18n 新增：`org_follow` / `org_following` / `org_read_more` / `org_repositories_row` 等。
