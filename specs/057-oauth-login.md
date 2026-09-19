# Spec 057: OAuth 登录（Device Flow）

> BFS Level: 0
> 关联截图: 无官方参考图——GitHub OAuth Device Flow 标准交互（gh CLI 同款流程）
> 上游 Spec: 无（TokenSetup 为初始脚手架既成实现，本 Spec 将其纳入范围）
> 状态: implemented（2026-09-08 随 PR #41 合入 develop；2026-09-17 随 PR #52 修订收敛为 Device Flow 单一路径）

---

## 一、页面/功能概述

TokenSetup 登录页提供 GitHub OAuth（Device Flow）登录：App 内一键发起，
展示 8 位设备码并拉起系统浏览器到 `github.com/login/device`，
用户输入代码点 Authorize 后，App 轮询拿到 token 自动进入主界面。

背景（2026-09-06 调研定案，详见第七章）：OAuth（`gho_`）scopes 覆盖现有功能所需
权限全集，Device Flow 全程无需 client_secret、无回跳依赖，符合纯端侧架构。

Scope 边界：本批只做鉴权层与登录 UI；不包含 PKCE web flow 浏览器回跳（二期增强，见边界）。

**9/9 可行**。

---

## 二、整体 UI 结构

登录页（无凭证冷启动；Accounts 添加账号以 embedded 形式复用），自上而下：

1. ArkCat 大图标居中
2. 标题「登录到 ArkCat」（page_text_font_size、600 粗）
3. 说明文案：直连 GitHub API 与授权方式一句话说明（body 字号、text_secondary、居中）
4. 主按钮「使用 GitHub 登录」：link_blue 底白字、button_height，点击发起 Device Flow

OAuth 授权等待页（发起 OAuth 后的同页状态切换）：

1. 自绘 AppBar：返回钮 + 标题「在浏览器中完成授权」（hideTitleBar(true)，全局二级页约定）
2. 正文居中，自上而下：
   - 提示文案「请在浏览器中输入以下代码：」
   - user_code 大号等宽展示（约 24fp、8 位含连字符）+ 「复制」按钮（蓝字）
   - 「打开浏览器授权」蓝按钮（进页自动拉起一次；按钮供未拉起时手动重试）
   - 等待态：spinner + 「等待浏览器授权完成…」+ 副文案「授权成功后自动进入主界面」
   - 失败态（条件显示）：错误文案红字 + 「重试」按钮

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | 登录页 | 图标 + 标题 + 说明文案 | 纯展示 | ✅ | - | text_primary/body 字号/bg_page |
| 2 | 登录页 | 主按钮「使用 GitHub 登录」 | 发起 Device Flow | ✅ | POST /login/device/code | link_blue 底白字、button_height |
| 3 | 等待页 | 自绘 AppBar（返回 + 标题） | 中断返回 | ✅ | - | hideTitleBar(true)（全局二级页约定） |
| 4 | 等待页 | user_code 大号展示 | 用户对照输入 | ✅ | - | 约 24fp 等宽字体，8 位含连字符（XXXX-XXXX） |
| 5 | 等待页 | 复制按钮 | 写入剪贴板 | ✅ | - | pasteboard Kit；成功 toast |
| 6 | 等待页 | 「打开浏览器授权」按钮 | 拉起系统浏览器到 verification_uri | ✅ | - | 进页自动拉起一次；按钮供未拉起时手动重试 |
| 7 | 等待页 | 等待态（spinner + 文案） | 轮询反馈 | ✅ | POST /login/oauth/access_token | 按 interval 轮询；slow_down 后 interval += 5s |
| 8 | 等待页 | 成功态 | 落库并进入主界面 | ✅ | GET /user | AccountStore.addAccount 落库；触发 onSaved |
| 9 | 等待页 | 失败态（文案 + 重试） | expired/denied/网络失败 | ✅ | - | 复用 friendlyError 区分网络失败与授权失败；不落库 |

> 可行性图例：✅ 可直接实现 ｜ ⚠️ 部分可行/降级 ｜ ❌ 不可实现

---

## 四、核心接口（HTTP）

非 GraphQL 页面，核心为 OAuth Device Flow 三步（Accept: application/json）：

```text
① 获取设备码
POST https://github.com/login/device/code
Body: client_id=<ARKCAT_CLIENT_ID>&scope=repo%20read:user%20notifications%20read:org%20user
→ 200 {
    device_code, user_code, verification_uri: "https://github.com/login/device",
    verification_uri_expires_in, interval, expires_in   // 默认 interval=5s，expires_in≈900s
  }

② 轮询令牌（间隔 interval 秒；收到 slow_down 后 interval += 5s）
POST https://github.com/login/oauth/access_token
Body: client_id=<...>&device_code=<...>&grant_type=urn:ietf:params:oauth:grant-type:device_code
→ 200 { access_token }
  或 { error }：
    authorization_pending  → 继续轮询
    slow_down              → interval += 5s 继续轮询
    expired_token          → 终止，提示重试（设备码约 15 分钟过期）
    access_denied          → 终止，用户在浏览器点了拒绝
    unsupported_grant_type / incorrect_client_code → 终止（client_id 配置错误）

③ 保存前实测（无效 token 不落库）
GET https://api.github.com/user
Headers: Authorization: Bearer <access_token>
→ 200 { login, ... } → AccountStore.addAccount → onSaved 进入主界面
```

