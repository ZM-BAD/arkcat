# Spec 059: Copilot 功能批（真实 Chat + 本地会话 + 用量本地记账）

> BFS Level: 1
> 关联截图: 058 已收 4 张官方图（本批在 058 UI 骨架上接真实数据，不改版面）
> 上游 Spec: 058（Copilot UI 架子）、057（OAuth 登录——已合 develop，gho_ 直通 Copilot API）、
> 049a（多账号 AccountStore——settings 登录名的事实源）
> 状态: implemented（2026-09-08 用户放行功能批并完成部署验收；验收见六章勾选）
> 付费红线（用户强制，2026-09-08）：**涉及 Copilot Pro 的付费操作一律不执行**——本批只有
> Copilot Free 免费额度内的 chat/completions 调用（实测 gpt-4o-mini 免费），无任何
> premium 模型请求、无任何订阅/账单/升级端点、UPGRADE 按钮保持 058 的 toast 占位不接跳转。

---

## 一、页面/功能概述

058 落地了 Copilot Tab 的纯 UI 骨架（主页/聊天详情/settings 三页，数据全 mock）。
本批打通真实聊天链路：主页会话列表与详情消息改为**本地持久化**（Copilot 无会话历史
公开 API，实测 404——见五章边界），发送消息走 **POST /chat/completions**（Copilot Free
免费额度），settings 的登录名与用量改为**真实数据**（登录名取当前账号、用量本地记账近似）。

**强制红线实现方式**：模型白名单为代码常量（唯一入口），UI 不暴露模型选择；
请求体恒用免费模型；不实现任何 premium/计费相关调用；服务层只暴露 chat 一个写端点。

---

## 二、整体 UI 结构

骨架不变（058 已定案），以下只写改动点：

1. **主页**（Copilot Tab）：
   - Chats 列表数据源：mock 常量 → `CopilotStore`（本地 preferences 持久化，@ObservedV2
     单例@Trace 响应主页刷新），空态卡逻辑不变。
   - FAB / NEW CHAT：真实创建会话（本地生成 id + 空消息）并 push 详情页。
   - 会话行右侧时间：本地会话 `updatedAt`（新增消息时刷新）。
   - 右上竖三点：点击弹出菜单（官方同款，仅一项 **Refresh**）→ 重读本地会话列表。
2. **聊天详情页**：
   - AppBar 副标「Auto」不变；标题 = 会话标题（新建时为 New conversation）。
   - 消息列表：来源 = 会话消息数组（本地）；助手消息支持**键入中占位**（发送后、
     未响应前显示 loading 圆钮气泡）与**失败卡片**（错误文案 + 重试按钮）。
   - 底部输入栏：发送 → 真实请求（发送中禁用），空输入禁用逻辑不变；输入框为多行
     TextArea（随内容自增高，显式行高 20vp + constraintSize 封顶 11 行 ≈ 240vp，
     超出后内部滚动并显示滚动条），灰底（input_bg 令牌，与白色页/栏区分）、
     圆角胶囊、浮动投影，发送钮底部对齐。
   - 竖三点菜单：New conversation / 历史会话切换 / Copilot settings 变真实动作；
     Delete conversation 弹确认框（showDialog：标题 Delete conversation + 小字
     Are you sure you want to delete this conversation? + 蓝 DISMISS / 红 DELETE，
     对齐官方）后真删本地会话；View all conversations 回主页（pop）。
