# Spec 058: Copilot Tab 官方化（Agent Sessions + Chats + Settings UI 架子）

> BFS Level: 1
> 关联截图: 官方 App Copilot 页 4 张（主页空态 / 主页有会话 / 聊天详情+菜单 / Copilot settings）
> 上游 Spec: 004（Copilot Tab 空态占位）、057（OAuth 登录——本批不依赖）
> 状态: approved（2026-09-07 用户放行：先搭 UI 架子，不接 OAuth/API）

---

## 一、页面/功能概述

按官方 App 参考图将 Copilot Tab 从「Empty State 占位」升级为官方化列表页骨架：

- **主页**：Agent Sessions 宣传卡 + Chats 会话列表（空态/有记录两态）+ 右下 FAB 新建。
- **聊天详情页**（二级页）：自绘 AppBar（返回 + 会话标题 + Auto 模式副标 + 竖三点菜单）、
  消息气泡列表、底部固定输入栏（Ask Copilot + 纸飞机发送钮）。
- **Copilot settings 页**（二级页）：Subscription / Usage / About 三分组 + 页脚说明。

**Scope 边界（用户拍板）**：本批只做界面 UI 与 mock 数据，不接任何网络接口——
OAuth（Spec 057）与 Copilot 私有 API（聊天/用量/订阅真实性）另批；
本批所有数据来自内置 mock 常量，交互动作（UPGRADE、DELETE、发送等）以
coming soon toast 占位，**_唯一例外是页面跳转**（会话→详情、菜单→settings）。

**11/11 可行**（全部纯 UI + mock）。

---

## 二、整体 UI 结构

**主页（Copilot Tab 内容）**：大标题「Copilot」（title 字号加粗）+ 右上竖三点（灰→点按 toast）。
正文纵向：Agent Sessions 分组标题（半粗）→ 宣传卡（三个圆钮装饰 + 标题 + 说明 + UPGRADE TO
COPILOT PRO 描边按钮）→ Chats 分组标题 → 会话列表行（标题单行 + 右侧灰色相对时间，细分隔线）
或无会话时空态卡（Copilot 圆钮 + No chats yet + 副文案 + NEW CHAT 蓝字按钮）。
右下角蓝底加号 FAB 悬浮于内容区底部（底栏之上）。整页列表滚动 + 滚动顶部阴影。

**聊天详情页（NavDestination 二级页）**：自绘 AppBar = 返回钮 44 + 标题两行（会话标题 20 加粗 / Auto
灰色 caption 副标）+ 竖三点钮 44。正文 = 消息气泡列表（助手消息：左对齐浅灰圆角卡；用户消息：右对齐
浅蓝圆角卡），底部常驻输入栏 = 圆角灰底输入框（Placeholder「Ask Copilot」）+ 右侧圆形纸飞机发送钮
（空输入禁用态浅蓝、非空激活蓝）。竖三点菜单浮层（bindPopup，下拉式六项）：New conversation（蓝，+ 图标）
/ 当前会话（灰 + 眼睛图标，不可点）/ 历史会话标题（灰，点按切换）/ View all conversations（灰 + 对话图标）/
Copilot settings（黑 + Copilot 图标，点按跳转 settings）/ 分割线 / Delete conversation（红 + 垃圾桶图标）。

**Copilot settings 页（NavDestination 二级页）**：自绘 AppBar = 返回 + 标题「Copilot」（20 加粗，无右钮）。
正文分组（组间 8vp 灰粗分隔条，分组标题灰字）：Subscription（Copilot Free 24 加粗 + Active for <login>
灰字）→ Usage（两行：名称 + N% used + 蓝环进度圈；下方 UPGRADE PLAN 浅蓝底蓝字全宽按钮 + 灰说明
两行）→ About（Copilot Free / Copilot / Privacy policy / Copilot Terms 四个可点行，点按 toast）→
页脚灰底说明（含蓝色链接文字「show code suggestions that match public code」「settings」）。

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | 主页 | 大标题「Copilot」+ 右上竖三点 | 展示 + 更多菜单（toast 占位） | ✅ | - | 竖三点 kebab_horizontal rotate90（Idx 页约定） |
| 2 | 主页 | Agent Sessions 宣传卡 | 纯展示 | ✅ | - | 三圆钮：灰云 / 蓝环 / 绿分支（OctIcon 装饰）；UPGRADE TO COPILOT PRO 描边按钮点按 toast |
| 3 | 主页 | Chats 列表行（mock 2 条） | 点按进详情 | ✅ | - | mock 标题 + githubShortTime 相对时间；行间细分隔线 |
| 4 | 主页 | Chats 空态卡 | 无会话时展示 | ✅ | - | Copilot 图标圆钮 + No chats yet + 副文案 + NEW CHAT 蓝字按钮 |
| 5 | 主页 | 右下 FAB（+） | 新建会话（进空详情页） | ✅ | - | 低栏之上悬浮；蓝底白加号，圆角约 14 |
| 6 | 详情页 | 自绘 AppBar（返回 + 标题 + Auto 副标 + 竖三点） | 导航 + 打开菜单浮层 | ✅ | - | hideTitleBar(true)；两行标题（复习 047 模式） |
| 7 | 详情页 | 消息气泡列表（mock） | 纯展示 | ✅ | - | 助手左灰卡（16 圆角）/ 用户右蓝卡；loading 圆钮装饰（第一轮为 assistant 消息） |
| 8 | 详情页 | 底部输入栏 | 输入 + 发送（toast 占位） | ✅ | - | 空输入发送钮禁用；键盘避让（RESIZE） |
| 9 | 详情页 | 竖三点菜单浮层 | 菜单项跳转/选择/删除 | ✅ | - | bindPopup 下拉；Delete 红字；当前会话项置灰不可点 |
| 10 | settings | 三分组页面 | 展示当前套餐/用量/链接 | ✅ | - | 用量=本地 mock（50%/60%）；环形进度 Progress Ring 蓝 |
| 11 | 底栏 | Copilot Tab 选中态 fill 图标 | 选中视觉 | ✅ | - | 官方 octicons 无 copilot-fill → 手绘入库 oct_copilot_fill_16 |

