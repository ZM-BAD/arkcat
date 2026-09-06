# Spec 057: OAuth 登录（Device Flow，与 PAT 并存）

> BFS Level: 0
> 关联截图: 无官方参考图——GitHub OAuth Device Flow 标准交互（gh CLI / Copilot CLI 同款流程）
> 上游 Spec: 001（TokenSetup 登录前置）
> 状态: draft

---

## 一、页面/功能概述

TokenSetup 登录页升级为「登录方式二选一」选择页：

- **主路径——GitHub OAuth（Device Flow）**：用户无需手动去网页创建 token；App 内一键发起，
  展示 8 位设备码并拉起系统浏览器到 `github.com/login/device`，用户输入代码点 Authorize 后，
  App 轮询拿到 token 自动进入主界面。
- **兼容路径——PAT 粘贴**：现有 Spec 001 流程原样保留，折叠为次入口。

背景（2026-09-06 调研定案，详见第七章）：classic PAT 无法访问 Copilot API；
OAuth token（`gho_`）与 PAT 同 scope 体系、现有功能 100% 覆盖，且实测直通 Copilot API。
故 OAuth 为主推登录方式；**并存期间 PAT 保留，待 OAuth 稳定后另行退役（不在本批）**。

Scope 边界：本批只做鉴权层与登录 UI。不包含 Copilot 功能页（挂 Spec 004，另批）；
不包含 PKCE web flow 浏览器回跳（二期增强，见边界）。

**11/11 可行**。

---

## 二、整体 UI 结构

登录选择页（无凭证冷启动，改造现 TokenSetup）：

```text
┌─────────────────────────────────────┐
│                                     │
│                🐙                   │
│          登录到 StarRaft（标题）      │
│    说明文案（两种方式一句话差异）      │
│                                     │
│  ┌─────────────────────────────┐   │
│  │   使用 GitHub 登录（主按钮）   │   │
│  └─────────────────────────────┘   │
│        推荐 · 无需手动创建 token      │
│  ┌─────────────────────────────┐   │
│  │  使用 Personal Access Token  │   │
│  └─────────────────────────────┘   │
│                                     │
│  （展开后 PAT 折叠表单）              │
│  ┌─────────────────────────────┐   │
│  │  Token 输入框（密码态）       │   │
│  ├─────────────────────────────┤   │
│  │  错误文案（红，条件显示）      │   │
│  ├─────────────────────────────┤   │
│  │       保存并连接（蓝按钮）     │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

OAuth 授权等待页（发起 OAuth 后的独立视图，NavDestination 或同页状态切换）：

```text
┌─────────────────────────────────────┐
│ ←  在浏览器中完成授权（自绘 AppBar）   │
├─────────────────────────────────────┤
│      请在浏览器中输入以下代码：        │
│                                     │
│        W D J B - M J H T            │
│      （大号等宽字体）   [复制]        │
│                                     │
│  ┌─────────────────────────────┐   │
│  │      打开浏览器授权（蓝按钮）  │   │
│  └─────────────────────────────┘   │
│                                     │
│         ⟳ 等待浏览器授权完成…         │
│      （授权成功后自动进入主界面）      │
│                                     │
│  （失败态：错误文案红字 + 重试按钮）   │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
|---|------|------|------|--------|------|------|
| 1 | 选择页 | 图标 + 标题 + 说明文案 | 纯展示 | ✅ | - | 复用现 token_setup 风格（text_primary/body 字号/bg_page） |
| 2 | 选择页 | 主按钮「使用 GitHub 登录」 | 发起 Device Flow | ✅ | POST /login/device/code | link_blue 底白字、button_height；下方 caption 灰字「推荐 · 无需手动创建 token」 |
| 3 | 选择页 | 次按钮「使用 Personal Access Token」 | 展开 PAT 表单 | ✅ | - | 无底色蓝字文字按钮，视觉次级 |
| 4 | 选择页 | PAT 折叠表单 | 既有 001 流程原样保留 | ✅ | GET /user（保存前实测） | 输入框 + 保存 + 错误文案 + friendlyError，逻辑零改动 |
| 5 | 等待页 | 自绘 AppBar（返回 + 标题） | 回到选择页 | ✅ | - | hideTitleBar(true)（全局二级页约定） |
| 6 | 等待页 | user_code 大号展示 | 用户对照输入 | ✅ | - | 约 24fp 等宽字体，8 位含连字符（XXXX-XXXX） |
| 7 | 等待页 | 复制按钮 | 写入剪贴板 | ✅ | - | pasteboard Kit；成功 toast |
| 8 | 等待页 | 「打开浏览器授权」按钮 | openLink 拉起 verification_uri | ✅ | - | 进页自动拉起一次；按钮供未拉起时手动重试 |
| 9 | 等待页 | 等待态（spinner + 文案） | 轮询反馈 | ✅ | POST /login/oauth/access_token | 按 interval 轮询；slow_down 后 interval += 5s |
| 10 | 等待页 | 成功态 | 落库并进入主界面 | ✅ | GET /user | TokenStore.save 复用现有 alias；触发 onSaved |
| 11 | 等待页 | 失败态（文案 + 重试） | expired/denied/网络失败 | ✅ | - | 复用 friendlyError 区分网络失败与授权失败；不落库 |

> 可行性图例：✅ 可直接实现 ｜ ⚠️ 部分可行/降级 ｜ ❌ 不可实现

---

## 四、核心接口（HTTP）

非 GraphQL 页面，核心为 OAuth Device Flow 三步（Accept: application/json）：

```text
① 获取设备码
POST https://github.com/login/device/code
Body: client_id=<STARRAFT_CLIENT_ID>&scope=repo%20read:user%20notifications%20read:org
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

③ 保存前实测（对齐 PAT 逻辑，review A13）
GET https://api.github.com/user
Headers: Authorization: Bearer <access_token>
→ 200 { login, ... } → TokenStore.save → onSaved 进入主界面
```

