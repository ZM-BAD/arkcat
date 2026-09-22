# Spec 076: 用户状态（Profile 状态条 + Edit status 弹层）

> BFS Level: 2
> 关联截图: 官方 App 2026-09-22 截图 3 张（个人主页状态条 / Edit status 弹层 / Select Expiration 子弹层）
> 上游 Spec: 005（用户主页）
> 状态: approved

---

## 一、页面/功能概述

把个人主页头卡的状态行从占位升级为**可读可写**：读 `user.status`，在头像行下方渲染灰底状态条（emoji + 文案），本人主页条尾挂铅笔；点铅笔拉开官方同构的 **Edit status 弹层**（自底部近全屏、抓取条自绘）——顶栏 ✕ + Edit status + SAVE，内容区 = emoji 选择框（点开 Select an emoji 子弹层）+ 状态文案输入（80 上限 + N characters remaining 计数）+ Busy 开关 + Clear after... 行（Select Expiration 子弹层六档）+ CLEAR STATUS 红字行。

写入经 GraphQL `changeUserStatus`（清空 = 空 message，GraphQL 无独立 clear mutation，见 §五）。他人主页同一条状态行只读（无铅笔），状态由对方在网页/其它客户端设置时同样展示。

---

## 二、整体 UI 结构

**A. 状态条（Profile 头卡，位序 = 头像行之下、bio 之上）**

1. 圆角矩形整行：左侧 emoji 字形（无 emoji 时省略，不占位）+ 状态文案；本人主页条尾 16 铅笔钮。常态灰底；**Busy（indicatesLimitedAvailability）=黄底 + 文案/铅笔转深琥珀**（官方 busy 态截图量测，2026-09-22 走查；**描边已按用户走查口径去掉——无论是否 busy 一律无描边**）
2. 本人主页整行可点（官方口径「点状态即改状态」）；他人主页整行只读
3. 本人主页**无状态时整行仍渲染**：emoji 位为 smiley OctIcon（`oct_smiley_16`，次级色），其后为引导语（Set a status）——编辑器唯一入口就在此行，整行不渲染会让功能不可达（§七）；他人主页无状态时整行不渲染，不占高度

**B. Edit status 弹层（自底部弹出近全屏，抓取条自绘）**

1. 顶栏：✕ + Edit status 粗体标题 + 右侧 SAVE 蓝字
2. 分隔线
3. 输入行（白底）：emoji 选择框（44×44 灰底描边圆角方框，内为当前 emoji；无 emoji 时显示 smiley OctIcon 占位）+ 无边框状态文案输入框（单行，maxLength 80，placeholder = Set your status）
4. 灰带：N characters remaining（N = 80 − 已输入长度）
5. Busy 行（白底）：左 Busy 文案 + 右侧开关
6. 灰带：Busy 说明文案（他人提及/指派/请求评审时 GitHub 会告知可用性受限）
7. Clear after... 行（白底）：左文案 + 右侧当前过期档（大写蓝字，如 NEVER）
8. CLEAR STATUS 行（danger 红字居中，整行可点；无既有状态时点按为空操作）
9. 余下区域留灰底

**C. Select Expiration 子弹层（挂在弹层内容上，半屏）**

1. 自绘抓取条 + 顶栏 ✕ + Select Expiration 粗体标题
2. 六行单选（行右蓝圈单选钮，当前档实心）：Never / In 30 minutes / In 1 hour / In 4 hours / Today / This week
3. 点任一行即生效并关闭子弹层（不设 SAVE）

**D. Select an emoji 子弹层（同上，半屏）**

