# Spec 024: Octicons 图标资产引入（官方图标集，横向规范）

> BFS Level: 4
> 关联说明: 用户决策（2026-08-31）— 官方 Octicons 下载嵌入使用；官方彩色插画与非 Octicons 图标待定（后续自研）
> 上游 Spec: 012（横向基建）/ 013（My Work 图标）
> 状态: ✅ implemented（2026-08-31，构建通过 / 模拟器截图验收通过）

---

## 一、页面/功能概述

引入 GitHub 官方图标集 **Octicons**（MIT 许可，Primer 设计系统）作为 ArkCat 的图标资产基座，替换现有页面中用于「App 骨架/系统级符号」的 Unicode 字形与 emoji（返回、搜索、更多、刷新、新建、Tab、My Work 七入口、列表状态图标、计数气泡、筛选漏斗、拖拽手柄等）。着色方式：SVG 纯路径 + ArkUI `Image.fillColor()` 按语义着色（与官方 App 的「Octicons 线框 + 品牌色」做法一致）。**不包含**：官方彩色插画（蓝色 Octocat 空态等）、内容性 emoji（趋势🔥、文档📖、位置📍 等）——这两类留待后续自研（本 Spec 登记为待定项）。

---

## 二、整体 UI 结构

```text
assets/
└── octicons/                          # 上游原始 SVG 归档（v19.33.0）+ LICENSE
    ├── LICENSE                       # MIT（Copyright (c) 2026 GitHub Inc.）
    ├── README.md                     # 来源/版本/下载命令
    └── icons/*.svg                   # 原始文件（未改动）

entry/src/main/resources/base/media/
└── oct_*.svg                         # 生产用 SVG（与原始一致，命名 oct_<name>）

ets/components/OctIcon.ets            # 统一样式入口
# OctIcon({ res: $r('app.media.oct_issue_opened_16'), size: 16, color: '#2DA44E' })

用法约定：Image 由 OctIcon 组件统一包装（size/fillColor/onClick），
禁止页面直接写 Image($r('app.media.oct_*'))（统一收口便于后续自研替换）。
```

---

## 三、元素清单

| # | 位置 | 元素 | 原字形 | Octicons 名称 | 可行性 | 备注 |
| --- | ------ | ------ | -------- | -------------- | -------- | ------ |
| 1 | 全局 | 返回 | `←` | `arrow-left-24` | ✅ | — |
| 2 | 全局 | 更多 | `⋯` | `kebab-horizontal-16` | ✅ | — |
| 3 | 全局 | 搜索 | `🔍` | `search-24` | ✅ | — |
| 4 | Home Header | 刷新 | `🔄` | `sync-16` | ✅ | — |
| 5 | 全局 | 新建 | `＋` | `plus-24` | ✅ | — |
| 6 | Checks 胶囊 | 通过 | `✓` | `check-16` | ✅ | SUCCESS |
| 7 | Checks 胶囊 | 失败/清除 | `✗` / `×` | `x-16` | ✅ | FAILURE/ERROR；搜索清空 |
| 8 | 列表行 | 评论数 | `💬` | `comment-16` | ✅ | — |
| 9 | PR 行 | 审查数 | `👁` | `eye-16` | ✅ | — |
| 10 | 筛选行 | 漏斗徽标 | `≡` | `filter-16` | ✅ | — |
| 11 | Edit My Work | 拖拽手柄 | `⋮` | `grabber-16` | ✅ | v19 已移除 kebab-vertical |
| 12 | My Work/计数 | 已加星 | `★` | `star-fill-16` | ✅ | — |
| 13 | Starred 分组头 | 空星 | `☆` | `star-16` | ✅ | — |
| 14 | My Work/建议 | Issues | `◷` | `issue-opened-16` | ✅ | — |
| 15 | 旧 Issues 列表 | 已关闭 | `🟣` | `issue-closed-16` | ✅ | — |
| 16 | 行状态 | 完成/合并 | `✔` | `check-circle-fill-16` | ✅ | completed/merged |
| 17 | 行状态 | 未计划/关闭 | `⊘` / `✗` | `x-circle-16` | ✅ | not_planned/closed |
| 18 | My Work/建议 | Pull Requests | `⑂` | `git-pull-request-16` | ✅ | — |
| 19 | My Work | Discussions | `❞` | `comment-discussion-16` | ✅ | — |
| 20 | My Work | Projects | `▦` | `project-16` | ✅ | — |
| 21 | My Work/建议 | Top Repos | `▤` | `repo-16` | ✅ | — |
| 22 | My Work/建议 | Organizations | `⌂` | `organization-16` | ✅ | — |
| 23 | 底部 Tab | Home | `🏠` | `home-16` | ✅ | — |
| 24 | 底部 Tab | Inbox | `🔔` | `inbox-16` | ✅ | — |
| 25 | 底部 Tab | Explore | `🧭` | `telescope-16` | ✅ | — |
| 26 | 搜索建议 | Code | `<>` | `code-16` | ✅ | — |
| 27 | 搜索建议 | People | `👤` | `person-16` | ✅ | — |
| 28 | 搜索页 | 代码文件 | `📄` | `file-16` | ✅ | — |

