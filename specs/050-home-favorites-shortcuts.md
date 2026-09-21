# Spec 050: Home 个性化（Favorites 收藏）

> BFS Level: 3
> 关联截图: 官方 App 2026-09-20 截图 5 张——Home Favorites 有值态/空态 + Favorites 编辑页三态（默认拖拽 / ⋮ 菜单展开 / 重排按钮模式）
> 上游 Spec: 013（Home 官方布局）、016（Edit My Work 交互范式）、043（Picker 数据源）
> 状态: implemented（2026-09-20 实现；Shortcuts 拆分至 Spec 074，2026-09-21 回写）

---

## 一、页面/功能概述

Home 页 Favorites 区块从 013 的静态空态占位接通为真功能：有收藏时区块按用户定义顺序列出收藏仓库行，区块头右侧 ⋯ 进入 Favorites 编辑页；编辑页负责增删、排序（拖拽 / 重排按钮两模式）与添加（Top Repositories 候选 + 全 GitHub 搜索）。收藏为端侧按账号隔离持久化——官方为服务端同步，但公开 API 无 favorites 能力（见四）。Shortcuts 区块拆分至 Spec 074。

---

## 二、整体 UI 结构

1. Home 页 Favorites 区块（013 布局内嵌区块，两种状态互斥）：
   - 空态：区块标题「Favorites」+ 居中引导文案 + ADD FAVORITES 全宽描边钮，点击进编辑页（现状保留，仅接通入口）
   - 有值态：区块头行「Favorites」+ 右侧 kebab-horizontal 三点（44×44 触点）进编辑页；下方收藏仓库行列表（owner 头像 + owner login 次级色字 + 仓库名主色字），点击行进仓库详情
2. Favorites 编辑页（新全屏 NavDestination `favoritesEdit`，隐藏底栏 Tab）：
   - App Bar（自绘，016 范式）：返回 + 标题「Favorites」+ SAVE 蓝色文字钮 + 蓝色竖三点 ⋮（菜单单项 Show / Hide reorder actions，标签随当前模式取反）
   - 搜索框：🔍 图标 +「Search Repositories」占位，内联圆角描边样式
   - Selected 区：区块标题 + 已选仓库行——行首灰底 × 圆钮（移除）；行尾常态 grabber 六点拖拽柄（拖拽排序），重排模式切换为 ▲▼ 逐格钮（首行 ▲ / 末行 ▼ 置灰不可点）
   - Select Repositories 区：区块标题 + 候选仓库行（行尾蓝色 ⊕ 添加）——未搜索时为 Top Repositories（本人/协作/组织成员仓库 ∪ 本人参与过的仓库，最近推送序前 100），输入搜索词后为全 GitHub 仓库搜索结果；已选仓库不出现在候选区
   - 两区之间以页面底色分隔带区隔（官方为灰隙分段）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | ------ | ------ | ------ |
| 1 | Home·区块头 | 标题 + kebab 三点入口 | 进编辑页 | ✅ | 无（本地） | 空态时官方无 ⋯，入口为 ADD FAVORITES 钮 |
| 2 | Home·收藏行 | 头像 + owner + 仓库名 | 点击进 repoDetail | ✅ | 无（本地缓存渲染） | ownerAvatar 添加时缓存，离线可渲染 |
| 3 | Home·空态 | 引导文案 + ADD FAVORITES | 进编辑页 | ✅ | 无 | 复用既有 home_favorites_* 字符串 |
| 4 | 编辑页·App Bar | 返回 / SAVE / ⋮ 菜单 | 保存返回；切换重排模式 | ✅ | 无 | ⋮ 标签随模式取反（016 范式） |
| 5 | 编辑页·搜索框 | 🔍 + Search Repositories | 输入触发全局搜索 | ✅ | search(type: REPOSITORY) | 复用 RepoSubService.searchPickerRepos |
| 6 | 编辑页·Selected 行 | × / 拖拽柄 / ▲▼ | 移除；拖拽或逐格排序 | ✅ | 无 | List onMove 拖拽（016 范式）；首末行边界置灰 |
| 7 | 编辑页·候选区（默认） | Top Repositories + ⊕ | 追加到 Selected 末尾 | ✅ | viewer.repositories ∪ repositoriesContributedTo | 复用 RepoSubService.fetchPickerRepos |
| 8 | 编辑页·候选区（搜索） | 全 GitHub 结果 + ⊕ | 追加到 Selected 末尾 | ✅ | search(type: REPOSITORY) | 已选仓库从结果中隐藏；竞态用代际守卫（043 范式） |
| 9 | 数据·持久化 | 收藏列表按 login 分区 | 跨会话保留、切账号互不可见 | ✅ | 无（Preferences） | WorkConfig Store 单例范式 |
| 10 | 数据·云端同步 | 官方服务端同步收藏 | 跨设备一致 | ❌ | 公开 schema 无 favorites 读写字段 | 端侧存储替代，详见五 |

