# Spec 072: Profile Pinned → Popular 兜底（无 Pin 展示热门仓库）

> BFS Level: 2
> 关联截图: 无官方对照截图（官方 App 无 Pin 用户的主页展示 Popular repositories 区；用户 2026-09-20 口述驱动）
> 上游 Spec: 005（User Profile Pinned 区）、035（Profile 改造）
> 状态: implemented（2026-09-20 状态回写：随 PR #55 squash 合并 develop=baa9029，CI 绿；走查确认后合并）

---

## 一、页面/功能概述

查看他人主页时，若该用户**没有 Pinned 仓库**，原 Pinned 区改为 **Popular 区**（star 图标 + Popular 标题，横滑仓库卡展示**最多 6 个**仓库、按 star 数从高到低）；若该用户**一个可见仓库都没有**（无 public repo），则整个区块（标题行 + 卡片行）都不展示。本人主页同规则（官方本人无 Pin 时同样展示 Popular）。数据与卡片组件全复用现有管线。

---

## 二、整体 UI 结构

Pinned 区（Profile 头部卡与三导航行之间，既有位置）三态：

1. **有 Pinned**（现状不变）：oct_pin 图标 + 「Pinned」标题 + 横滑仓库卡（isPinned 形态）
2. **无 Pinned、有可见仓库**：oct_star 图标 + 「Popular」标题 + 横滑仓库卡（普通形态，同 RepoCard，最多 6 张，star 降序）
3. **无 Pinned 且无可见仓库**：标题行与卡片行整体不渲染（区块消失，下方导航行直接上移）

---

## 三、元素清单

可行性：6/6 全部可行

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | 主查询 | `popular` 别名字段 | 取 star 降序前 6 个自有可见仓库 | ✅ | `repositories(first: 6, ownerAffiliations: OWNER, orderBy: {field: STARGAZERS, direction: DESC})` | 节点字段与 pinnedItems 完全同形（mapRepo 复用）；他人主页仅返回可见（public）仓库 |
| 2 | 模型 | UserProfile.popular: RepoSummary[] | Popular 卡片数据 | ✅ | mapProfile 扩展 | pinned 为空时 UI 才消费 |
| 3 | Pinned 区标题 | star 图标 + Popular | 区块标题（无 Pin 时） | ✅ 纯 UI | — | oct_star_16；字面 Popular（用户 2026-09-20 拍板），zh「热门」 |
| 4 | Pinned 区卡片 | 横滑仓库卡（Popular 态） | 打开仓库 | ✅ | — | RepoCard 复用，isPinned=false；ForEqEach key=id/nameWithOwner（既有） |
| 5 | 区块显隐 | 三态切换 | pinned 非空→Pinned；popular 非空→Popular；两者皆空→整区隐藏 | ✅ 纯 UI | — | 皆空等价于无可见仓库（GraphQL 对他人只回可见仓库；nodes 为空 ⟺ totalCount 为 0） |
| 6 | 关注联动 | toggleFollow 后的 profile 重建 | popular 字段透传不丢 | ✅ | — | Profile 页 toggleFollow 乐观更新处的 UserProfile 字面量同步补字段 |

---

## 四、核心接口

```graphql
# 主查询新增别名节点（与 pinnedItems 同批返回，无额外请求）
query UserProfile($login: String!) {
  user(login: $login) {
    # …既有字段…
    pinnedItems(first: 6, types: [REPOSITORY]) { nodes { ... on Repository { … } } }
    popular: repositories(first: 6, ownerAffiliations: OWNER, orderBy: {field: STARGAZERS, direction: DESC}) {
      nodes { ... on Repository { … 同 pinnedItems 节点字段 … } }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ---- | ------------------- |
| fork 仓库是否计入 Popular | 官方未证实是否排除 fork；GraphQL 侧无官方口径 | 不做 fork 过滤，按 star 直排（§七 推断项，走查可再收） |
| 「无 public repo」判定 | GraphQL 对他人只返回可见（public）仓库 | popular nodes 为空 ⟺ 无可见仓库 ⟺ 整区隐藏；私有仓库不参与 |
| 本人主页 | 官方本人无 Pin 时同样展示 Popular | 与他人主页同规则，不做区分 |
| Popular 的分页/更多入口 | 官方 Popular 区固定最多 6 个，无「更多」 | first: 6 定长，无分页 |

---

## 六、TDD 验收标准

- [x] bash scripts/check-spec.sh 通过
- [x] 宿主单测不回归（bash scripts/ut/run-local-tests.sh）
- [x] 宿主单测：mapProfile popular 映射（节点→RepoSummary、pinned 空场景、字段透传）
- [x] 模拟器：无 Pin 用户主页显示 star 图标 + Popular 标题，卡片按 star 降序、最多 6 张，点击进仓库详情
- [x] 模拟器：有 Pin 用户主页不变（Pinned 态回归）
- [x] 模拟器：无任何可见仓库用户主页，标题行与卡片行都不展示
- [x] 模拟器：本人主页（tab4）无 Pin 时同样出现 Popular；关注/取关后区块不消失（toggleFollow 重建透传 popular）
- [x] base/zh_CN 新增 key 对齐；硬编码颜色/字号门禁通过

---

## 七、备注

- 排序与口径：`orderBy STARGAZERS DESC` + `ownerAffiliations OWNER`；fork 是否排除为推断项（未过滤），官方对照截图缺，走查时可依观感再收。
- 标题字面「Popular」为用户 2026-09-20 拍板（官方 web 全称 Popular repositories，移动端截图未捕获）；star 图标用 oct_star_16（描边态，与 Pinned 的 oct_pin_16 同权重）。
- 纯映射扩展进宿主单测（ProfileModels.mapProfile）；UI 为 Profile.ets 单区块三态条件渲染，无新组件。
