# Spec 002: Inbox Tab（通知收件箱）

> BFS Level: 1
> 关联截图: 官方 App Inbox（Inbox▾/Focused/Unread/Repository▾ 四筛选 + 卡片样式）
> 状态: implemented（2026-08-31，官方布局对齐验收通过）

---

## 一、页面/功能概述

通知中心，展示所有 GitHub 通知（Issue/PR/Release/Security 等）。对照官方 App 布局：

- **标题**：Inbox + ⋯ 菜单入口
- **筛选行**：`Inbox▾` `Focused` `Unread` `Repository▾` 四个 pill（可点击/下拉）
- **列表**：通知卡片 = 仓库名+编号行 → 标题(粗) → 类型图标+摘要行，右侧相对时间

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│  Inbox                          ⋯   │  ← 标题+菜单
├─────────────────────────────────────┤
│  [Inbox▾] [Focused] [Unread] [Repo▾] │  ← 四个筛选 pill
├─────────────────────────────────────┤
│  ZM-BAD / DAG-chat #82          11h  │
│  fix(backend): use $addToSet...     │
│  ● Merged #82 into main.            │  ← 卡片(状态图标+摘要)
│  ────────────────────────────────── │
│  ZM-BAD / headroom #5           5d  │
│  chore(deps): update ...            │
│  ● @renovate[bot] pushed 1 commit.  │
│  ...                                │
├─────────────────────────────────────┤
│  🏠    🔔      🧭      🤖           │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | 标题行 | Inbox 标题 | 纯展示 | ✅ 纯 UI | — | — |
| 2 | 标题行右 | ⋯ 菜单 | 后续 Spec 提供 | ⚠️ | — | 点击提示 |
| 3 | 筛选行 | Inbox▾ pill | 全部通知 | ✅ | REST `GET /notifications?all=true&per_page=30` | — |
| 4 | 筛选行 | Focused pill | 参与类高价值通知 | ✅ | REST `GET /notifications?participating=true&per_page=30` | 官方 Focused 语义近似 participating |
| 5 | 筛选行 | Unread pill | 仅未读 | ✅ | REST `GET /notifications?all=false&per_page=30` | — |
| 6 | 筛选行 | Repository▾ pill | 按仓库过滤 | ✅ | 客户端过滤 | 下拉列出会话仓库 |
| 7 | 卡片行1 | 仓库全名 · #编号 | 纯展示 | ✅ | `repository.full_name` + `subject.url` 提取 | 编号纯函数 |
| 8 | 卡片行2 | 通知标题 | 纯展示 | ✅ | `subject.title` | 加粗，最多 2 行 |
| 9 | 卡片行3 | 类型图标+摘要 | 类型展示 | ⚠️ | `subject.type` | 官方摘要(操作者)无公开 API，降级为类型+reason |
| 10 | 卡片右 | 相对时间 | 纯展示 | ✅ | `updated_at` | timeParts |
| 11 | 卡片左 | 未读绿圈 | 未读标识 | ✅ | `unread` | — |
| 12 | 点击卡片 | 标记已读+进详情 | 交互 | ⚠️ | REST `PATCH /notifications/threads/{id}` | 详情页后续 Spec |

---

## 四、核心接口（REST 兜底）

> 通知接口在公网 GitHub GraphQL **不存在**，全部用 REST v3 Notifications API。

```http
# 全部 / 参与 / 未读
GET /notifications?all=true&per_page=30
GET /notifications?participating=true&per_page=30
GET /notifications?all=false&per_page=30

# 标记单个线程已读
PATCH /notifications/threads/{thread_id}
```

字段映射：`repository.full_name` → 仓库行；`subject.title` → 标题；`subject.type` → 类型图标；`subject.url` → 提取 `#编号`（`/issues/123`、`/pull/123` 等）；`unread` → 绿圈；`updated_at` → 相对时间。

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 官方摘要行（"Merged #82 into main"） | 需 per-thread 事件 API，无公开接口 | 降级：类型图标 + reason 文案 |
| Focused 语义 | 官方为通知分级，REST 无对应字段 | 用 `participating=true` 近似 |
| Repository 下拉远程选项 | 通知列表仅能拿到会话中出现过的仓库 | 从当前列表提取去重仓库下拉 |

---

## 六、TDD 验收标准

- [x] 四个筛选 pill（Inbox/Focused/Unread/Repository）切换正确：REST 参数/客户端过滤验证
- [x] 卡片呈现仓库名+编号、标题粗体、类型图标、相对时间
- [x] 未读绿圈与已读状态正确
- [x] base/zh_CN 新增 key 对齐；ohosTest 21/21 通过
- [x] 模拟器截图验收：四筛选 + 卡片样式与官方对齐

---

## 七、备注

- 全部走 REST Notifications API；编号提取纯函数 `issueNumberFromUrl` 位于 GitHubModels（可单测）
- 2026-08-31：官方布局对齐完成，截图验收通过
