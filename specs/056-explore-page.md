# Spec 056: Explore Tab 官方化（Discover 入口 + Activity 动态流）

> BFS Level: 2
> 关联截图: 官方 App Explore Tab（微信图片_20260906025804，Explore 大标题 + Discover 两入口 + Activity 合并 PR 卡片流）
> 上游 Spec: 003
> 状态: implemented

---

## 一、页面/功能概述

Explore 底栏 Tab 页，按官方 App 2026 版式重做：上部 Discover 区提供 Trending Repositories / Awesome Lists 两个入口，下部 Activity 区展示关注网络中的合并 PR 动态卡片流。替代 Spec 003 的占位实现（入口 toast、高星推荐卡、自创 Topics 网格）。

---

## 二、整体 UI 结构

Explore 主页（Tab 内容，自上而下）：

1. 顶栏：「Explore」大标题（20fp 加粗，同 Home 头部约定）
2. Discover 分组（节标题）：两个入口行（可点、行尾 ›）
   - Trending Repositories：红方块图标（flame_fg 底 + oct_flame_16 白 icon）
   - Awesome Lists：紫方块图标（oct_smiley_16 白 icon）
3. Activity 分组（bg_page 灰带全宽，组头右侧 Filter 图标）：活动卡列表（card_background 白卡），每卡自上而下：
   - 首行：头像（组织活动含 org 小像）+ 动作文案「zccz14 contributed to No-Trade-No-Life / Midas」+ 相对时间（18m）
   - 仓库行：仓库名（No-Trade-No-Life / Midas）
   - PR 卡：标题（✨ Add automatic …）+ [Merged] 芯片 + 分支芯片 + 行尾 ›
   - Summary 折叠区：bullet 列表（超 4 行渐隐，「Read more ›」浮层可展开）
   - 反应行：☺ 按钮（8 官方 reaction）
   - 后续活动卡同构

二级页 `exploreRepoList`（kind=trending/awesome 共用）：官方参考图到位后已收口（2026-09-07）——

Trending 页（Awesome Lists 无筛选行，同构列表），自上而下：

1. 自绘返回头「← Trending」+ 固定筛选行（Today ∨ / Language ∨ / Spoken lg ∨，不随列表滚动）
2. 列表卡（card_background，横幅/内容/contributors 行/按钮行为兄弟节点分别可点），自上而下：
   - 横幅图（openGraphImageUrl 按比例贴宽；未设置 social preview 的仓库无横幅）
   - avatar + owner（灰）
   - 仓库名（黑 600 + 下划线）
   - 描述（text_primary，最多 4 行）
   - 元信息行：⭐ N（总星数）+ 语言点（● JavaScript）+ 👥 N contributors ›
   - 按钮行三态：未星 = 全宽 [☆ STAR]；已星 = [★] + [＋ ADD TO LIST]
   - 后续仓库卡同构

- Today = 下拉菜单（Today ✓ / This week / This month，FilterDropdownChip 蓝勾）
- Language / Spoken language = 底部 sheet（✕ + 标题 + 蓝色🔍展开搜索框；语言行=色圆点+名称，口语行=纯文本；点选中项=取消筛选）
- Filter Activity 页（Activity 区 filter 图标进入）：返回 + Filter Activity + SAVE；六类勾选行（蓝复选框+彩色圆角图标+名称），SAVE 持久化 Preferences 后返回

---

## 三、元素清单