1. 自绘抓取条 + 顶栏 ✕ + Select an emoji 粗体标题
2. 六列 emoji 网格（内置常用 GitHub 标准 emoji，可滚），当前 emoji 高亮
3. 点任一格即生效并关闭（不设 SAVE）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | 状态条 | emoji + 文案行 | 展示对方/自己的当前状态 | ✅ | `User.status { message emoji emojiHTML }` | emoji 渲染走 `parseStatusEmoji`（§七） |
| 2 | 状态条 | 铅笔钮 + 整行点击（仅本人主页） | 打开 Edit status 弹层 | ✅ | — | 他人主页不渲染、整行只读（同 005 元素 6 口径） |
| 2b | 状态条 | 空状态引导行（仅本人主页）：smiley OctIcon + Set a status | 无状态时仍提供编辑器入口 | ⚠️ | — | 官方空态形态未取证；smiley 字形按用户走查口径（2026-09-22） |
| 3 | 弹层顶栏 | ✕ / Edit status / SAVE | ✕ 关弹层丢弃改动；SAVE 提交 | ✅ | `changeUserStatus` | SAVE 恒可点（空 message = 清空，官方语义） |
| 4 | 输入行 | emoji 选择框 | 打开 Select an emoji 子弹层 | ✅ | — | 无 emoji 时框内空白 |
| 5 | 输入行 | 状态文案输入框 | 编辑状态文案 | ✅ | `changeUserStatus(message)` | `maxLength`=80（官方上限） |
| 6 | 输入行 | N characters remaining 计数 | 实时剩余字符数 | ✅ | — | 单数走 character 文案 |
| 7 | Busy 行 | Busy 开关 | 标记可用性受限 | ✅ | `changeUserStatus(limitedAvailability)` | 开=Busy |
| 8 | Clear after... 行 | 当前过期档 + 子弹层入口 | 打开 Select Expiration | ✅ | `changeUserStatus(expiresAt)` | 既有档位反推见 §五 |
| 9 | Select Expiration | 六档单选 | 设置到期时间 | ✅ | 同上 | Never 档提交时省略 `expiresAt` |
| 10 | 弹层底部 | CLEAR STATUS | 清空状态 | ✅ | `changeUserStatus(message: "")` | 恒 danger 红（2026-09-22 走查定案）；无状态时点按为空操作 |
| 11 | 弹层 | 提交防重入 | 连点不重复提交 | ✅ | — | `saving` 门闩（弹层关闭即销毁重置） |
| 12 | 弹层 | 保存成功回页刷新 | 状态条即时反映 | ✅ | — | 关弹层 + 静默重取主页 |
| 13 | 写入后 | 失败反馈 | 失败原因可见 | ✅ | — | toast `friendlyError`，弹层保持打开 |
| 14 | Select an emoji | 官方全量 emoji 网格 | 全库 emoji 选择 | ⚠️ | — | 降级为内置常用集见 §五 |

---

## 四、核心 GraphQL 片段

```graphql
# 主页查询扩展（ProfileService.PROFILE_QUERY，原 status 选择集补三字段）
query UserProfile($login: String!) {
  user(login: $login) {
    # ...
    status { message emoji emojiHTML indicatesLimitedAvailability expiresAt }
  }
}

# 写入（设置与清空同一 mutation：清空 = 空 message，见 §七）
mutation SetUserStatus($message: String!, $emoji: String, $limited: Boolean, $expiresAt: DateTime) {
  changeUserStatus(input: {
    message: $message
    emoji: $emoji
    limitedAvailability: $limited
    expiresAt: $expiresAt
  }) {
    status { message emoji emojiHTML indicatesLimitedAvailability expiresAt }
  }
}
```

无需新增读取查询：弹层初值全部取自主页已拉的 `status`（零额外请求）。

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ---- | --------------- |
| Select an emoji 全量网格 | 官方为完整 emoji 网格（1800+），ArkCat 无对应可视资产台账，逐张落盘体积不可接受 | 内置常用 GitHub 标准 emoji（约 130 枚 Unicode 字形，六列表格可滚）；**展示侧不受限**——任意来源（网页/其它客户端）设置的状态一律按 §七 规则渲染 |
| 无 Unicode 字形的 GitHub 自定义 emoji（`:shipit:` 等） | 无字形可画 | 优先渲染 `emojiHTML` 内 GitHub CDN 的 `<img src>`；仅当 `emojiHTML` 缺失时按短代码拼 CDN 图；两者皆空则省略 emoji 只显文案 |
| 组织可见状态（`organizationId`） | 官方 App 状态编辑器无组织选择入口 | 不提供；他人的组织可见状态读取时按公共状态展示 |
| 既有到期档反推 | 官方「Clear after...」档位枚举不可考（接口只给绝对 `expiresAt`） | 按剩余时长就近归档（阈值见 §七），仅影响文案回显 |
| status 为空但仍想只留 emoji | 官方允许 emoji 无文案 | 支持：SAVE 只发 emoji（message 空串）时 GitHub 返回 emoji-only 状态，状态条随之只显 emoji |
| 无状态时的空态形态 | 官方「无状态时状态行长什么样」无截图、无公开资料（社区仅说明「点自己名字下方的状态即可改」） | 本人主页按引导语渲染（Set a status）+ 整行可点；他人主页不渲染。**待用户走查拍板**（若官方为空态隐藏，需另给入口，否则功能不可达） |
| emoji 只增不减 | 官方选择器未取证 | 选择框只能换不能清空；要清空 emoji 需 CLEAR STATUS 后重设（emoji-only 状态同样成立），待走查确认是否补「无 emoji」格 |

