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
- **More Options**：Share Feedback / Terms of Service / Privacy Policy / Open Source Libraries / Sign Out
- 底部版本号

真实功能：Theme（跟随系统/浅色/深色，持久化）、Language（English/简体中文，`setAppPreferredLanguage` 冷启动生效）、Notification Options→二级页（032）、Code Options→二级页（033）、Sign Out（清 Token 回 TokenSetup）。其余为分组行 + 点击提示后续。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + Settings 标题（← 顶栏（返回））
2. Notifications 分组：分组标题 + Notification Options（> 行）
3. General 分组：Theme（当前值 Follow system）/ Code Options / Language（当前值 English）/ Accounts / App Lock
4. More Options 分组：Share Feedback / Terms of Service / Privacy Policy / Open Source Libraries / Sign Out
5. 底部：ArkCat v1.0.0 版本号

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | 顶栏 | ← 返回 + Settings 标题 | 返回个人主页 | ✅ 纯 UI | — | — |
| 2 | Notifications | Notification Options 行 | 进 Notification Settings | ✅ | — | 二级页（032） |
| 3 | General | Theme 行（下拉 Follow system/Light/Dark） | 主题切换 | ✅ | `preferences` 持久化 + UI 配置 markMode | 真功能 |
| 4 | General | Code Options 行 | 进 Code Options | ✅ | — | 二级页（033） |
| 5 | General | Language 行（三态下拉 Follow system/简体中文/English，默认 Follow system） | 语言切换 | ✅ | `i18n.System.setAppPreferredLanguage`（system 态设 `getSystemLanguage()` 快照即时切换；冷启动不设覆盖=真·跟随系统）+ preferences | 真功能（三态均即时生效） |
| 6 | General | Accounts 行 | 提示后续 | ⚠️ | — | — |
| 7 | General | App Lock 行 | 提示后续 | ⚠️ | — | — |
| 8 | More Options | Share Feedback/Terms/Privacy/Open Source | 打开对应内容 | ✅ | inAppBrowser 路由（标题+URL 参数） | Share Feedback→仓库 Discussions（065）；Terms→GitHub 官方 ToS；Privacy→GitHub General Privacy Statement（无 Tracking 开关：无自建后端/无数据收集，假 UI + 合规冲突，见 §七）；Open Source→开源库页（064） |
| 9 | More Options | Sign Out | 清除 Token → 回 TokenSetup | ✅ | `TokenStore.remove` | 真功能；确认弹窗=官方样式：仅标题 Sign Out + CANCEL/SIGN OUT 两蓝色大写按钮，无正文 |
| 10 | 底部 | 版本号 | 纯展示 | ✅ 纯 UI | — | ArkCat v1.0.0 |

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
- 2026-09-12 偏离记录：移除官方 More Options 的 Get Help 行。官方该行打开「Contact Support」应用内工单表单（Subject/Body 必填 + 截图附件 + 自动附设备上下文），提交至 GitHub Support（support.github.com/Zendesk），邮件回复。
  ArkCat 不复刻的三点理由：① 提交管道为 GitHub 支持系统非公开接口，第三方无合法 API；② 语义错位——该表单是向 GitHub 反馈官方 App 问题，ArkCat 用户的问题应由本仓库 Discussions 承接（Share Feedback 行已直达）；③ 应用内向境外支持系统 提交表单多一条数据出境通道，备案口径下无必要。官方「点开一次即从 Settings 消失、重进恢复」的行为属官方状态 bug，亦不复刻
- 2026-09-12 偏离记录：官方 Settings 有「Privacy Policy & Analytics」二级页（内含 Optional Activity Data Tracking 开关）。ArkCat 纯端侧直连 GitHub API、无自建后端、无统计/崩溃 SDK，无数据可收集——不做 Tracking 开关（假 UI 且与备案申报口径冲突），仅保留 Privacy 行经应用内浏览器打开 GitHub General Privacy Statement；行标签去「& Analytics」。此为合规/产品实质偏离，非样式偷懒