**Token 类型判定**：由前缀实时判定，无需新增存储——`gho_`=OAuth、
`github_pat_`=fine-grained PAT、`ghp_`=classic PAT（后续 Copilot 批据此前缀
判定 Copilot 可用性；本批只保证前缀信息可获取，即 token 字符串本身）。

**client_id 说明**：注册 OAuth App 为一次性管理动作（见第七章）；client_id 是公开
标识非 secret，以常量入库 `services/OAuthService.ets`。Device Flow 全程无需
client_secret，符合纯端侧无后端架构。

**scope 说明**：`repo read:user notifications` 与现 PAT 最小集对齐；追加 `read:org`
顺带解锁组织数据 GraphQL 化前置（现存 REST 兜底保留不动）。

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
|----|------|-------------------|
| PKCE web flow 浏览器回跳（点 Authorize 自动跳回 App） | GitHub 2025-07 起支持 PKCE，但鸿蒙浏览器对 302→自定义 scheme 的拉起行为需真机验证 | 本批不做；Device Flow 无回跳依赖、确定性最高，回跳作二期增强 |
| PAT 退役 | 用户拍板：OAuth 稳定后再删 | 本批 PAT 与 OAuth 并存；退役另开批 |
| 后台轮询可能被系统冻结 | 鸿蒙后台调度限制，浏览器停留期间 App 可能挂起 | 回前台 onShown 续轮询兜底；等待页常驻展示状态，感知成功即自动进入 |
| Copilot 功能解锁 | 功能开发与鉴权解耦 | 本批仅落地 token（`gho_` 可被 Copilot 批复用），Copilot 页另批 |
| 设置页展示当前登录方式 | 范围收口 | 本批不做；随 Copilot 批或设置批补充 |
| 中国大陆网络访问 github.com | 既有前提 | 与 PAT 创建流程同前提，行为不变 |

---

## 六、TDD 验收标准

- [ ] 无凭证冷启动：登录选择页二选一引导可见，OAuth 主按钮视觉主次明确（蓝底主按钮 + 文字次按钮）
- [ ] 选择 PAT 入口：粘贴/保存前 /user 实测/错误文案行为与改造前一致（Spec 001 回归）
- [ ] 发起 OAuth：浏览器拉起 github.com/login/device，等待页显示 user_code 且剪贴板内容与展示一致
- [ ] 正常授权：轮询获得 token → /user 实测通过 → TokenStore 落库 → onSaved 进入主界面；杀 App 重启不再出现登录页
- [ ] 轮询节奏：mock 序列 authorization_pending×N → slow_down → success，interval 递增 +5s 正确
- [ ] 失败路径：expired_token / access_denied / 网络异常分别给出对应文案与重试入口，均不落库
- [ ] `gho_` 登录后四 Tab 数据拉取正常（GraphQL/REST 与 PAT 等价；含 read:org 组织数据）
- [ ] 返回中断：等待页返回选择页后停止轮询，再次发起重新获取新 device_code
- [ ] 单元测试覆盖 OAuthService 状态机（pending / slow_down / expired / denied / success 五态）

---

## 七、备注

**前置管理动作（一次性，代码外）**：GitHub Settings → Developer settings →
OAuth Apps → New OAuth App；Homepage URL 填仓库地址；callback URL 填占位
（Device Flow 不使用回调）；勾选 **Enable Device Flow**。将 client_id 写入
`services/OAuthService.ets` 常量。

**新增/改动文件**：

- 新增 `services/OAuthService.ets`：Device Flow 状态机（获取设备码/轮询/五态错误映射），约 150 行
- 改造 `pages/TokenSetup.ets`：选择视图 + PAT 折叠表单 + OAuth 等待视图（三态切换）
- `services/TokenStore.ets`：零改动（alias 与存取 API 不变；类型由前缀实时判定）
- `services/GitHttpClient.ets`：零改动（`Bearer` 头对 `gho_` 通用）
- 其余页面：零改动（token 消费面不变）
- i18n：base/zh_CN string.json 新增约 10 个 key（login_oauth_button、login_pat_button、
  oauth_wait_title、oauth_code_hint、oauth_code_copy、oauth_open_browser、oauth_waiting、
  oauth_error_expired、oauth_error_denied 等）

**鸿蒙适配**：openLink（@kit.AbilityKit）拉起系统浏览器；pasteboard（@kit.BasicServicesKit）
复制设备码；轮询用 setTimeout 循环 + NavDestination onShown 续跑；等待页返回即取消轮询。

**与官方 App 差异**：官方 GitHub Mobile 用 web flow 深链回跳（一线厂商自有 client 与后端）；
第三方无后端 App 的标准做法是 Device Flow（gh CLI / Copilot CLI 同款）。

**调研依据（2026-09-06，已实测）**：

- `gho_` token 直通 `api.githubcopilot.com`：`POST /chat/completions` 200、`GET /models` 200、
  `GET /agents/tasks` 200——无需 `copilot_internal/v2/token` 兑换（旧兑换端点对 `gho_` 已 403，且不再必要）
- classic PAT（`ghp_`）官方不支持 Copilot API（Copilot CLI / Copilot SDK 文档双重确认）
- 官方 OAuth scopes 列表无 `copilot` scope；实测无该 scope 的 `gho_` 亦直通，不依赖
- PKCE 官方支持（2025-07-14 changelog）→ 二期 web flow 回跳可行
- 实测账号 ZM-BAD 为 Copilot Free（chat 200 credits / completions 2000 / premium 0），
  套餐差异由服务端强制，客户端如实渲染即可