---

## 六、TDD 验收标准

- [x] 测试 1：`parseStatusEmoji` — `emojiHTML='<div>🎯</div>'` → 文本字形 🎯（非短代码文本）
- [x] 测试 2：`parseStatusEmoji` — `emojiHTML` 含 `<img src>` → 取图片地址、文本为空
- [x] 测试 3：`parseStatusEmoji` — `emojiHTML` 缺失且 `emoji=':shipit:'` → CDN 图片地址兜底
- [x] 测试 4：`statusVisible` — message 空但 emoji 有字形时仍展示；两者皆空不展示
- [x] 测试 5：`expiryIsoOf` — `in30m/in1h/in4h` 为 now + 对应分钟数；`never` 返回空串（提交时省略字段）
- [x] 测试 6：`expiryIsoOf` — `today` 落在本地当日 23:59:59，`thisweek` 落在本地本周六 23:59:59（跨周不早于 today）
- [x] 测试 7：`expiryKeyOf` — 空/已过期 → `never`；剩余 20 分钟 → `in30m`；剩余 45 分钟 → `in30m`（含边界）；剩余 3 小时 → `in4h`；当日更晚 → `today`；跨日 → `thisweek`；**全天逐小时六档往返自洽**（回归：21:00 时 `today` 不得被 in4h 窗口抢走）
- [x] 测试 8：`statusRemainingCount` — 80 上限下的剩余数（含 1 字符单数文案分支）
- [x] 测试 9：`mapUserProfile` — 无 `status` 字段 → `status` 为 null；有 status → 四字段落位
- [ ] 测试 10：真机走查——状态条渲染（emoji 字形/自定义 emoji）、编辑→保存→回页刷新、Busy、六档到期、CLEAR STATUS、他人主页只读（由用户执行）

---

## 七、备注

