# Spec 068: 筛选交互统一约定（全库跨页面）

> BFS Level: —
> 关联截图: 官方 App 各筛选面板（Work Issues / Trending / Repositories / Inbox / Projects）
> 上游 Spec: 002（Inbox）/ 007（仓库内 Issues）/ 017（工作区 Issues）/ 018（工作区 PRs）/ 020（Projects）/ 021（Top Repositories）/ 027（仓库内 PRs）/ 037（仓库列表）/ 056（Trending）
> 状态: implemented（2026-09-13，约定已落全库；宿主单测覆盖判定纯函数）

---

## 一、页面/功能概述

本 Spec 固化**全库筛选交互的统一约定**：任何页面新增或修改筛选控件（下拉 / 底部面板 / 开关 / 多选 / 排序），都必须符合本文的定义；各页面具体的筛选清单、默认值与接口仍写在各自的页面 Spec 中，本文只规定**跨页面一致的部分**。

约定由四条原则组成：

1. **默认值原则**：每个筛选控件都有一对 `(当前值, 默认值)`，默认值可以为空。默认值非空的控件（State=Open、Sort=Recently pushed）chip 直接显示该值；默认值为空的控件（Language、Author、Repository）chip 显示占位名，未选择时不呈现任何"已筛选"的视觉信号。
2. **dirty 原则（有筛选条件 = 当前值 ≠ 默认值）**：漏斗徽标后的数字 = dirty 控件个数，数字为 0 时徽标不出现。多选控件按"集合非空"计 1 项（不按选中个数）；开关控件开启即 dirty；**排序与时间窗同样计入**（它们改变结果集，不是"非筛选"）。
3. **复位同口径原则**：空态 `RESET ALL FILTERS` 与漏斗菜单 `Clear all filters` **必须调用同一个复位函数**，效果完全一致——所有控件回默认 + 清空多选 + 重查。二者**都不清理页内搜索**；页内搜索**也不计入**徽标数字（与官方 App 一致）。
4. **服务端优先原则**：能下推服务端的筛选一律下推（见第四章矩阵）；不能下推的保留客户端过滤，并接入"空态自动补拉"兜底（第五章）。

**假空问题**：客户端过滤时，第一页 25/30/50 条可能全被过滤掉，而服务端还有数据 —— 这是"假空"，用户会误判为"真的没有"。约定的兜底是：过滤后可见条数为 0 且还有下一页时**自动续拉，最多 5 页**；补拉结束仍空且服务端仍有数据时，空态追加"已加载的内容中没有匹配"提示。

---

## 二、整体 UI 结构

1. **筛选条**：位于 App Bar 下方或列表首项，整条**横向可滑**（`Scroll` 横向 + `BarState.Off`），左侧内距 16。
2. **漏斗徽标 chip**（筛选条最左，dirty>0 时才渲染）：`oct_filter_16` 蓝色漏斗 + 计数徽标；点击弹 `bindMenu`，含"创建快捷方式（占位）"与 `Clear all filters`（后者走统一复位函数）。
   - **固定不滚动**：漏斗徽标出现在筛选条最左后，**横向滑动只滚动 chips，徽标钉在原地**。实现=外层 `Row` 内「徽标（条件渲染）」+「chips 的 `Scroll`（`layoutWeight(1)` + `align(Alignment.Start)`）」，滑动内容在滚动区内被裁剪，不会压到徽标下方。
3. **筛选 chip 三种形态**（外形同款：高 32vp / 圆角 16vp / 文字 12fp / 左右内距 8 / chevron-down 12 间距 8 / `responseRegion` 扩至 44 触控高度）：
   - **下拉型** `FilterDropdownChip`：点击弹出**自绘卡片**（非原生菜单），弹层宽度按**实测**最长选项文本宽自适应（+ 左右内距与勾位，刚好包住最宽一行，不做字符估算），选中项右侧主题蓝勾，遮罩点击关闭；
   - **必须在屏幕内**：出屏避让**交给 ArkUI 框架内建策略**（框架按可用空间自动调整气泡位置）——`bindPopup` 设 `placement: Placement.BottomLeft`（首选「弹层左缘对齐 chip 左缘、置于下方」），**不手算 offset**（offset 是叠加在框架避让结果之上的相对微调，再叠一层自算夹取会双重修正、把弹层推出屏幕，chip 被屏幕右缘裁切时最明显）；弹层宽度按可用宽度封顶（可用宽取**同步**来源：`display.getDefaultDisplaySync` 兜底 + 窗口宽覆盖），超长文案由行内 ellipsis 兜底；
   - **面板型** `FilterSheetChip`：点击拉起页面 `bindSheet` 底部面板；支持前置图标（单选仓库时显示 repo octicon）与**前置计数徽标**（多选仓库时显示"蓝底白字数字 + 复数名词"）；
   - **开关型**：无 chevron 的纯 toggle pill（Inbox 的 Focused/Unread、Discussions 的 Unanswered），激活态走 `chip_active_bg` + `link_blue`。
