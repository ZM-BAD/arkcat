# Spec 074: Home Shortcuts（快捷方式 = 已保存搜索）

> BFS Level: 3
> 关联截图: 官方 App 2026-09-21 截图 2 张——Shortcuts 管理页（Saved 空态 + Suggested）+ Create Shortcut 编辑页
> 上游 Spec: 013（Home 布局与 Shortcuts 空态引导）、016（快照编辑范式）、017/018（Work 筛选词汇表与 WorkFilterBar）、043（Picker 数据源）、050（Favorites 同构骨架：端侧存储 + 版本泵）
> 状态: implemented（2026-09-21 状态回写：当批实现+真机走查验收通过，Scope 菜单/选仓库页走查修正已折入；随 PR #57 squash 合并 develop=888926d）

---

## 一、页面/功能概述

Home 页 Shortcuts 区块从 013 的静态空态引导接通为真功能：Shortcuts = 已保存的 Issue/PR 搜索（名称 + 图标 + 颜色 + 查询串）。Shortcuts 管理页负责已保存项的增删（快照 + SAVE）、排序与「建议快捷方式」一键添加；Create Shortcut 编辑页负责命名、Scope（全部/指定仓库）、Type（Issues/Pull Requests）、筛选组合（复用 Work 筛选词汇）、颜色与图标个性化。快捷方式本体为端侧按账号隔离持久化——官方为服务端同步，公开 API 无 shortcuts 读写能力（见五）。点击快捷方式打开 `searchResults` 结果列表（复用 Spec 046 通道，`kind|query` 路由参数）。

---

## 二、整体 UI 结构

1. Home 页 Shortcuts 区块（013 布局内嵌区块，两态互斥）：
   - 空态：现状引导（标题 + 8 枚装饰字形 + 文案 + GET STARTED 描边钮），入口从 toast 占位改为进 Shortcuts 管理页
   - 有值态：区块头行「Shortcuts」+ 右侧 kebab-horizontal 三点（44×44 触点）进管理页；下方快捷方式行列表——**与管理页 Saved 行同款**（彩色 tile + 两行文本：首行 head 次级色、次行名称主色加粗；用户 2026-09-21 定案），点击行打开结果列表
2. Shortcuts 管理页（新全屏 NavDestination `shortcuts`；**底部 Tab 栏保留**——官方两张截图均带 Home/Inbox/Explore/Copilot 底栏，不进 TAB_BAR_HIDDEN_ROUTES）：
   - App Bar（自绘，016 范式）：返回 + 标题「Shortcuts」+ SAVE 蓝色文字钮 + 蓝色竖三点 ⋮（菜单单项 Show / Hide reorder actions，标签随当前模式取反）
   - Saved Shortcuts 区（区块头次级色）：空态为「No saved Shortcuts」整行文案；有值态为已保存行——行首灰底 × 圆钮（移除）+ 彩色 tile + 两行文本（**建议收藏后两行文案原样保留**：首行=建议行首行持久化、次行=名称主色加粗；手动创建首行=类型标签。用户 2026-09-21 定案）+ 行尾 grabber 拖拽柄（重排模式切换 ▲▼ 逐格钮，首行 ▲/末行 ▼ 置灰）；点击行打开结果列表。整页快照编辑：返回静默丢弃，SAVE 落盘并 pop（050 FavoritesEdit 同构）
   - CREATE SHORTCUT 行：行首蓝色 ⊕ + 蓝色大写字文案，整行点击进创建页
   - Suggested Shortcuts 区（区块头次级色）：建议行 = 彩色 tile + 两行文本（次级色首行 + 主色加粗次行）+ 行尾蓝色 ⊕（点击追加到 Saved 快照末尾）；全局 3 条（Issues·Mentioned / Issues·Assigned / Pull Requests·Review requested）+ 仓库建议 3 条（viewer 仓库最近推送序，行首行「owner / name」、次行「Open, Created-desc」，查询 = `repo:x is:open sort:created-desc`）；已保存快照中存在同 kind+query 项的建议隐藏；仓库建议加载失败/为空呈现状态行（StateView 语义），全局 3 条不受影响
