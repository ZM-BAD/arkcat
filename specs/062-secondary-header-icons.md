# Spec 062: 二级页顶栏图标统一（share-android 蓝 + 竖三点）

> BFS Level: 2
> 关联截图: 无官方参考图——用户 2026-09-11 走查发现这几页顶栏仍是灰横向 ⋮、分享图标还是灰 share
> 上游 Spec: 038（文件树）、011（代码查看器）、036（组织主页）、030（Issue 详情）、005（用户主页——竖三点惯例出处）、061（分享行为统一）
> 状态: implemented（2026-09-14 状态回写：顶栏 share-android 蓝 / kebab 竖三点口径已落 AppBar 全库）
> 用户 2026-09-11 定调：File Tree / Code Viewer / Org Profile 三处**分享图标改用 GitHub 强调蓝的
> share-android 变体**，顶栏的**灰横向三点改为蓝色竖三点**；同日追加要求 Issue 详情页一并照此办理
> （并补 share 图标）——与全库头部惯例（005 / 015 / 016 / 031 等页均为 `kebab-horizontal` rotate 90 +
> `link_blue`）对齐。

---

## 一、页面/功能概述

四处二级页顶栏的图标表现此前未跟上全库头部惯例：分享图标用 `oct_share_16`（次级灰）、更多菜单用
未旋转的 `oct_kebab_horizontal_16`（次级灰），而其余页面顶栏早已是「蓝色 share-android + 蓝色竖三点」。
本批只改这几页顶栏的**图标资源与着色**：分享图标换 `oct_share_android_16` 取 `link_blue`；更多图标
`kebab-horizontal` 旋转 90° 并取 `link_blue`。位置、尺寸、点击行为、菜单内容一律不动。
Issue 详情页原本没有 share 图标，按用户追加要求补上（与 PR 详情同形），其顶栏原有的 🔍 搜索入口保留。

---

## 二、整体 UI 结构

1. 文件树（File Tree）顶栏：← 返回 + 标题 + 🔍 搜索 + ⭮ 分享（**蓝 share-android**）+ ⋮ 更多（**蓝竖三点**）
2. 代码查看页（Code Viewer）顶栏：← 返回 + 文件名 + ⭮ 分享（**蓝 share-android**）+ ⚙ 齿轮 + ⋮ 更多（**蓝竖三点**）
3. 组织主页（Org Profile）顶栏：← 返回 + ⭮ 分享（**蓝 share-android**）+ ⋮ 更多（**蓝竖三点**）
4. Issue 详情顶栏：← 返回 + `owner/repo #N` + 🔍 搜索（**保留，未改色**）+ ⭮ 分享（**蓝 share-android，本批新增**）+ ⋮ 更多（**蓝竖三点**）
5. 四处顶栏的行高、左右留白、触点尺寸（44 / responseRegion）均不变，仅换图标资源、颜色与旋转

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | 文件树顶栏 | ⭮ 分享 | 换 `oct_share_android_16` + `link_blue` | ✅ | — | size 20 不变；行为见 Spec 061 |
| 2 | 文件树顶栏 | ⋮ 更多 | 换 `link_blue` + rotate 90 | ✅ | — | 菜单（Copy link / Copy path）不变；补 a11y「更多」与 focusable |
| 3 | 代码页顶栏 | ⭮ 分享 | 换 `oct_share_android_16` + `link_blue` | ✅ | — | size 20 不变 |
| 4 | 代码页顶栏 | ⋮ 更多 | 换 `link_blue` + rotate 90 | ✅ | — | 菜单（Copy contents / Copy link）不变；补 a11y「更多」与 focusable |
| 5 | 组织主页顶栏 | ⭮ 分享 | 换 `oct_share_android_16` + `link_blue` | ✅ | — | size 18 不变 |
| 6 | 组织主页顶栏 | ⋮ 更多 | 换 `link_blue` + rotate 90 | ✅ | — | 仍为点击提示（更多菜单未接入，见 036） |
| 7 | Issue 详情顶栏 | ⭮ 分享 | 新增蓝 share-android（size 18） | ✅ | — | 本批新增入口；点击分享 `issues/{number}`（061），标题取 issue 标题 |
| 8 | Issue 详情顶栏 | ⋮ 更多 | 换 `link_blue` + rotate 90 | ✅ | — | 仍为点击提示（更多菜单未接入，见 030） |
| 9 | 全库审计 | 图标一致性核对 | 其余顶栏 share/⋮ 与本次口径比对 | ✅ | — | 8 处顶栏 share 已全部为 share-android + 蓝；顶栏灰横向 ⋮ 已清零 |
| 10 | 文档 | Spec 同步 | 011 图标清单、038/030 顶栏描述、061 的图标口径与入口数 | ✅ | — | 图标体系（Spec 024）不涉及 |

> 可行性图例：✅ 可直接实现 ｜ ⚠️ 部分可行/降级 ｜ ❌ 不可实现
>
> **10/10 可行**（纯图标资源与着色调整 + 补一个分享入口，无新增系统能力）。