4. **底部面板通用结构**：拖拽条（系统）→ 标题行（自绘 ✕ 44×44 + 标题 `title_font_size` 600）→ 细分隔线 → 可选的 🔍 内联搜索框（点标题行右侧放大镜展开）→ 选项行列表（可滚动）。
   - 选项行：下拉型面板 52vp 行高；语言/排序面板 56vp 行高；选中态为右侧蓝勾（多选）或蓝色单选圆钮（排序，20vp 描边 + 10vp 实心）；
   - 分组：排序面板为 4 组 × 2，组间插 **16vp 灰带**（`heat_empty`），组内不插；
   - 弹层底部留白 16vp；`Scroll` 内容**顶对齐**（`align(Alignment.Top)`，否则内容不足一屏时会被默认居中对齐、首行离头部很远）。
5. **筛选状态条与面板的关系**：面板选择立即生效（单选/开关即关面板，多选可继续勾选）；**排序面板选完即关**；面板可下滑/遮罩关闭，关闭后 `sheetKind` 复位，否则再次点击同一个 chip 拉不起面板。
6. **空态**：
   - `RESET ALL FILTERS` 按钮仅在**存在 dirty 且列表为空**（非加载中、非错误态）时显示；没有 dirty 时不显示（刚进页即空列表的场景不该给"重置"入口）；
   - 同屏的"减少筛选条件"提示与按钮同条件显示；
   - 客户端过滤页补拉到上限仍空时，追加"已加载的内容中没有匹配"（`filter_loaded_range_hint`）说明是范围受限。

---

## 三、元素清单

| # | 位置 | 元素 | 规范 | 可行性 | 实现 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | 筛选条 | 漏斗徽标 chip | 32vp/圆角 16/`chip_bg` 描边；`oct_filter_16` 14vp 蓝 + 计数徽标 | ✅ | 各页内联（样式一致） | 仅 dirty>0 渲染；点开含 Clear all filters |
| 2 | 筛选条 | 计数徽标（漏斗 / chip 前置） | 18vp 圆 / 圆角 9 / `link_blue` 底 / 白字 12fp | ✅ | 同上 + `FilterSheetChip.badgeCount` | 两处同款样式 |
| 3 | 筛选条 | 下拉型 chip | 通用 `FilterDropdownChip` | ✅ | `components/FilterDropdownChip.ets` | 弹层宽度按最长项自适应 |
| 4 | 筛选条 | 面板型 chip | 通用 `FilterSheetChip` | ✅ | 同上（同文件第二个导出） | 支持前置图标 / 计数徽标 |
| 5 | 筛选条 | chip 未选文案 | 显示占位名（`Language`/`Repository`/`Author`） | ✅ | 调用方传入 | 默认值为空时不做"已筛选"视觉暗示 |
| 6 | 筛选条 | chip 单选文案 | 显示具体值；仓库附带 repo octicon | ✅ | `WorkFilterBar.repoChipLabel` | 仓库名用 GitHub 规范写法 `owner/name` |
| 7 | 筛选条 | chip 多选文案 | 计数徽标 + 复数名词（`N Repositories`） | ✅ | 同上 + `badgeCount` | 中文为「计数徽标 + 仓库」 |
| 8 | 面板 | 标题行 | ✕ 44×44 + 标题 600；`showClose: false` | ✅ | `LanguageFilterSheet` / `SortBySheet` / `WorkFilterSelectSheet` 等 | 自绘关闭钮，避免与系统 ✕ 重叠 |
| 9 | 面板 | 内联搜索框 | 高 40 / 圆角 6 / `chip_bg`；放大镜切换显隐 | ✅ | 同上 | 搜索词为面板内部态，每次拉起重置 |
| 10 | 面板 | 选项行 | 52vp（下拉型）/ 56vp（语言、排序）；选中蓝勾或蓝圆钮 | ✅ | 同上 | 行组件化 + key 含选中态（见第七章坑位） |
| 11 | 面板 | 组间灰带 | 16vp `heat_empty` 全宽 | ✅ | `SortBySheet.groupGap` | 分组面板（排序）专用 |
| 12 | 空态 | RESET ALL FILTERS | 与 Clear all filters 同函数；仅 dirty 且空列表时显示 | ✅ | 各页 `canResetFilters()` | 不清理页内搜索 |
| 13 | 空态 | 范围受限提示 | `filter_loaded_range_hint` 副文案 | ✅ | `StateView.emptySub` / `WorkEmptyView.subtitle` | 补拉到上限仍空时显示 |
| 14 | 逻辑 | 自动补拉判定 | `shouldAutoLoadMore` / `isLimitedRangeEmpty`，上限 5 页 | ✅ | `utils/FilterLoading.ets` | 有宿主单测 |
| 15 | 逻辑 | 复位信号 | 页面→组件复位用 `resetTick` + `@Monitor` | ✅ | `WorkFilterBar` | 状态住在组件内部时唯一正确解法 |

