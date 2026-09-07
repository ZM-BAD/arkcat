# Specs 目录

> StarRaft 项目所有页面/功能的 Spec 文档

## 文件命名规范

- 格式：`NNN-name.md`（三位数字递增，短横线分隔）
- 模板：[`_TEMPLATE.md`](_TEMPLATE.md)

## Spec 索引

| 编号 | 文件 | 描述 | BFS Level | 状态 |
| ------ | ------ | ------ | ----------- | ------ |
| 001 | [home-tab.md](001-home-tab.md) | 首页 Tab（已被 013 替换） | Level 1 | deprecated |
| 002 | [inbox-tab.md](002-inbox-tab.md) | 通知收件箱 Tab | Level 1 | ✅ |
| 003 | [explore-tab.md](003-explore-tab.md) | 发现探索 Tab | Level 1 | ✅ |
| 004 | [copilot-tab.md](004-copilot-tab.md) | AI 助手 Tab | Level 1 | ✅ |
| 005 | [user-profile.md](005-user-profile.md) | 用户个人主页 | Level 3 | ✅ |
| 006 | [repo-detail.md](006-repo-detail.md) | 仓库详情页（官方布局对齐） | Level 3 | ✅ |
| 007 | [issues-list.md](007-issues-list.md) | Issue 列表页 | Level 3 | ✅ |
| 008 | [pr-list.md](008-pr-list.md) | PR 列表页（已被 027 实现） | Level 3 | deprecated |
| 009 | [pr-detail.md](009-pr-detail.md) | PR 详情页（已被 031 实现） | Level 3 | deprecated |
| 010 | [pr-diff.md](010-pr-diff.md) | PR Diff / Files Changed | Level 3 | ✅ |
| 011 | [code-viewer.md](011-code-viewer.md) | 代码文件查看页（行号/高亮/Code Options 联动） | Level 3 | ✅ |
| 015 | [search.md](015-search.md) | 全局搜索页 | Level 3 | ✅ |
| 016 | [edit-my-work.md](016-edit-my-work.md) | Edit My Work（Home 工作区条目编辑） | Level 3 | ✅ |
| 017 | [work-issues.md](017-work-issues.md) | 工作区 Issue 列表（跨仓库） | Level 3 | ✅ |
| 018 | [work-prs.md](018-work-prs.md) | 工作区 PR 列表（跨仓库） | Level 3 | ✅ |
| 019 | [discussions.md](019-discussions.md) | 工作区 Discussion 列表 | Level 3 | ✅ |
| 020 | [projects.md](020-projects.md) | 工作区 Projects 列表 | Level 3 | ✅ |
| 021 | [top-repos.md](021-top-repos.md) | 工作区 Top Repositories | Level 3 | ✅ |
| 022 | [organizations.md](022-organizations.md) | 工作区 Organizations | Level 3 | ✅ |
| 023 | [starred-repos.md](023-starred-repos.md) | 工作区 Starred Repositories | Level 3 | ✅ |
| 024 | [octicons.md](024-octicons.md) | Octicons 图标资产引入（横向） | Level 4 | ✅ |
| 025 | [release-prep.md](025-release-prep.md) | 发布与开源准备（License/声明/上架清单） | Level 4 | ✅ |
| 026 | [dark-mode.md](026-dark-mode.md) | 暗黑模式（三态主题，横向） | Level 4 | ✅ |
| 027 | [repo-pr-list.md](027-repo-pr-list.md) | 仓库内 PR 列表 | Level 3 | ✅ |
| 028 | [repo-commits.md](028-repo-commits.md) | 仓库 Commits 列表 | Level 3 | ✅ |
| 029 | [repo-releases.md](029-repo-releases.md) | 仓库 Releases 页 | Level 3 | ✅ |
| 030 | [issue-detail.md](030-issue-detail.md) | Issue 详情页 | Level 3 | ✅ |
| 031 | [pr-detail.md](031-pr-detail.md) | PR 详情页（Changes/Status/Conversation） | Level 3 | ✅ |
| 032 | [notifications-settings.md](032-notifications-settings.md) | 设置 → 通知选项二级页 | Level 3 | ✅ |
| 033 | [code-options.md](033-code-options.md) | 设置 → 代码查看选项（Code Options） | Level 3 | ✅ |
| 034 | [user-list-followers-following.md](034-user-list-followers-following.md) | Followers / Following 列表 | Level 3 | ✅ |
| 035 | [org-list-profile-restructure.md](035-org-list-profile-restructure.md) | Profile 重构 + 组织列表 | Level 3 | ✅ |
| 036 | [org-profile.md](036-org-profile.md) | 组织主页 | Level 3 | ✅ |
| 037 | [repositories-list.md](037-repositories-list.md) | 仓库列表（筛选/排序） | Level 3 | ✅ |
| 038 | [file-tree.md](038-file-tree.md) | 仓库文件列表页（Files） | Level 3 | ✅ |
| 039 | [primer-design-system.md](039-primer-design-system.md) | GitHub Primer 设计系统接入（横向规范） | Level 4 | ✅ |
| 040 | [markdown-render.md](040-markdown-render.md) | Markdown 渲染底座（MarkdownView + MarkdownService，横向） | Level 4 | draft |
| 041 | [comments-reactions.md](041-comments-reactions.md) | 评论与反应（Issue/PR/Discussion 统一书写链路） | Level 3 | draft |
| 042 | [pr-review-merge.md](042-pr-review-merge.md) | PR 代码审阅与合并（review threads + merge 选项） | Level 3 | draft |
| 043 | [issue-pr-create-edit.md](043-issue-pr-create-edit.md) | Issue/PR 创建与编辑（生命周期） | Level 3 | draft |
| 044 | [triage-editors.md](044-triage-editors.md) | Issue/PR 元数据编排（Labels/Assignees/Milestone/Projects） | Level 3 | draft |
| 045 | [notifications-subscriptions.md](045-notifications-subscriptions.md) | 通知与订阅增强（Inbox 高级 + 仓库 Watch） | Level 3 | draft |
| 046 | [search-full.md](046-search-full.md) | 搜索全类型与最近搜索（Search 五类详情） | Level 3 | draft |
| 047 | [releases-detail-download.md](047-releases-detail-download.md) | Release 详情与资产下载 | Level 3 | draft |
| 048 | [actions-checks.md](048-actions-checks.md) | Actions/Checks 状态检查（Check runs 详情 + 一键重跑） | Level 3 | draft |
| 049 | [multi-account-security.md](049-multi-account-security.md) | 多账号与安全（账号管理器 + App Lock 探测） | Level 3 | draft |
| 050 | [home-favorites-shortcuts.md](050-home-favorites-shortcuts.md) | Home 个性化（Favorites 收藏 + Shortcuts 快捷入口） | Level 3 | draft |
| 051 | [accessibility-multidevice.md](051-accessibility-multidevice.md) | 无障碍与多设备适配（横向规范） | Level 4 | draft |
| 057 | [oauth-login.md](057-oauth-login.md) | OAuth 登录（Device Flow，与 PAT 并存） | Level 0 | draft |
| 012 | [i18n.md](012-i18n.md) | 国际化（英/简中，默认英语） | Level 4 | ✅ |
| 013 | [home-official.md](013-home-official.md) | Home Tab 官方布局（My Work/Favorites/Shortcuts） | Level 1 | ✅ |
| 014 | [settings.md](014-settings.md) | Settings 设置页 | Level 3 | ✅ implemented |

## 覆盖率

| 指标 | 数值 |
| ------ | ------ |
| 已分析 Spec 数 | 11 |
| 已分析元素总数 | 123+ |
| 核心场景覆盖率 | ~95%（按使用频率加权） |
| GraphQL 可覆盖 | ~85% |
| 需 REST 兜底 | ~15% |

## 不可实现功能汇总

| Tab/页面 | 功能 | 原因 | StarRaft 处理 |
| --------- | ------ | ------ | -------------- |
| Explore | Collections 精选集合 | 无公开 API | MVP 隐藏 |
| Copilot | 全部 Chat 功能 | Copilot API 不公开 | 展示 Empty State |
| User Profile | Packages Tab | 无公开用户级 API | 不展示 |
| Repo Detail | Packages/Settings Tab | 无公开 API / 无意义 | 不展示 |
