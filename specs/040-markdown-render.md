# Spec 040: Markdown 渲染底座（MarkdownView 组件 + MarkdownService）

> BFS Level: 4（横向底座）
> 关联截图: 官方 App README / Issue 正文 / PR Conversation 样式（.markdown-body）
> 上游 Spec: 006（RepoDetail README）、029（Releases）、030（IssueDetail）、031（PrDetail）、019（Discussions）
> 状态: implemented（2026-09-07 漂移复核：ArkWeb 主方案落地，11 项验收通过）
> 前置条件：样式机械门禁三件套已完成（2026-09-03，develop 76c2931/8481eee）

---

## 一、页面/功能概述

本 Spec 是**全部 Markdown 内容的统一渲染底座**：README、Issue/PR 正文与评论、Release 说明、Discussion 描述，一律走同一个 `MarkdownView` 组件渲染。技术决策（2026-09-02 调研结论）：**主方案 = GitHub 官方渲染管线**——凡是 GraphQL 能取到 `bodyHTML` 的节点直接展示官方 HTML；README 用 REST `GET /repos/{o}/{r}/readme` 的 HTML 媒体类型（或 `POST /markdown` 渲染）；展示载体用系统 ArkWeb（Web 组件）+ `github-markdown-css` 风格（映射 Primer token），与官方 App 同管线同观感。备选方案：纯 ArkUI 渲染库 `@luvi/lv-markdown-in`（69★、2026-08 仍维护、MIT），仅当 ArkWeb 方案在性能/桥接上不可行时启用（本 Spec 备注记录决策点）。

交付物：`components/MarkdownView.ets`（组件）+ `services/MarkdownService.ets`（抓取/渲染）+ 现有 5 处裸文本展示全部替换为组件。

---

## 二、整体 UI 结构

1. MarkdownView 组件（无 AppBar，纯内容区）：
   - ArkWeb（Web 组件，透明底）
   - 渲染 `div.markdown-body`：`<h1>标题</h1>`、`<p>正文</p>`、`<pre><code>代码块</code></pre>`、`<table>表格</table>`
   - 加载态：骨架 / Progress
   - 错误态：内容降级为纯文本 + 重试
2. 接入点（替换现有裸 Text）：RepoDetail README · OrgProfile README · IssueDetail 正文/评论 · PrDetail 正文/评论 · Releases 说明 · Discussion 描述 · 041 评论预览

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | 组件 | MarkdownView（html 模式） | 直接渲染官方 HTML（bodyHTML / readme html / /markdown 结果），内嵌 github-markdown-css 简化版样式 | ✅ | 见四 | 核心组件，80% 场景走此模式 |
| 2 | 组件 | MarkdownView（md 模式，仅预览用） | 本地渲染（ArkWeb 内跑 marked 之类 JS 或先服务端渲染后展示）用于评论发布前预览 | ✅ | `POST /markdown`（REST） | 041 复用；优先服务端渲染保证与官方一致 |
| 3 | 服务 | fetchReadmeHtml(owner, repo, branch?) | REST 取 README HTML（`Accept: application/vnd.github.html`，**实测返回纯 HTML 流，直接作为 body 渲染**） | ✅ | REST `GET /repos/{o}/{r}/readme` | 默认 default branch；支持分支切换后的 README |
| 4 | 服务 | renderMarkdown(md) | 任意 Markdown → 官方 HTML（`POST /markdown`，支持 mode gfm + context 仓库名） | ✅ | REST `POST /markdown` | 用于没有 bodyHTML 字段的场合 |
| 5 | 服务 | 无 README 处理 | 404/空文件 → 展示「This repository has no README」占位 | ✅ | 无 | 与官方空态一致 |
| 6 | 交互 | 链接点击 | 站内链接（/owner/repo、/o/r/issues/1 等）→ 路由到对应页面；外链 → 系统浏览器（want 跳转） | ⚠️ | 无 | 路由表见备注；未匹配链接一律外开 |
| 7 | 交互 | 图片 | Web 内自动加载（GitHub 域名图片）；跳转拦截可选；gif/视频自动播放跟随系统设置 | ✅ | 无 | 不代理；断网显示占位（Web 默认） |
| 8 | 交互 | 代码块 | 复制按钮（点击复制 → pasteboard，Web 侧 JS 与 ArkTS 桥或右上角浮层按钮） | ✅ | 无 | 官方移动端为全屏代码视图，我们暂以浮层复制为主，跳转 CodeViewer 作备注项 |
| 9 | 交互 | 深链头部 | 文件路径/提及/引用样式由官方 HTML 与 CSS 自带，无需额外解析 | ✅ | 无 | 关键卖点：零解析 |
| 10 | 主题 | 暗黑适配 | 注入 CSS 变量/媒体查询，跟随 ThemeMode 三态（system/light/dark）；ArkWeb 透明底不遮挡页面背景 | ✅ | 无 | css + token 映射写在组件内 |
| 11 | 性能 | 长文折叠 | 超长内容（> 阈值字符）默认折叠腰部，点击「展开全部」；避免整页 web 卡顿 | ⚠️ | 无 | 阈值 4000 字符可配（collapse=false 关闭折叠）；README 场景全量加载，无「展开全部」按钮 |
| 12 | 兜底 | 降级渲染 | HTML 拉取失败/网络异常 → 降级纯文本（bodyText / 原文）展示 + 重试按钮 | ✅ | 无 | 错误处理必须逐处接入 |
| 13 | 安全 | HTML 消毒 | 官方管线输出已消毒；POST /markdown 同理；不引入额外 sanitize 依赖 | ✅ | 无 | 若启用 lv 本地渲染则需自备转义（备注） |
| 14 | 能力 | 数学公式/自定义表情 | 官方 bodyHTML 不渲染 LaTeX 等扩展语法，保持与官方一致（不实现） | ❌ | 无 | 与官方差异：不做扩展；Mermaid 等不渲染（见五） |

