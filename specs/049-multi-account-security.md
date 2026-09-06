# Spec 049: 多账号与安全（账号管理器 + App Lock 探测）

> BFS Level: 3
> 关联截图: 官方 Settings 账号列表 + Profile 长按/头像切换器；官方 App Lock（生物识别）设置项
> 上游 Spec: 014（Settings）、005（Profile）、TokenStore（现状单 token）
> 状态: draft（2026-09-02 规划）

---

## 一、页面/功能概述

现在 App 单 PAT（加密 AssetStoreKit 单存储）。本 Spec：**账号管理器**（多 token 列表、添加/校验/切换/移除，每个账号独立缓存与偏好；Profile 页头像长按或 Settings「Accounts」进入切换器——对齐官方 long-press Profile tab 的行为）+ **App Lock**（探测 HarmonyOS 生物识别认证 API 可用性：不可用则降级「应用手势锁/跳过」，不为了安全牺牲体验）。多账号是官方长期支持且我们扩展开发（分享测不同 PAT 权限场景）的基础设施。

---

## 二、整体 UI 结构

1. 入口：Settings → Accounts（新页）
2. App Bar：Accounts · ＋（添加）
3. 账号列表：
   - 当前账号：头像 · login — 状态「当前」，点击切换（确认弹窗）
   - 其他账号：头像 · login（非当前），更多菜单：切换 / 移除 / 编辑别名
   - 添加新账号：TokenSetup 复用（校验 login）
4. 安全区：App Lock 开关（探测）
   - 可用（生物识别 API）→ 开启锁定
   - 不可用 → 开关置灰 + 说明
5. Profile 页头：长按头像 → 账号切换弹层（快捷）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | Settings | Accounts 入口 | 替换「coming soon」占位行，进入账号管理页 | ✅ | 无 | —— |
| 2 | 账号页 | 账号列表 | 多 token（AssetStoreKit 批量加密存储 `accounts` 数组 + activeLogin） | ✅ | 无（本地存储） | 结构：{login, token, name?, addedAt} |
| 3 | 账号页 | 添加账号 | 复用 TokenSetup 表单；校验=用 token 查询 viewer.login 成功 | ✅ | `query { viewer { login avatarUrl } }` | token 有效才入列 |
| 4 | 账号页 | 切换账号 | 设置 activeLogin；所有数据源重载（App 内数据带 login 缓存键） | ✅ | 无 | 全引用 TokenStore 的调用点改为「当前账号 token」 |
| 5 | 全局 | 数据隔离 | 缓存 key 均加 login 后缀（最近搜索/通知 badge/草稿/收藏等） | ✅ | 无 | 与 050/046 协作 |
| 6 | Profile | 快捷切换器 | 长按头像弹出账号列表（官方行为），当前账号✓ | ✅ | 无 | 长按手势（ArkUI Gesture LongPress） |
| 7 | 安全 | App Lock | 生物识别认证（face/指纹）+「返回桌面>2min 自动锁定」：HarmonyOS 标准生物识别 API 探测 | ⚠️ | 探测 | 不可用则整开关降级「密码 lock（4 位）」仍不可行则关闭入口（见边界） |
| 8 | 账号页 | 移除账号 | 移除时提示「本地 token 将被删除」+ 确认；当前账号不可移除 | ✅ | 无 | 移除后回到登录态/列表 |
| 9 | 账号页 | 别名/伪装名 | 自定义显示名（本地） | ✅ | 无 | 可选 |

> 可行性: 8/9 可行（App Lock 为其一 ⚠️；其余 ✅）

---

## 四、核心接口片段

```graphql
# 校验 token（添加账号时）
query ViewerCheck {
  viewer { login name avatarUrl }
}
```

```text
# 本地存储结构（TokenStore 改造，保持 AssetStoreKit 加密）
# Key: "starraft.accounts.v2" = JSON [{login, token, alias, addedAt}]
# Key: "starraft.activeAccount" = login
# 所有旧版单 token 读取兼容：v1 → 迁移为 accounts[0]
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| App Lock 生物识别 | HarmonyOS 生物特征认证 API（face/fingerprint）存在性需真机探测（系统权限/机型支持差异大） | 探测任务（Pura 90 Pro 真机）；不支持 → 提供「PIN 锁」开关（本地安全存储比较），再不行则整项关闭并说明 |
| 多账号并发冲突 | 同时请求（切号中） | 切换期间 pending 请求统一 abort；加载中防误切换 |
| token 泄漏 | AssetStoreKit 加密存储保持 | 账号移除时立即清缓存不落盘 |
| OAuth/私密 token 无法识别 | 只支持 PAT（沿用） | 说明文案标注「仅支持 PAT」 |
| 官方「多账号同时登录」（iOS 3 个） | 我们无硬限制 | 最多 5 个（防列表膨胀），提示 |

---

## 六、TDD 验收标准

- [ ] 测试 1：添加账号输入有效 token → viewer 查询返回 login → 列表出现（+旧单 token 迁移为 accounts[0]）
- [ ] 测试 2：两账号 A/B 切换：全局 user 信息、Home badge、最近搜索 key（login 后缀）随之切换
- [ ] 测试 3：切换瞬间取消进行中的请求（请求数断言）
- [ ] 测试 4：移除账号确认弹窗 → 列表删除；当前账号移除被禁
- [ ] 测试 5：Profile 长按头像 → 弹层切换器 → 选 B 生效（activeLogin 变更）
- [ ] 测试 6：App Lock 探测结果缓存（不可用则不重复探测），开关交互与结果一致
- [ ] 测试 7：别名编辑仅本地生效
- [ ] 测试 8：设置页 Accounts 行存在且无「coming soon」残留（字符串检查）
- [ ] 测试 9：i18n 双份 + check-spec 通过

---

## 七、备注

- 官方 2026-08（1.273 bugfixes）「iOS 26 long-press Profile tab 标记未读/切换账号」→ 我们对齐为长按头像（行为等价，位置自定义）。
- 多账号是后续所有扩展（046 搜索历史、050 收藏、草稿）的隔离前提，**建议 049 尽早排期**（与 041 并行无冲突——TokenStore 接口 abstract 层面先行，API 不动的调用点不用等）。
- 影响面：`TokenStore.ets` → `AccountStore.ets`（或在原文件扩展）；`GitHttpClient` 调用处全部按当前账号注入 token。
