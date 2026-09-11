# Spec 004: Copilot Tab（AI 助手）

> BFS Level: 1
> 关联截图: 底部导航第四个 Tab
> 状态: deprecated（由 Spec 058/059 取代：058 重写本页，059 以 GitHub 官方 chat/completions 实现真实对话与本地会话）

---

## 一、页面/功能概述

GitHub Copilot AI 助手对话页（**已废弃**，由 Spec 058/059 取代）：058 重写 `pages/Copilot.ets`，059 接入真实 chat/completions 与本地会话。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + Copilot Chat 标题 + ✏️ 新对话按钮
2. 问候区：☀️ Good morning! + 用户名（username）
3. 输入框：Ask Copilot... + 📎 附件按钮（← 输入框 ❌）
4. 快捷提示：Quick prompt chips（← 快捷提示 ❌）
5. 底部导航：Home / Inbox / Explore / Copilot

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar 左 | ← 返回 | 导航 | ✅ 纯 UI | — | — |
| 2 | App Bar 中 | 标题「Copilot Chat」 | 展示 | ✅ 纯 UI | — | — |
| 3 | App Bar 右 | ✏️ 新对话 | 新建会话 | ❌ | Copilot 私有 API | — |
| 4 | 问候区 | Good morning + 用户名 | 纯展示 | ✅ 纯 UI | — | — |
| 5 | 输入框 | Ask Copilot + 附件 | 输入问题、发送 | ❌ | 无公开 API | — |
| 6 | 快捷提示 | Quick prompt chips | 点击填入预设问题 | ❌ | 无公开 API | — |
| 7 | 底部导航 | Copilot Tab 选中态 | 导航标识 | ✅ 纯 UI | — | — |

---

## 四、核心 GraphQL 片段

> 本页所有 Chat 功能均由 Copilot 私有 API 驱动，无公开 GraphQL/REST 接口，**无可用片段**。

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 全部 Chat 功能 | GitHub Copilot 对话完全由私有 API 驱动，无公开 GraphQL/REST 接口 | Tab 显示「暂不支持」Empty State 页 |
| 输入框 + 附件 | 依赖 Copilot 私有 API | Empty State |
| Quick prompt chips | 依赖 Copilot 私有 API | Empty State |
| 新对话按钮 | 依赖 Copilot 私有 API | Empty State |

---

## 六、TDD 验收标准

- [x] Copilot Tab 展示 Empty State 页面
- [x] Empty State 说明「此功能需使用 GitHub 官方 App」
- [x] 底部导航 Copilot Tab 正常切换

---

## 七、备注

- 4/7 可行，全部 Chat 功能不可实现
- Empty State 文案：「Copilot 功能暂不支持（无公开 API），请使用 GitHub 官方 App」
- 2026-08-31：Empty State、说明文案、Tab 切换三项 TDD 均在模拟器验收通过
- 2026-08-31 真实数据验收：使用 GitHub PAT（模拟器实测）完成以上勾选项；未实测项见「备注」（详情跳转由 Spec 030/031 接管）
