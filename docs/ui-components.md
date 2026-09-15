# UI 组件库台账与抽取路线图

> 本文是 `entry/src/main/ets/components/` 公共组件的单一台账：已有哪些组件、怎么用、
> 下一步还抽什么。新增 UI 代码前先查此表——能用台账组件的不许再手写同构 UI；
> 要新增公共组件的，先在此文档立项再动手。

## 一、底座组件（全库强约束，页面必须复用）

| 组件 | 职责 | 采用情况 |
| --- | --- | --- |
| `AppBar` | 二级页顶栏（行高 48/图标 20，Spec 067） | 全部二级页 |
| `PageShadowBar` | 滚动阴影条 | 滚动页 |
| `StateView` | loading/error/empty 三态（empty 支持 sub 文案 + Retry） | 38 页 |
| `WorkEmptyView` | 业务空态（图标 emoji + 标题 + 副文案 + 可选按钮；RESET 统一走 button） | 7 页 + 4 处筛选空态 |
| `ListLoadingFooter` | 分页加载 footer | 20/22 个分页页 |
| `OctIcon` | Octicon 渲染（统一尺寸/着色，禁系统字形） | 全库 |

## 二、行与内容原语

| 组件 | 职责 | 参数化点 |
| --- | --- | --- |
| `Avatar` | 头像（占位底 heat_empty，person 兜底） | `diameter` / `square`（org 方角）/ `fallbackIcon` |
| `UserRow` | 用户列表行（名/login/bio 可省） | `avatarSize`(56/48)、`verticalPadding`(10/8)、`fallbackIcon` |
| `LabelPill` | Issue 标签胶囊（官方配色算法） | `large`（列表行 small / 面板 large） |
| `CountChip` | 图标计数胶囊（评论/eye/关联 PR；Checks 描边变体） | `outlined` / `iconColor` / `textColor` |
| `LanguageDot` / `LanguageDotRow` | 语言色点（回退 repo_language_unknown） | `dotSize`(9/10/12) |
| `SectionRows` | 分组头 `SectionHeaderRow` + 列表行 `UserListRow` | `iconSize`/`titleFontSize`/`titleBold`/`rowHeight`/`actionText` |

采用口径：列表行一律组合 Avatar/UserRow/CountChip/LanguageDotRow，不再手写同构块；
占位色统一 heat_empty、语言点统一 Circle 画法、空态统一「图标+文字顶部居中」。

## 三、弹层体系（双态搜索交互全库统一，Spec 068）

| 组件 | 职责 |
| --- | --- |
| `SheetHeader` | 双态标题行：常态=[✕ 标题 🔍]，搜索态=标题原地变搜索框、✕ 变 ←（清词退出）；`iconSize`(16/18)、`alwaysDivider` 两口径参数化 |
| `FilterOptionSheet` | 列表单选面板（双态头 + plain/label 胶囊/circle-slash 哨兵三态行）；仓库内 Issues/PRs 四面板共用 |
| `WorkFilterSelectSheet` | 多选面板（org/repo，头像行 + 全库真搜索） |
| `WorkFilterSortSheet` / `SortBySheet` | 排序面板 |
| `LanguageFilterSheet` / `InboxFilterSheets` / `StarredListSheet` | 语言筛选 / 通知筛选 / 星标列表选择 |

## 四、筛选体系

`WorkFilterBar`（筛选条骨架：漏斗徽标固定 + chips 横滚 + 空态 RESET）、
`FilterDropdownChip`（下拉型，含 `badgeCount` 徽标与分组标记）、`FilterSheetChip`（面板型）。
筛选条口径唯一出处：specs/068-filter-interaction.md。

## 五、业务卡片（页面级，暂不参数化）

`RepoCard`（isPinned 变体）、`StarredRepoRow`、`TrendingRepoCard`、`SearchRows`（四类结果行）、
`ExploreActivityCard`、`InboxNotifyCard`、`CommentCard`/`CommentComposer`/`ReactionBar`、
`CommitDiffBlock`/`PrDiffCard`/`PrStatusCard`、`ProfileHeaderCard`/`ProfileNavRows`、
`CodeSearchCard`、`DownloadRow`、`MarkdownView`。

## 六、路线图（后续抽取，按价值/风险排序）

| 项 | 规模 | 说明 |
| --- | --- | --- |
| `SearchBarHeader` | 7 页 × ~70 行 | 顶栏内联搜索（标题⇄搜索框）；退出形态有 ✕/Cancel 两种漂移，迁移时随官方口径收口；逐页迁移逐页走查 |
| `PagingSource` | 21 页 × ~45 行 | refresh/loadMore/cursor/guard 状态机样板；逻辑层，建议配专项回归 |
| `ConfirmDialog` | 6 处 | 双钮确认弹窗两套 API（showDialog/showAlertDialog）与两套配色（双蓝 vs 灰+红）需先拍板规范 |
| 筛选 chip 归并 | ~10 处 | 页内手写 chip 样式归并到 FilterDropdownChip/FilterSheetChip，逐处判定下拉型/面板型 |
| `WorkItemCard` | 4 套 | issue/PR 卡骨架参数化；布局有真实差异（icon 位置/labels 滚动区），待 CountChip 采纳稳定后评估 |
| `IconCountRow` | 3 处 | ProfileNavRows @Builder 升级 struct 并吸收 RepoDetail countRow/OrgProfile 行（含负数哨兵） |
| Avatar 补采 | ~10 处 | Index tab 头像、Forks/OrgList、WorkFilterSelectSheet（'◯' 兜底口径需先统一）等存量点位 |

## 七、改动纪律

- 新增公共组件：先在本文档台账立项（职责/参数化点），再写代码；单文件超 300 行拆子组件。
- 视觉口径变化必须同步 DESIGN.md；防回归的「有意不改」决策记录在对应 Spec §七。
