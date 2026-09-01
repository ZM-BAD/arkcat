# DESIGN.md — StarRaft 设计规范（GitHub Primer）

> 本文件定义 StarRaft 的设计准则与令牌规范。**单一事实来源：GitHub Primer 设计系统**
> （[primer.style](https://primer.style)，MIT；源仓库 `primer/primitives` / `primer/octicons`）。
>
> 原则一句话：**用 HarmonyOS ArkTS/ArkUI 原生能力，尽可能满足 GitHub Primer 的设计要求**
> ——复刻 IA/交互/视觉节奏，不复刻平台无关控件实现；色值/尺寸/字号等一律来自官方令牌，
> 不记忆臆造值、不硬编码随意数值。

---

## 0. 三层令牌模型（与 Primer 一致）

| 层 | 含义 | StarRaft 落地 |
|---|---|---|
| Base（原始值） | `base-color-blue-5` 等原始色板/尺寸 | `primer/primitives` 归档 + `PrimerTokens.ets` |
| Functional（语义角色） | `fgColor-accent` / `bgColor-default` | resources base 与 dark 两套 `element/color.json`（双主题） |
| Component（组件级） | 按钮/卡片覆写 | ArkUI 组件内按规范引用上述令牌 |

**禁止**：页面内硬编码色值/尺寸/字号（当前代码存量除外，由合规批次清理）。

---

## 1. 颜色（Color）

- 全部使用官方语义色，双主题成对存在：
  - accent 蓝：light `#0969DA` / dark `#4493F8`（链接、选中、强调、加载、FAB 类，一律 `link_blue` token）
  - success 绿：light `#1A7F37` / dark `#3FB950`（成功语义；Merge/✅/Latest 类）
  - muted 文本：light `#59636E` / dark `#9198A1`；默认文本：light `#1F2328` / dark `#E6EDF3`
  - 快捷圆（category）：绿/蓝/紫/橙/粉/靛/灰——`shortcut_*` token 组
- **dark 背景叠加**：Primer 的 muted 背景为「基色 + alpha」（如 `#33DDF4FF`，AARRGGBB 格式——HarmonyOS 颜色资源 alpha 在前）
- 对比度：文本 ≥ 4.5:1、UI 组件 ≥ 3:1（WCAG AA 硬门槛，验收必查）
- 颜色**不得作为唯一信息载体**：状态变化必须配合图标/文字/形状（如 成功勾 + 绿色）

## 2. 间距（4px 网格）

`SPACING_*`（4/8/12/16/24/32/48，见 `utils/PrimerTokens.ets`）。约定：
- 图标与文字间隙 ≥8；卡片/列表内边距 16；区块间 24；页面级分节 32+
- 所有 padding/margin 取常数或 4px 倍数——评审时逐项核对

## 3. 排版（Typography）

| 级别 | 字号/行高 | 字重 | 用途 |
|---|---|---|---|
| title-large | 32 / 48 | 600 | 页面标题 |
| title-medium | 20 / 32 | 600 | 区块标题（Home/Files 等） |
| body-large | 16 / 24 | 400 | 正文（强调处 500） |
| body-medium | 14 / 20 | 400 | **默认正文**（列表/卡片主文本） |
| caption | 12 / 16 | 400 | 标签、辅助文字、时间 |

- 现有 `resources/base/element/float.json` 的 `title/body/caption_font_size` 与此对应（18/14/12→18 略偏，评审批统一为 20/14/12）
- 字体栈：HarmonyOS 默认（`HarmonyOS Sans`），**代码/行号用等宽**（`monospace`）
- 行高对齐 4px 网格（1.5 倍字号即可）

## 4. 圆角（Border Radius）

| Token | 值 | 用途 |
|---|---|---|
| `RADIUS_SMALL` | 3 | 输入框、小标签、chip |
| `RADIUS_MEDIUM` | 6 | 按钮、卡片（配合 border 时） |
| `RADIUS_LARGE` | 12 | 大卡片、模态框、列表容器 |
| `RADIUS_FULL` | 9999 | 胶囊（avatar、tab 选中、badge） |

## 5. 动效（Motion）

- 时长：`DURATION_FAST=100ms`（hover/active/focus）、`DURATION_NORMAL=200ms`（状态切换/展开收起）、`DURATION_SLOW=400ms`（页面级）
- 缓动：标准 `cubic-bezier(0.2, 0, 0, 1)`（急入缓出）
- **`prefers-reduced-motion`**：系统开启「减少动效」时禁用/缩短动画（HarmonyOS 为「动画效果减弱」设置，ArkUI `animateTo` 前检测）

## 6. 阴影（Elevation）

| Token | 值 | 用途 |
|---|---|---|
| `SHADOW_RESTING` | `0 1px 0 rgba(31,35,40,0.04)` | 静置卡片、底栏 |
| `SHADOW_FLOATING` | `0 8px 24px rgba(140,149,159,0.2)` | 浮层、下拉、对话框（dark 下减弱至 50% 不透明度） |

## 7. 响应式

- 断点：320 / 544 / 768 / 1012 / 1280 / 1400（ArkUI：`displaySize` + `GridRow/GridCol`，必要时 `breakpoints`）
- 移动优先：单列；宽度 ≥768 可用 2 列（如仓库列表、组织卡）；≥1400 允许 3 列
- **当前优先级**：手机竖屏（Pura 90 Pro）为准做精；平板/折叠屏为渐进适配，不阻塞评审

## 8. 无障碍（WCAG 2.2 AA）

- 对比度：文本 4.5:1 / UI 3:1（上面颜色节已列）
- 触摸目标 ≥ 44×44（`TOUCH_TARGET_MIN`；列表行/按钮/图标钮同规则）
- Focus 环：专注可见 `0 0 0 3px rgba(3,102,214,0.35)`（ArkUI `focusable + outline`）
- 语义：可点击组件有可读性描述（`accessibilityText/Description`）；颜色状态 + 图标/文字双通道
- 减少动效：遵循系统「动画效果减弱」

## 9. 图标（Octicons）

- 全量归档：`assets/octicons/icons/`（v19.33.0，743 个，MIT）
- 生产资源：`resources/base/media/oct_*.svg` 按需复制（命名 `oct_<name>_<size>.svg`）
- 渲染必须走 `OctIcon` 组件（统一尺寸/着色）；`fillColor` 等价 `fill="currentColor"` 语义；颜色用语义令牌
- 品牌红线：不引入 GitHub 官方插画/logo（见成就徽章规范）

## 10. 参考映射（Primer Web → ArkUI）

| Primer React | ArkUI 实现 | 备注 |
|---|---|---|
| Button (variant) | `Button` 或自定义组件 | 参照官方 variant 语义 |
| ActionList | `List` + `ListItem` | 注意 44px 行高、leading 图标 |
| Dialog | `CustomDialog` | 浮层阴影 + 焦点管理 |
| Stack | `Column`/`Row`/`Flex | 原子布局 |
| Avatar | `Image` + `borderRadius(FULL)` | 圆形裁剪 |
| Label/Badge | `Badge` 或自绘 | 语义色 + 文字双通道 |

## 11. 落地清单（评审批次核对项）

- [ ] 全部页面：尺寸/间距/字号/圆角/阴影引用令牌（无硬编码）
- [ ] 触摸目标 ≥44px（列表行、图标钮、chip、tab）
- [ ] 聚焦可见（可交互元素 focus 态）
- [ ] 动效时长/缓动符合；减少动效适配
- [ ] dark 模式全套语义色（含 muted alpha 叠加）双主题截图验证
- [ ] 状态变化双通道（颜色 + 图标/文字）
- [ ] README/SPEC 与此文档一致

---

*维护：本文与 `specs/039-primer-design-system.md` 同步更新；新增 token 必须先落官方值再使用。*
