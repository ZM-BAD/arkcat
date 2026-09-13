# Spec 049: 多账号与安全（账号管理器 + App Lock 探测）

> BFS Level: 3
> 关联截图（官方 App 实机 2026-09 采集 3 张）：
> ① Accounts 浏览态（Edit 按钮/账号行蓝勾/Add account 行）
> ② Accounts 编辑态（Done/浅蓝勾+红色登出图标/Sign out all accounts 红行）
> ③ Sign In 登录页（`+ ADD ACCOUNT` 的结果：黑色品牌按钮/Terms 链接）
> 上游 Spec: 014（Settings）、005（Profile）、TokenStore（现状单 token）
> 状态: implemented（2026-09-14 状态回写：049a 账号管理器已随 PR #43 合入 develop；049b App Lock 由 Spec 066 承接并已实现；多账号设备实测项留在第六章）

---

## 一、页面/功能概述

049a（本期）：**账号管理器**——多 token 列表（AssetStoreKit 加密批量存）、添加/校验/切换/移除/全部登出，Profile 头像长按快捷切换器（官方 Profile tab 长按等价，位置为头像）。让 App 从单 PAT 升级为可切换多账号（开发/测试不同权限 PAT 场景的基础设施）。交互完全对齐官方 3 张截图：浏览态列表 + EDIT 管理态 + ADD ACCOUNT 进登录页。
049b（后续）：**App Lock**——探测 HarmonyOS 生物识别 API 可用性（真机 Pura 90 Pro），不可用则降级 PIN 4 位锁，再不行整项关闭说明。本期不做、占位行保留。

---

## 二、整体 UI 结构

Accounts 页（官方对齐）：

1. App Bar：返回 · 标题 Accounts · 右上 **EDIT**（蓝色纯文字）→ 编辑态变 **DONE**
2. 账号列表（**平铺行 + 分隔线**，官方设置列表样式，非项目圆角卡片行）：
   - 行 = 56vp 圆形头像 + 双行文字（上：login 黑体；下：name 灰体）+ 右侧当前账号**蓝底白勾**
   - 点击**非当前**账号行 → 切换（勾移动、数据源重载）；点击当前行无操作
3. 编辑态（EDIT → DONE）：
   - 当前勾变**浅蓝底**；每行右侧出现**红色登出图标**（方框+箭头）→ 点击 = 移除该账号（确认弹窗）
   - 页尾出现红色 **Sign out of all accounts** 行（红色登出图标 + 全大写红字）→ 移除全部（确认弹窗）→ 回 TokenSetup
   - **ADD ACCOUNT 行隐藏**
