# Spec 052: GitHub 成就徽章详情页

> BFS Level: 2
> 关联截图: 微信图片_20260903231418_49_181.jpg（YOLO 徽章详情：渐变底/大徽章/解锁信息/圆点翻页/Share）
> 上游 Spec: 005（用户主页勋章行）
> 状态: implemented（2026-09-07 漂移复核：页面/模型/服务完整实现）

---

## 一、页面/功能概述

点击 Profile 页勋章行中的某一枚成就徽章，进入全屏徽章详情页：
官方蓝紫渐变底（兜底）+ 每徽章官方主题横幅铺满整页背景 + 居中大徽章 + 名称/描述 + 「Unlocked 日期」与触发事件 + 底部圆点翻页（已解锁徽章间左右滑）与 Share 按钮。
徽章无 GraphQL/REST 字段，数据沿用 Spec 005 的官方页面 HTML 抓取方案：slug 列表取 `?tab=achievements` 页面，
详情取 `/users/{login}/achievements/{slug}/detail` 懒加载片段（X-Requested-With: XMLHttpRequest）。

---

## 二、整体 UI 结构

1. 顶部：关闭按钮（深蓝圆底）+ 整页主题背景（每徽章官方横幅，渐变兜底）
2. 居中：大徽章圆图
3. 徽章名称：YOLO（粗体白）
4. 徽章描述：You want it? You merge it.（白 15fp、opacity 0.85）
5. 解锁信息：奖杯圆钮 + Unlocked September 1（粗体白）
6. 触发事件：圆点 + ZM-BAD/arkcat #3 · Merged without a review（白）
7. 翻页圆点（当前 = 白实心）
8. 底部：Share 按钮（全宽浅紫圆角钮·白字）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | 右上 | ✕ 关闭（深蓝圆底） | 返回 Profile | ✅ | — | 与二级页返回语义一致，自绘 |
| 2 | 居中 | 大徽章图（260×260） | 展示 | ⚠️ | — | 详情片段 img（hash 版）→ 兜底 CDN `{slug}-default.png` |
| 3 | 居中 | 名称（20fp（title_font_size）） | 展示 | ✅ | — | 片段 `<h3>` |
| 4 | 居中 | 描述（15fp（chip_font_size）、opacity 0.85） | 展示 | ✅ | — | 片段 `<div class="mt-1">`；文本框左右各留 36（奖杯中轴），整体居中且最左不越过奖杯，长文案框内换行 |
| 5 | 中部 | 🏆 圆钮（圆形底 + 阴影）+ 解锁文案 | 展示解锁日期 | ✅ | — | 文案国际化：英文「Unlocked August 10」/ 中文「解锁时间: 8月10日」；日期按应用首选语言（Settings 语言三态覆盖后）格式化，非系统 locale；圆钮为半透明阴影色圆垫底（achievement_icon_shadow，无实底/无描边），距屏幕左缘固定 24（每页一致，不随内容居中） |
| 6 | 中部 | • dot-fill +「`引用` · `事件标签`」 | 展示触发事件 | ⚠️ | — | 片段 `.achievement-history-tier`；私有仓库引用为 `inaccessible` → 仅显示事件标签；每条「dot-fill + 文案」整体在行内水平居中（Unlocked 行不受影响，仍固定左缘 24）；点与首行文字垂直居中；行数多时区域受限内滚（maxHeight 160、无滚动条），内滚子 Column 显式 width('100%') + Text 显式 maxWidth 防无界测量丢字；底部渐变淡出带（32vp、主题底部色透明→实色）仅内容溢出需要滚动时显示（独立组件 AchievementEventList 按页测量溢出） |
| 7 | 底部 | 圆点翻页（Swiper 已解锁徽章） | 左右滑切换徽章 | ✅ | — | 页数=已解锁徽章数；入口参数为起始下标 |
| 8 | 底部 | Share 按钮 | 分享该徽章页面 URL | ⚠️ | — | 走 Spec 061 统一出口（HYPERLINK）；分享图片资源未落地，边界外；样式与 Home outlineButton（ADD FAVORITES/GET STARTED）同构：透明底 + 1vp 半透明白描边（achievement_share_border）+ 6vp 圆角 + 高 44 + caption 字号白字 |

---

## 四、核心 GraphQL 片段

无 GraphQL 查询；数据来自官方页面 HTML（保留现有抓取方案，与 Spec 005 一致）：

