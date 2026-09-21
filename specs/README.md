# Specs 目录

> ArkCat 项目所有页面/功能的 Spec 文档

## 文件命名规范

- 格式：`NNN-name.md`（三位数字递增，短横线分隔）
- 模板：[`_TEMPLATE.md`](_TEMPLATE.md)

## Spec 索引

| 编号 | 文件 | 描述 | BFS Level | 状态 |
| ------ | ------ | ------ | ----------- | ------ |
| 001 | [home-tab.md](001-home-tab.md) | 首页 Tab（已被 013 替换） | Level 1 | deprecated |
| 002 | [inbox-tab.md](002-inbox-tab.md) | 通知收件箱 Tab | Level 1 | implemented |
| 003 | [explore-tab.md](003-explore-tab.md) | 发现探索 Tab（已被 056 取代） | Level 1 | deprecated |
| 004 | [copilot-tab.md](004-copilot-tab.md) | AI 助手 Tab（已被 060 移除：上架合规） | Level 1 | deprecated |
| 005 | [user-profile.md](005-user-profile.md) | 用户个人主页 | Level 3 | implemented |
| 006 | [repo-detail.md](006-repo-detail.md) | 仓库详情页（官方布局对齐） | Level 3 | implemented |
| 007 | [issues-list.md](007-issues-list.md) | Issue 列表页 | Level 3 | implemented |
| 008 | [pr-list.md](008-pr-list.md) | PR 列表页（已被 027 实现） | Level 3 | deprecated |
| 009 | [pr-detail.md](009-pr-detail.md) | PR 详情页（已被 031 实现） | Level 3 | deprecated |
| 010 | [pr-diff.md](010-pr-diff.md) | PR Diff / Files Changed | Level 3 | implemented |
| 011 | [code-viewer.md](011-code-viewer.md) | 代码文件查看页（行号/高亮/Code Options 联动） | Level 3 | implemented |
| 012 | [i18n.md](012-i18n.md) | 国际化（英/简中，默认英语） | Level 4 | implemented |
| 013 | [home-official.md](013-home-official.md) | Home Tab 官方布局（My Work/Favorites/Shortcuts） | Level 1 | implemented |
| 014 | [settings.md](014-settings.md) | Settings 设置页 | Level 3 | implemented |
| 015 | [search.md](015-search.md) | 全局搜索页 | Level 3 | implemented |
| 016 | [edit-my-work.md](016-edit-my-work.md) | Edit My Work（Home 工作区条目编辑） | Level 3 | implemented |
| 017 | [work-issues.md](017-work-issues.md) | 工作区 Issue 列表（跨仓库） | Level 3 | implemented |
| 018 | [work-prs.md](018-work-prs.md) | 工作区 PR 列表（跨仓库） | Level 3 | implemented |
| 019 | [discussions.md](019-discussions.md) | 工作区 Discussion 列表 | Level 3 | implemented |
| 020 | [projects.md](020-projects.md) | 工作区 Projects 列表 | Level 3 | implemented |
| 021 | [top-repos.md](021-top-repos.md) | 工作区 Top Repositories | Level 3 | implemented |
| 022 | [organizations.md](022-organizations.md) | 工作区 Organizations | Level 3 | implemented |
| 023 | [starred-repos.md](023-starred-repos.md) | 工作区 Starred Repositories | Level 3 | implemented |
| 024 | [octicons.md](024-octicons.md) | Octicons 图标资产引入（横向） | Level 4 | implemented |
| 025 | [release-prep.md](025-release-prep.md) | 发布与开源准备（License/声明/上架清单） | Level 4 | implemented |
| 026 | [dark-mode.md](026-dark-mode.md) | 暗黑模式（三态主题，横向） | Level 4 | implemented |
| 027 | [repo-pr-list.md](027-repo-pr-list.md) | 仓库内 PR 列表 | Level 3 | implemented |
| 028 | [repo-commits.md](028-repo-commits.md) | 仓库 Commits 列表 | Level 3 | implemented |
| 029 | [repo-releases.md](029-repo-releases.md) | 仓库 Releases 页 | Level 3 | implemented |
| 030 | [issue-detail.md](030-issue-detail.md) | Issue 详情页 | Level 3 | implemented |
| 031 | [pr-detail.md](031-pr-detail.md) | PR 详情页（Changes/Status/Conversation） | Level 3 | implemented |
| 032 | [notifications-settings.md](032-notifications-settings.md) | 设置 → 通知选项二级页 | Level 3 | implemented |
| 033 | [code-options.md](033-code-options.md) | 设置 → 代码查看选项（Code Options） | Level 3 | implemented |
| 034 | [user-list-followers-following.md](034-user-list-followers-following.md) | Followers / Following 列表 | Level 3 | implemented |
| 035 | [org-list-profile-restructure.md](035-org-list-profile-restructure.md) | Profile 重构 + 组织列表 | Level 3 | implemented |
| 036 | [org-profile.md](036-org-profile.md) | 组织主页 | Level 3 | implemented |
| 037 | [repositories-list.md](037-repositories-list.md) | 仓库列表（筛选/排序） | Level 3 | implemented |
| 038 | [file-tree.md](038-file-tree.md) | 仓库文件列表页（Files） | Level 3 | implemented |
| 039 | [primer-design-system.md](039-primer-design-system.md) | GitHub Primer 设计系统接入（横向规范） | Level 4 | implemented |
| 040 | [markdown-render.md](040-markdown-render.md) | Markdown 渲染底座（MarkdownView + MarkdownService，横向） | Level 4 | implemented |
| 041 | [comments-reactions.md](041-comments-reactions.md) | 评论与反应（Issue/PR 统一书写链路） | Level 3 | implemented |
| 042 | [pr-review-merge.md](042-pr-review-merge.md) | PR 代码审阅与合并（review threads + merge 选项） | Level 3 | implemented |
| 043 | [issue-pr-create-edit.md](043-issue-pr-create-edit.md) | Issue/PR 创建与编辑（生命周期） | Level 3 | implemented |
| 044 | [triage-editors.md](044-triage-editors.md) | Issue/PR 元数据编排（Labels/Assignees/Milestone/Projects） | Level 3 | implemented |
| 045 | [notifications-subscriptions.md](045-notifications-subscriptions.md) | 通知与订阅增强（Inbox 高级 + 仓库 Watch） | Level 3 | draft |
| 046 | [search-full.md](046-search-full.md) | 搜索全类型与最近搜索（Search 六类详情） | Level 3 | implemented |
| 047 | [releases-detail-download.md](047-releases-detail-download.md) | Release 详情与资产下载 | Level 3 | implemented |
| 048 | [actions-checks.md](048-actions-checks.md) | Actions/Checks 状态检查（Check runs 列表/详情/重跑） | Level 3 | approved |
| 049 | [multi-account-security.md](049-multi-account-security.md) | 多账号与安全（049a 账号管理器已实现；App Lock 拆出至 066） | Level 3 | implemented |
| 050 | [home-favorites-shortcuts.md](050-home-favorites-shortcuts.md) | Home 个性化（Favorites 收藏；Shortcuts 拆分至 074） | Level 3 | implemented |
| 051 | [accessibility-multidevice.md](051-accessibility-multidevice.md) | 无障碍与多设备适配（横向规范） | Level 4 | draft |
| 052 | [achievement-detail.md](052-achievement-detail.md) | 成就详情页（徽章大图/事件/分享） | Level 3 | implemented |
| 053 | [repo-stargazers-forks.md](053-repo-stargazers-forks.md) | 仓库 Stargazers / Forks 列表 | Level 3 | implemented |
| 054 | [repo-contributors-watchers.md](054-repo-contributors-watchers.md) | 仓库 Contributors / Watchers 列表 | Level 3 | implemented |
| 055 | [repo-license.md](055-repo-license.md) | 仓库 License 正文页 | Level 3 | implemented |
| 056 | [explore-page.md](056-explore-page.md) | Explore 官方化（Discover 入口 + Trending/Awesome + Activity） | Level 1 | implemented |
| 057 | [oauth-login.md](057-oauth-login.md) | OAuth 登录（Device Flow） | Level 0 | implemented |
| 058 | [copilot-ui.md](058-copilot-ui.md) | Copilot UI 架子（已被 059 取代：mock 换真实 API） | Level 1 | deprecated |
| 059 | [copilot-chat.md](059-copilot-chat.md) | Copilot 真实对话（已被 060 移除：上架合规，Copilot 三关无解） | Level 1 | deprecated |
| 060 | [profile-tab-remove-copilot.md](060-profile-tab-remove-copilot.md) | 底栏结构调整（tab4 = 我的主页 Tab，图标为账号头像）+ Copilot 移除 | Level 1 | implemented |
| 061 | [share-system-panel.md](061-share-system-panel.md) | 全应用分享按钮统一走系统分享面板（ShareKit） | Level 1 | implemented |
| 062 | [secondary-header-icons.md](062-secondary-header-icons.md) | 二级页顶栏图标统一（share-android 蓝 + 蓝色竖三点；含 Issue 详情） | Level 2 | implemented |
| 063 | [issues-list-header.md](063-issues-list-header.md) | 仓库 Issue 列表顶栏改版（两行标题 owner/name + 顶栏内联搜索 + circle-plus） | Level 3 | implemented |
| 064 | [open-source-libraries.md](064-open-source-libraries.md) | 开源库披露页（Octicons/Primer MIT 条目） | Level 3 | implemented |
| 065 | [share-feedback-discussions.md](065-share-feedback-discussions.md) | Share Feedback → 仓库 Discussions（REST 开启 has_discussions + repo 限定模式） | Level 3 | implemented |
| 066 | [app-lock.md](066-app-lock.md) | App Lock（设备凭据锁定：Toggle 子页 + 后台回前台/冷启动系统认证） | Level 3 | implemented |
| 067 | [appbar-unification.md](067-appbar-unification.md) | 统一 App Bar 组件（行高 48/内边距 16/中心距 44/图标 20） | Level 2 | implemented |
| 068 | [filter-interaction.md](068-filter-interaction.md) | 筛选交互统一约定（dirty 徽标/RESET ALL FILTERS/面板规范，全库跨页） | Level — | implemented |
| 069 | [settings-about.md](069-settings-about.md) | Settings About 行与关于页（备案号/Star 引导仓库行，静态零网络） | Level 2 | implemented |
| 070 | [create-repository.md](070-create-repository.md) | New Repository 两步弹层（General/Options） | Level 3 | implemented |
| 071 | [branch-picker-contribute.md](071-branch-picker-contribute.md) | 分支行 Choose Branch + CONTRIBUTE 复用 prCompare | Level 3 | implemented |
| 072 | [profile-popular-fallback.md](072-profile-popular-fallback.md) | 主页 Popular 兜底区（无 Pin 时 star 降序前 6） | Level 3 | implemented |
| 073 | [profile-nav-sponsoring-projects.md](073-profile-nav-sponsoring-projects.md) | 主页导航行 Sponsoring/Projects 增补 | Level 3 | implemented |
| 074 | [shortcuts.md](074-shortcuts.md) | Home Shortcuts 快捷方式（已保存搜索：管理页 + 创建页 + 端侧存储） | Level 3 | approved |

## 覆盖率

> 以下为 2026-08 初始 BFS 分析（前 11 份 spec）的统计，后续 spec 未重新统计，仅作历史参考。

| 指标 | 数值 |
| ------ | ------ |
| 已分析 Spec 数 | 11（初始批次） |
| 已分析元素总数 | 123+ |
| 核心场景覆盖率 | ~95%（按使用频率加权） |
| GraphQL 可覆盖 | ~85% |
| 需 REST 兜底 | ~15% |

## 不可实现功能汇总

| Tab/页面 | 功能 | 原因 | ArkCat 处理 |
| --------- | ------ | ------ | -------------- |
| Explore | Collections 精选集合 | 无公开 API | MVP 隐藏 |
| Copilot | 全部 Chat 功能 | 上架合规不可行（模型方算法备案号 + 合作协议 + 境内可达性 + 生成内容标识，四项无解） | 功能与入口已移除（060） |
| User Profile | Packages Tab | 无公开用户级 API | 不展示 |
| Repo Detail | Packages/Settings Tab | 无公开 API / 无意义 | 不展示 |