4. 浏览态列表末尾：**`+ ADD ACCOUNT`** 行（蓝色 + 图标 + 全大写蓝字）→ push 登录页（复用 TokenSetup）→ 保存成功后切到新账号并回本页刷新
5. 账号数上限 5（提示，不做硬限制弹窗）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | Accounts | EDIT/DONE | AppBar 右上纯文字按钮切换编辑态（浏览态可切换/添加，编辑态只能管理） | ✅ | 无 | 官方样式：蓝色、等宽字距感；编辑态 ADD ACCOUNT 隐藏 |
| 2 | Accounts | 账号行 | 头像+login/name 双行；点击非当前行=切换账号 | ✅ | 无（本地） | 平铺+hairline，行高约 64；无 ⋯ bindMenu（官方无，操作全在编辑态） |
| 3 | Accounts | 当前账号勾 | 右侧蓝底白勾（跟 StarredListSheet 勾选同款）；编辑态置灰（半透明）不可点 | ✅ | 无 | 官方两态：浏览态实蓝勾；编辑态浅色勾，位于登出图标左侧（走查 09-08 定案） |
| 4 | Accounts | ADD ACCOUNT | 蓝 `+` 图标 + 全大写蓝字行 → push TokenSetup（即官方 Sign In 页等价物） | ✅ | 无 | 保存后自动切到新账号、pop 回列表刷新；重复 login 提示 |
| 5 | Accounts | 移除单账号 | 编辑态行内红色登出图标 → showDialog 确认 → 移除；列表仍有余号则自动切第一个 | ✅ | 无 | 官方语义 Sign Out=remove account（2026-09 调研定案）；当前账号可移除（官方不改此限制） |
| 6 | Accounts | 全部登出 | 页尾红色行 → 确认 → 清空全部账号 + 回 TokenSetup | ✅ | 无 | 官方 Edit 态红色行 |
| 7 | 全局 | 账号列表/当前账号 | AssetStoreKit alias `arkcat.accounts.v2` 加密 JSON + Preferences `arkcat_accounts/active_login` | ✅ | 无（加密存储） | 上限 5 个；结构 {login, token, name?, addedAt} |
| 8 | 全局 | v1 迁移 | 启动读旧 alias `arkcat.github.pat` → viewer 查询补 login（失败置空占位）→ 写 v2 → 删 v1 | ✅ | `query { viewer { login name avatarUrl } }` | 纯函数可测 |
| 9 | 全局 | 数据隔离 | 缓存 key 加 login 后缀（搜索历史 `recent_{login}`；未读 badge 切换时重算；inboxUnreadTick 内存广播） | ✅ | 无 | 设备级偏好（主题/语言/代码设置/通知设置/Explore 活动类型/My Work）不隔离 |
| 10 | Profile | 快捷切换器 | 头像长按 → bindSheet 账号列表（当前✓/点击切换/Add account 入口） | ✅ | 无 | LongPressGesture；官方 Profile tab 长按等价（位置自定=头像） |
| 11 | 049b | App Lock | 生物识别探测 + PIN 降级 + 冷启动/后台锁定 | ❌（本期） | 探测 | 真机依赖（模拟器无生物识别），待 049b 排期 |

> 可行性: 10/11 可行（App Lock 拆 049b 总挂账；049a 全部 ✅）

---

## 四、核心接口片段

```text
# 本地存储结构（AssetStoreKit 加密，先删后写同 TokenStore 现状）
# Alias: "arkcat.accounts.v2" = JSON [{login, token, name?, addedAt}]（上限 5）
# Preferences 文件 "arkcat_accounts"，key "active_login" = login（非敏感）
# 迁移：旧 Alias "arkcat.github.pat" 存在 → 读 token → viewer 查询补 login →
#       写 v2 → 删 v1（纯函数 migrateV1ToV2 可三域测试）
```

```graphql
# 校验 token（添加账号时，复用现有 HomeService.fetchViewerBasic）
query ViewerCheck {
  viewer { login name avatarUrl }
}
```