3. **Settings 页**：
   - 版面：Subscription / Usage / About 三组各为一张白卡（card_background + card_radius +
     card_padding），卡间 8vp 露出灰底画布形成分隔带——原实现是「白底上铺 8vp 灰条」，
     灰条与底色同色导致三组连成一片（用户走查定案改卡片式）。
   - `Active for <login>`：login 取当前账号（Index 透传 `currentLogin`，事实源=Spec 049a
     的 AccountStore）；仅账号 login 为空占位（v1 迁移 viewer 查询失败）时兜底拉取 viewer
     供本页展示，不回写存储。
   - Usage 两行：**服务端真实用量**（`copilot_internal/user` 的 `quota_snapshots`，
     Chat messages / Code completions 已用百分比 + 环进度）；该端点取不到时降级为
     本地记账近似（本机用户消息数 / Free 月配额 200）并显示「离线估算」小字。
   - Subscription 行「Copilot Free」：保留静态文案（无公开 API 查询套餐；实测账号为
     Free——见五章边界）。
   - About 四行：「Copilot Free」保持 toast 占位；「Copilot」「Privacy policy」「Copilot Terms」
     经路由 `inAppBrowser` 在 **App 内浏览器**打开 GitHub Docs（ArkWeb，手机宽度即移动端
     版式，深色跟随系统；路由参数=标题|URL，标题=该行文案；底栏隐藏）。
   - 底栏：本页与 `inAppBrowser` 均隐藏底部四 Tab（用户 09-08 定案，与 Settings 页一致）。
   - 页脚说明：随内容滚动；其中「show code suggestions that match public code」与
     「settings」为可点链接（Span 不支持 onClick → StyledString + GestureStyle），
     分别打开 find-matching-code 文档与 GitHub 网页版 Copilot 设置；**该两条的浏览器
     标题固定为 Copilot**（About 行则用行文案）。

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | 主页 | Chats 列表/空态 | 读本地持久化会话 | ✅ | - | mock 删除；空态逻辑不变 |
| 2 | 主页 | FAB / NEW CHAT | 本地新建会话 + 进详情 | ✅ | - | 新会话标题占位 New conversation |
| 3 | 主页 | 右上竖三点菜单 | Refresh 重读本地会话列表 | ✅ | - | 官方同款菜单仅一项（bindMenu） |
| 4 | 详情页 | 消息气泡列表 | 读会话消息数组 | ✅ | - | 本地数组，发送后追加 |
| 5 | 详情页 | 发送 | 真实 chat/completions | ✅ | POST /chat/completions | 模型=白名单常量（免费）；发送中禁用按钮 |
| 6 | 详情页 | 键入中占位 | 发送后未响应时显示 loading 气泡 | ✅ | - | 助手侧圆钮 + spinning，失败消失 |
| 7 | 详情页 | 失败卡片 | 错误文案 + 重试 | ✅ | - | friendlyError 本地化；重试=重发同消息 |
| 8 | 详情页 | 菜单：New conversation | 新建并跳转 | ✅ | - | 050 式新建会话 |
| 9 | 详情页 | 菜单：历史会话切换 | 切换到另一本地会话 | ✅ | - | 保留当前会话置灰项 |
| 10 | 详情页 | 菜单：Delete conversation | 确认框 + 真删本地会话 | ✅ | - | showDialog 标题/小字/DISMISS/DELETE 对齐官方 |
| 11 | 详情页 | 菜单：View all conversations | pop 回主页 | ✅ | - | 主页=全部会话列表 |
| 12 | Settings | Active for <login> | 登录名真实化 | ✅ | - | 当前账号 login（AccountStore，Index 透传） |
| 13 | Settings | Usage 环进度 | 服务端真实用量 | ✅ | GET copilot_internal/user | quota_snapshots 已用%；失败降级本地估算 + caption |
| 14 | Settings | UPGRADE PLAN | toast 占位（红线） | ✅ | - | 不引入任何升级/账单端点 |
| 15 | 全页 | 会话数据 | 本地 persistence | ✅ | - | preferences JSON（仿 WorkConfigStore 模式） |
| 16 | 详情页 | 底部输入栏 | 多行自增高（11 行封顶后滚动） | ✅ | - | TextArea + lineHeight(20vp) + constraintSize 240vp + input_bg 灰底 + 投影 |
| 17 | 全页 | 应用内浏览器 | About/页脚外链在 App 内打开 | ✅ | - | ArkWeb 加载 docs.github.com；路由 inAppBrowser（参数=URL，标题固定 Copilot），底栏隐藏 |

> 可行性图例：✅ 可直接实现 ｜ ⚠️ 部分可行/降级 ｜ ❌ 不可实现

---

## 四、核心接口（HTTP）

Copilot 私有 API 为 OpenAI 兼容 REST，走 `https://api.githubcopilot.com`（与
GitHub 主 API 不同域，`GitHttpClient` 硬编码主域，故新建 `CopilotService` 独立封装）：

