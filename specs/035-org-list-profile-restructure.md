# Spec 035: 组织列表页 + Profile 三入口导航化

> BFS Level: 4
> 关联截图: GitHub 官方 App Organizations 列表页（gaius-qi，用户提供 2026-09-01）
> 上游 Spec: 005（User Profile）/ 006（Repo Detail）
> 状态: draft

---

## 一、页面/功能概述

Profile 页下方 **Repositories / Organizations / Starred 三入口**由「内嵌切换」改造为「点击跳独立列表页」：Organizations → 本组织列表页；Repositories → Spec 037 仓库列表页；Starred → 现有 StarredRepositories 页（参数化 login）。同时**删除贡献日历与内嵌 tab 切换**（对齐官方 App 的 Profile 结构：头部 + Pinned + 计数行 + 三导航入口）。组织列表行点击进入组织主页（Spec 036）。

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│ ←  gaius-qi           （灰 login 上）│
│     Organizations      （粗体标题下）│
├─────────────────────────────────────┤
│ (logo) Feedit                       │
│         feedit                      │
│         feed it reader.             │
│ (logo) Macaca                       │
│         macacajs                    │
│         AI 自动化解决方案...         │
│        ……（加载更多）                │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
|---|------|------|------|--------|-------------|------|
| 1 | App Bar | ← 返回 + login（灰，上）+ Organizations（粗体，下） | 导航 | ✅ | —（纯 UI） | 自绘头部，hideTitleBar |
| 2 | 行 | 组织头像（logo 原样形状） | 展示 | ✅ | `avatarUrl` | 不强制方形 |
| 3 | 行 | 显示名（粗体） | 展示 | ✅ | `name` | — |
| 4 | 行 | 组织 login（灰） | 展示 | ✅ | `login` | — |
| 5 | 行 | 简介（灰，可选，最多 2 行） | 展示 | ✅ | `description` | — |
| 6 | 行 | 整行点击 → 组织主页 | 导航 | ✅ | —（纯 UI） | pushPathByName('orgProfile', login) |
| 7 | 列表底 | 加载更多（first:25 + endCursor） | 请求 | ✅ | `pageInfo` | — |
| 8 | Profile 改造 | 三入口改导航（保留彩块图标+标签+计数） | 导航 | ✅ | — | 本 Spec 入口改造 |
| 9 | Profile 改造 | 删除贡献日历 + 内嵌 tab 切换 | — | ✅ | — | 官方 App 无日历 |

> 可行性比例声明：9/9 可行。

---

## 四、核心 GraphQL 片段

```graphql
query UserOrganizations($login: String!, $first: Int = 25, $after: String) {
  user(login: $login) {
    organizations(first: $first, after: $after) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes { id login name description avatarUrl }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
|----|------|-------------------|
| 组织内成员数/公开成员切换 | 截图未展示 | 不实现 |
| 组织行点击只看组织主页 | — | 后续可在组织主页详情内达仓库（Spec 037） |
| Profile 原「内嵌仓库/星标列表」 | 已由独立列表页替代 | 删除内嵌视图；Starred 页参数化 login（WorkService 扩展） |
| ContributionCalendar 组件 | 官方无日历 | 组件与查询字段一并移除（contributionsCollection 不再查询） |

---

## 六、TDD 验收标准

- [ ] 测试 1：Profile 三个入口点击分别导航到 Repositories 列表 / 组织列表 / Starred 列表；不再有内嵌切换与日历
- [ ] 测试 2：组织列表页头部（灰 login 上 + 粗体标题下）与行样式按截图对齐；真实数据加载 + 翻页
- [ ] 测试 3：行点击进入组织主页（Spec 036 页面）；空态处理正常
- [ ] 测试 4：构建 + 模拟器实测；grep 无中文字符串字面量；check-spec.sh 通过

---

## 七、备注

- Profile 查询瘦身：移除 `contributionsCollection`、`repositories(first:30)`、`starredRepositories(first:30)` 内嵌列表字段（改由列表页按需分页）；保留 pinned/计数/跟随状态字段。
- i18n 新增：`org_list_title`、`profile_repositories`（已有）、`org_list_empty` 等。
