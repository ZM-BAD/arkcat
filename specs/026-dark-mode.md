# Spec 026: 暗黑模式（三态主题：跟随系统 / 浅色 / 深色，横向规范）

> BFS Level: 4
> 关联截图: GitHub 官方 App 深色模式 6 张（仓库二级页，用户提供 2026-08-31）
> 上游 Spec: 014（Settings）/ 024（Octicons 图标着色）
> 状态: ✅ implemented（2026-08-31，构建通过 / 仪器测试 30/30 / 模拟器双主题验收通过）

---

## 一、页面/功能概述

为用户提供主题三态：**跟随系统（默认）/ 浅色 / 深色**，入口在 Settings → Theme。实现路径：① 颜色全部语义化进 `color.json`（base=浅色，`resources/dark/element/color.json` = 深色覆盖，系统自动按 colorMode 解析）；② 三态持久化（`starraft_settings`，已有 `theme_mode` key）并调用 `ApplicationContext.setColorMode(ColorMode)` 应用；③ 全部页面/组件消除页面内硬编码色值（迁移 19 个文件约 90 处）；④ 深色配色以官方 App 深色截图为准（背景近似 `#010409`、卡片 `#0D1117`、边框 `#30363D` 基调）。本批次同时完成仓库二级页面（Spec 027-031），其新页面直接按语义色编写。

---

## 二、整体 UI 结构

```text
resources/
├── base/element/color.json          # 浅色值（语义 token，约 34 个）
└── dark/element/color.json          # 深色覆盖（同名 token，系统自动切换）

Settings → Theme → [跟随系统] [浅色] [深色]（单选，默认跟随系统）

启动链路：Index.aboutToAppear → 读 preferences('theme_mode') →
          applicationContext.setColorMode(ColorMode.LIGHT/DARK/COLOR_MODE_NOT_SET)
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
|---|------|------|------|--------|------|------|
| 1 | Settings | Theme 三态单选 | 主题切换 | ✅ | `setColorMode` + preferences | 默认跟随系统 |
| 2 | 启动 | 主题恢复 | 重启保持 | ✅ | preferences | 读 `theme_mode` |
| 3 | 资源 | dark/element/color.json | 深色覆盖 | ✅ | 资源限定目录 | 与 base 同名 token |
| 4 | 全页面 | 语义色 token 迁移 | 浅深通用 | ✅ | color 资源 | 19 文件约 90 处硬编码 |
| 5 | 配色基准 | 官方深色基调 | 视觉对齐 | ✅ | — | 背景 #010409 系 |
| 6 | OctIcon | fillColor 走 token | 图标适色 | ✅ | color 资源 | text_primary/secondary 自动适配 |

> 可行性比例声明：6/6 可行。

---

## 四、核心 GraphQL 片段

无（纯客户端主题）。

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
|----|------|-------------------|
| 品牌/数据色（紫绿橙黄蓝 tile、API 返回标签色、Checks 语义色） | 深浅通用，无单值适配必要 | 保持硬编码常量（tile 色 = GitHub 品牌色，深色下依然正确） |
| 截图「半深半浅」漏网 | 硬编码漏迁移 | 迁移后以模拟器深色模式逐页截图核对 |
| Markdown 富文本渲染 | 依赖后续 Spec | 文本化正文展示（与本批页面一致） |

---

## 六、TDD 验收标准

- [x] 测试 1：base 与 dark color.json 同名 token 集一致（脚本比对）
- [x] 测试 2：`devecocli build` 全量构建通过（含 setColorMode 签名验证）
- [x] 测试 3：模拟器实测——Settings 切换深色 → 全页面变暗；切回浅色/跟随系统恢复；重启保持
- [x] 测试 4：模拟器深色截图与官方 6 张基准对照（背景/卡片/边框/选中态）
- [x] 测试 5：grep 页面残留硬编码主题色（白底/浅灰底/浅边框类）为 0
- [x] 测试 6：`bash scripts/check-spec.sh` 通过

---

## 七、备注

- 语义 token 规划：`bg_page/card_background/divider/border/chip_bg/chip_active_bg/chip_active_border/text_primary/text_secondary/link_blue/star_gold/success_text/danger_text/warning_text/checks_success_bg/checks_failure_bg/checks_pending_bg/discussion_badge_bg/shortcut_*（6 个圆底）/heat_empty/primary`。
- `setColorMode` 取值：LIGHT / DARK / COLOR_MODE_NOT_SET（跟随系统）；API 签名以构建验证为准。
- 官方深色基调参考（截图）：页面背景近似 `#010409`，卡片 `#0D1117`，边框/分隔 `#30363D`，次级文字 `#8D96A0`，链接蓝 `#58A6FF`，选中 chip 底 `#1F6FEB`。
