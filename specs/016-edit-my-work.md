# Spec 016: Edit My Work（Home 工作区条目编辑页）

> BFS Level: 3
> 关联截图: GitHub 官方 App「Edit My Work」页（用户提供，2026-08-31）
> 上游 Spec: 013
> 状态: ✅ implemented（2026-08-31，构建通过 / 仪器测试 29/29 / 模拟器验收通过）

---

## 一、页面/功能概述

Home Tab「My Work」区块的编辑页（入口：My Work 标题右侧 ⋯）。用户通过复选框控制七个条目（Issues / Pull Requests / Discussions / Projects / Top Repositories / Organizations / Starred）在 Home 的显示/隐藏，长按整行拖拽调整顺序；点击 SAVE 将配置持久化（Preferences），返回 Home 后按新配置渲染 My Work 区块。纯客户端页面，无网络请求。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + Edit My Work 标题 + SAVE 按钮 + ⋯ 更多菜单（← App Bar：返回/标题/保存/更多）
2. 条目列表：七行，每行 = ☑/▢ 复选框 + 彩色图标 + 标签 + ⋮⋮ 拖拽柄（← 复选框 + 彩色图标 + 标签 + 拖拽柄）
   - Issues / Pull Requests / Discussions / Projects / Top Repositories / Organizations / Starred
3. 底部空白区

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar 左 | ← 返回 | 放弃未保存变更并返回 | ✅ | —（纯 UI） | 未点 SAVE 的修改不落盘 |
| 2 | App Bar 中 | 「Edit My Work」标题 | 页面标题 | ✅ | —（纯 UI） | — |
| 3 | App Bar 右 | SAVE 按钮 | 持久化配置 + 返回 | ✅ | —（纯 UI） | Preferences `work_sections_v1` |
| 4 | App Bar 右 | ⋯ 更多 | 预留菜单 | ✅ | —（纯 UI） | 点击提示后续 Spec |
| 5 | 行左 | 复选框 | 切换条目在 Home 显示 | ✅ | —（纯 UI） | — |
| 6 | 行中 | 彩色图标 + 标签 | 条目标识 | ✅ | —（纯 UI） | 色系/图标复用 Home 013 |
| 7 | 行右 | ⋮⋮ 拖拽柄 | 长按拖拽排序 | ✅ | —（纯 UI） | List onItemDragStart/Drop |
| 8 | 行本体 | 整行可拖拽 | 排序交互 | ✅ | —（纯 UI） | — |

> 可行性比例声明：8/8 可行。

---

## 四、核心 GraphQL 片段

无（纯客户端功能，不涉及网络请求）。

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 官方 App 行内 ⋯ 菜单（Move up/down/Remove） | 与复选框 + 拖拽语义重复 | 不重复提供；拖拽即移动，复选框即显隐 |
| 拖拽动画观感 | 原生 List 拖拽无 iOS 式弹性动画 | 用 List onItemDragStart/onItemDrop 原生拖拽，不做自绘动画（体验级复刻） |
| 全部取消勾选 | 允许态 | Home 仍显示 My Work 标题 + ⋯ 入口，区块内容区为空（可随时回来恢复） |

---

## 六、TDD 验收标准

- [x] 测试 1：`visibleWorkSections` 纯函数：按显隐过滤 + 顺序正确，全取消返回空数组
- [x] 测试 2：`workSectionsToStorage`/`workSectionsFromStorage` 序列化往返一致、坏数据回退默认配置
- [x] 测试 3：模拟器实测 — 取消 Starred 后 SAVE，Home 不再显示 Starred 入口；重新勾选恢复
- [ ] 测试 4：模拟器实测 — 拖拽将 Starred 移到首位并 SAVE，Home 顺序随之变化
- [x] 测试 5：grep 检查 EditMyWork.ets 无中文字符串字面量残留（i18n 约定）
- [x] 测试 6：`bash scripts/check-spec.sh` 通过
- [x] 测试 7：`devecocli build` 全量构建通过

---

## 七、备注

- 配置存储：`@ohos.data.preferences`，文件名 `work_prefs`，key `work_sections_v1`，值为 JSON 数组 `[{ "id": "issues", "visible": true }, ...]`（顺序即数组顺序）。
- 默认配置：七项全勾选，顺序与 013 一致（Issues → Pull Requests → Discussions → Projects → Top Repositories → Organizations → Starred）。
- 配置为全局单例（@ObservedV2 + @Trace），Home 与编辑页共享同一实例，SAVE 后 Home 立即反映，无需手动刷新。
- 拖拽实现：`List` + `ListItem` + `onItemDragStart`（返回行卡片 Builder）+ `onItemDrop`（移动数组元素）。

- 模拟器实测：勾选/取消 + SAVE 持久化 + Home 实时刷新通过（uitest 无法模拟长按拖拽，拖拽排序仅代码完成，待人工复验）。