> 可行性: 11/14 可行（其余 3 项为 ⚠️/❌：链接路由映射、长文折叠为 ⚠️；公式为 ❌ 与官方对齐）

---

## 四、核心 GraphQL 片段

```graphql
# 1) 已有 bodyHTML 的节点（各详情页查询直接补字段即可）：
query IssueDetail($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    issueOrPullRequest(number: $number) {
      __typename
      ... on Issue { # 或 PullRequest / Comment / Release / Discussion
        bodyHTML
      }
    }
  }
}

# 2) README：无 bodyHTML 字段，走 REST（优先）
# GET /repos/{owner}/{repo}/readme        Accept: application/vnd.github.html
#  → 纯 HTML 流（无 JSON 信封；内容含 <article class="markdown-body">…）
# 带分支：/repos/{owner}/{repo}/readme?ref={branch}

# 3) 任意 Markdown 渲染（评论预览等）：
# POST /markdown
#   {"text": "**bold**", "mode": "gfm", "context": "owner/repo"}
#  → 官方渲染的 HTML（已消毒，链接完整化）
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 公式 / Mermaid / 自定义注解 | 官方 GFM 渲染管线不输出这类 HTML，官方 App 同样不渲染 | 保持与官方一致，不做扩展渲染 |
| 站内链接全量路由 | 页面路由表有限（已实现页面为主） | 维护一张正则映射表：`/o/r`、`/o/r/issues\|pulls/{n}`、`/o/r/blob/{path}` 等命中即路由；未命中交系统浏览器 |
| 长文性能 | 单篇超大正文（>4000 字符）ArkWeb 内存开销 | 评论/Issue 场景默认折叠 + 展开；README 场景全量加载（collapse=false），按内容高度撑开整页 |
| 图片防盗链 | 某些仓库图片外链域名可能 403 | 依赖 Web 引擎默认行为 + 错误占位；不做代理转发（保持端侧不引入服务） |
| `POST /markdown` 未认证限流 | REST 免认证端为 60 req/h（与 OAuth token 同一配额） | 仅预览用，配合节流；优先使用 bodyHTML |
| ArkWeb 降级场景（低端机） | —— | 若真机性能不达标，切换 lv-markdown-in（纯 ArkUI，API 12 起，MIT）——备选方案需在 040 验收前决策并归档 |

---

## 六、TDD 验收标准

- [x] 测试 1：`MarkdownService.fetchReadmeHtml` 对公开仓库返回非空 html 字符串，包含 `markdown-body` 类名
- [x] 测试 2：README 不存在（404）时返回空态标记，组件渲染「no README」占位而非报错
- [x] 测试 3：`renderMarkdown` 对 `**bold**` 返回含 `<strong>` 的 HTML；对外链 `<a href>` 返回官方完整化的 URL
- [x] 测试 4：IssueDetail/PrDetail 正文在 mock GraphQL（含 bodyHTML）下，页面出现 Web 组件且加载内容含 `.markdown-body`
- [x] 测试 5：RepoDetail README 区域由裸 Text 替换为 MarkdownView，暗黑模式下背景透明、文字可用
- [x] 测试 6：MarkdownView 链接点击：站内 `/owner/repo` 触发路由回调；外链触发浏览器 want，回调不被吞
- [x] 测试 7：长文（>500 字符且超 240vp）默认折叠，点「展开全部」后按内容高度完整显示
- [x] 测试 8：网络失败时降级纯文本 + 重试按钮可恢复
- [x] 测试 9：代码块复制按钮点击后系统剪贴板内容与代码一致
- [x] 测试 10：全量替换后 grep 确认 RepoDetail/OrgProfile/IssueDetail/PrDetail 不再存在裸 README/body 纯 Text 渲染路径
- [x] 测试 11：预览（md 模式）在 041 接入后，输入 `- [ ] 任务` 渲染为任务列表（官方 gfm 行为一致）

---

## 七、备注

- **本 Spec 为本批（040-051）第一个开发任务**（2026-09-02 与用户确认）。基线样式约束（颜色/图标/字号 token 强制、页面骨架复用、分域 polish 收口策略）见 handoff「关键约定」；观感标准：README/正文渲染**直接对齐官方 `.markdown-body`**（不适用「先糙后美」，本 Spec 开发时即达标）。
- **选型依据（2026-09-02 调研）**：官方 App 移动端 = 服务端 GFM→HTML（GraphQL `bodyHTML`）经客户端 Web 呈现；ArkWeb + 官方 HTML = 我们与官方同管线，零解析差异；`github-markdown-css`（8923★/MIT）仅作样式底稿，颜色必须换用我们 `resources/base|dark/color.json` 的 Primer token 覆盖。
- **选型拍板（2026-09-03）**：用户确认**主方案（ArkWeb + 官方 HTML 管线）**，备选 `@luvi/lv-markdown-in` 不再作为前置决策项，仅当 ArkWeb 真机性能明显不达标时再单独评估（数据色板集中 `utils/MarkdownPalette.ets`，门禁白名单同 CodeTheme/LanguageColors 先例）。
- **实测发现（2026-09-03 模拟器验证，已固化进实现）**：① `onControllerAttached` 后立即 `loadData` 会被 Web 引擎丢弃（文档不加载/URL 停 about:blank），**延迟 300ms 再加载**；② README/contents 的 HTML 媒体类型（`application/vnd.github.html` / `html+json`）**一律返回纯 HTML 流，不存在 JSON 信封**（对 readme/contents/org profile 三个端点实测），统一 `vnd.github.html` 直取 body、**无分支解析**；③ 折叠态需 `body.style.overflow=hidden` 禁 Web 内滚（否则嵌套滚动会把「展开全部」卷走）；④ 复制按钮 = onPageEnd 注入 JS（`__mdReady` 防重）+ `javaScriptProxy` 桥（桥对象仅方法，label 走模块级变量）；⑤ 官方 HTML 的**相对路径不重写**（README 内 `frontend/public/logo.png`、`docs/x.webp`、`README_zh.md` 均原样保留；web 页面是 img→raw、a→blob 绝对化），MarkdownView 注入 `buildFixRelativeJs` 按 GitHub 网页行为重写（owner/repo/默认分支由调用方经 imgBase/linkBase 传入）；README 场景全量加载时 Web 高度钳到窗口高，超长内容由 Web 内滚（超大高度会白屏）。
- **待实机确认**：Dark 主题 CSS 变量切换（模拟器 token 无 user scope 无法进设置，逻辑=buildSetThemeJs 换 body class）；站内链接路由（routeOf 已单测全覆盖，外开实机验证通过）。
- **Discussion 描述接入点**：Spec 019 当前仅列表页（无讨论详情/正文渲染），故 040 未接入；MarkdownView 已按通用组件设计，讨论详情实现时直接喂 `bodyHTML` 即可。
- 备选纯 ArkUI 库 `@luvi/lv-markdown-in`（gitee 88star、60 版本、2026-08-15 还在发版、API 12 起、MIT）——优点无 Web 引擎开销；缺点本地解析与官方管线存在差异（如任务列表/表格细节）、需自调样式。决断点：真机（Pura 90 Pro）上 ArkWeb 首屏延迟 > 300ms 或出现明显滚动掉帧时启用。
- 本组件是 041（评论）/043（创建编辑）/046（搜索）/047（Releases）的共同前提，建议作为下一批第一个开发任务。
- 「README 直渲」现状（006）与 OrgProfile 的正则剥取逻辑（OrgProfile.ets `readmeLinesOf`）应在本 Spec 内移除，统一走组件。
