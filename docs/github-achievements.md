# GitHub Achievements 徽章素材 — 运行时引用规范

> 调研日期：2026-08-31（所有 URL 逐一 curl 验证，HTTP 200）
> 决策：**运行时引用**——徽章图片一律以 URL 直连官方 CDN 加载，**禁止**下载入库/进制包（品牌红线，Spec 025）

## 背景与原则

- 徽章是 GitHub 专有美术资产（无开源许可），不同于 Octicons（MIT 可入库）。
- 展示用户成就 = 与其头像 `avatarUrl` 同机制：`Image(url)` 运行时加载，图片不进 `assets/`、不进 media 资源、不进商店包。
- 官方文档自身亦以 `<img>` 方式引用这些 URL，第三方工具（如 github-readme-stats）同样做法，风险最低。

## 已验证 URL 映射（默认色，仅此一档）

| 成就显示名 | slug | 文件名 | 完整 URL |
|---|---|---|---|
| Quick Draw | `quickdraw` | `quickdraw-default.png` | <https://github.githubassets.com/images/modules/profile/achievements/quickdraw-default.png> |
| Starstruck | `starstruck` | `starstruck-default.png` | <https://github.githubassets.com/images/modules/profile/achievements/starstruck-default.png> |
| Pair Extraordinaire | `pair-extraordinaire` | `pair-extraordinaire-default.png` | <https://github.githubassets.com/images/modules/profile/achievements/pair-extraordinaire-default.png> |
| Pull Shark | `pull-shark` | `pull-shark-default.png` | <https://github.githubassets.com/images/modules/profile/achievements/pull-shark-default.png> |
| Galaxy Brain | `galaxy-brain` | `galaxy-brain-default.png` | <https://github.githubassets.com/images/modules/profile/achievements/galaxy-brain-default.png> |
| YOLO | `yolo` | `yolo-default.png` | <https://github.githubassets.com/images/modules/profile/achievements/yolo-default.png> |
| Open Sourcerer | `open-sourcerer` | `open-sourcerer-default.png` | <https://github.githubassets.com/images/modules/profile/achievements/open-sourcerer-default.png> |
| Public Sponsor | `public-sponsor` | `public-sponsor-default.png` | <https://github.githubassets.com/images/modules/profile/achievements/public-sponsor-default.png> |

**URL 模式**：`https://github.githubassets.com/images/modules/profile/achievements/<slug>-default.png`

## 已证伪（勿采信）

| 猜测 | 结果 |
|---|---|
| `quick-draw-default.png`（带连字符 slug） | HTTP 404 |
| `star-struck-default.png` | HTTP 404 |
| `*-rainbow.png`（彩虹/经典变体） | 全部 404，仅有一档 default |
| `investor-default.png` | HTTP 404（该项成就不在该统一命名下或用文件名未公开） |
| `github.com/<用户>.png?achievement=xxx&size=48`（渲染服务） | 参数被忽略，实际返回用户头像（redirect 至 avatars.githubusercontent.com）——**不是**成就渲染服务 |

## 工程约定（未来实现成就展示时）

1. 封装纯函数 `achievementBadgeUrl(slug: string): string`：拼接上述 URL 模式；`slug` 白名单取自本表（不可信输入先查表，杜绝任意 URL）。
2. 用户持有的徽章类型经 GraphQL `User.achievements` 连接获取（类型枚举 slug 即上表 slug）；无该徽章时不渲染。
3. `Image(url)` 加载失败（用户隐私设置/网络异常）时静默隐藏，不做错误态。
4. 全部图标尺寸统一（原图约 48×48 系，UI 按需缩放）。
5. 本规范只存 URL 模式、**永不**存放图片文件本身。

## 后续 Spec 建议

- Profile 页「成就卡片」（Level 3 子功能）：以本文件为素材前置；含空态（无成就时不显示区块）、点击跳转官方成就说明页、横滑卡片或格子布局（与官方 App 对齐）。
