# Spec 003: Explore Tab（发现探索）

> BFS Level: 1
> 关联截图: 官方 App Explore（Explore 标题 + Discover 区块 + Activity 流）
> 状态: implemented（2026-08-31，官方 Discover/Activity 布局对齐验收通过）

---

## 一、页面/功能概述

发现页。对照官方 App 布局：

- **标题**：Explore
- **Discover 区**：Trending Repositories / Awesome Lists 两个入口块
- **Activity 区**：信息流（推荐仓库卡 + PR/Release 卡片样式引导）
- **保留 Topics**：原有 Topic 标签网格（点击展示该主题仓库列表）

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│  Explore                             │  ← 标题
├─────────────────────────────────────┤
│  Discover                            │
│  🔥 Trending Repositories            │  ← 入口块
│  ✦  Awesome Lists                    │
├─────────────────────────────────────┤
│  Activity                       ⚙ │  ← 信息流
│  ┌───────────────────────────┐     │
│  │ 🤖 gh-actions-bot ... 28m │     │
│  │   PR Build                │     │
│  │   v0.0.10-nightly...      │     │
│  │   [ View release details>]│     │
│  ├───────────────────────────┤     │
│  │ 🌟 Recommended for you  1d │     │
│  │   easy-javadoc ...        │     │
│  │   ☆ 2.9k  Java            │     │
│  │   [ STAR ]                │     │
│  └───────────────────────────┘     │
├─────────────────────────────────────┤
│  Topics                              │
│  🏷 harmonyos 🏷 arkts ...           │
├─────────────────────────────────────┤
│  🏠    🔔      🧭      🤖           │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | 标题 | Explore | 纯展示 | ✅ 纯 UI | — | — |
| 2 | Discover 区 | 🔥 Trending Repositories 入口块 | 跳转趋势仓库 | ⚠️ | REST `search/repositories?q=stars:>1000&sort=stars` | 无官方 trending 接口，用高星 search 近似 |
| 3 | Discover 区 | ✦ Awesome Lists 入口块 | 跳转精选列表 | ✅ | GraphQL `search topic:awesome` | — |
| 4 | Activity 区 | 推荐仓库卡（作者/标题/星数/语言 + STAR 按钮） | 展示推荐流 | ✅ | GraphQL `search(type: REPOSITORY, sort: stars)` | 官方个性化推荐无公开 API，用高星近似 |
| 5 | Activity 区 | Release 样式卡（版本/Release Time/View release details） | 版本流 | ⚠️ | REST `releases/latest` | 简化：推荐仓库卡复用 |
| 6 | Topics 区 | Topic 标签网格 | 展示主题仓库 | ✅ | GraphQL `search(query: "topic:$topic")` | 原功能保留 |
| 7 | 底部导航 | Explore Tab 选中态 | 导航 | ✅ 纯 UI | — | — |

> 可行性比例声明：5/7 可行。

---

## 四、核心 GraphQL 片段

```graphql
# 推荐/Awesome 仓库（按星标热门）
query StarredSearch($query: String!, $first: Int = 20) {
  search(query: $query, type: REPOSITORY, first: $first) {
    repositoryCount
    nodes {
      ... on Repository {
        id
        nameWithOwner
        description
        stargazerCount
        forkCount
        primaryLanguage { name color }
      }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 官方个性化 Activity 流 | 官方 App 独立 API，无公开接口 | 用高星推荐仓库卡近似 |
| Collections 精选集合 | 官方运营内容无公开 API | 隐藏（原边界） |
| Trending 官方数据源 | 无公开 trending 接口 | `stars:>1000` 按星标 search 近似 |

---

## 六、TDD 验收标准

- [x] Discover 区：Trending / Awesome 两个入口块渲染，点击进入对应列表
- [x] Activity 区：推荐仓库卡渲染（作者/星数/语言/STAR 按钮）
- [x] Topics 标签网格功能保留
- [x] 模拟器截图验收：布局与官方对齐

---

## 七、备注

- 推荐仓库 search 与 Topic search 复用同一查询封装（ExploreService）
- 2026-08-31：Discover/Activity 布局对齐完成，截图验收通过
