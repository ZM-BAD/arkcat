# Spec 014: Settings（设置页）

> BFS Level: 3
> 关联截图: 官方 App Settings（Notifications/General/Subscriptions/More Options 分组）
> 上游 Spec: 005（个人主页 ⚙ 进入）
> 状态: implemented（2026-08-31，截图验收通过）

---

## 一、页面/功能概述

应用设置页，入口为个人主页顶栏 ⚙。对照官方 App 分组：

- **Notifications**：Notification Options
- **General**：Theme（Follow system）/ Code Options / Language（English）/ Accounts / App Lock
- **Subscriptions**：Copilot（Copilot Free）
- **More Options**：Share Feedback / Get Help / Terms of Service / Privacy Policy & Analytics / Open Source Libraries / Sign Out
- 底部版本号

真实功能：Theme（跟随系统/浅色/深色，持久化）、Language（English/简体中文，`setAppPreferredLanguage` 冷启动生效）、Notification Options→二级页（032）、Code Options→二级页（033）、Sign Out（清 Token 回 TokenSetup）。其余为分组行 + 点击提示后续。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + Settings 标题（← 顶栏（返回））
2. Notifications 分组：分组标题 + Notification Options（> 行）
3. General 分组：Theme（当前值 Follow system）/ Code Options / Language（当前值 English）/ Accounts / App Lock
4. Subscriptions 分组：Copilot（当前值 Copilot Free）
5. More Options 分组：Share Feedback / Get Help / Terms of Service / Privacy Policy & Analytics / Open Source Libraries / Sign Out
6. 底部：ArkCat v1.0.0 版本号

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | 顶栏 | ← 返回 + Settings 标题 | 返回个人主页 | ✅ 纯 UI | — | — |
| 2 | Notifications | Notification Options 行 | 进 Notification Settings | ✅ | — | 二级页（032） |
| 3 | General | Theme 行（下拉 Follow system/Light/Dark） | 主题切换 | ✅ | `preferences` 持久化 + UI 配置 markMode | 真功能 |
| 4 | General | Code Options 行 | 进 Code Options | ✅ | — | 二级页（033） |
| 5 | General | Language 行（English/简体中文） | 语言切换 | ✅ | `i18n.System.setAppPreferredLanguage` + preferences | 真功能（冷启动生效） |
| 6 | General | Accounts 行 | 提示后续 | ⚠️ | — | — |
| 7 | General | App Lock 行 | 提示后续 | ⚠️ | — | — |
| 8 | Subscriptions | Copilot 行（Copilot Free） | 纯展示 | ✅ 纯 UI | — | — |
| 9 | More Options | Share Feedback/Get Help/Terms/Privacy/Open Source | 浏览器打开对应页 | ⚠️ | URL 打开 | 点击提示后续 |
| 10 | More Options | Sign Out | 清除 Token → 回 TokenSetup | ✅ | `TokenStore.remove` | 真功能 |
| 11 | 底部 | 版本号 | 纯展示 | ✅ 纯 UI | — | ArkCat v1.0.0 |

---

## 四、核心接口

无 GraphQL 新增。全部本地能力：

```typescript
// Theme 持久化
preferences.putSync('theme_mode', 'system' | 'light' | 'dark')

// 语言切换（冷启动生效）
i18n.System.setAppPreferredLanguage('zh')
i18n.System.setAppPreferredLanguage('en')

// Sign Out
await TokenStore.remove()
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| App Lock | 需要生物识别/系统能力 | 行保留，点击提示后续 |
| 账号管理（Accounts） | 官方多账号体系超范围 | 行保留，点击提示 |
| 反馈/帮助/法律页 | 属官网内容 | 行保留，点击提示后续 |
| 官方版本号 | 我方版本 | 显示 ArkCat v1.0.0 |

---

## 六、TDD 验收标准

- [x] Settings 页分组渲染：Notifications/General/Subscriptions/More Options（截图验证）
- [x] Theme 切换（system/light/dark）持久化成功
- [x] Language 切换（en/zh）调用 setAppPreferredLanguage
- [x] Sign Out 清除 Token 并回 TokenSetup 页
- [x] base/zh_CN 新增 key 对齐；check-spec 通过
- [x] 模拟器截图验收

---

## 七、备注

- 主题切换使用 `@ohos.preferences` 持久化，AppState 监听；仅移动端支持
- 2026-08-31：Settings 页面实现完成，截图验收通过
