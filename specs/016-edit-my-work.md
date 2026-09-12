# Spec 016: Edit My Work（Home 工作区条目编辑页）

> BFS Level: 3
> 关联截图: GitHub 官方 App「Edit My Work」页（用户提供，2026-08-31）
> 上游 Spec: 013
> 状态: ✅ implemented（2026-08-31 首版；2026-09-11 增补重排模式 ▲▼ 与蓝色竖点菜单）

---

## 一、页面/功能概述

Home Tab「My Work」区块的编辑页（入口：My Work 标题右侧 ⋯）。用户通过复选框控制七个条目（Issues / Pull Requests / Discussions / Projects / Top Repositories / Organizations / Starred）在 Home 的显示/隐藏，点击 SAVE 将配置（含顺序）持久化（Preferences），返回 Home 后按新配置渲染 My Work 区块。纯客户端页面，无网络请求。

改顺序有两种方式，分模式使用：

- **常态**：按住行右六个点（拖拽柄）拖动排序；
- **重排模式**：点 App Bar 右侧蓝色竖点 ⋮ → 菜单选 Show reorder actions，每行右侧出现 ▲ ▼ 逐格移动；再选 Hide reorder actions 退出。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + 「Edit My Work」标题 + SAVE 按钮 + 蓝色竖点 ⋮（重排菜单）
2. 条目列表：七行，每行 = 复选框 + 彩色图标 + 标签 + 行右控件（随模式二选一）
   - 常态：行右 = 六个点拖拽柄
   - 重排模式：行右 = ▲ + ▼（逐格上/下移；首行 ▲ 与末行 ▼ 置灰不可点）
   - Issues / Pull Requests / Discussions / Projects / Top Repositories / Organizations / Starred
3. 底部空白区

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar 左 | ← 返回 | 放弃未保存变更并返回 | ✅ | —（纯 UI） | 未点 SAVE 的修改不落盘 |
| 2 | App Bar 中 | 「Edit My Work」标题 | 页面标题 | ✅ | —（纯 UI） | — |
| 3 | App Bar 右 | SAVE 按钮 | 持久化配置 + 返回 | ✅ | —（纯 UI） | Preferences `work_sections_v1`（含顺序） |
| 4 | App Bar 右 | 蓝色竖点 ⋮ | 打开重排菜单 | ✅ | —（纯 UI） | 竖三点走全库惯例：`oct_kebab_horizontal_16` 旋转 90°，取 `link_blue` |
| 5 | 菜单项 | Show / Hide reorder actions | 切换重排模式 | ✅ | —（纯 UI） | 单条菜单项，标签随当前模式取反（同一时刻只出现其一） |
| 6 | 行左 | 复选框 | 切换条目在 Home 显示 | ✅ | —（纯 UI） | — |
| 7 | 行中 | 彩色图标 + 标签 | 条目标识 | ✅ | —（纯 UI） | 色系/图标复用 Home 013（Top Repos 用 work_dark_bg 令牌） |
| 8 | 行右（常态） | 六个点拖拽柄 | 长按拖拽排序 | ✅ | —（纯 UI） | 重排模式下不显示，让位给 ▲▼；六个点仅为视觉提示——长按**整行任意位置**均可起拖（见第七章） |
| 9 | 行右（重排模式） | ▲ 上移 | 与上一行交换位置 | ✅ | —（纯 UI） | 可点 `text_primary`（黑）、首行置灰不可点（`text_tertiary`） |
| 10 | 行右（重排模式） | ▼ 下移 | 与下一行交换位置 | ✅ | —（纯 UI） | 可点 `text_primary`（黑）、末行置灰不可点（`text_tertiary`） |
| 11 | 行本体 | 整行可拖拽 | 排序交互 | ✅ | —（纯 UI） | 常态长按整行拖动，落位由 ForEach.onMove 回调 |

> 可行性比例声明：11/11 可行。

---

## 四、核心 GraphQL 片段

无（纯客户端功能，不涉及网络请求）。

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 首行 ▲ / 末行 ▼ | 该方向无处可移 | 置灰（`text_tertiary`）且点击不生效；不做循环回绕 |
| 拖拽与 ▲▼ 并存 | 两种改序方式同屏会争抢行右触区 | 分模式渲染：重排模式只出 ▲▼，常态只出拖拽柄 |
| 拖拽动画观感 | 原生拖拽无 iOS 式弹性动画 | 走 `ForEach.onMove`（自带落位动画与拖到边缘的自动滚动），不做自绘动画（体验级复刻） |
| 全部取消勾选 | 允许态 | Home 仍显示 My Work 标题 + ⋯ 入口，区块内容区为空（可随时回来恢复） |

---

## 六、TDD 验收标准