**client_id 说明**：注册 OAuth App 为一次性管理动作（见第七章）；client_id 是公开
标识非 secret，以常量入库 `services/OAuthService.ets`。Device Flow 全程无需
client_secret，符合纯端侧无后端架构。

**scope 说明**：`repo read:user notifications read:org user` 四项；前三项覆盖数据面
最小集，`read:org` 解锁组织数据 GraphQL 化前置（现存 REST 兜底保留不动），
`user` 档含 `user:follow`——Follow/Unfollow mutation 必需（2026-09-12 补：缺它时
Follow 报 INSUFFICIENT_SCOPE，旧授权 token 须重新登录换新 scope）。

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| PKCE web flow 浏览器回跳（点 Authorize 自动跳回 App） | GitHub 2025-07 起支持 PKCE，但鸿蒙浏览器对 302→自定义 scheme 的拉起行为需真机验证 | 本批不做；Device Flow 无回跳依赖、确定性最高，回跳作二期增强 |
| 后台轮询可能被系统冻结 | 鸿蒙后台调度限制，浏览器停留期间 App 可能挂起 | 回前台不自动续跑（**未实现，提前规划中**）；等待页常驻展示状态，感知成功即自动进入。挂起期间轮询可能中断，需重新发起 |
| 设置页展示当前登录方式 | 范围收口 | 本批不做；随设置批补充 |
| 中国大陆网络访问 github.com | 既有前提 | Device Flow 授权需浏览器可达 github.com（可在任一设备完成），与数据访问同前提 |

---

## 六、TDD 验收标准

- [x] 无凭证冷启动：登录页引导可见，主按钮视觉主次明确（蓝底主按钮）
- [x] 发起 OAuth：浏览器拉起 github.com/login/device，等待页显示 user_code 且剪贴板内容与展示一致
- [ ] 正常授权：轮询获得 token → /user 实测通过 → AccountStore 落库 → onSaved 进入主界面；杀 App 重启不再出现登录页
- [ ] 轮询节奏：mock 序列 authorization_pending×N → slow_down → success，interval 递增 +5s 正确
- [ ] 失败路径：expired_token / access_denied / 网络异常分别给出对应文案与重试入口，均不落库
- [x] `gho_` 登录后四 Tab 数据拉取正常（GraphQL/REST；含 read:org 组织数据）
- [x] 返回中断：等待页返回登录页后停止轮询，再次发起重新获取新 device_code
- [x] 单元测试覆盖 OAuthService 状态机（pending / slow_down / expired / denied / success 五态）

---

## 七、备注

**前置管理动作（一次性，代码外）**：GitHub Settings → Developer settings →
OAuth Apps → New OAuth App；Homepage URL 填仓库地址；callback URL 填占位
（Device Flow 不使用回调）；勾选 **Enable Device Flow**。将 client_id 写入
`services/OAuthService.ets` 常量。

**已注册（2026-09-07）**：OAuth App「ArkCat」，**client_id = `Ov23liBbyQ0Am7PNXBcj`**
（Redirect URI 占位填仓库地址；**Expire user access tokens 须取消勾选**——纯端侧无
client_secret 无法兑换 refresh_token，勾选则 token 约 8 小时过期、只能重新授权）。

**涉及文件**：

- `services/OAuthService.ets`：Device Flow 状态机（获取设备码/轮询/五态错误映射）
- `pages/TokenSetup.ets`：登录选择视图 + OAuth 等待视图（两态切换）
- 落库走 `services/AccountStore.ets`（多账号结构，Spec 049a；token 作不透明字符串）
- `services/GitHttpClient.ets`：零改动（`Bearer` 头对 `gho_` 通用）
- 其余页面：零改动（token 消费面不变）
- i18n：base/zh_CN string.json 的 login_oauth_button、oauth_wait_title、oauth_code_hint、
  oauth_code_copy、oauth_open_browser、oauth_waiting、oauth_error_expired、
  oauth_error_denied 等 key

**鸿蒙适配**：openLink（@kit.AbilityKit）拉起系统浏览器；pasteboard（@kit.BasicServicesKit）
复制设备码；轮询用 setTimeout 循环（无 onShown 续跑，回前台需重新发起）；等待页返回即取消轮询。

**与官方 App 差异**：官方 GitHub Mobile 用 web flow 深链回跳（一线厂商自有 client 与后端）；
第三方无后端 App 的标准做法是 Device Flow（gh CLI 同款）。

**调研依据（2026-09-06，已实测）**：

- Device Flow 全程无需 client_secret、无回跳依赖，符合纯端侧架构
- 请求 scope 为 `repo read:user notifications read:org user`，覆盖数据面与 Follow（依赖 `user` 档内的 `user:follow`，2026-09-12 补）
- PKCE 官方支持（2025-07-14 changelog）→ 二期 web flow 回跳可行
