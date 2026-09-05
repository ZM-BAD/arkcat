# Spec 056: Explore Tab 官方化（Discover 入口 + Activity 动态流）

> BFS Level: 2
> 关联截图: 官方 App Explore Tab（微信图片_20260906025804，Explore 大标题 + Discover 两入口 + Activity 合并 PR 卡片流）
> 上游 Spec: 003
> 状态: draft

---

## 一、页面/功能概述

Explore 底栏 Tab 页，按官方 App 2026 版式重做：上部 Discover 区提供 Trending Repositories / Awesome Lists 两个入口，下部 Activity 区展示关注网络中的合并 PR 动态卡片流。替代 Spec 003 的占位实现（入口 toast、高星推荐卡、自创 Topics 网格）。

---

## 二、整体 UI 结构

```text
┌──────────────────────────────────────┐
│  Explore（20fp 大标题）               │
├──────────────────────────────────────┤
│  Discover                            │
│  [🔥红方块] Trending Repositories  › │
│  [☺紫方块] Awesome Lists           › │
├──────────────────────────────────────┤
│  Activity（bg_page 灰带全宽）    ⚭filter │
│  ┌─ 白卡（card_background）────────┐ │
│  │ ◉头像+org小像  zccz14 contributed to │
│  │     No-Trade-No-Life / Midas  18m │ │
│  │ ⛁ No-Trade-No-Life / Midas      │ │
│  │ ✨ Add automatic …（PR 标题）     │ │
│  │ [⛓Merged] [分支芯片]           › │ │
│  │ Summary ─────────────────────── │ │
│  │ ・ bullet（超 4 行渐隐）          │ │
│  │        ( Read more › ) 浮层      │ │
│  │ ☺（反应按钮，8 官方 reaction）    │ │
│  └────────────────────────────────┘ │
└──────────────────────────────────────┘
```

二级页 `exploreRepoList`（kind=trending/awesome 共用）：自绘返回头 + RepoCard 列表，空态/加载/错误用 StateView。

---

## 三、元素清单

> 可行性：15 项中 11/15 可行

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
|---|------|------|------|--------|-------------|------|
| 1 | 顶部 | Explore 大标题 | 静态 | ✅ | - | 20fp，同 Home 头部约定 |
| 2 | Discover | 节标题 | 静态 | ✅ | - | |
| 3 | Discover | Trending Repositories 入口 | 跳转列表页 | ✅ | - | 红方块（flame_fg）+ oct_flame_16 白 icon |
| 4 | Discover | Awesome Lists 入口 | 跳转列表页 | ✅ | - | 紫方块（merged_badge_bg 同紫）+ oct_smiley_16 白 icon |
| 5 | Activity 头 | filter 图标 | 类型筛选 | ⚠️ | - | 官方筛选面板无参考图，点击 toast 占位待下批 |
| 6 | 活动卡头 | 贡献者头像+org 小头像/X contributed to/仓库全名/相对时间 | 跳 profile/repo | ✅ | - | org 小头像取 event.org.avatar_url；时间 githubShortTime |
| 7 | 活动卡 | 仓库行（repo 图标+全名） | 跳 repoDetail | ✅ | - | |
| 8 | 活动卡 | PR 标题 | 展示 | ✅ | alias 补 title | |
| 9 | 活动卡 | Merged 徽章+分支芯片+chevron | 跳 prDetail | ✅ | - | 复用 merged_badge_bg/shortcut_blue_bg 令牌 |
| 10 | 活动卡 | Summary 区（bullet+渐隐+Read more 展开） | 展开/收起 | ✅ | alias 补 body | 原生轻量 markdown 解析，展开=全高无内滚（010 定案） |
| 11 | 活动卡 | 反应笑脸按钮 | 8 官方 reaction 选择 | ✅ | addReaction/removeReaction | 复用 041 REACTION_META + mutation |
| 12 | 数据源 | Activity 动态流 | 拉取合并 PR 事件 | ⚠️ | viewer.login + alias | 官方个性化 feed 无公开 API，received_events 近似 |
| 13 | 数据源 | Trending 列表 | 按星近似 | ⚠️ | - | REST search created:>7d sort:stars，官方算法无 API |
| 14 | 数据源 | Awesome Lists 列表 | 精选近似 | ⚠️ | - | REST search topic:awesome-list sort:stars |
| 15 | 二级页 | Trending/Awesome 列表页 | RepoCard 列表 | ✅ | - | 基线样式，待官方参考图再收口 |

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
REST GET /search/repositories?q=created%3A%3E{7天前}&sort=stars&order=desc&per_page=25
REST GET /search/repositories?q=topic%3Aawesome-list&sort=stars&order=desc&per_page=25
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
|----|------|-------------------|
| 官方个性化 Activity feed | 无公开 API | REST received_events（关注者+watch 仓库事件）近似，仅取 merged PR 事件，repo+number 去重、上限 10 条 |
| 官方 Trending 算法 | 无公开 API | REST search 近似（7 天新建按星排序） |
| 官方 Awesome Lists 精选 | 编辑内容无 API | REST search topic:awesome-list 按星近似 |
| Activity filter 面板 | 无官方参考图 | 图标照常渲染，点击 toast 占位，待参考图后实现 |
| Summary 完整 Markdown | 信息流卡片需轻量 | 原生解析 bullet/inline code，剥离链接/图片/标题/围栏行；完整渲染在 prDetail |
| Spec 003 Topics 网格与推荐卡 | 官方页无此区块 | 移除；buildTopicQuery/mapSearchResult/FEATURED_TOPICS 及对应 LogicTest 一并清理 |

---

## 六、TDD 验收标准

- [ ] mapActivityEvents：仅保留 PullRequestEvent 且 payload.action=merged，映射 actor/org 头像/repo/number/headRef/createdAt
- [ ] mapActivityEvents：repo+number 去重（保留最新）、上限 10 条
- [ ] buildPrDetailsQuery：N 条 ref 生成 r0..rN alias，owner/name 引号转义
- [ ] mapPrDetails：事件与 GraphQL 详情合并；PR 已删（alias 为 null）的条目被剔除；author 空时 fallback actor
- [ ] summarizeBody：bullet 行识别、inline code 分段（code=true）、链接/图片/标题行/围栏标记剥离
- [ ] buildTrendingPath/buildAwesomePath：7 天窗口日期与 topic qualifier 拼接
- [ ] 主页面：Discover 两入口跳转、Activity 加载/错误重试/空态渲染
- [ ] 卡片：整体点击进 prDetail，仓库行进 repoDetail，头像/名字进 userProfile，Read more 展开/收起
- [ ] 反应笑脸：picker 选择 add/remove、viewerHasReacted 高亮、失败 toast
- [ ] Dark 模式全部走双套令牌，无新增硬编码色值

---

## 七、备注

- alias 拼接为字符串注入（owner/name 来自 GitHub 事件数据，需转义 `"`/`\`）；GraphQL 形状已按纪律先 `gh api graphql` 实测（author 为 Actor 联合，login/avatarUrl 直取合法；PullRequestEvent 事件体不含 title/body）
- Summary 渐隐浮层 + Read more 沿用 Spec 010 定案（展开=全高无内滚）
- 卡片内多组件实例各自 bindSheet 单实例（041 ReactionBar 同模式已验证）
- 时间短格式 githubShortTime（Inbox 批约定）；复用令牌 merged_badge_bg/shortcut_blue_bg/flame_fg，无新增色值
- Trending/Awesome 二级页为基线样式，官方参考图到位后单独收口