- **emoji 渲染口径（本 Spec 核心结论）**：GitHub 的 `UserStatus.emoji` 返回的是**短代码**（实测 `viewer.status.emoji` = `":dart:"`），直接当文本渲染会显示成 `:dart: Focusing`（本 Spec 落地前状态行即为此状）。正确取字形的通道是 `emojiHTML`：GitHub 现返回 `<div>🎯</div>`（Unicode 字形，可直接 `Text` 渲染）；自定义 emoji 则返回 `<img src="…githubassets…">`。故 `parseStatusEmoji(emoji, emojiHTML)` 三段取用：**img src → 图片；去标签后的字形 → 文本；两者皆空 → 短代码拼 `https://github.githubassets.com/images/icons/emoji/<name>.png?v8`（实测 dart/shipit 均 200）**。ArkUI 文本渲染 Unicode emoji 无障碍（反应条 👍👎😄🎉 同类字形早已在用）。
- **清空语义**：GraphQL 无 `clearUserStatus`（`ClearUserStatusInput` 类型不存在），清空与设置同走 `changeUserStatus`：空 `message` 即清空，且**省略的字段一并清空**（设置类 mutation 的替换语义）——故「Never」档直接省略 `expiresAt`，不做 null 传参（ArkTS 侧 `Record<string, Object>` 也无法表达 null）。
- **到期档推导**：`never`=省略字段；`in30m/in1h/in4h`=now+30/60/240 分钟；`today`=本地当日 23:59:59.999；`thisweek`=本地本周六 23:59:59.999（今天即周六时顺延 7 天，避免与 today 重合）。时间函数一律注入 `nowMs` 便于宿主单测。
- **回显归档阈值**（`expiryKeyOf`）：空/已过期 → never；命中本地日末/周末末**精确时刻** → today/thisweek（写入侧 `expiryIsoOf` 写的就是这两个绝对时刻，可整数比对）；其余按剩余时长归档：≤45 分钟 → in30m、≤2.5 小时 → in1h、≤4.5 小时 → in4h，再超出则按是否同一本地日归 today/thisweek。**必须「先精确匹配日末、再按时长分档」**：19:30 后今天日末只剩 <4.5 小时，若先按时长分档会被 in4h 抢走——「今天」全天误显为 IN 4 HOURS，且随后的 SAVE 会把真实到期时刻改写成 now+4h（2026-09-22 code review 修正；日末/周末末的计算抽成 `endOfLocalWeekMs` 供写入与回显共用，防两侧漂移）。
- **组织归属回传**：`changeUserStatus` 是替换语义，省略 `organizationId` 即被 GitHub 视为**公开可见**——不回传的话，用户改一次 emoji 就把组织限定的状态改成全网可见。故 `PROFILE_QUERY` 取 `status { organization { id } }`，写入与清空均原样回传（本弹层不提供切换组织入口，只做保真）。
- **SAVE 置灰口径**：官方截图 SAVE 为禁用灰（#676D7B 量测，非蓝）——本实现按「与打开时状态相比无改动即置灰且不可点」，改动后转蓝；创建/编辑类页面（070/075）无此态，属本弹层的官方对齐。
- **计数口径**：80 为 GitHub 状态文案上限，`maxLength(80)` 与计数同源（UTF-16 长度），emoji 计 2 属可接受偏差。
- **Busy 渲染口径（2026-09-22 走查定案）**：busy 状态条=黄底（新 token `status_busy_bg`，base #FFF8C5 / dark #26BB8009 半透明琥珀）+ 文案与铅笔转 `warning_text`（=#9A6700，恰为 Primer attention.fg，存量 token）。**无描边**（初版加过 amber 描边，用户走查去掉——无论是否 busy 一律无描边）。官方截图量测：条内填充 ≈#FEF9E5、文字 ≈#655816（JPEG 压缩偏移，就近官方 token 落位）。
- **弹层三处摆位按走查定案（2026-09-22）**：CLEAR STATUS **恒为 danger 红字**（原按「无状态置灰」实现，用户指出要红）；emoji 框空态显示 smiley OctIcon 占位（与 Profile 空态行同字形）；状态文案输入框 placeholder = `Set your status`。
- **文案口径**：SAVE 与 CLEAR STATUS 文案按官方大写形态渲染（`textCase` 转写，非字面量大写串）；弹层内其余文案为句首大写（与截图一致）。「Save 失败」走 toast + `friendlyError`，弹层不关以保留已填内容（与 070/075 一致）。
- **状态条实测档与占位期口径校正**：官方截图量测——状态文案/emoji ≈16fp（明显大于元信息行 12fp）、条高 ≈42vp、条底色 ≈#F5F8F9（=`bg_page` #F6F8FA，非 `heat_empty` #EBEDF0）、emoji 选择框 ≈42vp 方形、框内 emoji ≈20fp。故本条：文案与 emoji 走 `sub_text_font_size`(16fp)、条底色改 `bg_page`、内边距 10/12/4、铅笔改 `text_primary`（官方为黑）；**原实现（`heat_empty` + `caption_font_size` + 灰铅笔）属占位期口径，本次随功能落地校正**。同页 bio 仍为 `caption_font_size`（官方截图为 16fp）——该漂移不在本 Spec 范围，另案处理。
- 弹层骨架复用建仓弹层（070）与仓库详情单 bindSheet + sheetKind 分派（045/006）：本体一个 `bindSheet`（`SheetSize.LARGE` + `dragBar:false` + 自绘抓取条），两个子弹层复用**同一个嵌套 `bindSheet`** 按 `sheetKind` 分派（同组件多 bindSheet 只有最后一个生效，坑 2）；内容槽一律直传单层构建函数（2026-09-22 事故口径）。
- 弹层内容关闭即销毁重建：重开自动回填当前状态（官方语义）。
- **空态入口为推断项**（smiley 字形部分已按用户走查口径定案）：官方 iOS 版状态编辑的进入方式是「点头像下方自己的状态」（GitHub Community 讨论 136646「shipped on iOS v1.161.0」；App Store 版本说明另记「修复了看他人主页时错误显示编辑状态入口」的缺陷，反证入口仅本人主页有）。无状态时的空态形态无公开取证，但若照搬「无状态即整行不渲染」，编辑器将无入口——故本人主页按「smiley OctIcon + Set a status 引导语」渲染并整行可点，他人主页保持不渲染。**2026-09-22 用户走查指出「Set a status 前要有 smiley octicon」，已按此落地**（`oct_smiley_16`，次级色，占 emoji 位）。