> 可行性比例声明：28/28 可行。

---

## 四、核心 GraphQL 片段

无（纯前端资产，不涉及网络请求）。

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 官方彩色插画（蓝色 Octocat 空态等） | 无公开渠道，版权归 GitHub | 待定自研；当前沿用 🐱/文字占位（spec 017-023 既定处理） |
| 非 Octicons 内容 emoji（🔥 趋势 / 📖 文档 / 📍 位置 / 🔗 链接 / 🗂 空态 / ◯ 头像占位 / ● 语言点） | 内容型符号或需定制 | 待定自研，本批次不改动 |
| `.fillColor()` 对个别 SVG 无效 | 若资源管线着色失败 | 回退方案：脚本按色值生成着色变体（SVG 内嵌 `fill`），命名 `oct_<name>_<color>.svg` |
| 垂直省略号 `kebab-vertical` | v19.33.0 已移除垂直变体 | 拖拽手柄改用 `grabber-16`（官方拖拽图标，样式接近） |
| 品牌徽标（mark-github 等） | GitHub logos 品牌指南约束（原文：Do not use any GitHub logo as the icon or logo for your business/organization） | **不引入，界面不使用官方 logo 图形**。Filter Activity 页 Recommendations 行用中性图标 `oct_graph_stacked_area_16`（官方该行用 mark-github，为避品牌红线有意偏离，详见 spec 056 §七） |

---

## 六、TDD 验收标准

- [x] 测试 1：`devecocli build` 全量构建通过（media SVG 资源管线可用）
- [x] 测试 2：模拟器截图核对——My Work 七入口/底部 Tab/导航图标替换后正常显示、颜色正确
- [x] 测试 3：grep 检查保留清单外无残留系统字形（`← ⋯ 🔍 🔄 ＋ ≡ ⋮` 等 chrome 符号）
- [x] 测试 4：`bash scripts/check-spec.sh` 通过
- [x] 测试 5：i18n key 对齐检查仍通过（本次仅动代码级字形，不涉及字符串）

---

## 七、备注

- 来源：<https://github.com/primer/octicons>（tag v19.33.0，2026-08-04），MIT License（Copyright (c) 2026 GitHub Inc.）；图标清单见 `assets/octicons/README.md`。
- 生产资源放在 `entry/src/main/resources/base/media/`（命名 `oct_<name>_<size>.svg`），与原始文件保持一致，着色全部由 `OctIcon.fillColor` 完成。
- 所有图标默认 `size=16`；头部操作类（返回/搜索/新建）用 24。
- 不新增/修改任何 i18n key（字形为代码内字面量）。
- **内部 `Image` 固定 `.draggable(false)`（2026-09-11）**：`Image` 的 `draggable` 默认为 `true`（官方「拖拽事件」文档），长按图标会被当成「拖出这张图」——在可拖拽列表里会截胡 List 的行拖拽（EditMyWork 的拖拽柄曾因此完全失效）。图标在本项目只作视觉/按钮，全库无「拖出」用法，故统一关闭。

---

## 八、实施记录（2026-08-31）

- 来源：Octicons v19.33.0（全量 743 图标 2026-09-01 归档，含最初 30 个 + zap 等后续补充），原始 SVG 归档 `assets/octicons/`（含 MIT LICENSE）。
- 交互实现约定：OctIcon 为纯视觉组件（无 onClick），可点击图标由调用侧 `Stack() { OctIcon(...) }.onClick(...)` 包装——避免组件内部 onClick 吞掉父级点击（My Work 行点击回归曾因此发生，已修复并实测）。
- 保留项清单（待定自研）：官方彩色插画（🐱 占位）、内容 emoji（🔥📖📍🔗🗂👍 等）、语言点 ●、头像占位 ◯、RepoDetail 文件树/标签图标（▶▸◷⑂▣▤）、Profile 计数图标（▤）。
- 品牌徽标避嫌（2026-09-09）：Filter Activity 页 Recommendations 行由 `oct_mark_github_16` 换为 `oct_graph_stacked_area_16`（官方该行用 mark-github，为避 GitHub 品牌红线有意偏离，见 spec 056 §七）；`oct_mark_github_16.svg` 已从生产资源 `media/` 移除，归档 `assets/octicons/icons/mark-github-*.svg`、`logo-github-*.svg` 仅作上游全量留存，不入 media、不入界面。