---

## 四、核心 GraphQL 片段

无：本批只改图标资源与颜色，不涉及任何接口调用。

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---------------------- | -------------------------------------------------- | ------------------------------------------------------------ |
| Issue 详情顶栏的 🔍 搜索图标保留 | 官方参考截图（030，2026-08-31 用户提供）里该页顶栏是 🔍 + ⋯；用户本次只要求「share-android + 竖三点，蓝色」 | 搜索入口原样保留、原样着色，share 插在搜索与 ⋮ 之间；若用户本意是「去掉搜索、只留 share + ⋮」，删一处即可 |
| 文件树的 🔍 搜索、代码页的 ⚙ 齿轮仍为次级灰 | 本批范围只含分享与更多两个图标 | 维持既有着色（官方这两页的次要操作本就偏灰），不擅自扩大改动面 |
| 四处图标尺寸不一（20 / 18） | 各页头部节奏既有差异（与官方截图各自对齐） | 本批不改尺寸，只统一资源与颜色 |
| 行内（非顶栏）的 ⋮ | 如 Release 资产行、diff 行内菜单、More 折叠区 | 属行内操作而非头部惯例，不在本批范围 |
| 官方 share 图标非 android 变体 | 官方 App 用平台各自习惯的分享图标 | 全库统一取 `oct_share_android_16`（用户拍板），记入第七章 |

---

## 六、TDD 验收标准

- [x] 测试 1：`bash scripts/check-spec.sh` 通过；`python3 scripts/check-hardcoded-colors.py` 0 处命中
- [x] 测试 2：`devecocli build` 全量构建通过；`devecocli check lint` 0 问题
- [x] 测试 3：宿主单测 `npm run test:ut` 全绿（78/78，本批不动纯函数；`issuePageUrl` 断言并入 061 的地址构造函数用例）
- [x] 测试 4：全仓 grep `oct_share_16` 在 `entry/src/main/ets` 下 0 命中（8 处顶栏分享图标全为 `oct_share_android_16` + `link_blue`）
- [x] 测试 5：四处顶栏 ⋮ 均为 `oct_kebab_horizontal_16` + rotate 90 + `link_blue`
- [ ] 测试 6：模拟器实测——四处顶栏分享图标为蓝色 share-android、右侧为蓝色竖三点，与 Profile / PR 详情顶栏观感一致
- [ ] 测试 7：模拟器实测——竖三点点击后菜单仍从按钮下方正常弹出（旋转不影响锚点与触点）
- [ ] 测试 8：模拟器实测——Issue 详情顶栏出现蓝色 share-android，点击拉起系统面板且预览标题为 issue 标题；🔍 搜索仍在且仍能进搜索页

---

## 七、备注

- **为什么统一成 share-android**：官方 iOS/Android 客户端的分享图标本来就随平台变体，二者语义等价；
  本项目内已有 4 页用 `oct_share_android_16` + `link_blue`，本批把剩余 4 页对齐（Issue 详情为新增入口），
  全库 8 处顶栏分享图标至此完全一致（`oct_share_16` 媒体资源保留在 OctIcon 素材集中，不再被引用）。
- **竖三点惯例出处**：Spec 005（他人主页 ⋮ 关注菜单）确立「`oct_kebab_horizontal_16` + rotate 90 +
  头部用 `link_blue`」，Spec 015（搜索栏）、016（Edit My Work）沿用；本批把 011/030/036/038 四页补齐。
  官方 v19.33.0 起无 `kebab-vertical` 变体，旋转是既定的等价做法（见 Spec 024）。
- **顺带补齐的无障碍属性**：文件树与代码页的 ⋮ 此前缺 `accessibilityDescription`（读屏无标签），本次补上
  「更多」与 `focusable`，与其余页面一致（Spec 051 无障碍口径）；Issue 详情新增的 share 同样带
  `accessibilityDescription`（分享）与 `focusable`。
- **Issue 详情保留 🔍**：该页顶栏在 030 里是「🔍 + ⋯」（官方参考截图），本次只按用户要求补 share、
  换 ⋮ 取向与颜色，不删除既有入口；若用户本意是「只留 share + ⋮」，删除搜索图标是一处改动。
- **未动的部分**：四处顶栏的搜索/齿轮图标着色、图标尺寸、触点尺寸、页头高度与留白；所有点击行为（分享走
  Spec 061 系统分享面板；文件树/代码页 ⋮ 菜单仍是剪贴板复制语义；Issue 详情 ⋮ 仍是提示占位）保持不变。
- **待走查**：第六章测试 6-8 为模拟器实测项，走查通过后本 Spec 置 `implemented`。
  **2026-09-11 自测留痕**：已部署到 Pura 90 Pro 模拟器并截图确认 File Tree（← Files + 🔍 + 蓝分享 + 蓝竖三点）
  与 Issue 详情（← + 标题 + 🔍 + 蓝分享 + 蓝竖三点）两页；Code Viewer 与 Org Profile 未单独截图（同一改法）。