```text
GET https://github.com/{login}?tab=achievements
  → slug 列表（原文中 ?achievement=<slug>&tab=achievements 链接）

GET https://github.com/users/{login}/achievements/{slug}/detail
  Header: X-Requested-With: XMLHttpRequest
  → 片段：
    - h3 名称 / div.mt-1 描述
    - img (tier-badge) → 徽章图
    - .achievement-history-unlocked-at > relative-time[datetime] → 解锁时间
    - .achievement-history-tier > [`<ref>` · `<label>`] → 事件
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 私有仓库事件引用显示 `inaccessible` | 详情片段为匿名抓取；移动端因登录态可解析（如 ZM-BAD/arkcat #3） | `inaccessible`/空 → 隐藏引用，仅显示事件标签（如 Merged without a review） |
| 未解锁徽章 | 端点 404，且 slug 列表不含 | 不展示（swiper 页数=已解锁数） |
| 徽章描述/名称本地化 | GitHub 原文为英文 | 原文展示（与官方一致） |
| 分享图片 | 需下载底图到临时目录再分享 | 仅分享 URL（HYPERLINK），后续按需扩展 |
| 页面结构变更 | github.com 持续改版 | 解析函数集中可测；解析失败 → StateView 错误 + 重试 |
| 深色模式底图 | 官方移动端深色渐变无参考图 | base/dark 双色各配渐变色，dark 取同色系压暗 |

---

## 六、TDD 验收标准

- [x] 测试 1：parseAchievementDetail：正常详情片段 → name/description/badgeImageUrl/unlockedAt/eventLabel/eventRef 完整
- [x] 测试 2：parseAchievementDetail：事件引用为 `inaccessible` → eventRef = ''，eventLabel 保留
- [x] 测试 3：parseAchievementDetail：空 / 异常 HTML → 抛出 ParseError
- [x] 测试 4：parseAchievementDetail：无 relative-time 时 unlockedAt = ''（无 crash）
- [x] 测试 5：unlockDateText：合法 ISO → 本地日期「月 日」非空；非法 ISO → ''
- [x] 测试 6：fetchSlugs（抽出后的 slug 提取纯函数）：重复 slug 去重保序（沿用现有 fetch 正则）

---

## 七、备注

- 整页背景（2026-09-13 定案，色源=官方资产）：详情片段头图 div 的 `background-image` 即官方每徽章
  主题横幅（`<slug>-detail-<hash>.png`，768×360 渐变/纯色图，全部徽章均有），解析为 `detailBgUrl`，
  根布局 `.backgroundImage(url) + Fill 拉伸` 铺满整页（含顶部关闭区与底部圆点/Share 区），随 Swiper
  当前页切换；模型层纯函数解析有单测。蓝紫渐变 #434986→#303788 保留为兜底（URL 空/图未加载时露出）。
  翻页时背景随滑动进度渐变过渡：根布局分「基底层（当前页横幅，过渡期钉在来源页）+ 过渡层（目标页
  横幅按 onGestureSwipe 进度淡入）」两层；松手补间阶段不再逐帧回调，onChange 时用 animateTo 把过渡
  层推到终态（翻页成功→1/取消→0）后清除，消除突变。
  官方横幅逐像素色值（资产解码，非截图）：YOLO 全图纯色 #FEBC9C；Starstruck 橙黄→紫→青多向渐变；
  Pull Shark #0A6ADD→#2B34A6；Quickdraw #FCF2C7→#FB9146；Pair Extraordinaire #ADEEBA→#CDEC79。
  本地全量色表 `models/AchievementThemeColors.ets`（数据色板，颜色门禁白名单）：覆盖全部 14 枚官方
  徽章 slug（7 枚可获取 + arctic-code-vault/heart-on-your-sleeve/mars-2020/open-sourcerer 及 3 枚
  proxima 内部徽章），色值采样自官方横幅镜像（Schweinepriester/github-profile-achievements
  images/backgrounds/，即官方 CDN 原图）。兜底链：官方横幅图 → 本地色表渐变 → 蓝紫渐变 token。
- Profile 页勋章行图片目前 24vp；详情页大图用官方 `{slug}-default-{hash}.png`（详情片段内嵌），失败兜底 CDN 无 hash URL（服务端仍有效）。
- 翻页圆点：自绘 Circle（当前页白实心 7vp / 其余白 30% 7vp）；Swiper indicator 自绘。
- 关闭按钮用 oct_x_16 白，半透明阴影色圆垫底（36×36，与 trophy 圆钮同款）。
- 保留现有 AchievementsService.fetch（Profile 行）不变；新增 fetchSlugs / fetchDetail。