3. Create Shortcut 编辑页（新全屏 NavDestination `shortcutCreate`；底栏同样保留）：
   - App Bar：返回 + 标题「Create Shortcut」+ SAVE（保存后 pop 回管理页，经版本泵刷新 Home 与管理页）
   - 名称行：行首图标 tile 预览（当前 iconKey+colorKey 着色）+ 下划线式 TextInput（占位为类型名，留空保存时以类型名兜底）
   - Scope 行：左「Scope」+ 右蓝色值（ALL REPOSITORIES / owner/name）；点击弹出两项菜单（Type 菜单同款自适应卡片：bindPopup + 实测宽度 + mask + placement BottomRight）——未选仓库 = **All Repositories / Choose Repository**，已选仓库 = **All Repositories / owner/name**（第二行随当前态切换，用户 2026-09-21 定案）；蓝勾（check octicon）挂当前态行——未选挂 All Repositories、已选挂仓库名行；「All Repositories」点击切回全部仓库；第二行点击（Choose 或已选仓库名）均压栈整页选仓库页——复用 043 RepoPickerView（pRole='shortcut'，小字行 = Create Shortcut、粗体 Choose a repository、右上 🔍 服务端检索），独立路由名 `shortcutRepoPicker`（官方该页带底部 Tab，不进 TAB_BAR_HIDDEN_ROUTES）；选中经 RepoPickResult 静态槽回传 + pop，本页经 Index onShown tick 消费（onPop 不触发坑，BranchPickResult 同款范式）；菜单宽度下限 96、上限窗口宽 -16（超长仓库名行内 ellipsis，FilterDropdownChip.menuWidth 同款封顶）
   - Type 行：左「Type」+ 右蓝色值（**全大写** ISSUES / PULL REQUESTS / DISCUSSIONS，随选项变化）；点击弹菜单三项 **Issues / Pull Requests / Discussions**（用户 2026-09-21 定案，对齐官方），选中项尾随蓝色 **check octicon**（自绘菜单行同 FilterDropdownChip 弹层范式；曾误用系统符号 sys.symbol.checkmark 致字形不协调，已校正），菜单锚定行右端贴触区弹出（显式 placement BottomRight）；切换时重置筛选 chips 为默认态（各类状态选项不同）
   - 筛选 chips 行：整体复用 WorkFilterBar（State/Scope/Visibility/Organization/Repository/Sort by），state/scope 选项按 Type 取 017/018 各自词汇表；chips 与屏幕左右端保持 16 边距（2026-09-21 校正）；**选了筛选后最左出现漏斗徽标（filter icon + 蓝圈激活组数计数），菜单只留 Clear all filters**（创建页内不嵌 Create Shortcut 入口，2026-09-21 定案）
   - 颜色行：7 色（gray/blue/green/orange/red/pink/indigo；用户 2026-09-21 定案去掉 purple），**与图标网格同形态**——无底块、44 槽位等距分布、静态一排不横滚；圆点 = octicon dot 原生字形（20 渲染，与网格 dot 同视觉尺寸）：未选=空心 dot、选中=实心 dot-fill（用户 2026-09-21 校正：尺寸随 octicon 实际占比，不再放大）
   - 图标网格：**固定 7 列**分块 × 36 图标（Flex wrap 随屏宽变 8 列已废弃，2026-09-21 校正；整行均匀分布、末行 inbox 单枚居中；清单见七），选中格 = 灰底（text_secondary）白字形，默认选中 zap；第 2 格 = octicon 原生 dot（空心圆环，用户 2026-09-21 校正）
   - 预填：路由参数 JSON（kind+筛选快照）支持从 Work Issues/Work PRs 漏斗菜单「Create Shortcut」带入当前筛选直达本页

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | ------ | ------ | ------ |
| 1 | Home·区块头 | 标题 + kebab 三点 / GET STARTED | 进管理页 | ✅ | 无（本地） | 空态入口为 GET STARTED，有值态为 ⋯ |
| 2 | Home·快捷方式行 | 彩色 tile + 名称 | 点击开 searchResults | ✅ | 无（本地缓存渲染） | `kind\|query` 参数泵；快捷键内容离线可渲染 |
| 3 | 管理页·App Bar | 返回 / SAVE / ⋮ 菜单 | 保存返回；切换重排模式 | ✅ | 无 | ⋮ 标签随模式取反（016 范式） |
| 4 | 管理页·Saved 空态 | No saved Shortcuts 行 | 空态文案 | ✅ | 无 | |
| 5 | 管理页·Saved 行 | × / tile+名称 / 拖拽柄 | 移除；排序；点击打开 | ✅ | 无 | × 移除为同仓库 FavoritesEdit 行解剖（官方 Saved 态截图未覆盖，见七） |
| 6 | 管理页·CREATE SHORTCUT 行 | ⊕ + 大写文案 | 进创建页 | ✅ | 无 | |
| 7 | 管理页·建议（全局） | 3 条建议行 + ⊕ | 追加到 Saved 快照 | ✅ | 无 | 已保存同 kind+query 的建议隐藏 |
| 8 | 管理页·建议（仓库） | viewer 仓库前 3 + ⊕ | 追加到 Saved 快照 | ✅ | viewer.repositories | 官方数据源为最近访问仓库，端侧无浏览史 → 用自有/协作/组织仓库最近推送序替代（见五） |
| 9 | 创建页·名称行 | tile 预览 + 下划线输入 | 命名 | ✅ | 无 | 留空以类型名兜底 |
| 10 | 创建页·Scope 行 | Scope + 蓝值 | 两项菜单 → All 直选 / Choose 整页选仓库 | ✅ | 复用 043 RepoPicker 同源查询（viewer.repositories） | All repositories = 不带 repo: 限定词；选仓库页选中回填行值 |
| 11 | 创建页·Type 行 | Type + 蓝值 | Issues / PRs 切换 | ✅ | 无 | 切换重置筛选 chips（resetTick） |
| 12 | 创建页·筛选 chips | WorkFilterBar 复用 | 状态/归属/可见性/组织/仓库/排序 | ✅ | 无 | 新增隐藏漏斗参数；选项词汇表同 017/018 |
| 13 | 创建页·颜色/图标 | 7 色横滚 + 36 图标网格 | 个性化 tile | ✅ | 无 | 色板去 purple（用户定案）；圆点与网格字形同尺寸 |
| 14 | 数据·持久化 | 快捷方式按 login 分区 | 跨会话保留、切账号互不可见 | ✅ | 无（Preferences） | FavoritesStore 单例范式 + Index 版本泵 |
| 15 | 数据·云端同步 | 官方服务端同步快捷方式 | 跨设备一致 | ❌ | 公开 schema 无 shortcuts 读写字段 | 端侧存储替代，详见五 |
| 16 | Work 页·漏斗菜单 | Create Shortcut 项接线 | 携当前筛选跳创建页 | ✅ | 无 | WorkIssues/WorkPrs 传入回调 + 预填 JSON；WorkFilterBar 新增 onCreateShortcut 事件 |