> 可行性图例：✅ 可直接实现 ｜ ⚠️ 部分可行/降级 ｜ ❌ 不可实现

---

## 四、核心 GraphQL 片段

> 本批为纯 UI + mock，无网络接口。后续功能批接入 Copilot 私有 API 时另立 spec。

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| OAuth 登录 | 未接入（Spec 057 另批） | 本批不依赖登录态；settings「Active for ZM-BAD」跑 mock 文案 |
| Copilot 对话/用量/套餐真实性 | Copilot 私有 API 无公开接口 | 全部 mock 常量；功能批另立 |
| UPGRADE / Delete / settings 内容链接 | 业务动作 | toast 占位；settings 内链接页不做 |
| 会话持久化 | 无存储逻辑 | mock 内存态，重启还原 |

---

## 六、TDD 验收标准

- [ ] 底栏第 4 Tab Copilot：选中态显示 fill 图标 + 浅蓝胶囊（与 Home/Inbox/Explore 一致）
- [ ] 主页三段结构可见：Copilot 标题行 / Agent Sessions 宣传卡 / Chats 列表（mock 2 条 + 相对时间）
- [ ] 点按会话行：进入详情页，AppBar 两行标题（标题 + Auto 副标）正确，返回可回主页
- [ ] 详情页：mock 消息（助手左灰卡 + 用户右蓝卡）全部可见；底部输入栏常驻，发送钮空输入禁用
- [ ] 详情页竖三点：浮层六项齐全，Delete 红字，当前会话项置灰；Copilot settings 项跳转 settings 页
- [ ] settings 页：Subscription / Usage / About 三组齐全；Usage 环进度（50% / 60%）与 mock 一致
- [ ] 主页 FAB：悬浮于底栏之上、白加号蓝底；点按进入空会话详情页
- [ ] 空态卡：mock 列表为空时展示 No chats yet + NEW CHAT（临时验证分支）
- [ ] 构建绿：devecocli build 无错误；全页面 Light 走查；Dark 抽查主页/详情气泡

---

## 七、备注

**新增/改动文件**：

- 新增 `models/CopilotModels.ets`：`ChatSession`（id/标题/updatedAt）与 `ChatMessage`（isUser/body）
  接口 + 2 条会话、3 条消息的 mock 常量（写死「参与 React 代码库的指导 / 网站性能优化方法」）
- 重写 `pages/Copilot.ets`：主页（原 004 空态占位整体替换）
- 新增 `pages/CopilotChat.ets`：详情页（路由 `copilotChat`，param=会话标题）
- 新增 `pages/CopilotSettings.ets`：settings 页（路由 `copilotSettings`）
- `pages/Index.ets`：destinationMap 注册 2 条路由；底栏 Copilot 图标换 fill 变体
- 资源：新增 `media/oct_copilot_fill_16.svg`（手绘）；string.json base/zh_CN 各增约 18 key

**i18n**：文案与官方一致（Agent Sessions / Chats / Auto / NEW CHAT 等）；zh_CN 补译文
（会话标题 mock 中文，界面文案中英双语）。

**Primer 对齐**：卡片=card_background + card_radius；分组标题=body 半粗；说明=text_secondary
caption；主色=link_blue；浅蓝底=tab_active_bg（UPGRADE PLAN 按钮）；分隔线=divider；
FAB 蓝底白 icon 圆角方（官方 float button 样，不走系统按钮）。

**后续功能批线索**：OAuth 就绪后，本页 mock 常量→真实会话列表（Copilot REST/私有 API 尚无
公开契约，需单独调研）；Usage 环进度=服务端限额（Copilot Free 200/2000 已实测，见 057 备注）。

**与官方 App 差异**：官方 UPGRADE 浅蓝底文案按钮→本批同款 Buttons 描边样式；三圆钮装饰图标
为官方插画近似（OctIcon 云/同步环/分支重绘），非逐像素复刻。