> 可行性: 9/10 可行（云端同步 ❌ 不做）

---

## 四、核心接口片段

```graphql
# 候选默认列表（Top Repositories）——复用 RepoSubService.VIEWER_REPOS_QUERY（043 选仓同源）
query PickerRepos($first: Int = 100) {
  viewer {
    repositories(first: $first, affiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER],
                 orderBy: { field: PUSHED_AT, direction: DESC }) {
      nodes { id name owner { login avatarUrl } }
    }
    repositoriesContributedTo(first: $first, includeUserRepositories: false) {
      nodes { id name owner { login avatarUrl } }
    }
  }
}

# 全 GitHub 仓库搜索——复用 RepoSubService.SEARCH_PICKER_REPOS_QUERY
query SearchPickerRepos($query: String!, $first: Int = 20) {
  search(query: $query, type: REPOSITORY, first: $first) {
    nodes { ... on Repository { id name owner { login avatarUrl } } }
  }
}
```

收藏本体不走网络（公开 GraphQL schema 无 favorites 读写字段：2026-09-20 octokit/graphql-schema 全文 grep「favorit」零匹配；pinnedItems 为 Profile 语义，不适用 Home）：

```ts
/** 收藏项（添加时从候选/搜索结果缓存头像） */
interface FavoriteRepo { ownerLogin: string; name: string; ownerAvatar: string; addedAt: number }

// Preferences 文件 favorites_prefs；key = `favorites_v1_${login}`（按账号隔离）
// 值 = FavoriteRepo[] 的 JSON，数组顺序即展示顺序
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| --- | ------ | ------ |
| 云端同步收藏 | 公开 API 无 favorites 读/写能力 | 端侧 Preferences 按 login 隔离存储；跨设备不同步 |
| 收藏仓库被删 / 转私有 | 本地缓存仍可渲染 | 行照常展示，点击进 repoDetail 由详情页呈现错误态 |
| 候选仓库超 100 | VIEWER_REPOS_QUERY 单页上限 | Top Repositories 取前 100，不做分页 |
| 搜索无结果 / 网络失败 | 服务端搜索可失败 | 候选区呈现空态 / 错误态 + 重试（StateView 语义） |
| 重复添加 | 两区联动 | 已选仓库从候选区与搜索结果中隐藏，天然去重 |
| 未 SAVE 返回 | 官方为静默丢弃（用户定案） | 编辑快照不落盘，直接 pop |

---

## 六、TDD 验收标准

宿主单测（scripts/ut/unit.test.ts 新增 Favorites 节，纯函数进 utils/Favorites.ts 同 WorkConfig 模式）：

- [ ] 测试 1：favoritesKey(login) 按账号分区，不同 login 键不同
- [ ] 测试 2：favoritesFromStorage / favoritesToStorage JSON 往返一致；坏数据（非数组 / 缺字段）兜底空数组
- [ ] 测试 3：addFavorite 幂等去重（同 owner/name 不重复入列、新项追加末尾）；removeFavorite 按 owner/name 定位删除
- [ ] 测试 4：moveFavorite(from, to) 落位正确，越界原样返回（同 016 moveWorkSection 语义）
- [ ] 测试 5：filterCandidates(candidates, favorites) 从候选与搜索结果中过滤已选仓库
- [ ] 测试 6：搜索词 trim 后为空判定为不可搜索（isSearchable）
- [ ] 测试 7：i18n base / zh_CN 双份新增键同名同序；bash scripts/check-spec.sh 通过

模拟器手工走查（不进单测）：Home 两态切换、区块头 ⋯ 与 ADD FAVORITES 双入口、增删联动、拖拽与 ▲▼ 排序边界置灰、SAVE 回 Home 即时生效、返回静默丢弃。

---

## 七、备注

- Shortcuts 区块拆分至 Spec 074（2026-09-21 官方截图驱动另立，本 Spec 不再覆盖）。
- 编辑页交互范式整体复用 Spec 016 EditMyWork：⋮ 菜单标签随模式取反（bindMenu 数组不随状态刷新，需显式重建）、List onMove 拖拽、▲▼ 逐格移动、快照编辑。菜单与保存文案复用既有 edit_work_save / edit_work_show_reorder / edit_work_hide_reorder 键（官方菜单项即「Show reorder actions」，再次点开为「Hide reorder actions」）。
- SAVE 成功落盘后 pop 回 Home 且立即反映——走 Index.ets 参数泵（同 016 workVersion 模式）刷新 Home。
- 官方两态入口：有值态区块头 ⋯、空态 ADD FAVORITES 钮，均进同一编辑页。
- 多账号：Home 已有 token @Monitor 刷新链路，收藏键随 login 切换。
