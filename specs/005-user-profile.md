# Spec 005: User Profile（用户个人主页）

> BFS Level: 3
> 关联截图: 官方 App 个人主页（share/gear 顶栏 + 状态行 + 元信息 + Pinned 横滑 + 三导航入口）
> 上游 Spec: 013（Home 头像进入）
> 状态: implemented（2026-08-31，官方布局对齐验收通过）

---

## 一、页面/功能概述

用户个人主页。对照官方 App 布局：

- **顶栏**：← 返回 + 分享/设置图标
- **Header 卡**：头像/名字/@login + 状态行（Focussing·编辑）+ bio + 元信息（位置/邮箱/链接/关注数）
- **Pinned 区**：横滑卡片（单行）
- **计数入口**：Repositories / Organizations / Starred 三行导航入口（含计数），点击进入独立列表页（无展开视图）

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + 用户名标题（@ZM-BAD）+ 🔗 分享 + ⚙ 设置（← 返回/分享/设置）
2. Header 卡：头像 + 名字（🖼 周铭）+ @ZM-BAD + 状态行 + bio + 元信息行（← 状态行+编辑）
   - 状态行：⚡ Focusing + ✏ 编辑笔
   - bio：Backend developer...
   - 元信息：📍 Hangzhou、✉ `prozm.bad@gmail.com`、🔗 `https://zmbad.me`、🔗 @zm_bad、👥 33 followers · 61 following
3. Pinned 区：📌 Pinned 标题 + 单行横滑仓库卡（→ 横滑查看更多）
4. 导航行：Repositories 8 / Organizations 0 / Starred 93（点击进入独立列表页）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | 顶栏左 | ← 返回 | 回退 | ✅ 纯 UI | — | — |
| 2 | 顶栏右 | 🔗 分享 | 分享用户主页 | ⚠️ | — | 点击提示（系统分享 API 后续） |
| 3 | 顶栏右 | ⚙ 设置 | 进入 Settings 页 | ✅ | — | 新路由 settings |
| 4 | Header | 头像/名字/@login | 纯展示 | ✅ | `user.avatarUrl/name/login` | — |
| 5 | Header | 状态行（emoji+message+编辑笔） | 观众可见状态 | ✅ | `user.status { emoji message }` | 编辑笔仅视图 |
| 6 | Header | bio | 纯展示 | ✅ | `user.bio` | — |
| 7 | Header | 元信息行：位置/邮箱/链接/X 账号 | 纯展示 | ✅ | `user.location/email/websiteUrl/twitterUsername` | email 空值隐藏 |
| 8 | Header | followers/following 计数 | 纯展示 | ✅ | `user.followers/following.totalCount` | — |
| 9 | Pinned 区 | 横滑仓库卡（单行） | 打开仓库 | ✅ | `user.pinnedItems` | Scroll+Row 横向滚动 |
| 10 | 计数入口 | Repositories/Organizations/Starred + 计数 | 进入对应列表页 | ✅ | `repositories.totalCount` / `starredRepositories.totalCount` / 独立 OrgCount 查询 | 导航 repositoriesList / orgList / starred |
| 11 | 正文区 | Pinned 区 + 三导航行 | 内容区 | ✅ | 现有查询 | 无展开视图（原 Tab/展开式已废弃） |
| 12 | ··· 菜单 | Follow/Unfollow | 关注动作 | ✅ | `user.viewerIsFollowing` + mutation | 保留原菜单 |

---

## 四、核心 GraphQL 片段

```graphql
query UserProfile($login: String!) {
  user(login: $login) {
    id
    avatarUrl name login bio company location websiteUrl email twitterUsername
    status { emoji message }
    followers { totalCount }
    following { totalCount }
    viewerIsFollowing
    pinnedItems(first: 6, types: [REPOSITORY]) { nodes { ... on Repository { id name nameWithOwner description stargazerCount forkCount owner { login avatarUrl } primaryLanguage { name color } } } }
    repositories { totalCount }
    starredRepositories { totalCount }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| Packages/Projects | 无公开用户级入口 / 超范围 | 不展示（原边界） |
| Achievements 徽章行 | 官方 HTML 抓取（052） | 展示（点击进成就详情） |
| user.email 字段 | 随 user 主查询获取（实测不触发 scope 报错） | 展示邮箱行，空值隐藏 |
| 系统分享 | 分享能力依赖系统能力集成 | 顶栏保留 🔗 图标，点击提示后续 |
| 编辑状态笔 | 编辑状态需页面级交互 | 图标展示（不触发编辑），后续 Spec |

---

## 六、TDD 验收标准

- [x] 顶栏 share/gear 图标渲染，gear 进入 Settings 页（截图验证）
- [x] 状态行、X 元信息行渲染，缺失字段隐藏（邮箱空值隐藏）
- [x] Pinned 单行横滑卡片
- [x] Repositories/Organizations/Starred 三计数入口渲染且计数正确（8/0/93 实测）
- [x] base/zh_CN key 对齐；ohosTest 21/21 通过
- [x] 模拟器截图验收

---

## 七、备注

- 状态笔、分享图标：交互为点击提示（后续 Spec），保持功能按钮位置对齐官方
- 2026-08-31：官方布局对齐完成，截图验收通过