- [x] 测试 1：`visibleWorkSections` 纯函数：按显隐过滤 + 顺序正确，全取消返回空数组
- [x] 测试 2：`workSectionsToStorage`/`workSectionsFromStorage` 序列化往返一致、坏数据回退默认配置
- [x] 测试 3：`moveWorkSection` 纯函数：中间行上移/下移位置正确；首行上移、末行下移、越界索引均原样返回（不改动入参）
- [x] 测试 4：模拟器实测 — 取消 Starred 后 SAVE，Home 不再显示 Starred 入口；重新勾选恢复
- [x] 测试 5：模拟器实测 — 点蓝色竖点 → Show reorder actions，每行右侧出现 ▲▼；再点 → 菜单变 Hide reorder actions，▲▼ 消失
- [x] 测试 6：模拟器实测 — 点 ▲▼ 调整顺序并 SAVE，Home 顺序随之变化；首行 ▲ 与末行 ▼ 置灰点不动
- [x] 测试 7：模拟器实测 — 常态下按住六个点拖拽排序生效（六个点／彩色图标／标签／复选框四区均可起拖；重排模式不提供拖拽柄）
- [x] 测试 8：grep 检查 EditMyWork.ets 无中文字符串字面量残留（i18n 约定）
- [x] 测试 9：`bash scripts/check-spec.sh` 通过
- [x] 测试 10：`devecocli build` 全量构建通过

---

## 七、备注

- 配置存储：`@ohos.data.preferences`，文件名 `work_prefs`，key `work_sections_v1`，值为 JSON 数组 `[{ "id": "issues", "visible": true }, ...]`（顺序即数组顺序）。
- 默认配置：七项全勾选，顺序与 013 一致（Issues → Pull Requests → Discussions → Projects → Top Repositories → Organizations → Starred）。
- 配置为全局单例（@ObservedV2 + @Trace），Home 与编辑页共享同一实例，SAVE 后 Home 立即反映，无需手动刷新。
- 拖拽实现：`List` + `ForEach.onMove(from, to)`（API 12+，官方推荐的拖拽排序路径）——离手后按上报的 from/to 改数据源落位，自带落位动画与边缘自动滚动。**不用 List 的 `onItemDragStart`/`onItemDrop` 组合**：其 `onItemDrop(event, itemIndex, insertIndex, isSuccess)` 第 2 参是**拖拽起点**、第 3 参才是**插入位**，把第 2 参当目标位会退化成 `move(from, from)` 的空操作，表现为「能拖起、松手不回位」。
- 重排菜单实现：`bindMenu` 的数组**不随状态刷新**（V2 坑，与 Profile 的 Follow 菜单同源）→ 菜单项由 `@Local` 持有，切换模式时显式重建。
- 排序逻辑：抽为 `utils/WorkConfig.ets` 的纯函数 `moveWorkSection(sections, from, to)`（越界原样返回），页面 ▲▼ 与拖拽共用同一函数，宿主单测覆盖。
- 图标：`chevron-up` 本批进 media（`oct_chevron_up_16.svg`，源自 `assets/octicons/icons/chevron-up-16.svg`）；`chevron-down` 复用既有 `oct_chevron_down_16.svg`；拖拽柄沿用 `oct_grabber_16.svg`。
- i18n：`edit_work_show_reorder` / `edit_work_hide_reorder` / `a11y_move_up` / `a11y_move_down`，base + zh_CN 双份。
- 拖拽起拖点（2026-09-11 用户拍板「保持现状」）：**长按整行任意位置均可起拖**——拖拽由 `ForEach.onMove` 绑定在行这一级，六个点只是视觉提示、本身无手势。九点实测（行最左内边距 60 / 复选框 150 / 图标与标签间 250 / 彩色图标 321 / 标签中段 700 / 标签右侧空白 1050 / 六个点 1112 / 行最右边缘 1200 / 标签左段 600）全部可起拖；单击行为不变（点复选框=切换勾选、点行体无响应），起拖需长按 ≥500ms 故不误触。
  - **不做「仅六个点可拖」的收敛**：那要放弃 `onMove`，改用统一拖拽 API 在抓柄挂 `onDragStart`、各行挂 `onDrop`，并自行实现落位动画与拖到边缘的自动滚动（现为 `onMove` 白送）。现状是官方行为的超集，视觉无差别。
  - 前提：图标须关掉 `Image` 的默认拖出能力——`OctIcon` 内部已统一加 `.draggable(false)`（官方「拖拽事件」文档：Image/Text 等组件 `draggable` 默认为 `true`；见 Spec 024 §七），否则长按图标会被当成「拖出这张图」，行拖拽永远起不来（拖拽柄区曾因此完全失效）。
- 模拟器实测：勾选/取消 + SAVE 持久化 + Home 实时刷新通过；拖拽排序与重排模式 ▲▼ 的交互验证见第六章已勾项（长按拖拽用 `hdc shell uinput -T -g x1 y1 x2 y2 <按住ms> <总ms>` 注入，按住须 ≥500ms）。
