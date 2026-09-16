# DESIGN.md — ArkCat 设计规范（GitHub Primer）

> 本文件定义 ArkCat 的设计准则与令牌规范。**单一事实来源：GitHub Primer 设计系统**
> （[primer.style](https://primer.style)，MIT；源仓库 `primer/primitives` / `primer/octicons`）。
>
> 原则一句话：**用 HarmonyOS ArkTS/ArkUI 原生能力，尽可能满足 GitHub Primer 的设计要求**
> ——复刻 IA/交互/视觉节奏，不复刻平台无关控件实现；色值/尺寸/字号等一律来自官方令牌，
> 不记忆臆造值、不硬编码随意数值。
>
> 还原度前提（用户 2026-09-11 定调）：**在满足中国法律法规与上架合规要求的前提下，最大程度还原官方
> App**；因合规或平台能力差异必须偏离的，在对应 Spec 第七章记录理由。无合规理由的偏离应避免。

---

## 0. 三层令牌模型（与 Primer 一致）

| 层 | 含义 | ArkCat 落地 |
| --- | --- | --- |
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

### 1.1 数据色（API 返回的运行时颜色）

GitHub API 返回一批**数据色**：仓库标签 `label.color`、语言 `languageColor`、成就徽章主题色等。
官方行为是**直接渲染原始值**，它们不进设计令牌体系；硬编码颜色门禁（`scripts/check-hardcoded-colors.py`）对数据来源色豁免（运行时拼 `#hex` 是数据，不是设计令牌）。各数据色的暗色策略不同：

| 数据色 | 亮色模式 | 暗色模式 | 说明 |
| --- | --- | --- | --- |
| Issue 标签 | 原色实底 + 黑白文字（按 §1.2 算法） | 原色 18% 透明底 + 同色相提亮文字 | 唯一有公式级官方规则的，见 §1.2 |
| 语言点 | 原色直渲 | 原色直渲（不做变换，官方同） | 无色回退 `repo_language_unknown` |
| 成就横幅 | 主题横幅图原样铺满 | 同左 | 唯一权威色源=官方横幅（spec 052） |

### 1.2 Issue 标签文字黑白判定（官方公式）

标签底色来自仓库自定义 hex，文字黑白由**感知光感**决定（官方给出的精确公式，唯一来源 primer/react IssueLabelToken）：

- `PL = (0.2126×R + 0.7152×G + 0.0722×B) / 255`（官方原样公式，**不做** sRGB gamma 解码）
- **阈值 = 0.6**：`PL < 0.6 → 白字，否则黑字`
  > 阈值口径说明：primer/react 里亮色主题是 0.453、暗色主题是 0.6；**官方移动端亮暗两态实测均为 0.6**
  > （2026-09-14 用真实仓库 10 个标签色逐一验证：0.453 只吻合 9/10，`#d876e3` PL=0.575 官方 App 为白字；
  > 0.6 十个全部吻合）。ArkCat 按 0.6 落地。
- **亮色模式**：背景=原色实底；近白标签（PL > 0.96）追加同色系发丝描边（同色相、亮度 −25、alpha=PL−0.96）
- **暗色模式**：背景=原色 18% 透明度；文字=同色相提亮 `lightenBy = (0.6 − PL) × 100`（仅 PL < 0.6 时生效）；描边=提亮色 30% 透明
- 实现位置：`utils/DataColors.ets`（纯函数 + 宿主单测，测试集即上述 10 色验证集）+ `components/LabelPill.ets`
- 官方出处（可查证）：
  - 组件页：<https://primer.style/product/components/label/>
  - 胶囊造型源码（primer/css labels mixins）：<https://github.com/primer/css/blob/main/src/labels/mixins.scss>
  - 颜色公式官方实现（primer/react，明暗两套 mixin）：<https://github.com/primer/react/blob/main/packages/react/src/Token/IssueLabelToken.module.css>
  - web 端公式逆向分析（阈值 bug 讨论）：<https://firsching.ch/github_labels.html>

## 2. 间距（4px 网格）

`SPACING_*`（4/8/12/16/24/32/48，见 `utils/PrimerTokens.ets`）。约定：
- 图标与文字间隙 ≥8；卡片/列表内边距 16；区块间 24；页面级分节 32+
- 所有 padding/margin 取常数或 4px 倍数——评审时逐项核对

## 3. 排版（Typography）

| 级别 | 字号/行高 | 字重 | 用途 |
| --- | --- | --- | --- |
| title-large | 32 / 48 | 600 | Hero 大字（特例，如 Release 版本号）；**页面标题走 title-medium 20** |
| title-medium | 20 / 32 | 600 | 页面标题 |
| section-title | 18 / 28 | 600 | 区块标题（Home My Work/Favorites/Shortcuts 等；官方 App 实测层级：页头 > 区块头，2026-09-15 走查修正） |
| body-large | 16 / 24 | 400 | 正文（强调处 500） |
| body-medium | 14 / 20 | 400 | **默认正文**（列表/卡片主文本） |
| caption | 12 / 16 | 400 | 标签、辅助文字、时间 |

- 现有 `resources/base/element/float.json` 的 `title/body/caption_font_size` 与此对应（已统一为 20/14/12）
- 字体栈：HarmonyOS 默认（`HarmonyOS Sans`），**代码/行号用等宽**（`monospace`）
- 行高对齐 4px 网格（1.5 倍字号即可）

### 3.1 字号档位与官方出处（2026-09-15 补）

官方 Primer 字号刻度（[primitives/typography](https://primer.style/product/primitives/typography/)）：
xs **12** / sm **14** / md **16** / lg **20** / xl **32** / 2xl **40**（16px 根换算）；代码块固定 **13**。
ArkCat 全量对应该刻度，落 `float.json`：

| float token | fp | 官方档 | 用途 |
| --- | --- | --- | --- |
| `caption_font_size` | 12 | xs | 辅助文字、时间、chip 计数 |
| `body_font_size` | 14 | sm | 默认正文（列表/卡片主文本） |
| `code_font_size` | 13 | 官方代码块固定 13 | 代码片段/摘要等宽段 |
| `sub_text_font_size` | 16 | md | 正文强调、次级标题 |
| `chip_font_size` | 15 | 移动端官方 App 实测 | 筛选 chip（勿按 web 16 修正） |
| `menu_font_size` | 17 | 移动端官方 App 实测（iOS body 档） | 弹层菜单行 |
| `title_font_size` / `page_text_font_size` | 20 | lg | 页面标题 |
| `section_title_font_size` | 18 | 官方 App 实测 | 区块标题（低于页面标题；Primer 无区域规定，以实测为准） |
| `title_large_font_size` | 32 | xl | Hero 大字（Release 版本号） |

**规则**：页面禁写 `fontSize(<数字>)` 字面量——`scripts/check-hardcoded-fontsize.py` 门禁已落地
（pre-commit + CI），豁免行内标注 `// typography-exempt`；新增字号先落 token 再用。
**装饰字形例外**：emoji 载体（空态大 emoji、reaction emoji、分类 emoji）与 OAuth user code 展示位
不是常规排版文本，按容器视觉取值（40/30/24/22/32 等），不进排版刻度、不受本条约束。

### 3.2 字重官方档（2026-09-15 补）

官方字重（同上出处）：light **300** / normal **400** / medium **500** / semibold **600**——**没有 700 档**；
web 端所有标题/强调上限即 semibold 600。ArkCat 对应：

| 场景 | 字重 |
| --- | --- |
| 标题（页面/区块/Hero） | **600**（写数字 `fontWeight(600)`，`FontWeight.Bold`=700 禁用） |
| 次强调/列表主文本 | 500（`FontWeight.Medium`） |
| 正文/辅助 | 400（默认） |
| 走查定案例外 | Release 详情/列表「作者名黑体」`FontWeight.Bold`、成就 Share 钮 Bold（2026-09-12~14 走查修正定案，勿回退） |

- 同一脚本一并拦截 `FontWeight.Bold`/`fontWeight(700)`（豁免同上：行内 `// typography-exempt`）。

- 层级不靠颜色硬撑：**勿把颜色作为主要强调手段**（官方 Typography 准则），层级优先用 字号/字重/布局 表达。

## 4. 圆角（Border Radius）

| Token | 值 | 用途 |
| --- | --- | --- |
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
| --- | --- | --- |
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

### 9.1 图标尺寸（2026-09-15 补）

官方规则（[octicons 设计规范](https://primer.style/octicons/design-guidelines)）：
每字形出 **16 与 24 两个设计版本**（各自网格、1.5px 统一描边）；**12 仅当 16 放不下才做**
（如行内小勾、chip 计数位）。图标色跟随语义令牌（`fill=currentColor`），不用彩色图标表达状态
（状态=字形+语义色，见 §10.1）。

ArkCat 渲染档位（官方 App 实测 + 已走查定案，**新增图标必须取以下档位，禁发明新值**）：

| 档位 | 用途 | 出处 |
| --- | --- | --- |
| 12 | chip 计数位、行内微图标（comment/eye/star 计数） | 官方 12 例外档 |
| 14 | 标签行/紧凑行内 | 实测 |
| 16 | 列表行、面板行、弹层选项（默认行内档） | 官方 16 主档 |
| 18 | 弹层双态标题行（✕/←/🔍） | 实测 |
| 20 | 顶栏/工具栏图标（App Bar 统一口径） | spec 067 |
| 22 | 列表行主状态图标（issue/PR 状态） | 实测 |
| 24 | 大按钮/空态/导航级 | 官方 24 主档 |
| 例外 | 实底徽标内嵌白图标 10/15（A 口径）、成就时间线 dot 10、文件大图标 36 | 走查定案，勿扩散 |

## 10. 组件级官方规范（跨页面原语）

> 页面骨架、chip/面板/搜索框等**官方 App 实测度量**的单一出处是对应 Spec（筛选体系见
> [specs/068-filter-interaction.md](specs/068-filter-interaction.md)，App Bar 见 specs/067），本节收录**跨页面复用、有 Primer/octicons 官方约束**的原语；组件目录总入口：<https://primer.style/product/components/>。

| Primer React | ArkUI 实现 | 备注 |
| --- | --- | --- |
| Button (variant) | `Button` 或自定义组件 | 参照官方 variant 语义；移动端高度口径见 §10.4 |
| ActionList | `List` + `ListItem` | 注意 44px 行高、leading 图标 |
| Dialog | `CustomDialog` | 浮层阴影 + 焦点管理 |
| Stack | `Column` / `Row` / `Flex` | 原子布局 |
| Avatar | `Image` + `borderRadius(FULL)` | 圆形裁剪，档位见 §10.3 |
| Label/IssueLabel | `components/LabelPill.ets` | 造型与颜色算法见 §10.2 / §1.2 |

### 10.1 Issue/PR 状态语义（StateLabel）

官方以「**专用 octicon 字形 + 语义色**」双通道表达状态（StateLabel：用于渲染 issue/PR 状态）。
全库唯一映射表如下；**禁止**各页自创字形/配色组合（曾因此出现关闭态 PR 误用灰色）：

| 状态 | Octicon 字形 | 语义 | ArkCat 令牌（light/dark 双套） |
| --- | --- | --- | --- |
| open issue / open PR | `issue-opened` / `git-pull-request` | success 绿 | `success_text` |
| closed issue（完成） | `issue-closed` | done 紫 | `shortcut_purple_fg` |
| not planned issue | `skip` | muted 灰 | `text_secondary` |
| draft PR | `git-pull-request-draft` | muted 灰 | `text_secondary` |
| merged PR | `git-merge` | done 紫 | `shortcut_purple_fg` |
| closed（未合并）PR | `git-pull-request-closed` | **danger 红** | `danger_text` |

> 历史注：closed PR 曾按 2026-09-05 review B9 定为「灰色 + x-circle」，与官方不符；
> 2026-09-14 以官方为准改为「红色 + `git-pull-request-closed`」。
> 出处：StateLabel（组件目录 <https://primer.style/product/components/>）、octicons（<https://github.com/primer/octicons>）。
>
> 详情页页头（`pages/PrDetail.ets`，2026-09-16 官方对齐）以**填充胶囊变体**渲染同一映射：
> 白字白图标、半径 12、内距 8/3；底色 open=`success_btn_bg`、merged=`merged_badge_bg`、
> closed=`badge_red`、draft=`text_secondary`。列表卡片仍用「左缘裸图标」变体，两处共用本表字形/语义色。

### 10.2 IssueLabel（标签胶囊）

- 造型（primer/css `labels-base`）：字号 12 半粗体；small=行高 18（总高≈20）左右内距 7；large=行高 22（总高≈24）左右内距 10；`border-radius: 2em` 全圆胶囊；1px 透明描边占位
- 颜色规则见 §1.2（PL 公式 + 0.6 阈值 + 明暗两套渲染）
- ArkCat 实现：`components/LabelPill.ets`（small=列表行内标签，large=筛选面板行）；出处：<https://github.com/primer/css/blob/main/src/labels/mixins.scss>

### 10.3 Avatar

- 一律正圆（`RADIUS_FULL`）；尺寸取官方档位 **16/20/24/32/40/48**（vp）：筛选面板行 40、顶栏/行内小头像 20，其余取最近档位，不发明中间值
- 出处：Avatar（组件目录 <https://primer.style/product/components/>）

### 10.4 Button（移动端口径）

- Primer web 的 Button 高 32（默认）/40（large）；**移动端官方 App 实测主按钮高 ≈48**，ArkCat 取 `button_height=48vp`——这是移动端放大口径，**勿按 web 文档「修正」回 32/40**；圆角 `button_radius=6`（`RADIUS_MEDIUM`）
- 出处：Button（组件目录 <https://primer.style/product/components/>）

### 10.5 PR 卡片胶囊全集（PullRequestCard，2026-09-16 收口）

PR 列表卡片的胶囊统一**描边变体**：透明底 + `divider` 1px 描边 + `text_primary` 文字（仅 Checks 图标着色），
半径 12、内距 8/2（`components/CountChip.ets` outlined 变体）；组容器 `Flex(wrap)` **放不下自动折行**
（不横向截断、头像不裁），头像跟在胶囊末尾。实现：`components/PullRequestCard.ets`（WorkPrs/RepoPrs 共用）。

**Checks 胶囊（StatusState 五态全集，GitHub GraphQL 权威枚举，勿增勿漏）**：

| StatusState | 图标 | 图标色（令牌） | 文字（base / zh_CN） | 字符串键 |
| --- | --- | --- | --- | --- |
| SUCCESS | `check` | `success_text` 绿 | Checks / 检查 | `work_pr_checks` |
| FAILURE、ERROR | `x` | `danger_text` 红 | Checks failed / Checks 失败 | `work_pr_checks_failed` |
| PENDING | `x` | `warning_text` 黄 | Checks pending / Checks 进行中 | `work_pr_checks_pending` |
| EXPECTED | `circle` | `text_secondary` 灰 | Checks expected / Checks 等待上报 | `work_pr_checks_expected` |

> SUCCESS 态数量口径**暂缓**：官方 App 行内曾见「绿圈勾 + 1」，与 checks 总数（#82=26/27）对不上，
> 候选=提交数/关联 issue 数/legacy status 数；解谜前 SUCCESS 用纯文案 `Checks`（数量已入库备用，UI 未展示）。
> 文字一律 `text_primary`（仅图标着色，2026-09-16 用户定案）；枚举出处 `StatusState`
>（introspection 实测，rollup `state` 只可能返回这五个值）；未知值静默不显示胶囊。

**计数胶囊**：评论（`comment` 图标 + N）、Reviews（`eye` 图标 + N），仅在数量 > 0 时显示，描边变体。
**标签胶囊**：`LabelPill`（§10.2，填充标签自身数据色——`dependencies=ededed` 浅灰即官方真实色，非渲染错误）。
**状态字形**：卡片左缘的状态图标/颜色走 §10.1 StateLabel 映射（draft/merged/closed 含在内）。

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
