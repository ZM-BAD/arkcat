# Spec 032: 通知设置页（Settings → Notifications）

> BFS Level: 4
> 关联截图: GitHub 官方 App Notifications 设置页（Android 截图，用户提供 2026-09-01）
> 上游 Spec: 014（Settings）
> 状态: implemented（2026-09-01，构建通过 / 模拟器冒烟 + 持久化验证通过）

---

## 一、页面/功能概述

Settings 页「Notification Options」行点击进入的通知设置二级页。含四区块：General（Working hours）、Push Notifications Types（6 开关）、Live notifications（2 开关）、Swipe Options（左/右滑动作选择 + 骨架预览）。纯本地偏好设置，无网络请求，所有状态经 preferences 持久化。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + 「Notifications」标题
2. General 组：Working hours 行 + 状态 Off
3. Push Notifications Types 组（6 个开关行）：Direct Mentions（开）、Review Requested（关）、Assigned（关）、Deployment Review（关）、Pull Request Review（关）、Workflow Runs（关）
4. Live notifications 组（2 个开关行，默认开）：Cloud Agent Updates、Remote Session Updates
5. Swipe Options 组：左滑动作行（Left swipe · Mark as done · CHANGE）+ 左滑预览卡（骨架 ░░ ░░░ + 绿色动作块 ▣）
6. Swipe Options 组：右滑动作行（Right swipe · Unsubscribe · CHANGE）+ 右滑预览卡（灰色·铃铛动作块 ▣ + 骨架 ░░ ░░░）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar | ← 返回 + Notifications 标题 | 导航 | ✅ | —（纯 UI） | 自绘头部，hideTitleBar |
| 2 | General | Working hours 行 + Off | 展示 | ✅ | — | 静态值，点击不响应 |
| 3 | General | System Options（齿轮 + Android 提示） | — | ✅ | — | **用户指令整行略过**，不渲染 |
| 4 | Push Types | 组标题 | 展示 | ✅ | —（纯 UI） | — |
| 5 | Push Types | 6 开关行（Direct Mentions 默认开，其余关） | 本地持久化 | ✅ | — | preferences |
| 6 | Live | 组标题 | 展示 | ✅ | —（纯 UI） | — |
| 7 | Live | Cloud Agent Updates 开关（默认开） | 本地持久化 | ✅ | — | — |
| 8 | Live | Remote Session Updates 开关（默认开） | 本地持久化 | ✅ | — | — |
| 9 | Swipe | 左滑动作行（Mark as done，默认）+ CHANGE | 选择动作 + 持久化 | ✅ | — | ActionMenu 二选一 |
| 10 | Swipe | 右滑动作行（Unsubscribe，默认）+ CHANGE | 选择动作 + 持久化 | ✅ | — | ActionMenu 二选一 |
| 11 | Swipe | 左滑预览卡（骨架 + 绿色动作块） | 展示 | ✅ | —（纯 UI） | 跟随 9 的选择 |
| 12 | Swipe | 右滑预览卡（骨架 + 灰色铃铛动作块） | 展示 | ✅ | —（纯 UI） | 跟随 10 的选择 |

> 可行性比例声明：12/12 可行。

---

## 四、核心接口

无 GraphQL 接口——本页为纯本地偏好设置，数据全部经 `preferences`（`arkcat_settings`）持久化，键前缀 `notif_`：

```text
notif_direct_mentions / notif_review_requested / notif_assigned /
notif_deployment_review / notif_pull_request_review / notif_workflow_runs
（boolean，默认 false，仅 Direct Mentions true）

notif_cloud_agent / notif_remote_session（boolean，默认 true）
notif_left_swipe / notif_right_swipe（'done' | 'unsubscribe'，默认 'done' / 'unsubscribe'）
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| System Options（Android 阻塞提示 + 齿轮） | 用户指令：Android 专属文案不抄 | 整行略过，不渲染 |
| Live notifications 的「require Android 16 or later」说明 | 用户指令：Android 专属文案不抄 | 说明行略过，保留开关行 |
| Working hours 点击编辑 | 参考截图未提供交互 | 静态展示 Off |
| 推送开关真实生效（系统推送） | 鸿蒙推送通道未接入 | 仅本地偏好存储，不真实推送 |
| 左/右滑动作对 Inbox 列表的真实生效 | 本轮范围外（后续批次） | 仅设置页选择 + 持久化 |

---

## 六、TDD 验收标准

- [ ] 测试 1：默认值正确——Direct Mentions / Cloud Agent / Remote Session 开，其余推送类型关；左滑 Mark as done、右滑 Unsubscribe
- [ ] 测试 2：切换任一开关后 preferences 值同步；退出页面重进保持
- [ ] 测试 3：CHANGE 弹 ActionMenu 二选一，选中后行值文本 + 预览动作块更新并持久化
- [ ] 测试 4：模拟器实测：四区块分区与骨架预览样式与截图对齐；System Options 与 Android 文案不出现
- [ ] 测试 5：grep 页面无中文字符串字面量；check-spec.sh 通过

---

## 七、备注

- 开关用原生 `Toggle`（ToggleType.Switch），CHANGE 用 `showActionMenu`，预览卡为静态组合组件（skeleton 灰条 + 动作块）。
- 动作块图标：Mark as done = 绿底白勾（复用 `oct_check_16`）；Unsubscribe = 灰块 `oct_bell_slash_16`（**新增官方 octicon 资产**，随本 Spec 引入）。
- 二级页头部沿用已验证方案：`NavDestination.hideTitleBar(true)` + 不设 `.title()` + 页内自绘返回/标题，避免双标题双返回。
- i18n：新增约 20 key，base（英）与 zh_CN（简中）成对补齐。