> 可行性：16 项中 11/16 可行

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | 顶部 | Explore 大标题 | 静态 | ✅ | - | 20fp，同 Home 头部约定 |
| 2 | Discover | 节标题 | 静态 | ✅ | - | |
| 3 | Discover | Trending Repositories 入口 | 跳转列表页 | ✅ | - | 红方块（flame_fg）+ oct_flame_16 白 icon |
| 4 | Discover | Awesome Lists 入口 | 跳转列表页 | ✅ | - | 紫方块（merged_badge_bg 同紫）+ oct_smiley_16 白 icon |
| 5 | Activity 头 | filter 图标 | 跳 Filter Activity 页 | ✅ | - | 六类勾选 + SAVE（2026-09-07 收口） |
| 6-12 | Activity 卡 | （沿用官方化首版，未变） | - | ✅ | - | 接收事件近似，仅 merged PR |
| 13 | 数据源 | Trending 列表 | 按星近似 | ⚠️ | - | REST search pushed:>N sort:stars，官方算法无 API |
| 14 | 数据源 | Awesome Lists 列表 | 精选近似 | ⚠️ | - | REST search topic:awesome-list sort:stars |
| 15 | 二级页 | Trending/Awesome 列表页 | 官方风卡列表 | ✅ | 补横幅 + meta | 官方参考图到位已收口 |
| 16 | 二级页 | 筛选行（Today/Language/Spoken language） | 服务端重过滤 | ✅ | - | 仅 Trending；qualifier 实测服务端有效 |
| 17 | 二级页 | Today 下拉菜单（3 项蓝勾） | 窗口切换 | ⚠️ | - | 窗口=pushed:>N 活跃近似（非官方今日增量星） |
| 18 | 二级页 | Language/Spoken sheet（✕+标题+🔍+搜索） | 语言/口语过滤 | ✅ | - | 语言=GET /languages 全量 833 项（免认证）+ linguist 色表 751 项 + 常用 7 项置顶；口语=内置 184 项 |
| 19 | 列表卡 | 横幅图（openGraphImageUrl 按比例贴宽） | 展示 | ✅ | repository.openGraphImageUrl | 未设置 social preview 的仓库无横幅 |
| 20 | 列表卡 | ⭐ N（总星数）+ 语言点 + 👥 N contributors › | 展示/跳转 | ⚠️ | contributors 无 GraphQL 字段 | 星数=仓库**总**星数（GitHub 无每日新增星公开接口，故不标 today）；contributors=REST Link rel=last 页数（精确总数，展示不压缩） |
| 21 | 列表卡 | 三态按钮（全宽 STAR / ★ + ADD TO LIST） | star/列表 mutation | ✅ | addStar/removeStar/updateUserListsForItem | ADD TO LIST 未星先自动 star |
| 22 | Filter Activity | 六类勾选行 + SAVE | 类型设置持久化 | ⚠️ | - | 勾选存 Preferences；仅 merged PR 近似 Follows；Recommendations 行图标为**有意偏离官方**（见 §七） |
| 23 | 页面 | Dark 模式 | 双套令牌 | ✅ | - | 无新增硬编码色值 |

---

## 四、核心 GraphQL / REST 接口

```graphql
# viewer 登录名（REST received_events 需要路径参数）
query { viewer { login } }

# 事件补详情：REST received_events 过滤出 merged PullRequestEvent 后，
# 按条数动态生成 r0..rN alias，单请求批量取标题/正文/作者/反应组
query ExploreActivity {
  r0: repository(owner: "No-Trade-No-Life", name: "Midas") {
    pullRequest(number: 383) {
      id
      title
      body
      merged
      author { login avatarUrl }
      reactionGroups { content viewerHasReacted reactors { totalCount } }
    }
  }
  # r1: … rN: …
}
```

```text
REST GET /users/{login}/received_events?per_page=60   # 过滤 type=PullRequestEvent 且 payload.action=merged
REST GET /search/repositories?q=pushed%3A%3E{窗口起点 ISO 日期}&sort=stars&order=desc&per_page=25
REST GET /search/repositories?q=topic%3Aawesome-list&sort=stars&order=desc&per_page=25
REST GET /search/repositories?q=...%20language%3AGo%20spoken_language%3AEnglish&...
  # 语言/口语 qualifier 服务端过滤（2026-09-07 实测有效）
REST GET /repos/{owner}/{name}/contributors?per_page=1&anon=0
  # Link 头 rel="last" 的 page 数 = 贡献者数（GraphQL Repository 无 contributors 字段）
```

