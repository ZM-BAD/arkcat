# Spec 052: GitHub 成就徽章详情页

> BFS Level: 2
> 关联截图: 微信图片_20260903231418_49_181.jpg（YOLO 徽章详情：渐变底/大徽章/解锁信息/圆点翻页/Share）
> 上游 Spec: 005（用户主页勋章行）
> 状态: implemented（2026-09-07 漂移复核：页面/模型/服务完整实现）

---

## 一、页面/功能概述

点击 Profile 页勋章行中的某一枚成就徽章，进入全屏徽章详情页：
官方蓝紫渐变底 + 居中大徽章 + 名称/描述 + 「Unlocked 日期」与触发事件 + 底部圆点翻页（已解锁徽章间左右滑）与 Share 按钮。
徽章无 GraphQL/REST 字段，数据沿用 Spec 005 的官方页面 HTML 抓取方案：slug 列表取 `?tab=achievements` 页面，
详情取 `/users/{login}/achievements/{slug}/detail` 懒加载片段（X-Requested-With: XMLHttpRequest）。

---

## 二、整体 UI 结构

1. 顶部：关闭按钮（深蓝圆底）+ 渐变底 #434986 → #303788
2. 居中：大徽章圆图
3. 徽章名称：YOLO（粗体白）
4. 徽章描述：You want it? You merge it.（白·90%）
5. 解锁信息：奖杯圆钮 + Unlocked September 1（粗体白）
6. 触发事件：圆点 + ZM-BAD/starraft #3 · Merged without a review（白）
7. 翻页圆点（当前 = 白实心）
8. 底部：Share 按钮（全宽浅紫圆角钮·白字）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | 右上 | ✕ 关闭（深蓝圆底） | 返回 Profile | ✅ | — | 与二级页返回语义一致，自绘 |
| 2 | 居中 | 大徽章图（约 300vp 圆） | 展示 | ⚠️ | — | 详情片段 img（hash 版）→ 兜底 CDN `{slug}-default.png` |
| 3 | 居中 | 名称（粗体白 26fp） | 展示 | ✅ | — | 片段 `<h3>` |
| 4 | 居中 | 描述（白 90%、16fp） | 展示 | ✅ | — | 片段 `<div class="mt-1">` |
| 5 | 中部 | 🏆 圆钮 + 「Unlocked 9月1日」 | 展示解锁日期 | ✅ | — | 片段 relative-time datetime（UTC → 本地「月 日」，intl 格式化） |
| 6 | 中部 | • +「`引用` · `事件标签`」 | 展示触发事件 | ⚠️ | — | 片段 `.achievement-history-tier`；私有仓库引用为 `inaccessible` → 仅显示事件标签 |
| 7 | 底部 | 圆点翻页（Swiper 已解锁徽章） | 左右滑切换徽章 | ✅ | — | 页数=已解锁徽章数；入口参数为起始下标 |
| 8 | 底部 | Share 按钮 | 分享该徽章页面 URL | ⚠️ | — | ShareKit systemShare（HYPERLINK）；分享图片资源未落地，边界外 |

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

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 私有仓库事件引用显示 `inaccessible` | 详情片段为匿名抓取；移动端因登录态可解析（如 ZM-BAD/starraft #3） | `inaccessible`/空 → 隐藏引用，仅显示事件标签（如 Merged without a review） |
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

- 渐变底色从参考截图采样：顶 #434986（右缘 y≈0.10）、底 #303788（右缘 y≈0.90），竖直 linearGradient；
  颜色入 resources color.json（base/dark 双套），ets 禁止 #RRGGBB 硬编码。
- Profile 页勋章行图片目前 24vp；详情页大图用官方 `{slug}-default-{hash}.png`（详情片段内嵌），失败兜底 CDN 无 hash URL（服务端仍有效）。
- 翻页圆点：oct_dot_fill_16 白（当前页）/白 30%（其余）；Swiper indicator 自绘。
- 关闭按钮用 oct_x_16 白，深蓝圆底（参考截图约 44vp 触点）。
- 保留现有 AchievementsService.fetch（Profile 行）不变；新增 fetchSlugs / fetchDetail。