> 可行性: 15/16 可行（云端同步 ❌ 不做）

---

## 四、核心接口片段

查询串在端侧拼装（复用 WorkModels 导出的 `workScopeQualifier` / `workVisibilityQualifier` / `workIssuesSortQualifier` 纯函数），**不落 `is:issue`/`is:pr`**——kind 单独存储，打开时经 `searchResults` 路由由 `buildSearchQuery` 追加类型限定词：

```ts
/** 快捷方式项（kind+query 唯一；iconKey/colorKey 为色板与图标网格的键） */
interface ShortcutItem {
  id: string; name: string; kind: string; // 'issues' | 'prs'
  query: string; iconKey: string; colorKey: string; createdAt: number;
}

// 查询串拼装（纯函数）：scopeRepo 非空 → repo:owner/name；scopeOrg 走 WorkFilterState.orgs
// buildShortcutQuery('issues', open, created, all, [], []) === 'is:open author:@me sort:created-desc'
// buildShortcutQuery('prs', open, review_requested, private, [], []) === 'is:open review-requested:@me is:private sort:created-desc'

// Preferences 文件 shortcuts_prefs；key = `shortcuts_v1_${login}`（按账号隔离，同 050 favorites_prefs）
// 值 = ShortcutItem[] 的 JSON，数组顺序即展示顺序

// 打开：pathStack.pushPathByName('searchResults', `${kind}|${query}`)
// —— SearchService.fetchSearchResults(kind, query) 通道（046），issues/prs 均 type: ISSUE + __typename 分诊
```