```graphql
# 列表元信息（r0..rN alias 单请求批量补全，失败降级 REST-only）
query ExploreRepoMeta {
  r0: repository(owner: "anomalyco", name: "opencode") {
    openGraphImageUrl
    viewerHasStarred
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 官方个性化 Activity feed | 无公开 API | REST received_events（关注者+watch 仓库事件）近似，仅取 merged PR 事件，repo+number 去重、上限 10 条 |
| 官方 Trending 算法 | 无公开 API | REST search 近似（pushed:>N 近 N 天活跃按星排序） |
| 官方 Awesome Lists 精选 | 编辑内容无 API | REST search topic:awesome-list 按星近似 |
| 「今日获星」/「本周获星」窗口 | 增量星数无公开 API | 窗口=pushed:>N 近 N 天活跃近似（created 窗口实测筛空，2026-09-07 Chinese 0 条）；★ 文案只显示仓库总星数、不标注 today；默认 Today（与官方一致） |
| Activity 六类（Announcements/Releases/Stars/Repositories/Follows/Recommendations） | 其余五类无公开数据源 | Filter Activity 页完整实现（勾选+SAVE 持久化）；内容侧仅 merged PR 动态（近似 Follows），关闭 Follows 后 Activity 区为空 |
| 语言/口语筛选列表 | 官方 App 走内部端点 | 语言=GET /languages 全量 833 项（免认证）+ linguist 色表 751 项 + 常用 7 项置顶；口语=内置 184 项；选中后服务端 qualifier 过滤，非纯客户端 |
| 横幅图 | 官方沿用仓库社交预览图 | repository.openGraphImageUrl（1200x630 social preview，按比例贴宽高自适应）；无自定义预览的仓库不显示横幅 |
| contributors 计数 | GraphQL 无 contributors 字段 | REST /contributors?per_page=1 的 Link last 页 = 总贡献者数（不存在=0） |
| 广告/赞助卡（openwhispr 式） | 无广告源 | 不渲染，仅普通仓库卡 |
| Summary 完整 Markdown | 信息流卡片需轻量 | 原生解析 bullet/inline code，剥离链接/图片/标题/围栏行；完整渲染在 prDetail |
| Spec 003 Topics 网格与推荐卡 | 官方页无此区块 | 移除；buildTopicQuery/mapSearchResult/FEATURED_TOPICS 及对应 LogicTest 一并清理 |

---

## 六、TDD 验收标准

- [x] mapActivityEvents：仅保留 PullRequestEvent 且 payload.action=merged，映射 actor/org 头像/repo/number/headRef/createdAt
- [x] mapActivityEvents：repo+number 去重（保留最新）、上限 10 条
- [x] buildPrDetailsQuery：N 条 ref 生成 r0..rN alias，owner/name 引号转义
- [x] mapActivityEventsWithDetails：事件与 GraphQL 详情合并；PR 已删（alias 为 null）的条目被剔除；author 空时 fallback actor
- [x] summarizeBody：bullet 行识别、inline code 分段（code=true）、链接/图片/标题行/围栏标记剥离
- [x] buildRepoListPath：窗口/语言/口语 qualifier 组合（trending=pushed:>N，awesome=topic；空 qualifier 不拼）
- [x] mapSearchRepos：node_id → graphqlId；语言色走 programLanguageColor（linguist 色表 751 项）
- [x] contributorCount：Link rel="last" 页数解析；>=1 无分页=1；空数组/非法=0
- [x] buildRepoMetaQuery/mapRepoMeta：r0..rN alias 补 openGraphImageUrl/viewerHasStarred；alias 为 null 保留 REST 原值
- [x] 主页面：Discover 两入口跳转、Activity 加载/错误重试/空态渲染
- [x] 列表页：筛选行三 chip 交互（Today 下拉改窗口重拉；Language/Spoken sheet 搜索/选中/再点取消）
- [x] 列表卡：横幅按比例；三态按钮（STAR→★+ADD TO LIST；★→STAR；ADD TO LIST 未星先自动 star）
- [x] 卡片：整体点击进 repoDetail，contributors 行进贡献者页，按钮区独立不冒泡
- [x] 活动卡：整体点击进 prDetail，仓库行进 repoDetail，头像/名字进 userProfile，Read more 展开/收起
- [x] Filter Activity：六类勾选翻转、SAVE 持久化（Preferences explore_activity_kinds）、Explore 按保存类型过滤
- [x] Dark 模式全部走双套令牌，无新增硬编码色值

---

## 七、备注

- alias 拼接为字符串注入（owner/name 来自 GitHub 事件数据，需转义 `"`/`\`）；GraphQL 形状已按纪律先 `gh api graphql` 实测（author 为 Actor 联合，login/avatarUrl 直取合法；PullRequestEvent 事件体不含 title/body）
- Summary 渐隐浮层 + Read more 沿用 Spec 010 定案（展开=全高无内滚）
- 卡片内多组件实例各自 bindSheet 单实例（041 ReactionBar 同模式已验证）
- 时间短格式 githubShortTime（Inbox 批约定）；复用令牌 merged_badge_bg/shortcut_blue_bg/flame_fg，无新增色值
- Trending/Awesome 二级页已于 2026-09-07 按官方参考图收口（筛选行/横幅卡/三态按钮/Filter Activity 页）；
  语言列表 = `GET /languages` 全量 833 项（失败降级内置子集），口语列表 = 内置常见子集（官方 App 走内部端点，详见边界表）
- Language 面板（✕ + 标题 + 🔍 内联搜索 + 色点行）已组件化为 `components/LanguageFilterSheet`，与 Spec 037 仓库列表页共用；Spoken 面板仍为页内自绘（无第二处复用）
- **Recommendations 行图标：有意偏离官方，不得改回（强调项）**——官方 App 该行用的是 `mark-github`，即 **GitHub logo 本体**；ArkCat 不引入任何 GitHub 官方徽标（spec 024 §五），故改用中性图标 `oct_graph_stacked_area_16`（黑底 `text_primary` + 白图标不变）。这是 Filter Activity 页六类中**唯一**与官方参考图不一致的位置，其余五类（megaphone / tag / star / repo / person-add）与官方一致。依据是 GitHub 品牌指南原文「Do not use any GitHub logo as the icon or logo for your business/organization」——第三方把 GitHub logo 用作自家界面元素会构成来源混淆，且 MIT 许可不覆盖 logo 类文件。后续按官方参考图复刻此页时，**不得**把该行改回 mark-github。
