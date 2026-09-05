# Primer 样式 Review 规则（docs/primer-review-rules.md）

> **定位**：本文件是 [DESIGN.md](../DESIGN.md) 的**执行核对视图**——code review 时逐条比对用，
> 不是第二事实来源。所有令牌值以 DESIGN.md 与 `entry/src/main/ets/utils/PrimerTokens.ets`、
> `resources/{base,dark}/element/color.json` 为准；规则与 DESIGN.md 冲突时以 DESIGN.md 为准并回改本文件。
>
> **图例**：〔机械〕=已有或可下沉为 `scripts/` 自动门禁；〔人工〕=code review 走查目验。
> 规则编号 `域字母 + 序号`（如 A1、C12），全局连续、跨节可引用。
>
> **增补约定**：新规则必须先有 DESIGN.md/官方 Primer 出处再立条文；机械条目成熟一条下沉一条
> （脚本进 `scripts/` + pre-commit + CI，先例 `check-hardcoded-colors.py`）。

## A. 颜色（DESIGN.md §1）

- **A1**〔机械〕`entry/src/main/ets` 内禁止色值字面量（`#RRGGBB`/`#AARRGGBB`）；豁免仅三个数据色板文件（`utils/CodeTheme.ets`、`models/LanguageColors.ets`、`utils/MarkdownPalette.ets`）。门禁：`scripts/check-hardcoded-colors.py`。
- **A2** 语义优先：必须用 functional 语义 token（`fg_default`/`fg_muted`/`accent`/`success`/`danger`…），禁止用 base 色板原始值表达语义角色。
- **A3** 每处颜色须能说出对应 Primer 语义角色（链接/选中/强调=accent，Merge/✅/Latest=success，删除=danger，时间/辅助=muted，正文=fg default）——「看着像」的用色打回。
- **A4** 新增颜色必须 base + dark 两套 color.json 成对落地；dark 的 muted 背景用 alpha 叠加（AARRGGBB 格式，alpha 在前）；走查必抽 dark 模式。
- **A5** 半透明是 token 而非代码行为：配色用透明度定义在 color.json；`.opacity()` 只许用于动效，不许用来凑色。
- **A6** 颜色不得是唯一信息载体：状态变化必须配图标/文字/形状双通道（范例：Merge 徽章=紫 + git-merge 图标）。
- **A7** 对比度门槛：文本 ≥4.5:1、UI 组件 ≥3:1（WCAG AA）；新彩底配字先验对比度再合入。

## B. 图标 Octicons（DESIGN.md §9）

- **B8** 图标只许走 `OctIcon` 组件渲染 `oct_*.svg`，禁止 emoji、自绘 Path、`Image` 直引。
- **B9** 图标语义与官方 App 对位（merged=git-merge、fork=repo-forked 等），不得拿近似字形将就；新增字形先确认 `assets/octicons` 归档存在，再复制入 `resources/base/media`（命名 `oct_<name>_<size>.svg`）。
- **B10** 尺寸走 `OctIcon` 统一档位（16 为主，24 用于空态/大场景），禁止 `.scale()`/`resize` 拉伸变形。
- **B11** 图标着色 = 语义 token（等价 `fill="currentColor"` 语义），禁止给图标单独定色或加透明度。

## C. 排版（DESIGN.md §3）

- **C12** 字号主档 5 档：12/14/16/20/32（`FONT_XS~XL`）+ 既有辅助档 chip 15 / menu 17（float.json，2026-09-06 复核增补出处）；页面标题 20fp、正文 14fp、辅助 12fp；出现其他数值打回。
- **C13** 字重只用官方 4 档：标题 600、正文 400、强调 500（300 仅弃用态）。
- **C14** 代码/行号/commit SHA/分支名必须 monospace；正文一律 HarmonyOS Sans，禁止混排。
- **C15** 行高对齐 4px 网格（≈1.5 倍字号）；单行截断 `maxLines`+ellipsis，路径/ref 类长文本优先考虑中段截断语义（Truncate）。

## D. 间距与布局（DESIGN.md §2）

- **D16**〔半机械〕padding/margin 只取 4 的倍数（4/8/12/16/24/32/48），优先 `SPACING_*` 常量；评审逐个数值核对。
- **D17** 间隙基准：图标↔文字 ≥8、卡片内边距 16、卡片间 24、页面分节 32+。
- **D18** 一切可点行/图标钮触点 ≥44×44（`TOUCH_TARGET_MIN`）；触点撑高导致内容错位的写法打回（历史踩坑：行内 44×44 框撑高 Row）。
- **D19** 分隔线 1px + border 语义色，禁止自造粗细、渐变线。

## E. 圆角 / 描边 / 阴影（DESIGN.md §4/§6）

- **E20** 圆角 4 档对位：chip/小标签=3（`RADIUS_SMALL`）、按钮/带边框卡=6（`RADIUS_MEDIUM`）、大卡/模态=12（`RADIUS_LARGE`）、头像/胶囊=9999（`RADIUS_FULL`）；禁止 4/8/10 等随意值。
- **E21** Shape 外轮廓用 `.stroke()`（`.border()` 在 Circle 上画矩形外框——已有踩坑定案）；描边宽 1 + border 语义色。
- **E22** 阴影只有 resting（静置卡片）/floating（浮层）两档；滚动顶部阴影统一走 `PageShadowBar`，禁止自造阴影参数。

## F. 控件与页面模式（DESIGN.md §10 + 复刻标准）

- **F23** 页面骨架复用既有模式（自绘 AppBar/RepoCard/列表卡等），禁自创布局风格；与官方 App 的按钮位置/菜单目录/交互逻辑对位（体验级复刻，不像素级）。
- **F24** 按钮语义对位 Primer variant：主操作=accent 实底、次操作=描边、弱操作=invisible、删除=danger 红；同屏多按钮层级清晰。
- **F25** 二级页必须自绘 AppBar + `NavDestination` `hideTitleBar(true)`（否则双标题双返回——正式修复过的定案）。
- **F26** 空态/加载/错误统一 `StateView` 模式，文案风格对齐官方（如 "Nothing to see here"）。
- **F27** 弹层对位：行内菜单=bindMenu/bindPopup、底部面板=bindSheet、模态=CustomDialog；浮层阴影/圆角按 floating 档。

## G. 动效（DESIGN.md §5）

- **G28** 时长只用 100/200/400 三档（`DURATION_FAST/NORMAL/SLOW`）+ 标准缓动 `cubic-bezier(0.2, 0, 0, 1)`。
- **G29** 尊重系统「减少动效」：非必要动画须有减弱模式降级路径（`animateTo` 前检测）。

## H. 流程性（DESIGN.md §0/§8/§11）

- **H30** 新增 token 必须先落 DESIGN.md / PrimerTokens / color.json 官方值再引用，禁止「代码先用、文档后补」。
- **H31** 涉色改动 dark 模式截图核对；44 触点与对比度列入走查固定项（Light 全页 + Dark 关键页）。
- **H32** 数据色板只允许集中在三个白名单文件（A1）；新场景需扩白名单时须在 DESIGN.md 增补依据后再改门禁脚本。

---

*维护：随评审批次持续增补；每条保持「可判定、有出处」。机械条目下沉门禁后在本文件标注脚本名。*
