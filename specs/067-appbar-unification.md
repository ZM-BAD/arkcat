# Spec 067: 统一 App Bar 组件

> BFS Level: 2
> 关联截图: 官方 App 各二级页/Tab 页顶栏（无单独截图，参数以官方通用规格为准）
> 上游 Spec: 062（二级页顶栏图标口径）、039（Primer 设计系统）
> 状态: implemented

---

## 一、页面/功能概述

全库顶栏（App Bar）此前由各页面自绘、无共享组件，经 2026-09-13 全量扫描发现严重不统一：左侧视觉内边距有 12/16 两种，右侧有 0/12/13/16/26/28~29 六种，行高有 44/48/52/56/60/64 六种，右侧图标间距有 12~42 四种写法，动作图标尺寸 18/20 混用。

本 Spec 建立共享组件 `components/AppBar.ets`，将顶栏骨架、边距、中心距、行高、图标尺寸全部收敛为官方 App 口径，并把存量页面逐页迁移。属于纯 UI 结构重构，不涉及任何数据与交互逻辑变化。

---

## 二、整体 UI 结构

1. 顶栏（`AppBar` 组件，单一行结构）：
   - 返回键（可选）：44×44 触控区，内含 20vp `oct_arrow_left_24`，色 `text_primary`
   - 标题区（可选）：主标题（`title_font_size`、600、`text_primary`）；副标题可选（两行型）
   - 动作图标 ×N（可选）：44×44 触控区，内含 20vp 图标，默认色 `link_blue`
2. 统一位置参数（全部收敛进组件，页面不可覆写）：
   - 行高 48；行 padding 左右 4
   - 触控区顶满行缘，44 触控区 + 20vp 图标居中 → **左右视觉内边距 = 16**
   - 相邻动作图标中心距 = 44（触控区相邻、Row space 0）→ **视觉缝 = 24**
   - 无返回键时标题区补 12 内距，标题左缘对齐 16
   - 副标题两行型仍用行高 48（主/副标题纵向紧凑排列）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | 顶栏 | 返回键（可选） | pop 路由，onBack 回调由页面传入 | ✅ | 无 | 触控区 44，a11y=a11y_back |
| 2 | 顶栏 | 主标题 | layoutWeight(1) 自适应，单行省略 | ✅ | 无 | 支持 ResourceStr 动态更新 |
| 3 | 顶栏 | 副标题（可选） | 两行型：默认主下副上可配（Profile 上小下大） | ✅ | 无 | subtitleAbove 参数 |
| 4 | 顶栏 | 动作图标 ×N | onClick；支持 rotate90（竖三点）、bindMenu（MenuElement[]） | ✅ | 无 | 默认 20vp/link_blue，逐项可覆盖 |
| 5 | 顶栏 | 无障碍 | 每个触控区 accessibilityDescription + focusable | ✅ | 无 | a11y 参数逐项传入 |

> 可行性图例：✅ 可直接实现 ｜ ⚠️ 部分可行/降级 ｜ ❌ 不可实现

---

## 四、核心 GraphQL 片段

本 Spec 为纯 UI 结构重构，不涉及任何 GraphQL 查询或变更。

---

## 五、边界 / 不可行项

> 列出所有 ⚠️ 和 ❌ 项的处理方式（跳过、降级、Empty State 等）。

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ---- | --------------- |
| 内联搜索头部（Search / SearchOverview / SearchResults / Discussions） | 标题区是运行时切换的 TextInput，不适合进通用组件 | 保留自绘头部，但按第二节统一数值对齐（行高 48、行 padding 4、触控区 44、Row space 0 → 中心距 44） |
| 搜索态切换头部（IssuesList / Projects / WorkIssues / WorkPrs / StarredRepositories / Forks 的 inSearch 分支） | 同上，标题↔TextInput 运行时切换 | 保留自绘头部，按统一数值对齐 |
| 文字动作头部（Accounts 的 EDIT/DONE、CreateList 的 SAVE/NEW、EditMyWork 的 SAVE、FilterActivity 的 SAVE） | 动作是文字按钮非图标 | 保留自绘头部，按统一数值对齐 |
| PrFiles 顶栏 | 标题行混排 +additions/−deletions 统计 Span，AppBar 无此槽位 | 保留自绘头部，按统一数值对齐 |
| Profile 顶栏 | 返回键条件渲染 + 两行标题（上小下大）+ 本人/他人动作分流 + ⋯ 菜单数组须随状态重建（V2 bindMenu 坑，review D6） | 保留自绘头部，按统一数值对齐（行 padding 4、无返回时标题 margin 12） |
| AchievementDetail 顶栏 | 全幅主题横幅页，关闭钮叠在横幅上、白色图标 | 保留自绘（spec 052 已定义），不迁移 |
| Explore 顶部 | 仅为标题 Text，无操作栏结构 | 不动 |
| TokenSetup | 引导流程页，无标准顶栏 | 不动 |

---

## 六、TDD 验收标准

- [x] `devecocli build` 通过，无新增 lint 告警
- [ ] 模拟器走查：任意二级页返回键图标与标题左缘均对齐 16
- [ ] 模拟器走查：右侧图标距右缘 16，相邻图标中心距 44（视觉缝 24）
- [ ] bindMenu 页面（Inbox / FileTree / CodeViewer / ListDetail / RepoPrs 等）菜单正常弹出
- [ ] 两行标题页（Stargazers / OrgList / RepoPrs 等）标题不截断、动态标题（异步加载）正常刷新
- [ ] 无返回键页（OrgProfile / RepoDetail / Home / Inbox）标题/动作左缘 16
- [x] 宿主单测无回归（node:test 82 条全过）

---

## 七、备注

1. **官方口径依据**：官方 App 顶栏为紧凑单行（约 48vp），左右内容内边距 16，动作图标触控区约 44、相邻中心距约 44（视觉缝 24）；此前我们的 32~42 视觉缝明显偏松，CodeViewer/FileTree 图标顶边属于实现疏漏。
2. **组件设计**：页面全部为 V1 `@Component`，AppBar 亦用 V1：`@Prop` 同步标题/副标题/动作数组（Stargazers、Profile 等异步标题可正常刷新）；动作项为 `AppBarAction` 类（icon/iconSize/iconColor/rotate90/a11y/menu/onAction）。
3. **迁移范围**：静态头部页全量迁入 AppBar；第五节所列保留自绘页仅对齐数值，不迁组件。
4. **图标尺寸收敛**：动作图标统一 20vp（原 18 的页面放大到 20），返回键 20vp 不变；OctIcon 资源文件不变。
5. 原 44 触控区内 `.padding(6)` 对 18/20 图标居中结果无实际作用（历史杂音），迁移后统一去除。
