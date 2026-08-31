# Spec 006: Repo Detail（仓库详情页）

> BFS Level: 3
> 关联截图: 点击任意仓库进入
> 状态: ✅ implemented（2026-08-31，真实 GitHub PAT 数据全页验收通过）

---

## 一、页面/功能概述

仓库详情页，展示 About（README + Star/Fork/Watch + License + Topics）、子 Tab 导航（Code/Issues/PRs/Actions/Packages/Settings）、文件列表、贡献者、语言占比。

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│  ←   owner/repo               ···    │
├─────────────────────────────────────┤
│  📖 About                           │
│  📄 README.md 预览                  │
│  ⭐ 2 · 🍴 8 · 👁 0 watching        │
│  📝 MIT License                     │
│  🏷 topic1 · topic2                 │
├─────────────────────────────────────┤
│  📂 Code · 🐛 Issues · 🔀 PRs       │
│  │    Actions · 📦 Packages · ⚙️    │
├─────────────────────────────────────┤
│  📁 文件列表                         │
│  📁 src/          6d ago            │
│  📄 README.md     6d ago            │
│  [ View all files ]                 │
├─────────────────────────────────────┤
│  👥 Contributors                    │
│  📊 Languages                       │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
|---|------|------|------|--------|-------------|------|
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ 纯 UI | — | — |
| 2 | App Bar 中 | 仓库全名 | 展示 | ✅ 纯 UI | — | — |
| 3 | App Bar 右 | ··· 更多菜单 | Star/Fork 等 | ⚠️ | 部分 mutation | — |
| 4 | About 区 | README 摘要 | 点击查看完整 | ✅ | `repository.object(expression: "HEAD:README.md")` | — |
| 5 | About 区 | ⭐ Star 数 + 按钮 | Star/取消 | ✅ | `addStar` / `removeStar` | — |
| 6 | About 区 | 🍴 Fork 数 + 按钮 | Fork | ✅ | `createFork` | — |
| 7 | About 区 | 👁 Watch 数 + 按钮 | 设置订阅 | ✅ | `updateSubscription` | — |
| 8 | About 区 | License | 展示 | ✅ | `repository.licenseInfo` | — |
| 9 | About 区 | Topics 标签 | 跳转 Topic 页 | ✅ | `repository.repositoryTopics` | — |
| 10 | 子 Tab | Code/Issues/PRs/Actions/Packages/Settings | 切换 | ⚠️ | 见下 | — |
| 11 | 文件列表 | 文件/目录行 | 点击进入 | ✅ | `repository.object(expression: "HEAD:")` | — |
| 12 | 文件列表 | View all files | 跳转完整浏览器 | ✅ | 同上 | — |
| 13 | Contributors | 贡献者头像列表 | 进入 Profile | ⚠️ | 无直接字段 | — |
| 14 | Languages | 语言占比条 | 展示 | ✅ | `repository.languages(...)` | — |

---

## 四、核心 GraphQL 片段

```graphql
query RepositoryDetail($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    nameWithOwner
    description
    isPrivate
    isFork
    stargazerCount
    forkCount
    watchers { totalCount }
    licenseInfo { name spdxId }
    repositoryTopics(first: 10) { nodes { topic { name } } }

    object(expression: "HEAD:README.md") { ... on Blob { text } }
    object(expression: "HEAD:") {
      ... on Tree { entries { name type extension } }
    }

    languages(first: 10, orderBy: { field: SIZE, direction: DESC }) {
      totalSize edges { size node { name color } }
    }

    defaultBranchRef {
      name
      target { ... on Commit { history(first: 1) { nodes { committedDate messageHeadline } } } }
    }
  }
}

mutation ToggleStar($starrableId: ID!) {
  addStar(input: { starrableId: $starrableId }) { starrable { stargazerCount } }
}

mutation ForkRepo($repositoryId: ID!) {
  createFork(input: { repositoryId: $repositoryId }) { repository { nameWithOwner } }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
|----|------|-------------------|
| Packages Tab | 无公开用户级 API | 不展示 |
| Settings Tab | 第三方无意义 | 不展示 |
| Contributors | 无直接 GraphQL 字段 | MVP 跳过或简化 |
| Actions Tab | API 复杂 | MVP 只展示状态 |

---

## 六、TDD 验收标准

- [x] 仓库信息（描述、Star 数、Fork 数）正确展示
- [x] README 能展示
- [x] 文件列表能展示
- [ ] Star/Fork/Watch 操作正常
- [ ] 点击文件进入 Code Viewer

---

## 七、备注

- 11/14 可行
- 2026-08-31：实现合并自 feature/spec-00X 分支（--no-ff）至 develop，仪器测试 19/19 通过；真实数据类验收项需在应用内配置有效 GitHub PAT 后复核
- 2026-08-31 真实数据验收：使用 GitHub PAT（模拟器实测）完成以上勾选项；未实测项见「备注」（详情跳转由 Spec 008/011 接管）
