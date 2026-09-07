# Spec 013: Home Tab 官方布局对齐（My Work / Favorites / Shortcuts）

> BFS Level: 1
> 关联截图: GitHub 官方 App Home Tab（用户提供，2026-08-31）
> 上游 Spec: 001（本次整体替换 001 的首页内容，001 状态转 deprecated）
> 状态: implemented（2026-08-31，模拟器中文系统实机截图验收通过）

---

## 一、页面/功能概述

对照 GitHub 官方 App 的 Home Tab 截图，将 ArkCat 首页从「用户卡片 + 贡献日历 + Pinned 仓库」重构为官方布局：

- **Header**：`Home` 标题 + 搜索/刷新/新建/头像 四个操作
- **My Work**：Issues / Pull Requests / Discussions / Projects / Top Repositories / Organizations / Starred 七个彩色图标入口（点击进对应列表页，见 017-023）
- **Favorites**：收藏仓库空态（说明文案 + `ADD FAVORITES` 按钮）
- **Shortcuts**：彩色圆形图标行 + 引导文案 + `GET STARTED` 按钮

原首页的用户卡片、贡献日历、Pinned 仓库均保留（贡献日历与 Pinned 已在个人主页 Spec 005 呈现），不在首页重复展示。未读角标从首页 Header 迁移到底部 Inbox Tab（与官方 App 一致）。

---

## 二、整体 UI 结构

1. 顶部 Header：Home 标题 + 🔍 搜索 + 🔄 刷新 + ＋ 新建 + 🖼 头像（← Header：搜索/刷新/新建/头像）
2. My Work 区块：区块标题 + ⋯ 更多菜单
   - 七个彩色圆点图标入口：Issues / Pull Requests / Discussions / Projects / Top Repositories / Organizations / Starred
3. Favorites 区块：标题 + 空态文案（Add favorite repositories ...）+ ADD FAVORITES 按钮
4. Shortcuts 区块：标题 + 彩色图标行（⚡ ✓ ⑂ ❞ ▤ ⌂ ★ ▦）+ 引导文案（The things you need, one tap away / Fast access your lists of ...）+ GET STARTED 按钮
5. 底部导航：Home / Inbox / Explore / Copilot 四个 Tab（🏠 🏔 🧭 🤖 图标）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | Header 左 | `Home` 标题 | 页面标题 | ✅ | —（纯 UI） | — |
| 2 | Header 右 | 🔍 搜索 | 进入搜索页 | ✅ | —（纯 UI） | 复用 home_search_hint；路由见 015/046 |
| 3 | Header 右 | 🔄 刷新 | 重新拉取 viewer 基础信息 | ✅ | `viewer { login name avatarUrl }` | — |
| 4 | Header 右 | ＋ 新建 | 提示新建在后续版本提供 | ✅ | —（纯 UI） | — |
| 5 | Header 右 | 头像 | 点击进入查看者个人主页 | ✅ | `viewer.avatarUrl/login` | 路由复用 userProfile |
| 6 | My Work | 区块标题 + ⋯ | 打开编辑页（016） | ✅ | —（纯 UI） | 路由 editMyWork |
| 7 | My Work | 七行彩色入口 | 点击进入对应列表（见 017-023） | ✅ | —（纯 UI） | 路由至对应列表页 |
| 8 | Favorites | 空态文案 + ADD FAVORITES | 收藏仓库入口 | ✅ | —（纯 UI） | 添加流程后续 Spec；无数据即空态 |
| 9 | Shortcuts | 图标行 + 文案 + GET STARTED | 快捷引导 | ✅ | —（纯 UI） | 点击提示 |
| 10 | 底部 Tab | Inbox 未读蓝点 | 未读通知提示 | ✅ | REST `/notifications?per_page=1` | 复用 REST 兜底，从旧 Home 迁移 |

> 可行性比例声明：10/10 可行。

---

## 四、核心 GraphQL 片段

```graphql
# Header 头像/登录名（My Work 等区块为静态入口，无数据依赖）
query ViewerBasic {
  viewer {
    login
    name
    avatarUrl
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| My Work 各列表页（我的 Issue/PR/Discussion 等） | 列表页设计超出本 Spec 范围 | 本次只做入口 UI，点击提示「将在后续 Spec 提供」，列表页立项后接入 |
| Favorites 添加/移除流程 | 需要仓库选择器与本地持久化，独立 Spec | 本次只做空态 UI 与 ADD FAVORITES 按钮，点击提示 |
| Shortcuts 配置化（用户可编辑） | 官方 App 有自定义配置，超出 MVP | 展示固定图标行 + GET STARTED 引导 |
| 官方图标（Octicons 线框白描） | 未引入图标库 | 使用单色 Unicode 字形 + 彩色圆角底，色系对齐官方 |
| 原首页用户卡片/贡献日历/Pinned 仓库 | 官方 App 首页无此内容 | 从首页移除；贡献日历与 Pinned 已在个人主页（Spec 005）呈现，功能不丢失 |

---

## 六、TDD 验收标准

- [x] 测试 1：`mapViewerBasic` 纯函数：login/name/avatarUrl 字段映射，缺失字段回退空串（ohosTest 实跑 20/20 通过）
- [x] 测试 2：base 与 zh_CN 新增 string key 集合一致（脚本比对，100/100 对齐）
- [x] 测试 3：grep 检查 Home.ets 无中文字符串字面量残留（i18n 约定）
- [x] 测试 4：`devecocli build` 全量构建通过（含 clean 重编）
- [x] 测试 5：模拟器实测——首页展示 My Work 七行入口、Favorites 空态、Shortcuts 引导（滚动截图验收）；头像点击进入个人主页 @ZM-BAD
- [x] 测试 6：模拟器实测——Inbox Tab 蓝点逻辑接入（当前账号无未读通知，蓝点未显示，符合逻辑）
- [x] 测试 7：`bash scripts/check-spec.sh` 通过

---

## 七、备注

- 首页移除的「用户卡片」查询（viewer followers/following/bio）不再在 Home 使用，`UserCard` 组件保留（供后续页面复用）。
- 彩色入口色系对齐官方：Issues 绿 `#2DA44E`、PR 蓝 `#3C78D8`、Discussions 紫 `#8250DF`、Projects 灰 `#57606A`、Top Repos 黑 `#24292F`、Organizations 橙 `#E87B2E`、Starred 黄 `#E3B341`。
- 未读蓝点（而非红点数字）：官方 App Inbox Tab 为蓝点样式；查询逻辑复用 HomeService.hasUnreadNotifications。
