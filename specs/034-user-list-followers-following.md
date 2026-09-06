# Spec 034: 用户列表页（Followers / Following）

> BFS Level: 4
> 关联截图: GitHub 官方 App Followers（ZM-BAD）/ Following（shellRaining）列表页（用户提供 2026-09-01）
> 上游 Spec: 005（User Profile）
> 状态: implemented（2026-09-01，构建通过 / 模拟器冒烟 + 真实数据验证通过）

---

## 一、页面/功能概述

Profile 页「N followers · N following」计数行拆为**两个可点击片段**（中间「·」分隔），点击进入对应用户列表二级页。Followers 与 Following 为同一页面组件、两个参数（login + 列表类型），副标题静态文本。行内无操作按钮，整行点击进入该用户主页；图表数据 GraphQL 分页（first:25 + 加载更多）。

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│ ←  ZM-BAD            （粗体 login） │
│     Followers                        │
├─────────────────────────────────────┤
│ (头像)  unmissable guy               │
│          transmutat                  │
│ (头像)  shellRaining  [仅用户名行]   │
│          shellRaining                │
│ (头像)  Li2C03                       │
│          HeyJavaBean                 │
│          To be a rock and not to roll│
│        ……（加载更多/其余行）          │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar | ← 返回 + login（粗体）+ Followers/Following（灰） | 导航 | ✅ | —（纯 UI） | 自绘头部，hideTitleBar；副标题静态 |
| 2 | 行 | 圆头像（80 逻辑宽内） | 展示 | ✅ | `avatarUrl` | — |
| 3 | 行 | 显示名（粗体；缺失时仅灰色用户名行） | 展示 | ✅ | `name` | 显示名空 → 单行 `@login` 灰色 |
| 4 | 行 | 用户名（灰，@ 前缀） | 展示 | ✅ | `login` | — |
| 5 | 行 | 简介（灰，可选，最多 2 行省略） | 展示 | ✅ | `bio` | — |
| 6 | 行 | 整行点击 → 用户主页 | 导航 | ✅ | —（纯 UI） | pushPathByName('userProfile', login) |
| 7 | 列表底 | 加载更多（首次 25 条，endCursor 分页） | 请求 | ✅ | `pageInfo { hasNextPage endCursor }` | 与 WorkService 同模式 |
| 8 | 空态 | 无数据提示 | 展示 | ✅ | —（纯 UI） | 复用 StateView/空态文案 |
| 9 | Profile 入口 | 计数行两段可点（%1$d followers / · / %2$d following） | 导航 | ✅ | —（纯 UI） | 本 Spec 入口改造 |

> 可行性比例声明：9/9 可行。

---

## 四、核心 GraphQL 片段

```graphql
query UserFollowers($login: String!, $first: Int = 25, $after: String) {
  user(login: $login) {
    followers(first: $first, after: $after) {
      pageInfo { hasNextPage endCursor }
      nodes { login name bio avatarUrl }
    }
  }
}

query UserFollowing($login: String!, $first: Int = 25, $after: String) {
  user(login: $login) {
    following(first: $first, after: $after) {
      pageInfo { hasNextPage endCursor }
      nodes { login name bio avatarUrl }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 行内 Follow/操作按钮 | 截图无此元素 | 不实现（整行进主页） |
| 头像加载失败 | 网络异常 | 圆形灰底占位（heat_empty） |
| 空列表 | 无粉丝/无关注 | 居中空态一行提示 |
| 计数行点击目标 | — | 仅本页两点（不拆分其他统计） |

---

## 六、TDD 验收标准

- [ ] 测试 1：Profile 计数行渲染为两段可点文本（中间「·」分隔），点左段进 Followers、右段进 Following；自/他用户 profile 均可用
- [ ] 测试 2：列表页头部（返回 + 粗体 login + 灰副标题）按截图对齐；行样式（有/无显示名 + 可选 bio）正确
- [ ] 测试 3：真实数据加载（≥25 条时出现加载更多并翻页）；行点击跳用户主页
- [ ] 测试 4：构建 + 模拟器实测通过；grep 无中文字符串字面量；check-spec.sh 通过

---

## 七、备注

- 行样式与 UserCard 不同（UserCard 带 followers 计数行，本页不展示），页内新建行 builder。
- 列表页数据须用户真实 PAT（ZM-BAD 有 60+ following，可测翻页）。
- i18n 新增：`user_list_followers` / `user_list_following`（标题）、`user_list_empty` 等。