```text
# AccountStore 对外接口（替代 TokenStore 三件套）
loadAccounts(): Promise<AccountInfo[]>          # 含迁移、坏 JSON 回退空表
getCurrentToken(): Promise<string>              # Index 启动用
addAccount(login, token): Promise<AddResult>    # 查重 + 上限 5
switchAccount(login): Promise<string>           # 返回新 token
removeAccount(login): Promise<AccountInfo[]>    # 返回剩余列表（供自动切换）
removeAll(): Promise<void>                      # Sign out all
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| App Lock 生物识别 | HarmonyOS 生物特征 API 需真机探测（机型/权限差异大） | **拆 049b**：独立排期 + Pura 90 Pro 探测；049a 仅保留 Settings 占位 |
| 多账号并发冲突 | 同时请求（切号中） | 切换期间提示；不做全量 abort registry，各常驻页经 accountSwitchTick/@Param token 变更重拉，旧响应被新响应覆盖（TDD 3 按走查口径「无残留」验收） |
| token 泄漏 | 账号移除时立即清缓存不落盘 | AssetStoreKit 加密保持；remove -> flush |
| OAuth/私密 token 无法识别 | 只支持 PAT（沿用） | 说明文案标注「仅支持 PAT」 |
| 账号数 | 防列表膨胀 | 上限 5，超出 toast 提示 |
| 官方云端同步 | 无公开 API 佐证 | 本地 only，备注说明 |
| Sign Out 语义 | 官方=移除该账号（2026-09 web 调研 + 截图 ② 红色登出图标证实） | **对齐官方**：Settings Sign Out = 移除当前账号，有余号自动切第一个；账号管理页编辑态红色图标同语义 |

---

## 六、TDD 验收标准（049a 部分，049b 项单独列）

- [ ] 测试 1：添加账号（TokenSetup 保存）→ Accounts 列表出现 + 自动成为当前账号（勾移）；旧 v1 单 token 迁移为 accounts[0]
- [ ] 测试 2：两账号 A/B：点击 B 行切换 → 当前勾移动、Home badge 重算、最近搜索 key（`recent_{login}` 后缀）分区
- [ ] 测试 3：切换后无 A 账号数据残留（走查口径：各常驻页以新 token 重拉）
- [ ] 测试 4：编辑态：行内红色登出图标 → 确认弹窗 → 列表删除；单账号时移除后回 TokenSetup；余号时自动切第一个
- [ ] 测试 5：Profile 长按头像 → 弹层切换器 → 选 B 生效（activeLogin 变更 + 当前勾移动）
- [ ] 测试 6：账号上限：第 6 个账号提示上限；重复 login 提示已存在
- [ ] 测试 7：Sign out of all accounts：确认后列表清空 + 回 TokenSetup
- [ ] 测试 8：设置页 Accounts 行存在且无「coming soon」残留（字符串检查）；Settings Sign Out 文案为「移除当前账号」语义
- [ ] 测试 9：i18n 双份 + check-spec 通过
- [ ] （049b）测试 A：App Lock 探测结果缓存、开关交互与结果一致

---

## 七、备注

- **官方交互三图要点（2026-09-08 采集，实现依据）**：
  1. 浏览态：AppBar 右上 EDIT 纯文字蓝；账号行=头像+login/name+右侧深蓝圆底白勾；行间分隔线平铺（**非**圆角卡片）；末尾 `+ ADD ACCOUNT` 蓝字行。
  2. 编辑态：EDIT→DONE；当前勾浅色（置灰不可点）；每行右侧红色登出图标（单账号登出）；页尾红色 `SIGN OUT ALL ACCOUNTS` 行；ADD ACCOUNT 隐藏。
  3. `+ ADD ACCOUNT` → 全屏 Sign In 页（黑色 GitHub 圆标 + 黑底白字 `SIGN IN TO GITHUB.COM` + 白底黑字 Enterprise + Terms/Privacy 蓝链 + Trouble signing in?）——**我们的等价物是 TokenSetup 页**（PAT 输入/OAuth），登录落地页与添加账号复用同一页。
- **走查 09-08 定案（App 壳）**：底栏仅在 **Settings 及其下级页面**（Accounts / Notification Options / Code Options / Add account）隐藏，其余二级页保留——`Index.ets` 用 `uiObserver.on('navDestinationSwitch')` 按目标路由名驱动 `hideTabBar`（另有 052 徽章详情模态页沿用隐藏）。编辑态行内**无铅笔**（官方无别名编辑）。
- 官方 Actions（2026-08 各版本）多账号入口 = Settings → Accounts + 长按 Profile tab；我们对齐为 Settings → Accounts + **头像长按**（位置自定义见 [[starraft-replication-standard]]）。
- 多账号是后续所有扩展（050 收藏、搜索历史）的隔离前提，建议 049a 尽早合入。
- 影响面：`TokenStore.ets` → `AccountStore.ets`；调用点仅 4 处（TokenSetup×2 / Index / Settings）；`Index.ets @State token` 与各页 `@Param token` 透传面（46 文件）无需逐个改——切换只改 Index 层 token，@Param 单向同步自动更新。