```text
POST https://api.githubcopilot.com/chat/completions
Headers: Authorization: Bearer <token>   // gho_ 或 github_pat_（057 实测；ghp_ 不支持）
         Content-Type: application/json
         Accept: application/json
Body: {
  "model": "gpt-4o-mini-2024-07-18",      // 白名单常量，永不从 UI 传入
  "messages": [{"role": "user|assistant", "content": "..."}],
  "stream": false
}
→ 200 { "choices": [ { "message": { "content": "..." } } ] }
   → 页面追加助手气泡；body 内 usage 字段含 tokens（本地统计可留用）
→ 400 model_not_supported   → Free 配额不支持该模型（白名单下不会发生；防御分支）
→ 401 / 403 / 429           → 授权过期 / token 无 Copilot 权限 / 限流 → friendlyError
```

**只读探测端点**：`GET /models`（200，本批不消费）、`GET /agents/tasks`（200，tasks 空）。
**用量端点**（undocumented 内部接口，2026-09-08 实测 200）：`GET https://api.github.com/copilot_internal/user`
→ `quota_snapshots.{chat,completions,premium_interactions} = {entitlement, remaining, percent_remaining}`，
已用% = 100 − percent_remaining；解析失败/请求失败回退本地估算（非公开契约，不作唯一数据源）。
**不存在的端点（404 实测）**：`/threads`、`/copilot_internal/v2/threads`、`/usage`、`/chat/usage`、
`/copilot_internal/v2/usage`、`/copilot_internal/v2/limits`——**会话历史**无可公开的服务端契约。

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 会话历史云端同步 | 无公开 API（/threads 等 404 实测） | 会话本地持久化（preferences）；跨设备不同步；058 的「重启还原」升级为「持久保留」 |
| 用量服务端数值 | 无公开 API（/usage 等 404）；`copilot_internal/user` 为内部端点（undocumented，实测稳定） | 主路径取该端点真实用量；失败降级本地记账近似并标注「离线估算」（不依赖单一非公开契约） |
| 套餐名 | 无公开 API；Subscription 行「Copilot Free」为静态文案 | 保留静态文案（实测账号 Free；Pro 用户显示不准，备注说明） |
| premium 模型 | Copilot Pro 付费能力；Free 用户实测 400 model_not_supported | **红线**：模型白名单常量（gpt-4o-mini-2024-07-18 实测通过），UI 无模型选择入口，杜绝 premium 请求 |
| 订阅/升级/账单 | 无公开端点；红线强制 | 不实现任何 upgrade/billing 调用；UPGRADE 按钮保持 toast 占位 |
| Agents 任务执行 | /agents/tasks 只有只读列表（无任务）；执行属能力增强且可能涉及额度消耗 | 本批不接执行；主页 Agent Sessions 卡保持 058 宣传态 |
| Markdown 渲染 | 助手回复为纯文本气泡 | 本批纯文本展示；Markdown 高亮/代码块渲染另批评估 |
| 流式回复（SSE） | ArkTS 非阻塞流式实现复杂 | 本批非流式（stream:false），一次取整；流式另批评估 |
| 会话标题自动生成 | 官方由用户首条消息生成 | 新建=New conversation；发送首条用户消息后以其前 40 字符作标题（本地截断） |

---

## 六、TDD 验收标准

- [x] 单元测试（宿主 UT）：`parseChatResponse` 正常/缺 choices/空 content 三分支；`isFreeModelAllowed` 白名单放行 + premium 拒绝；`copilotSessionsFromStorage` 坏 JSON/缺字段回退空数组；`parseCopilotQuota`/`usedPercentOf` 正常/缺字段/越界回退
- [x] 主页：本地无会话时显示空态卡；新建后列表出现会话行（标题 New conversation + 相对时间），App 重启会话仍在
- [x] FAB / NEW CHAT 点击：进入详情页，AppBar 显示 New conversation，可返回
- [x] 发送消息：输入非空可点；点击后用户气泡立即上屏、出现键入中占位、发送钮禁用
- [x] 响应成功：助手气泡替换占位，内容一致；会话标题变为首条消息前 40 字符
- [x] 响应失败：失败卡片（文案 + 重试）；重试后再次请求，成功则复现上条；不重复追加用户气泡
- [x] 菜单：New conversation 新建并跳转；历史会话可切换（消息列表正确）；Delete 确认框→删除→回主页→列表消失；View all 回主页
- [x] Settings：Active for <login> 显示真实登录名（OAuth 与 PAT 两路径）；Usage 环=服务端真实用量（copilot_internal/user），端点不可用时降级本地估算并显示「离线估算」；UPGRADE 按钮仍为 toast
- [x] 红线检查：全库无 `premium` 模型名落在请求体构造处；`upgrade`/`billing` 无新网络调用；grep 确认
- [x] 构建绿：devecocli build 无错误（2026-09-09 本地实测）；Light 全页 + Dark 主页/详情走查（部署验收通过）；ohosTest 未随本批复跑

