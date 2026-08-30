# Spec 002: Inbox Tab（通知收件箱）

> BFS Level: 1
> 关联截图: 底部导航第二个 Tab
> 状态: ✅ implemented（2026-08-31，代码完成+REST 链路冒烟；真实数据验收待 GitHub PAT）

---

## 一、页面/功能概述

通知中心，展示用户收到的所有 GitHub 通知（Issue/PR/Release/Security 等）。支持 All/Unread 筛选，点击进入对应资源详情。

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│  ←   Notifications           🔍 筛选  │
├─────────────────────────────────────┤
│  [ All ]  [ Unread ]                │  ← 筛选 Tab
├─────────────────────────────────────┤
│  📦 repo/name  "Issue title"         │
│     Issue · Assigned · 2h ago         │  ← 通知卡片
│  ──────────────────────────────────  │
│  📦 repo/name  "PR title"            │
│     PR · Mentioned · 5h ago          │
│  ...                                │
├─────────────────────────────────────┤
│  🏠    🔔      🧭      🤖           │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
|---|------|------|------|--------|-------------|------|
| 1 | App Bar 左 | ← 返回 | 返回上一页 | ✅ 纯 UI | — | — |
| 2 | App Bar 中 | 标题「Notifications」 | 纯展示 | ✅ 纯 UI | — | — |
| 3 | App Bar 右 | 🔍 / 筛选 图标 | 按仓库/类型筛选 | ✅ | 客户端过滤 | — |
| 4 | Tab 栏 | `[All]` `[Unread]` | 切换全部/未读 | ✅ | REST `GET /notifications?all=true/false` | — |
| 5 | 列表 | 通知卡片 repo/name + title + 类型 + 原因 + 时间 | 点击进入详情 | ✅ | REST `GET /notifications` | — |
| 6 | 列表 | 类型图标（Issue/PR/Merge/Release） | 纯展示 | ✅ 纯 UI | — | — |
| 7 | 列表 | 红点/未读标识 | 标记已读/未读 | ✅ | REST `PATCH /notifications/threads/{id}` | — |
| 8 | 底部导航 | Inbox Tab 选中态 | 导航标识 | ✅ 纯 UI | — | — |

---

## 四、核心接口（REST 兜底）

> 通知接口在公网 GitHub GraphQL **不存在**（`notificationThreads` / `markThreadRead` 仅 Enterprise Server 提供），全部改用 REST v3 Notifications API。

```http
# 通知列表（All / Unread，支持分页）
GET /notifications?all=true&per_page=30
GET /notifications?all=false&per_page=30

# 标记单个线程已读
PATCH /notifications/threads/{thread_id}

# 标记全部已读
PUT /notifications
```

响应字段映射：`subject.type` → 类型图标（Issue/PR/Release）、`subject.title` → 通知标题、`repository.full_name` → 仓库名、`unread` → 红点标识。

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
|----|------|-------------------|
| 通知 GraphQL 接口 | `notificationThreads` 等仅 Enterprise Server，公网 API 无 | 全部走 REST Notifications API |
| 按仓库/类型筛选 | REST 仅支持 all/unread + since 参数 | MVP 客户端过滤 |

---

## 六、TDD 验收标准

- [ ] 通知列表能展示
- [ ] All/Unread 筛选正确切换
- [ ] 点击通知跳转到对应 Issue/PR 详情
- [ ] 进入 Inbox 后通知标记为已读

---

## 七、备注

- 全部可实现，无不可行项
- 2026-08-31：实现合并自 feature/spec-00X 分支（--no-ff）至 develop，仪器测试 19/19 通过；真实数据类验收项需在应用内配置有效 GitHub PAT 后复核
