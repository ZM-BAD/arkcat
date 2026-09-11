# Spec 030: Issue 详情页（Issue 详情链路）

> BFS Level: 3
> 关联截图: GitHub 官方 App Issue 详情（deno/deno #1，用户提供 2026-08-31）
> 上游 Spec: 007（仓库内 Issue 列表）/ 017（工作区 Issue 列表）
> 状态: ✅ implemented（2026-08-31，构建通过 / 仪器测试 30/30 / 模拟器双主题验收通过）

---

## 一、页面/功能概述

从仓库内 Issue 列表/工作区 Issue 列表点击进入的详情页：标题 + 状态（open/closed 圆标）+ 正文（MarkdownView 直渲）+ 评论列表（头像/登录名/相对时间/正文 + 反应条 + 编辑/删除菜单）+ 底部 COMMENT 按钮。正文与评论由 MarkdownView 渲染（Spec 040）。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + `owner/repo #N` + 搜索（🔍）+ 更多菜单（⋯）
2. 标题区：标题（Parent-node "children" link…，2 行省略）+ 状态圆标（🟢 open / 🟣 closed）+ 作者 + 相对时间
3. 正文：MarkdownView 直渲（040）+ 折叠阈值 500 字符/240vp
4. 评论区：💬 N 评论标题 + 评论行（🀫 头像 + 登录名 denoland + 相对时间 2d + 正文多行 + 反应条 + 编辑/删除菜单）+ Load more 分页
5. 底部：[COMMENT] 按钮 + 表情按钮（😊）

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar | ← 返回 + `owner/repo #N` + 搜索/⋯ | 导航 | ✅ | —（纯 UI） | — |
| 2 | 标题 | 大标题（2 行省略） | 展示 | ✅ | `title` | maxLines 2 + Ellipsis |
| 3 | 标题 | 状态圆标 + 作者 + 相对时间 | 展示 | ✅ | `state/stateReason/author/createdAt` | 与 007/017 图标一致 |
| 4 | 正文 | MarkdownView 直渲（040） | 展示 | ✅ | `body/bodyHTML` | 折叠阈值 500 字符/240vp |
| 5 | 评论 | 头像/登录名/时间/正文 + 反应条 + 编辑/删除菜单 | 展示 | ✅ | `comments { nodes bodyHTML/viewerDidAuthor/reactionGroups }` | 编辑/删除仅本人（viewerDidAuthor）显示 |
| 6 | 评论区 | Load more 分页 | 翻页 | ✅ | `comments.pageInfo` | — |
| 7 | 底部 | COMMENT + 表情按钮 | 占位 | ✅ | —（纯 UI） | 提示后续 |

> 可行性比例声明：7/7 可行。

---

## 四、核心 GraphQL 片段

```graphql
query IssueDetail($owner: String!, $name: String!, $number: Int!, $first: Int = 20, $after: String) {
  repository(owner: $owner, name: $name) {
    issue(number: $number) {
      id title state stateReason body bodyHTML createdAt
      author { login avatarUrl }
      labels { name }
      comments(first: $first, after: $after) {
        totalCount
        pageInfo { hasNextPage endCursor }
        nodes {
          id body bodyHTML createdAt viewerDidAuthor
          author { login avatarUrl }
          reactionGroups {
            content viewerHasReacted
            reactors(first: 8) {
              totalCount
              nodes {
                ... on User { login avatarUrl }
                ... on Bot { login avatarUrl }
                ... on Mannequin { login avatarUrl }
                ... on Organization { login avatarUrl }
              }
            }
          }
        }
      }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| Markdown 渲染（代码块/列表/引用） | 渲染器后续 Spec | MarkdownView 直渲（040） |
| 关闭/重开操作 | 写操作暂不在范围 | COMMENT 已联通（041）；状态图标行点击提示（待后续） |

---

## 六、TDD 验收标准

- [x] 测试 1：`mapIssueDetail` 纯函数：字段/评论分页映射正确
- [x] 测试 2：构建 + 模拟器实测：深色下正文/评论/底部栏与截图对齐
- [x] 测试 3：grep 页面无中文字符串字面量；check-spec.sh 通过
- [ ] 测试 4：长标题超 2 行省略（实现完成，待模拟器走查）

---

## 七、备注

- 路由参数：`owner/name/number`（NavPath，param 字符串拼接）；工作区与仓库内入口统一。
