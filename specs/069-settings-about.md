# Spec 069: Settings About（关于页）

> BFS Level: 2
> 关联截图: 无官方对照页（官方 Settings 无 About 入口；样式沿用 Spec 014 Settings 骨架）
> 上游 Spec: 014（Settings）
> 状态: implemented（2026-09-20 状态回写：About 行与关于页已入 develop=70c2893；§六 模拟器实测项走查通过后勾选）

---

## 一、页面/功能概述

Settings → More Options 分组内新增「About」行，进入应用关于页。页面纯静态零网络请求，承载官方没有的内容：
① ICP 备案信息（工信部要求 App 内显著位置展示备案号，拿号起 30 日内硬性合规项）；
② Star 引导文案（点击跳转本项目仓库 ZM-BAD/arkcat 详情页，加星动作在详情页完成）；
页面同时展示 App 图标、名称与版本号，作为应用身份信息的集中呈现点。

---

## 二、整体 UI 结构

1. 顶部：App Bar（← 返回 + About 标题）
2. 头部区（居中）：App 图标（与桌面图标同源 foreground.png）+ ArkCat 名称 + 版本号（Version x.y.z，读 bundle 清单 versionName）
3. Star 引导文案（居中，行内金星）：「如果觉得好用，请您给个★」，纯展示不跳转
4. 仓库行：左仓库名 ZM-BAD/arkcat；右 star 钮（钮面=实际加星数，金星=已加星态）；star 钮为整行唯一可点区域，点击 → ZM-BAD/arkcat 仓库详情页（加星在详情页完成）
5. 下拉刷新：系统 Refresh 样式，重拉 star 态轻量查询，刷新钮面数字/加星态（失败静默收圈）
6. 底部：两行居中纯文本——上「ICP备案号：浙ICP备2026075163号-1A」（死值不走 i18n），下「Copyright © 2026 ZM-BAD」

---

## 三、元素清单

可行性：8/8 全部可行

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | Settings·More Options | About 行（Open Source Libraries 与 Sign Out 之间） | 进关于页 | ✅ | — | 复用 Settings 现成 row 构造；Sign Out 保持组尾（官方序不变） |
| 2 | App Bar | ← + About 标题 | 返回 Settings | ✅ | — | AppBar 组件，hideTitleBar(true) 惯例 |
| 3 | 头部 | App 图标 + ArkCat + Version x.y.z | 展示 | ✅ 纯 UI | bundleManager.getBundleInfoForSelfSync | 图标 = app.media.foreground（TokenSetup 同源）；版本文案 Version x.y.z（用户 2026-09-17 定案），读取失败回退静态串 |
| 4 | Star 引导文案 | 「如果觉得好用，请您给个★」 | 纯展示，无点击 | ✅ 纯 UI | — | 文案为用户口述、死值不走 i18n；金星 = 金色字形 Span（star_gold token） |
| 5 | 仓库行 | ZM-BAD/arkcat + star 钮（钮面=实际加星数） | star 钮点击 → ZM-BAD/arkcat 仓库详情页（行内不加星） | ✅ | repository(owner,name){ id stargazerCount viewerHasStarred }（RepoService.fetchRepoStarState 轻量查询） | 首拉中钮面转圈占位（不闪假描边）；未加星=描边钮 oct_star_16+数字；已加星=灰底 oct_star_fill_16 金星+数字；从详情页返回可见自动静默重拉；失败只显示图标、仍可点 |
| 6 | 页面 | 下拉刷新（系统 Refresh 样式） | 重拉 star 态轻量查询，刷新钮面数字/加星态 | ✅ | 同元素 5 | 接口同元素 5；失败同样静默收圈；头部/文案/底部为静态不重拉 |
| 7 | 底部 | ICP 备案号行「ICP备案号：浙ICP备2026075163号-1A」 | 纯展示 | ✅ 纯 UI | — | 死值直出不走 i18n（用户 2026-09-17 定案）；纯文本居中，位于版权行上方，无点击 |
| 8 | 底部 | 版权行 Copyright © 2026 ZM-BAD | 展示 | ✅ 纯 UI | — | caption 灰居中；所属 ZM-BAD（用户 2026-09-17 定案，App 内口径） |

