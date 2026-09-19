# Spec 073: Profile 导航行增补 Sponsoring / Projects

> BFS Level: 2
> 关联截图: 官方 App 2026-09-20 截图 1 张（Repositories/Organizations/Starred 下方 Sponsoring 粉块心形 + Projects 灰块表格，含计数）
> 上游 Spec: 005（User Profile 导航行）、035（ProfileNavRows）
> 状态: implemented（2026-09-20 状态回写：随 PR #55 squash 合并 develop=baa9029，CI 绿；走查确认后合并）

---

## 一、页面/功能概述

Profile 导航入口组（ProfileNavRows）在 Repositories / Organizations / Starred 三行下新增两行：**Sponsoring**（粉底白心形，计数=该用户作为 sponsor 的在效赞助数）与 **Projects**（灰底白表格，计数=该用户 Projects V2 数量）。**两行计数为 0 时整行隐藏，非 0 才显示**（走查定案）。计数走主查询同批返回，零额外请求；两行点击暂为占位 toast（详情列表页后续立项）。

---

## 二、整体 UI 结构

1. ProfileNavRows（既有单卡片容器）五行：Repositories / Organizations / Starred（不变）+ **Sponsoring**（oct_heart_16 白字形 + 粉块）+ **Projects**（oct_project_16 白字形 + 灰块）
2. 行结构复用既有 navRow：44 彩块图标 + 标签 + 右缘计数

---

## 三、元素清单

可行性：6/6 全部可行

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | 主查询 | 赞助计数 | Sponsoring 行计数 | ✅ | `sponsorshipsAsSponsor { totalCount }` | 与既有字段同批返回 |
| 2 | 主查询 | 项目计数 | Projects 行计数 | ✅ | `projectsV2 { totalCount }` | ProjectV2Connection 有 totalCount（schema 实证）；对齐官方 V2 口径 |
| 3 | Sponsoring 行 | oct_heart_16 + 粉块 + 标签 + 计数 | 展示+占位点击 | ✅ | — | 块色=shortcut_pink_fg（#BF3989，Primer pink，与橙/黄块同 token 族）；**计数 0 整行隐藏**；tap=占位 toast |
| 4 | Projects 行 | oct_project_16 + 灰块 + 标签 + 计数 | 展示+占位点击 | ✅ | — | 块色=text_tertiary（#8C959F，贴截图灰）；标签复用 home_work_projects（Projects/项目）；**计数 0 整行隐藏**；tap=占位 toast |
| 5 | 图标资产 | heart-16 / project-16 入库 | OctIcon 渲染 | ✅ | — | 自 assets/octicons 复制为 oct_heart_16 / oct_project_16（资产按需复制惯例） |
| 6 | 数据透传 | UserProfile 扩展两计数 | 关注乐观更新不丢 | ✅ | — | mapUserProfile 映射 + toggleFollow 字面量透传 |

---

## 四、核心接口

```graphql
# 主查询新增两个计数字段（同批返回，无额外请求）
query UserProfile($login: String!) {
  user(login: $login) {
    # …既有字段…
    sponsorshipsAsSponsor { totalCount }
    projectsV2 { totalCount }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ---- | ------------------- |
| Sponsoring / Projects 详情页 | 均无现成页面（官方为 Sponsoring 列表页 / Projects 列表页） | 行点击=占位 toast（与 RepoDetail CHANGE 接通前同模式）；两个列表页后续单独立 spec |
| 组织主页 | OrgProfile 走独立组件，不用 ProfileNavRows | 本期仅个人主页出现两行；组织侧后续对齐官方另行处理 |
| 经典 Projects 口径 | 官方计数为 Projects V2；经典 projects 字段已废弃 | 计数取 `projectsV2`，不用经典 `projects` |

---

## 六、TDD 验收标准

- [x] bash scripts/check-spec.sh 通过
- [x] 宿主单测不回归（bash scripts/ut/run-local-tests.sh）
- [x] 模拟器：五行顺序与配色（Repositories 深灰 / Organizations 橙 / Starred 黄 / Sponsoring 粉 / Projects 灰）、计数正确；**Sponsoring/Projects 计数为 0 时对应行不显示**
- [x] 模拟器：Sponsoring / Projects 行点击出占位 toast；既有三行跳转不回归
- [x] 模拟器：关注/取关后两行计数不丢（乐观更新透传）
- [x] base/zh_CN 新增 key 对齐；硬编码颜色/字号门禁通过

---

## 七、备注

- 块色沿用「fg 色 token 作彩块底」家族口径（ Organizations=shortcut_orange_fg 同理）：Sponsoring=shortcut_pink_fg、Projects=text_tertiary；截图中粉色更浅（≈pink-400），本版取 Primer pink 族现成 token，观感偏差走查时再议。
- Sponsoring 计数=「TA 赞助了谁」（sponsorshipsAsSponsor），与官方他人主页 Sponsoring 行语义一致；isSponsoredBy（TA 的赞助者）不在本行。
- Projects 标签复用 home_work_projects（Projects/项目），不另开 key。
- 纯计数透传，无新增纯函数；宿主单测仅回归。