---

## 七、备注

**2026-09-08 实测记录（OAuth gho_ token，账号 ZM-BAD，Copilot Free）**：

| 探测 | 结果 |
| ---- | ---- |
| POST /chat/completions（gpt-4o-mini-2024-07-18，max_tokens=1） | 200，正常 content |
| POST /chat/completions（claude-opus-4.7） | 400 model_not_supported（Free 硬拒，零消耗） |
| GET /models | 200（模型列表含 premium 项——故 UI 绝不能暴露） |
| GET /agents/tasks | 200（tasks 空） |
| GET /threads、/copilot_internal/v2/threads | 404 |
| GET /usage、/chat/usage、/copilot_internal/v2/usage、/copilot_internal/v2/limits | 404 |
| GET api.github.com/copilot_internal/user | 200（quota_snapshots：chat 197/200、completions 2000/2000、premium 0/0） |
| chat 响应头 | 无 quota/usage 字段（仅 x-copilot-service-request-id 等） |

**新增/改动文件**：

- 新增 `services/CopilotService.ets`：chat/completions 封装（白名单常量 + 纯函数
  parseChatResponse/isFreeModelAllowed + 错误映射）+ 用量查询（fetchCopilotQuota +
  纯函数 parseCopilotQuota/usedPercentOf，内部端点 copilot_internal/user）；独立 http
  （不硬编码 api.github.com 前缀，仿 OAuthService postForm 模式）
- 新增 `utils/CopilotStore.ets`：@ObservedV2 单例（@Trace sessions）+ preferences
  持久化（仿 WorkConfigStore）+ 纯函数 copilotSessionsFromStorage；会话模型带 messages
- 改 `models/CopilotModels.ets`：ChatSession 增加 `messages: ChatMessage[]`；删除 mock 常量
- 改 `pages/Copilot.ets`：数据源换 CopilotStore；FAB/NEW CHAT 真实新建
- 改 `pages/CopilotChat.ets`：路由参数 title → sessionId；真实发送/键入中/失败重试；
  菜单真实化；token 传入
- 改 `pages/CopilotSettings.ets`：login 改由 Index 透传（当前账号）+ Usage 服务端真实用量
  （失败降级本地估算 + 「离线估算」小字）
- 改 `pages/Index.ets`：copilotChat 传 sessionId + token；settings 传 token + currentLogin；
  Copilot 列表刷新泵 copilotTick
- i18n：base/zh_CN 各新增 10 key（copilot_settings_plan_unknown、copilot_usage_local_hint、
  copilot_error_send、copilot_error_quota、copilot_retry、copilot_delete_title、
  copilot_delete_confirm、copilot_delete_dismiss、copilot_delete_action、copilot_menu_refresh）

**红线自查清单（交付前执行）**：`grep -riE 'premium|upgrade|billing|checkout' entry/src/main/ets`——
允许命中仅限：058 的 UPGRADE 按钮文案/tag、本 spec 备注、页面注释；任何新网络调用点禁止出现。

**Token 类型判定**（057 结论）：`gho_`/`github_pat_` 可直通 Copilot API；`ghp_`（classic
PAT）不支持——CopilotService 请求失败由 friendlyError 兜底（401/403 文案），不做额外
前缀预判（边界收口）。

**与官方 App 差异**：官方会话/用量由 GitHub 服务端存储，本文档本地持久化+本地记账
为无公开 API 下的降级方案；回复非流式传输，长回复等待时长上限 30s（readTimeout 30s）。