---

## 四、核心接口

```graphql
# Star 态轻量查询（RepoService.fetchRepoStarState）：仅 id/计数/是否已加星，
# 详情大查询的 readme/fileTree/languages 对本页全为冗余；页面无 mutation，行内不加星
query RepoStarState($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    id
    stargazerCount
    viewerHasStarred
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 公安联网备案号 | 备案落地三件之二，开通后 30 日内办理，尚未取得 | 本版不渲染；取得后在备案号行上方加同款纯文本行 |
| 贡献者区块 | 首版除维护者外无其他贡献者 | 第一期删除（2026-09-17 用户定案）；恢复方案见 §七 |

---

## 六、TDD 验收标准

- [x] bash scripts/check-spec.sh 通过
- [x] 宿主单测不回归（bash scripts/ut/run-local-tests.sh）
- [ ] Settings More Options 出现 About 行（Open Source 与 Sign Out 之间），点击进入关于页
- [ ] 头部显示图标/名称/版本号，版本号与 bundle 清单一致
- [ ] Star 引导文案点击无任何动作
- [ ] 已加星用户进页直接渲染金星态（首拉期间钮面转圈，无描边闪变）
- [ ] 仓库行 star 钮面显示实际加星数（已加星为金星态）；点击 → ZM-BAD/arkcat 仓库详情页
- [ ] 详情页加星/取消后返回 About，按钮状态自动同步（onShown tick 重拉），无需手动刷新
- [ ] 下拉刷新触发重拉，钮面数字/加星态更新；失败时圈正常收起
- [ ] 底部居中显示「ICP备案号：浙ICP备2026075163号-1A」纯文本（死值、无点击）
- [ ] base/zh_CN 新增 key 对齐；硬编码颜色/字号门禁通过

---

## 七、备注

- **偏离官方记录**：官方 GitHub App Settings 无 About 行（版本号为页面底部纯文本行，我方已移入关于页，见 Spec 014 §七 2026-09-17 偏离记录）。新增 About 行的偏离理由：① 备案号入 App 为工信部对 App 备案持有者的 30 日硬性要求，设置-关于为审核最认可的显著位置（合规偏离，设计理念「合规优先」允许项）；② Star 引导文案为用户 2026-09-17 拍板的社区增强。
- Star 区块交互（用户 2026-09-17 定案）：引导文案纯展示不跳转；仓库行的 star 钮为唯一可点区域，点击跳转仓库详情页、加星在详情页完成，行内无 mutation。star 态实时性：首拉中钮面转圈占位（不闪假描边）；页面重新可见（NavDestination onShown，首显跳过）经 Index tick 节拍静默重拉——详情页加星后返回即同步，与下拉刷新等效。
- 行内金星用字形 `Span('★')` 而非 octicon：ImageSpan 不支持 fillColor（编译器实测），oct_* 资源又禁裸 Image（必须走 OctIcon 组件整体渲染，无法嵌进文本流）；金色字形走 star_gold token，明暗双态与随文换行均正确。平台后续支持可着色内嵌 ImageSpan 时可换回 octicon。
- 贡献者区块第一期删除（2026-09-17 用户定案：首版除维护者外无其他贡献者）；恢复时于 Star 引导文案下方加头像横排，数据管道复用 Spec 054（REST /contributors + GraphQL 批量补全），区块仅在有数据时渲染。
- 版本号仅保留在关于页头部（Settings 底部版本号已移除）；About 不复刻 Terms/Privacy/Open Source/Share Feedback 入口——Settings 已有，避免双入口双维护。
- 路由名 `settingsAbout`，已加入底栏隐藏列表（TAB_BAR_HIDDEN_ROUTES，与 notificationSettings 等设置族同层）。