> 可行性比例声明：15/15 可行。

---

## 四、核心接口（服务端 / 客户端分工矩阵）

2026-09-13 用 `gh api` 实测（GraphQL 内省 + 真实查询 + 官方 OpenAPI 参数表）后的结论；**能下推的一律下推，客户端过滤只作幂等兜底**。

| 页面 / 筛选 | 结论 | 接口与参数 | 备注 |
| ------------- | ------ | ----------- | ------ |
| 仓库列表 Type：archived / fork / source / private / public / all | 可下推 | `repositories(isArchived:, isFork:, privacy:)` | 6/8 项；`source` = `isFork:false` + `isArchived:false` |
| 仓库列表 Type：mirror / template | 不可下推 | — | 连接无 `isMirror` / `isTemplate`；客户端过滤 |
| 仓库列表 Language | 不可下推 | — | 无 `filterByLanguage`；`/search/repositories` 无 pushed 排序且 1000 上限 |
| 仓库列表 Sort | 可下推 | `orderBy{field: PUSHED_AT/CREATED_AT/NAME/STARGAZERS, direction}` | 8 项 = 4 字段 × 双向 |
| 组织模式 REST 兜底 | 部分可下推 | `/orgs/{o}/repos?type=public\|private\|forks\|sources` | 无 archived/mirror/template；`sort=stars` 被静默忽略（客户端排） |
| 仓库内 Issue：Author / Assignee | 可下推 | `issues(filterBy:{createdBy:, assignee:})` | 与 states/labels 正交，分页语义不变 |
| 仓库内 PR：Author / Assignee | 不可下推 | — | `pullRequests` 无该参数；REST `/pulls` 忽略 `creator` |
| Inbox：视图 / 模式（Focused/Unread） | 可下推 | `/notifications?all=…&participating=…` | 已用 |
| Inbox：reason 多选 / repository 单选 / Saved 视图 | 不可下推 | — | `/notifications` 参数集封闭；无 GraphQL 通知 API；Saved 是本地概念 |
| Inbox：分页 | 可下推 | `/notifications?per_page=50&page=N` | 满载推断 hasMore |
| Projects：范围（All/Owned） | 不可下推 | — | `projectsV2` 无 owner 过滤参数 |
| Projects：Sort | 部分可下推 | `projectsV2(orderBy:)` 覆盖 UPDATED_AT/CREATED_AT/TITLE/NUMBER | Most/Least viewed 是本地会话记录 |
| Projects：Status | 未实测 | `projectsV2(query:"is:closed")`（待验证） | 需 `read:project` scope，补 scope = 用户重新授权，暂缓 |

**自动补拉规则**（客户端过滤页统一）：

```text
过滤后可见条数 == 0 且 hasNextPage 且 已补拉页数 < 5  → 自动续拉下一页
补拉结束仍空 且 hasNextPage                        → 空态追加「已加载的内容中没有匹配」
```