Scope/仓库建议数据源（同 050 候选同源，取前 3 为仓库建议；选仓库页列表同源全量）：

```graphql
query PickerRepos($first: Int = 100) {
  viewer { repositories(first: $first, affiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER],
           orderBy: { field: PUSHED_AT, direction: DESC }) { nodes { id name owner { login avatarUrl } } } }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| --- | ------ | ------ |
| 云端同步快捷方式 | 公开 API 无 shortcuts 读/写能力 | 端侧 Preferences 按 login 隔离存储；跨设备不同步 |
| 建议数据源=最近访问仓库 | 端侧无仓库浏览史 | 用 viewer 仓库（自有/协作/组织成员，最近推送序）前 3 替代；与官方来源不同、形态一致 |
| 官方 Saved 态截图未覆盖 | 删除/排序交互细节未知 | 按本仓库 FavoritesEdit 行解剖实现（× 移除 + 拖拽/▲▼ + SAVE 快照），后续官方截图到位再校准 |
| 仓库建议加载失败 | 服务端可失败 | 建议区呈现状态行（StateView），全局 3 条建议与 Saved 区不受影响 |
| 重复添加建议 | 两区联动 | 已保存（快照）中同 kind+query 的建议隐藏；addShortcut 幂等去重 |
| Type 切换后筛选键失效 | Issues/PRs 状态选项不同 | 切换时经 resetTick 重置筛选 chips 为默认态（Open / Created by me / all / newest） |
| 快捷方式指向的仓库改名/删除 | 本地存储仍可点击 | 行照常展示，结果列表由搜索服务呈现空态/错误态（官方同类问题） |
| 打开结果页写入 Recent searches | searchResults 通道既有行为 | 接受（快捷方式本质即保存的搜索） |
| Discussions 快捷方式打开 | 公开 API 无 discussions 搜索（GraphQL search type: ISSUE 下 `is:discussion` 实测被忽略、返回普通 Issue，2026-09-21 gh 实测） | 菜单保留 Discussions 项（对齐官方），保存 kind=discussions（查询串不落 is:open）；点击行 toast 明确提示不支持，不给出错误结果 |
| 官方 Type 含 Discussions（2022 公告口径） | 现截图未展示且搜索通道无 Discussions 详情页 | 本批 Type 仅 Issues / Pull Requests，后续按官方截图再扩 |

---

## 六、TDD 验收标准

宿主单测（scripts/ut/unit.test.ts 新增 Shortcuts 节，纯函数进 utils/Shortcuts.ets，同 Favorites 模式；模块顶层禁 $r，保宿主可导入）：

- [x] 测试 1：shortcutsKey(login) 按账号分区，不同 login 键不同
- [x] 测试 2：shortcutsToStorage / shortcutsFromStorage JSON 往返一致；坏数据（非数组 / 缺字段 / 重复 kind+query）兜底剔除
- [x] 测试 3：addShortcut 幂等去重（同 kind+query 不重复入列、新项追加末尾）；removeShortcut 按 id 定位删除；moveShortcut(from, to) 落位正确、越界原样返回
- [x] 测试 4：buildShortcutQuery 组合正确——issues 默认串 / prs 全量串（state=open·closed·merged·queued、scope、visibility、orgs、repos、sort）；不含 `is:issue`/`is:pr` 限定词
- [x] 测试 5：sameShortcutQuery（kind+query 归一键）判定一致性——建议隐藏与 addShortcut 去重共用
- [x] 测试 6：i18n base / zh_CN 双份新增键同名同序；bash scripts/check-spec.sh 通过

模拟器手工走查（不进单测）：Home 两态切换与行点击、管理页增删排序 SAVE/返回丢弃、建议 ⊕ 追加与隐藏联动、创建页 Scope 菜单（All 直选 / Choose 进选仓库页选中回填）/Type/筛选/颜色/图标全链路、从 Work Issues/PRs 漏斗携筛选直达、点击快捷方式出结果列表、切账号互不可见。

---

## 七、备注

- 存储与刷新链路整体复用 050 骨架：utils/Shortcuts.ets（纯函数 + @ObservedV2 ShortcutStore 单例 + Preferences 按 login 分区）× Index 版本泵（`homeShortcutsVersion` 泵 Home 镜像与管理页/创建页刷新）。管理页与创建页均保留底栏（不进 TAB_BAR_HIDDEN_ROUTES，官方两截图均带 Tab）。
- 图标资产：`assets/octicons/icons/`（MIT）拷贝缺失 SVG 入 `entry/src/main/resources/base/media/`（`oct_` 前缀 + 尺寸后缀，024 惯例）。图标网格 36 键按官方截图映射（行序，**2026-09-21 用户对齐官方校正：第2格 issue-opened、第2行 file-diff/code-review/codescan、第5行 hubot/dependabot**）：zap·issue-opened·git-pull-request·comment-discussion·organization·people·briefcase / file-diff·code-review·codescan·comment·copilot·terminal·tools / beaker·alert·eye·telescope·bookmark·calendar·meter / moon·sun·flame·globe·bug·north-star·rocket / squirrel·hubot·dependabot·clock·mention·smiley·person / inbox。颜色板 7 键 = gray·blue·green·orange·red·pink·indigo（用户定案去 purple；red 色对为本批新增 base/dark token，键名 shortcut_red_bg/fg）。
- 建议行字形就近映射（走查校准中）：Mentioned→oct_eye_16 绿；Assigned→oct_repo_forked_16 红（截图为红 Y 叉字形）；Review requested→**oct_code_review_16 蓝（用户 2026-09-21 校正）**；仓库建议→oct_git_compare_16 蓝。建议收藏后 head（首行文案）随 ShortcutItem 持久化，Saved 行原样重现建议行两行文案。图标网格第 2 格 = octicon 原生 **dot（空心圆环）**（用户 2026-09-21 校正：非实心 dot-fill、非自绘带心点）。Home 快捷方式行与管理页 Saved 行同款解剖（tile + head/name 两行文案，用户 2026-09-21 定案）。
- 文案：管理页/创建页标题复用 home_shortcuts（Shortcuts）与新增 shortcut_create_title；「CREATE SHORTCUT」「Saved/Suggested Shortcuts」「Scope/Type」「ALL REPOSITORIES」「Scope 菜单项 All Repositories / Choose Repository（shortcuts_scope_menu_all/choose）」「Mentioned/Assigned/Review requested」等均新增 base/zh_CN 双份键；建议仓库次行 summary 为固定键（Open, Created-desc / 开启，创建时间降序）。
- Work 漏斗接线：WorkFilterBar 漏斗菜单「Create Shortcut」项从 toast 占位改经新事件上抛，WorkIssues/WorkPrs 以 JSON 预填参数 push `shortcutCreate`；IssuesList 的同款占位（063 域）本批不动，后续对齐其筛选模型后接线。
- 预填参数晚于 aboutToAppear：创建页经 @Monitor('prefill') 应用（路由参数时序坑既定对策）；Scope/Type 菜单均为 bindPopup 自定义 builder（isShow 状态驱动 + onStateChange 复位 + measureText 实测宽度）；选仓库页回传经静态槽 + onShown tick（onPop 不触发，坑库定案）。
