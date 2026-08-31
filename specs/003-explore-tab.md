# Spec 003: Explore Tab（发现探索）

> BFS Level: 1
> 关联截图: 底部导航第三个 Tab
> 状态: ✅ implemented（2026-08-31，真实 GitHub PAT 数据全页验收通过）

---

## 一、页面/功能概述

发现页，包含搜索入口、Collections 精选集合（不可实现）、Topics 主题标签网格、Browse all topics 入口。

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│  ←   Explore                  🔍     │
├─────────────────────────────────────┤
│  [ Search Bar ]                     │  ← 搜索入口
├─────────────────────────────────────┤
│  🌟 Featured / Collections           │  ← 精选集合 ❌ 不可实现
├─────────────────────────────────────┤
│  📂 Topics                           │
│  ┌──────┐ ┌──────┐ ┌──────┐       │
│  │React │ │Swift │ │Rust  │       │  ← Topic 网格
│  └──────┘ └──────┘ └──────┘       │
├─────────────────────────────────────┤
│     [ Browse all topics ]           │
├─────────────────────────────────────┤
│  🏠    🔔      🧭      🤖           │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
|---|------|------|------|--------|-------------|------|
| 1 | App Bar 左 | ← 返回 | 返回上一页 | ✅ 纯 UI | — | — |
| 2 | App Bar 中 | 标题「Explore」 | 纯展示 | ✅ 纯 UI | — | — |
| 3 | App Bar 右 | 🔍 搜索 | 跳转全局搜索 | ✅ | `search(...)` | — |
| 4 | 搜索栏 | Search Bar | 跳转搜索 | ✅ | 同上 | — |
| 5 | 精选区 | Collection 卡片 | 跳转专题详情 | ❌ | 无公开 API | MVP 隐藏 |
| 6 | Topics 区 | Topic 标签网格 | 跳转 Topic 页 | ✅ | `search(query: "topic:$topic")` | — |
| 7 | 底部入口 | Browse all topics | 跳转 Topics 全列表 | ✅ | 同上 | — |
| 8 | 底部导航 | Explore Tab 选中态 | 导航标识 | ✅ 纯 UI | — | — |

---

## 四、核心 GraphQL 片段

```graphql
query TopicRepositories($topic: String!, $first: Int = 20) {
  search(query: "topic:$topic", type: REPOSITORY, first: $first) {
    repositoryCount
    nodes {
      ... on Repository {
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
|----|------|-------------------|
| Collections 精选集合 | GitHub 官方运营内容，无公开 GraphQL 接口 | MVP 隐藏该区块 |

---

## 六、TDD 验收标准

- [x] 点击 Topic 标签能展示该主题下的仓库列表
- [x] Collections 区块不展示（已隐藏）

---

## 七、备注

- 7/8 可行，Collections 隐藏
- 2026-08-31：Topic 检索经 GraphQL search 实现；Collections 按边界隐藏（模拟器截图验证）
- 2026-08-31 真实数据验收：使用 GitHub PAT（模拟器实测）完成以上勾选项；未实测项见「备注」（详情跳转由 Spec 008/011 接管）