已接入：仓库列表（Type/Language）、Top Repositories、仓库内 PRs（Author/Assignee）、Inbox（reason/repo）、Projects。

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| Inbox 的 reason 多选 / Saved 视图 | `/notifications` 参数集在 OpenAPI 中是封闭的六个（`all/participating/since/before/page/per_page`），`reason=` 与 `repository=` 实测被**静默忽略**；GraphQL schema 无任何通知类型 | 保持客户端过滤；`per_page` 提到 50 + `page=N` 翻页 + 空态自动补拉缓解假空；Saved 恒空为官方语义缺失 |
| 仓库 Type 的 Mirror / Template | `RepositoryOwner.repositories` 参数集实测无 `isMirror` / `isTemplate` | 客户端过滤（其余 6 项已下推，假空面从 8 项收窄到 2 项） |
| 仓库 Language | GraphQL 无 `filterByLanguage`；search 方案牺牲 pushed 排序且 1000 上限 | 客户端过滤 + 自动补拉 |
| 仓库内 PR 的 Author / Assignee | `pullRequests` 无参数；`/pulls` 忽略 `creator`；唯一出口 `/search/issues` 需换分页模型 + 补 `assignees/merged` 字段 + 吃 30 req/min 限流 | 保持客户端过滤 + 自动补拉；仅在"要求结果精确"时再评估 search 方案 |
| Projects 的范围 / Most·Least viewed | 无 owner 过滤参数；浏览记录是本会话本地数据 | 客户端过滤 + 自动补拉 |
| Projects 的 Status 服务端化 | 需要 `read:project` scope，补 scope 会让全部用户重新授权 | 暂缓（属产品决策）；当前靠自动补拉兜底 |
| 多选「全选」等价于不筛 | 无法判定"全选 = 全不选" | 计为 1 项 dirty（近似），确认后接受 |
| 下拉候选列表受数据来源限制 | 候选从已加载数据/服务端返回集合聚合，非全量枚举 | 服务端筛选页用**只增不减的候选池**（选了一人后其他人不从下拉消失）；候选完整性弱于官方，记为已知限制 |
| 页内搜索不参与筛选体系 | 它是"当前列表内查找"，官方亦为本地行为，且与筛选语义不同 | 不计入徽标、不被清空、不进自动补拉 |

---

## 六、TDD 验收标准

- [x] 测试 1：`filterReposByType` 8 项语义（含 source=非 fork/镜像/归档、未知 key 不过滤）
- [x] 测试 2：`repoOrderFromKey` 8 项排序键 → orderBy 字段/方向（未知键回退默认）
- [x] 测试 3：`shouldAutoLoadMore` / `isLimitedRangeEmpty`：有结果不补拉、无下一页不补拉、上限 5 页截断
- [x] 测试 4：`buildNotificationsPath` 分页参数（page=1 不拼、page>1 拼 `&page=N`，Focused 模式 participating 取代 all）
- [ ] 测试 5：模拟器实测 — 徽标数字 = dirty 控件数（含排序）；改回默认值后数字减少/徽标消失
- [ ] 测试 6：模拟器实测 — 空态 RESET ALL FILTERS 与漏斗 Clear all filters 效果一致（含排序复位），且都保留页内搜索词
- [ ] 测试 7：模拟器实测 — 服务端筛选页切换 Type/Author/Assignee 触发重查并重置游标；不再出现"第一页没匹配就空态"
- [ ] 测试 8：模拟器实测 — 客户端筛选页在空结果时自动续拉，到上限后显示范围提示

---

## 七、备注

**实现位置索引**

- chip：`components/FilterDropdownChip.ets`（下拉型 `FilterDropdownChip` + 面板型 `FilterSheetChip`）
- 面板：`components/LanguageFilterSheet.ets`（语言，Trending/仓库列表共用）、`components/SortBySheet.ets`（排序）、`components/WorkFilterSelectSheet.ets`（组织/仓库/作者/标签多选）、`components/WorkFilterSortSheet.ets`（工作区排序）、`components/InboxFilterSheets.ets`
- 判定与过滤纯函数：`models/GitHubModels.filterReposByType`、`services/ProfileListService.repoOrderFromKey`、`utils/FilterLoading`
- 复位信号：`components/WorkFilterBar.resetTick`（+ 页面 `@Local resetTick`）

**两个 ArkUI 坑位（新增筛选 UI 必读）**

1. **选中态不刷新**：面板行若写成 `@Builder row(opt){ ... this.selected === opt.key ... }` 且 `ForEach` key 只用 `opt.key`，切换选中后行不会重算（表现：多选看似能同时选中、蓝勾/圆钮卡旧值）。正解=**行组件化（`@Param selected`）+ key 带上选中态** `(opt) => \`${opt.key}_${selected?'on':'off'}\``。
2. **页面重置只改了自己的快照**：筛选状态住在子组件内部时（如 `WorkFilterBar`），页面直接改自己那份状态不会让 chip/徽标复位。正解=递增 `resetTick`，由组件 `@Monitor` 执行内部复位。

**新增筛选控件的检查清单**

1. 明确默认值（可为空），并在页面状态里体现；
2. 是否计入徽标？除页内搜索外**都算**（含排序、开关、多选）；
3. chip 三态文案（未选占位名 / 单选值 / 多选计数徽标 + 复数名词）；
4. 能下推服务端的**一律下推**（第四章矩阵），客户端过滤保留为幂等兜底；
5. 无法下推的接入自动补拉 + 范围提示；
6. 确认切换筛选是否要重查并重置游标（服务端筛选必须重查）；
7. 复位路径与漏斗菜单 Clear all filters 共用同一函数；空态 RESET 仅在 dirty 时出现。
